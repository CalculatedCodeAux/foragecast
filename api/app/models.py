"""
Database models for the foraging prediction API.

Tables:
  observations    — iNaturalist/GBIF observation records with PostGIS geometry
  plant_metadata  — manually curated plant info (edibility, warnings, photos)
  guide_cache     — cached prediction results (24h TTL)
  feedback        — per-plant "did you find this?" user feedback
  email_subscribers — landing page email capture for monthly notifications
"""
import uuid
from datetime import datetime, timezone

from geoalchemy2 import Geography
from sqlalchemy import (
    Boolean, Column, Date, DateTime, Float, Integer, String, Text, Index,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID


def _uuid_str():
    return str(uuid.uuid4())

from app.database import Base


class Observation(Base):
    __tablename__ = "observations"

    id = Column(String(36), primary_key=True, default=_uuid_str)
    taxon_id = Column(Integer, nullable=False, index=True)
    scientific_name = Column(Text, nullable=False)
    observed_on = Column(Date, nullable=False, index=True)
    location = Column(Geography("POINT", srid=4326), nullable=False)
    quality_grade = Column(String(20), default="research")
    photo_url = Column(Text)
    photo_attribution = Column(Text)
    source = Column(String(20), default="gbif")  # "gbif" or "inat_api"
    inat_observation_id = Column(Integer, unique=True)

    __table_args__ = (
        Index("ix_observations_location", "location", postgresql_using="gist"),
    )


class PlantMetadata(Base):
    __tablename__ = "plant_metadata"

    id = Column(String(100), primary_key=True)  # slug e.g. "allium-tricoccum"
    taxon_id = Column(Integer, unique=True, nullable=False)
    common_name = Column(Text, nullable=False)
    scientific_name = Column(Text, nullable=False)
    family = Column(Text)
    edible_parts = Column(JSONB)   # [{"part": "Leaves", "preparation": "..."}]
    traditional_uses = Column(Text)
    warnings = Column(JSONB)       # [{"type": "lookalike", "severity": "high", ...}]
    photos = Column(JSONB)         # [{"url": "...", "label": "...", "attribution": "..."}]
    is_edible = Column(Boolean, default=True)
    data_sources = Column(JSONB, default=list)
    curated_by = Column(Text)


class GuideCache(Base):
    __tablename__ = "guide_cache"

    id = Column(String(36), primary_key=True, default=_uuid_str)
    cache_key = Column(String(100), unique=True, nullable=False, index=True)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    date_start = Column(Date, nullable=False)
    date_end = Column(Date, nullable=False)
    coverage_score = Column(Float, nullable=False)
    plants = Column(JSONB, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime, nullable=False)


class Feedback(Base):
    __tablename__ = "feedback"

    id = Column(String(36), primary_key=True, default=_uuid_str)
    guide_id = Column(String(36), nullable=False, index=True)
    plant_id = Column(String(100), nullable=False)
    device_id = Column(String(100), nullable=False)
    found = Column(Boolean, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        UniqueConstraint("guide_id", "plant_id", "device_id", name="uq_feedback_per_device"),
    )


class EmailSubscriber(Base):
    __tablename__ = "email_subscribers"

    id = Column(String(36), primary_key=True, default=_uuid_str)
    email = Column(String(255), unique=True, nullable=False)
    location_text = Column(Text)
    lat = Column(Float)
    lng = Column(Float)
    subscribed = Column(Boolean, default=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    unsubscribe_token = Column(String(64), unique=True)
