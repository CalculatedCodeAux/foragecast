"""iNaturalist photo fetching — shared between predict and plant detail."""
import logging

import httpx

from app.schemas import Photo

log = logging.getLogger(__name__)


def fetch_inat_photos(scientific_name: str, max_photos: int = 4) -> list[Photo]:
    """Fetch CC-licensed photos from iNaturalist API by scientific name."""
    try:
        with httpx.Client(timeout=10) as client:
            search = client.get(
                "https://api.inaturalist.org/v1/taxa",
                params={"q": scientific_name, "rank": "species", "per_page": 1},
                headers={"User-Agent": "ForageCast/1.1.0"},
            )
            if search.status_code != 200:
                return []
            results = search.json().get("results", [])
            if not results:
                return []
            inat_id = results[0].get("id")
            if not inat_id:
                return []

            detail = client.get(
                f"https://api.inaturalist.org/v1/taxa/{inat_id}",
                headers={"User-Agent": "ForageCast/1.1.0"},
            )
            if detail.status_code != 200:
                return []
            taxon_results = detail.json().get("results", [])
            if not taxon_results:
                return []
            taxon = taxon_results[0]

            photos = []
            for tp in taxon.get("taxon_photos", [])[:max_photos]:
                photo = tp.get("photo", {})
                url = photo.get("medium_url") or photo.get("url", "")
                if not url:
                    continue
                url = url.replace("/square.", "/medium.")
                photos.append(Photo(
                    url=url,
                    label="Observation photo",
                    attribution=photo.get("attribution", "iNaturalist CC"),
                ))
            return photos
    except Exception as e:
        log.warning(f"iNat photo fetch failed for {scientific_name}: {e}")
        return []


def get_or_fetch_photos(meta, db) -> list[Photo]:
    """Get photos from DB, or fetch from iNat and cache them."""
    photos = []
    if meta.photos:
        for p in meta.photos:
            try:
                photos.append(Photo(**p))
            except (TypeError, KeyError):
                continue

    if not photos and meta.scientific_name:
        photos = fetch_inat_photos(meta.scientific_name)
        if photos:
            try:
                meta.photos = [
                    {"url": p.url, "label": p.label, "attribution": p.attribution}
                    for p in photos
                ]
                db.commit()
            except Exception:
                db.rollback()

    return photos
