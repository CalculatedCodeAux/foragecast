#!/usr/bin/env python3
"""
Enrich plant_metadata with:
  - Common names, family, photos from iNaturalist API
  - Edibility info from PFAF (Plants For A Future) website

Prioritizes plants with most observations in the database.

Usage:
  python -m scripts.enrich_plants [--limit 500]
"""
import argparse
import json
import logging
import re
import sys
import time
from pathlib import Path

import requests
from bs4 import BeautifulSoup
from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import SessionLocal

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

INAT_API = "https://api.inaturalist.org/v1"
PFAF_URL = "https://pfaf.org/user/Plant.aspx?LatinName="
HEADERS = {"User-Agent": "ForageCast/1.1.0 (plant enrichment)"}


def fetch_inat_taxon(taxon_id: int) -> dict | None:
    """Fetch taxon info from iNaturalist API."""
    try:
        resp = requests.get(
            f"{INAT_API}/taxa/{taxon_id}",
            headers=HEADERS,
            timeout=15,
        )
        if resp.status_code == 200:
            results = resp.json().get("results", [])
            return results[0] if results else None
        elif resp.status_code == 429:
            log.warning("iNat rate limited, sleeping 10s...")
            time.sleep(10)
            return fetch_inat_taxon(taxon_id)
    except Exception as e:
        log.warning(f"iNat API error for taxon {taxon_id}: {e}")
    return None


def extract_inat_data(taxon: dict) -> dict:
    """Extract common name, family, and photos from iNat taxon."""
    data = {}

    # Common name
    name = taxon.get("preferred_common_name")
    if name:
        data["common_name"] = name.title()

    # Family from ancestors
    for ancestor in taxon.get("ancestors", []):
        if ancestor.get("rank") == "family":
            data["family"] = ancestor.get("name")
            break

    # Photos from taxon_photos (CC-licensed observation photos)
    photos = []
    for tp in taxon.get("taxon_photos", [])[:4]:
        photo = tp.get("photo", {})
        url = photo.get("medium_url") or photo.get("url", "")
        if not url:
            continue
        url = url.replace("/square.", "/medium.")
        photos.append({
            "url": url,
            "label": "Observation photo",
            "attribution": photo.get("attribution", "iNaturalist CC"),
        })
    if photos:
        data["photos"] = photos

    return data


def fetch_pfaf_data(scientific_name: str) -> dict:
    """Scrape PFAF for edibility, medicinal uses, and warnings."""
    data = {}
    try:
        # PFAF uses the binomial (first two words)
        binomial = " ".join(scientific_name.split()[:2])
        resp = requests.get(
            PFAF_URL + binomial.replace(" ", "+"),
            headers=HEADERS,
            timeout=15,
        )
        if resp.status_code != 200:
            return data

        soup = BeautifulSoup(resp.text, "html.parser")

        # Check if the plant was found (PFAF shows a results page if not)
        if "Search results" in (soup.title.string or ""):
            return data

        # Edible uses — look for the edible uses section
        edible_parts = []
        edible_section = None

        # PFAF has tables with ratings and descriptions
        for td in soup.find_all("td"):
            text = td.get_text(strip=True)
            if "Edible Parts:" in text:
                parts_text = text.replace("Edible Parts:", "").strip()
                if parts_text:
                    for part in re.split(r"[;,.]", parts_text):
                        part = part.strip().rstrip(".")
                        if part and len(part) > 1:
                            edible_parts.append({
                                "part": part,
                                "preparation": "",
                            })
            if "Edible Uses:" in text:
                edible_section = text.replace("Edible Uses:", "").strip()

        # If we got edible parts, try to match preparation from edible uses text
        if edible_parts and edible_section:
            # Use the full edible description as preparation for the first part
            # and distribute info if possible
            if len(edible_parts) == 1:
                edible_parts[0]["preparation"] = _truncate(edible_section, 200)
            else:
                # Put full text on first, brief on rest
                for ep in edible_parts:
                    part_lower = ep["part"].lower()
                    # Find sentences mentioning this part
                    sentences = edible_section.split(".")
                    relevant = [s.strip() for s in sentences if part_lower in s.lower()]
                    if relevant:
                        ep["preparation"] = _truncate(". ".join(relevant) + ".", 200)
                # If no specific sentences matched, use general text
                for ep in edible_parts:
                    if not ep["preparation"]:
                        ep["preparation"] = _truncate(edible_section, 150)

        if edible_parts:
            data["edible_parts"] = edible_parts

        # Medicinal / traditional uses
        for td in soup.find_all("td"):
            text_content = td.get_text(strip=True)
            if "Medicinal Uses" in text_content and len(text_content) > 30:
                uses = text_content.replace("Medicinal Uses", "").strip()
                if uses.startswith(":"):
                    uses = uses[1:].strip()
                if uses and len(uses) > 10:
                    data["traditional_uses"] = _truncate(uses, 500)
                break

        # Known hazards / warnings
        for td in soup.find_all("td"):
            text_content = td.get_text(strip=True)
            if "Known Hazards" in text_content and len(text_content) > 20:
                hazard = text_content.replace("Known Hazards", "").strip()
                if hazard.startswith(":"):
                    hazard = hazard[1:].strip()
                if hazard and hazard.lower() not in ("none known", "none.", "none known."):
                    data["warnings"] = [{
                        "type": "toxicity",
                        "severity": "medium",
                        "title": "Known Hazards",
                        "description": _truncate(hazard, 300),
                    }]
                break

    except Exception as e:
        log.warning(f"PFAF error for {scientific_name}: {e}")

    return data


