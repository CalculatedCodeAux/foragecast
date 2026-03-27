"""
Foraging Prediction API

Endpoints:
  GET  /predict    — predict plants for location + date range
  GET  /plants/:id — full plant detail
  POST /feedback   — per-plant "did you find this?" feedback
  GET  /coverage   — observation density heatmap data
  GET  /health     — health check
  POST /subscribe  — email capture for monthly notifications
"""
import secrets
import uuid
from datetime import date, datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError, OperationalError
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import (
    EmailSubscriber, Feedback, GuideCache, Observation, PlantMetadata,
)
from app.predict import predict_plants
from app.schemas import (
    CoverageHexBin, CoverageResponse, EmailSubscribeRequest,
    FeedbackRequest, FeedbackResponse, GuideResponse, HealthResponse,
    Location, DateRange, PlantDetailResponse, EdiblePart, Warning, Photo,
)

app = FastAPI(title="Foraging Prediction API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_methods=["*"],
    allow_headers=["*"],
)


def _cache_key(lat: float, lng: float, start: date, end: date) -> str:
    """Round coords to configured precision for cache dedup."""
    p = settings.coord_precision
    return f"{round(lat, p)}:{round(lng, p)}:{start}:{end}"


# ── GET /predict ──────────────────────────────────────────────────────


@app.get("/predict", response_model=GuideResponse)
def get_prediction(
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    start: date = Query(),
    end: date = Query(),
    db: Session = Depends(get_db),
):
    if end < start:
        raise HTTPException(400, "end date must be after start date")

    key = _cache_key(lat, lng, start, end)

    # Check cache
    cached = db.query(GuideCache).filter_by(cache_key=key).first()
    now = datetime.now(timezone.utc)
    expires = cached.expires_at if cached else None
    if expires and expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    if cached and expires > now:
        return GuideResponse(
            id=str(cached.id),
            location=Location(lat=cached.lat, lng=cached.lng),
            date_range=DateRange(start=cached.date_start, end=cached.date_end),
            coverage_score=cached.coverage_score,
            plants=cached.plants,
        )

    # Generate prediction
    try:
        plants, coverage = predict_plants(db, lat, lng, start, end)
    except OperationalError:
        raise HTTPException(503, "Service temporarily busy, try again in a moment.")

    # Cache the result
    guide = GuideCache(
        cache_key=key,
        lat=round(lat, settings.coord_precision),
        lng=round(lng, settings.coord_precision),
        date_start=start,
        date_end=end,
        coverage_score=coverage,
        plants=[p.model_dump() for p in plants],
        expires_at=now + timedelta(hours=settings.guide_cache_ttl_hours),
    )

    # Upsert: delete old cache entry if exists
    if cached:
        db.delete(cached)
    db.add(guide)
    db.commit()
    db.refresh(guide)

    return GuideResponse(
        id=str(guide.id),
        location=Location(lat=guide.lat, lng=guide.lng),
        date_range=DateRange(start=start, end=end),
        coverage_score=coverage,
        plants=plants,
    )


# ── GET /plants/{plant_id} ───────────────────────────────────────────


@app.get("/plants/{plant_id}", response_model=PlantDetailResponse)
def get_plant_detail(plant_id: str, db: Session = Depends(get_db)):
    meta = db.query(PlantMetadata).filter_by(id=plant_id).first()
    if not meta:
        raise HTTPException(404, f"Plant '{plant_id}' not found")

    edible_parts = []
    if meta.edible_parts:
        for ep in meta.edible_parts:
            try:
                edible_parts.append(EdiblePart(**ep))
            except (TypeError, KeyError):
                continue  # skip malformed entries, log in production

    warnings = []
    if meta.warnings:
        for w in meta.warnings:
            try:
                warnings.append(Warning(**w))
            except (TypeError, KeyError):
                continue

    photos = []
    if meta.photos:
        for p in meta.photos:
            try:
                photos.append(Photo(**p))
            except (TypeError, KeyError):
                continue

    return PlantDetailResponse(
        id=meta.id,
        common_name=meta.common_name,
        scientific_name=meta.scientific_name,
        family=meta.family,
        edible_parts=edible_parts,
        traditional_uses=meta.traditional_uses,
        warnings=warnings,
        photos=photos,
        data_sources=meta.data_sources or [],
    )


# ── POST /feedback ───────────────────────────────────────────────────


@app.post("/feedback", response_model=FeedbackResponse)
def submit_feedback(req: FeedbackRequest, db: Session = Depends(get_db)):
    feedback = Feedback(
        guide_id=req.guide_id,
        plant_id=req.plant_id,
        device_id=req.device_id,
        found=req.found,
    )
    try:
        db.add(feedback)
        db.commit()
        return FeedbackResponse(status="saved")
    except IntegrityError:
        db.rollback()
        return FeedbackResponse(status="duplicate")


# ── GET /coverage ────────────────────────────────────────────────────


@app.get("/coverage", response_model=CoverageResponse)
def get_coverage(
    min_lat: float = Query(ge=-90, le=90),
    max_lat: float = Query(ge=-90, le=90),
    min_lng: float = Query(ge=-180, le=180),
    max_lng: float = Query(ge=-180, le=180),
    resolution: float = Query(default=0.5, ge=0.1, le=5.0),
    db: Session = Depends(get_db),
):
    """
    Returns observation density in hex-bin-like grid cells.
    Resolution is in degrees (0.5 ≈ 55km at equator).
    """
    from sqlalchemy import cast, Numeric

    results = (
        db.query(
            func.round(cast(func.ST_Y(func.ST_Centroid(Observation.location)), Numeric), 1).label("bin_lat"),
            func.round(cast(func.ST_X(func.ST_Centroid(Observation.location)), Numeric), 1).label("bin_lng"),
            func.count(Observation.id).label("count"),
        )
        .filter(
            func.ST_Y(func.ST_Centroid(Observation.location)) >= min_lat,
            func.ST_Y(func.ST_Centroid(Observation.location)) <= max_lat,
            func.ST_X(func.ST_Centroid(Observation.location)) >= min_lng,
            func.ST_X(func.ST_Centroid(Observation.location)) <= max_lng,
        )
        .group_by("bin_lat", "bin_lng")
        .all()
    )

    max_count = max((r.count for r in results), default=1)
    total = sum(r.count for r in results)

    hex_bins = [
        CoverageHexBin(
            lat=float(r.bin_lat),
            lng=float(r.bin_lng),
            count=r.count,
            density=round(r.count / max_count, 3),
        )
        for r in results
    ]

    return CoverageResponse(hex_bins=hex_bins, total_observations=total)


# ── POST /subscribe ──────────────────────────────────────────────────


@app.post("/subscribe")
def subscribe_email(req: EmailSubscribeRequest, db: Session = Depends(get_db)):
    sub = EmailSubscriber(
        email=req.email,
        location_text=req.location_text,
        lat=req.lat,
        lng=req.lng,
        unsubscribe_token=secrets.token_urlsafe(32),
    )
    try:
        db.add(sub)
        db.commit()
        return {"status": "subscribed"}
    except IntegrityError:
        db.rollback()
        return {"status": "already_subscribed"}


# ── GET /health ──────────────────────────────────────────────────────


@app.get("/health", response_model=HealthResponse)
def health_check(db: Session = Depends(get_db)):
    try:
        count = db.query(func.count(Observation.id)).scalar()
        return HealthResponse(status="ok", db_connected=True, observation_count=count)
    except OperationalError:
        return HealthResponse(status="degraded", db_connected=False)
