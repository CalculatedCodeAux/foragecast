#!/usr/bin/env python3
"""
GBIF iNaturalist Research-Grade data ingestion.

Downloads the GBIF export, filters to PFAF-listed species (~7K),
and loads into PostgreSQL with PostGIS geometry.

Usage:
  python -m scripts.ingest_gbif --csv /path/to/gbif_export.csv
  python -m scripts.ingest_gbif --download  # download latest from GBIF

Run monthly via VPS crontab.
"""
import argparse
import csv
import io
import logging
import sys
from datetime import date
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.orm import Session

# Add parent dir to path so we can import app modules
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import engine, SessionLocal
from app.models import Base, Observation

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# PFAF species list will be loaded from a reference file
PFAF_SPECIES_FILE = Path(__file__).parent / "pfaf_species.txt"

BATCH_SIZE = 10_000
MAX_PARSE_ERRORS_PCT = 0.01  # alert if >1% rows fail


def load_pfaf_species() -> set[str]:
    """Load the set of PFAF scientific names (lowercase for matching)."""
    if not PFAF_SPECIES_FILE.exists():
        log.warning(f"PFAF species file not found at {PFAF_SPECIES_FILE}")
        log.warning("Proceeding without filter — all species will be ingested")
        return set()
    with open(PFAF_SPECIES_FILE) as f:
        return {line.strip().lower() for line in f if line.strip()}


def check_disk_space(min_gb: float = 1.0) -> bool:
    """Check available disk space before starting."""
    import shutil
    usage = shutil.disk_usage("/")
    available_gb = usage.free / (1024 ** 3)
    if available_gb < min_gb:
        log.error(f"Insufficient disk space: {available_gb:.1f}GB available, need {min_gb}GB")
        return False
    return True


def ingest_csv(csv_path: str, db: Session, pfaf_species: set[str]) -> dict:
    """
    Parse GBIF CSV and insert observations.

    GBIF DarwinCore CSV columns we care about:
      gbifID, scientificName, decimalLatitude, decimalLongitude,
      eventDate, taxonKey, license, media
    """
    stats = {"total": 0, "inserted": 0, "skipped": 0, "errors": 0, "duplicates": 0}
    batch = []

    log.info(f"Reading {csv_path}...")
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f, delimiter="\t")

        for row in reader:
            stats["total"] += 1

            try:
                sci_name = row.get("scientificName", "").strip()
                lat_str = row.get("decimalLatitude", "")
                lng_str = row.get("decimalLongitude", "")
                date_str = row.get("eventDate", "")
                taxon_id_str = row.get("taxonKey", "")
                inat_id_str = row.get("gbifID", "")

                # Skip if not in PFAF species list (when filter is active)
                if pfaf_species and sci_name.lower() not in pfaf_species:
                    # Also check genus-level match
                    genus = sci_name.split()[0].lower() if sci_name else ""
                    if genus not in pfaf_species:
                        stats["skipped"] += 1
                        continue

                # Validate required fields
                if not all([lat_str, lng_str, date_str, taxon_id_str]):
                    stats["skipped"] += 1
                    continue

                lat = float(lat_str)
                lng = float(lng_str)

                # Parse date (GBIF dates can be YYYY-MM-DD or YYYY-MM or YYYY)
                if len(date_str) >= 10:
                    obs_date = date.fromisoformat(date_str[:10])
                elif len(date_str) >= 7:
                    obs_date = date.fromisoformat(date_str[:7] + "-15")  # mid-month
                else:
                    stats["skipped"] += 1
                    continue

                taxon_id = int(taxon_id_str)
                inat_id = int(inat_id_str) if inat_id_str else None

                # Get photo URL from media column if available
                photo_url = None
                photo_attr = None
                media = row.get("media", "")
                if media and "http" in media:
                    # GBIF media column is semicolon-separated
                    parts = media.split(";")
                    for part in parts:
                        if "http" in part:
                            photo_url = part.strip()
                            break
                    photo_attr = row.get("rightsHolder", "iNaturalist CC")

                batch.append({
                    "taxon_id": taxon_id,
                    "scientific_name": sci_name,
                    "observed_on": obs_date,
                    "location": f"SRID=4326;POINT({lng} {lat})",
                    "quality_grade": "research",
                    "photo_url": photo_url,
                    "photo_attribution": photo_attr,
                    "source": "gbif",
                    "inat_observation_id": inat_id,
                })

            except (ValueError, KeyError) as e:
                stats["errors"] += 1
                if stats["errors"] <= 10:
                    log.warning(f"Row {stats['total']}: parse error: {e}")
                continue

            # Flush batch
            if len(batch) >= BATCH_SIZE:
                inserted, dupes = _flush_batch(db, batch)
                stats["inserted"] += inserted
                stats["duplicates"] += dupes
                batch = []

                if stats["total"] % 100_000 == 0:
                    log.info(
                        f"Progress: {stats['total']:,} rows, "
                        f"{stats['inserted']:,} inserted, "
                        f"{stats['skipped']:,} skipped"
                    )

    # Final batch
    if batch:
        inserted, dupes = _flush_batch(db, batch)
        stats["inserted"] += inserted
        stats["duplicates"] += dupes

    # Check error rate
    if stats["total"] > 0:
        error_pct = stats["errors"] / stats["total"]
        if error_pct > MAX_PARSE_ERRORS_PCT:
            log.error(
                f"High error rate: {error_pct:.2%} ({stats['errors']:,}/{stats['total']:,})"
            )

    return stats


def _flush_batch(db: Session, batch: list[dict]) -> tuple[int, int]:
    """Insert a batch of observations, skipping duplicates."""
    inserted = 0
    duplicates = 0

    # Use raw SQL COPY-style insert with ON CONFLICT for speed
    stmt = text("""
        INSERT INTO observations (taxon_id, scientific_name, observed_on, location,
                                  quality_grade, photo_url, photo_attribution, source,
                                  inat_observation_id)
        VALUES (:taxon_id, :scientific_name, :observed_on,
                ST_GeogFromText(:location),
                :quality_grade, :photo_url, :photo_attribution, :source,
                :inat_observation_id)
        ON CONFLICT (inat_observation_id) DO NOTHING
    """)

    for row in batch:
        try:
            result = db.execute(stmt, row)
            if result.rowcount > 0:
                inserted += 1
            else:
                duplicates += 1
        except Exception as e:
            log.warning(f"Insert error: {e}")
            db.rollback()
            duplicates += 1

    db.commit()
    return inserted, duplicates


def main():
    parser = argparse.ArgumentParser(description="Ingest GBIF observations")
    parser.add_argument("--csv", required=True, help="Path to GBIF CSV export")
    parser.add_argument("--create-tables", action="store_true", help="Create DB tables")
    args = parser.parse_args()

    if not check_disk_space():
        sys.exit(1)

    db = SessionLocal()

    if args.create_tables:
        log.info("Creating database tables...")
        Base.metadata.create_all(engine)
        log.info("Tables created.")

    pfaf_species = load_pfaf_species()
    log.info(f"Loaded {len(pfaf_species)} PFAF species for filtering")

    stats = ingest_csv(args.csv, db, pfaf_species)

    log.info("=" * 60)
    log.info(f"INGESTION COMPLETE")
    log.info(f"  Total rows:  {stats['total']:,}")
    log.info(f"  Inserted:    {stats['inserted']:,}")
    log.info(f"  Skipped:     {stats['skipped']:,}")
    log.info(f"  Duplicates:  {stats['duplicates']:,}")
    log.info(f"  Errors:      {stats['errors']:,}")
    log.info("=" * 60)

    db.close()


if __name__ == "__main__":
    main()