def _truncate(s: str, max_len: int) -> str:
    if len(s) <= max_len:
        return s
    return s[:max_len-3].rsplit(" ", 1)[0] + "..."


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=500)
    args = parser.parse_args()

    db = SessionLocal()

    # Get plants needing enrichment, sorted by observation count
    rows = db.execute(text("""
        SELECT pm.id, pm.taxon_id, pm.common_name, pm.scientific_name,
               pm.family, pm.photos, pm.edible_parts, pm.traditional_uses,
               pm.warnings,
               count(o.id) as obs_count
        FROM plant_metadata pm
        LEFT JOIN observations o ON pm.taxon_id = o.taxon_id
        GROUP BY pm.id
        ORDER BY count(o.id) DESC
        LIMIT :limit
    """), {"limit": args.limit}).fetchall()

    log.info(f"Processing {len(rows)} plants")
    enriched = 0

    for i, row in enumerate(rows):
        plant_id, taxon_id = row[0], row[1]
        current_common, scientific_name = row[2], row[3]
        current_family = row[4]
        current_photos = row[5]
        current_edible = row[6]
        current_uses = row[7]
        current_warnings = row[8]
        obs_count = row[9]

        needs_inat = (
            current_common == scientific_name
            or not current_family
            or not current_photos or current_photos == []
        )
        needs_pfaf = (
            not current_edible or current_edible == []
        )

        if not needs_inat and not needs_pfaf:
            continue

        log.info(f"[{i+1}/{len(rows)}] {scientific_name} (obs={obs_count})")

        updates = {}
        params = {"plant_id": plant_id}

        # iNaturalist: common name, family, photos
        if needs_inat:
            inat = fetch_inat_taxon(taxon_id)
            if inat:
                inat_data = extract_inat_data(inat)
                if "common_name" in inat_data and current_common == scientific_name:
                    updates["common_name = :common_name"] = True
                    params["common_name"] = inat_data["common_name"]
                if "family" in inat_data and not current_family:
                    updates["family = :family"] = True
                    params["family"] = inat_data["family"]
                if "photos" in inat_data and (not current_photos or current_photos == []):
                    updates["photos = :photos::jsonb"] = True
                    params["photos"] = json.dumps(inat_data["photos"])
            time.sleep(1.1)  # iNat rate limit

        # PFAF: edibility, uses, warnings
        if needs_pfaf:
            pfaf = fetch_pfaf_data(scientific_name)
            if pfaf:
                if "edible_parts" in pfaf and (not current_edible or current_edible == []):
                    updates["edible_parts = :edible_parts::jsonb"] = True
                    params["edible_parts"] = json.dumps(pfaf["edible_parts"])
                if "traditional_uses" in pfaf and not current_uses:
                    updates["traditional_uses = :traditional_uses"] = True
                    params["traditional_uses"] = pfaf["traditional_uses"]
                if "warnings" in pfaf and (not current_warnings or current_warnings == []):
                    updates["warnings = :warnings::jsonb"] = True
                    params["warnings"] = json.dumps(pfaf["warnings"])
            time.sleep(0.5)  # Be nice to PFAF

        if updates:
            set_clause = ", ".join(updates.keys())
            db.execute(
                text(f"UPDATE plant_metadata SET {set_clause} WHERE id = :plant_id"),
                params,
            )
            enriched += 1
            log.info(f"  Updated: {list(updates.keys())}")

        if (i + 1) % 25 == 0:
            db.commit()

    db.commit()
    log.info(f"Done. Enriched {enriched}/{len(rows)} plants.")
    db.close()


if __name__ == "__main__":
    main()
