"""
Heuristic prediction engine (v1).

Prediction flow:
  1. Query observations within radius (PostGIS ST_DWithin)
  2. Filter to same calendar month ± 2 weeks across all years
  3. Group by species, count observations
  4. Compute confidence: High (≥20), Medium (5-19), Low (1-4)
  5. Join with plant_metadata
  6. Rank by confidence descending
  7. Return top N plants

This module is the ONLY thing that changes when we swap to the
embedding model (v2). Everything else (API, cache, frontend) stays the same.
"""
from datetime import date, timedelta

from geoalchemy2.functions import ST_DWithin, ST_MakePoint, ST_SetSRID
from sqlalchemy import func, extract, and_
from sqlalchemy.orm import Session

from app.config import settings
from app.models import Observation, PlantMetadata
from app.schemas import PredictedPlant, PeakSeason


def predict_plants(
    db: Session,
    lat: float,
    lng: float,
    date_start: date,
    date_end: date,
) -> tuple[list[PredictedPlant], float]:
    """
    Returns (plants, coverage_score) for the given location and date range.
    """
    radius_m = settings.prediction_radius_km * 1000
    from sqlalchemy import cast
    from geoalchemy2 import Geography
    point = cast(ST_SetSRID(ST_MakePoint(lng, lat), 4326), Geography)

    # Date window: same day-of-year range across all years, ± window
    window = timedelta(weeks=settings.prediction_date_window_weeks)
    doy_start = (date_start - window).timetuple().tm_yday
    doy_end = (date_end + window).timetuple().tm_yday

    # Handle year boundary (e.g., late December to early January)
    if doy_start <= doy_end:
        date_filter = and_(
            extract("doy", Observation.observed_on) >= doy_start,
            extract("doy", Observation.observed_on) <= doy_end,
        )
    else:
        date_filter = (
            (extract("doy", Observation.observed_on) >= doy_start)
            | (extract("doy", Observation.observed_on) <= doy_end)
        )

    # Query: observations within radius + date window, grouped by taxon
    results = (
        db.query(
            Observation.taxon_id,
            Observation.scientific_name,
            func.count(Observation.id).label("obs_count"),
        )
        .filter(
            ST_DWithin(
                Observation.location,
                point,
                radius_m,
            ),
            date_filter,
        )
        .group_by(Observation.taxon_id, Observation.scientific_name)
        .having(func.count(Observation.id) >= 1)
        .order_by(func.count(Observation.id).desc())
        .limit(settings.max_plants_per_guide)
        .all()
    )

    # Compute coverage score
    total_obs = sum(r.obs_count for r in results)
    coverage = min(1.0, total_obs / 200.0)

    # Join with plant metadata and build response
    plants = []
    for row in results:
        meta = db.query(PlantMetadata).filter_by(taxon_id=row.taxon_id).first()
        if not meta or not meta.is_edible:
            continue

        obs_count = row.obs_count
        if obs_count >= settings.confidence_high_threshold:
            confidence = "high"
            score = min(1.0, obs_count / 50.0)
        elif obs_count >= settings.confidence_medium_threshold:
            confidence = "medium"
            score = 0.3 + (obs_count / 20.0) * 0.4
        else:
            confidence = "low"
            score = obs_count / 10.0

        # Estimate peak season from observation dates in this area
        peak = _estimate_peak_season(db, row.taxon_id, lat, lng, radius_m)

        reason = f"{obs_count} observations within {settings.prediction_radius_km:.0f}km"
        month_name = date_start.strftime("%B")
        reason += f" in {month_name}"

        plants.append(PredictedPlant(
            id=meta.id,
            common_name=meta.common_name,
            scientific_name=meta.scientific_name,
            confidence=confidence,
            confidence_score=round(score, 2),
            reason=reason,
            observation_count=obs_count,
            peak_season=peak,
        ))

    return plants, round(coverage, 2)


def _estimate_peak_season(
    db: Session, taxon_id: int, lat: float, lng: float, radius_m: float
) -> PeakSeason | None:
    """Estimate peak season by finding the month with most observations."""
    from sqlalchemy import cast
    from geoalchemy2 import Geography
    point = cast(ST_SetSRID(ST_MakePoint(lng, lat), 4326), Geography)

    result = (
        db.query(
            extract("month", Observation.observed_on).label("month"),
            func.count(Observation.id).label("cnt"),
        )
        .filter(
            Observation.taxon_id == taxon_id,
            ST_DWithin(
                Observation.location,
                point,
                radius_m,
            ),
        )
        .group_by("month")
        .order_by(func.count(Observation.id).desc())
        .first()
    )

    if not result:
        return None

    peak_month = int(result.month)
    start_month = peak_month
    end_month = (peak_month % 12) + 1
    return PeakSeason(
        start=f"{start_month:02d}-01",
        end=f"{end_month:02d}-15",
    )
