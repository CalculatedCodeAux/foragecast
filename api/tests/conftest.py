"""
Test fixtures for the Foraging API.

Uses SQLite for tests (no PostGIS needed for basic endpoint testing).
The Geography column on Observation is swapped to Text for SQLite compat.
PostGIS-specific tests (spatial queries) should use a real PostgreSQL instance.
"""
import uuid
from datetime import date, datetime, timedelta, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, Text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from sqlalchemy import JSON

from app.database import Base, get_db
from app.main import app
from app.models import PlantMetadata, GuideCache, Observation, Feedback, EmailSubscriber


# Swap Postgres-specific column types for SQLite compatibility
def _patch_for_sqlite():
    """Replace Geography and JSONB types with SQLite-friendly equivalents."""
    for table in Base.metadata.tables.values():
        # Remove GiST indexes (SQLite doesn't support them)
        table.indexes = {
            idx for idx in table.indexes
            if not any("gist" in str(getattr(idx, "dialect_options", {})).lower()
                       for _ in [0])
            and idx.name != "ix_observations_location"
        }
        for col in table.columns:
            type_name = type(col.type).__name__
            if type_name == "Geography":
                col.type = Text()
            elif type_name == "JSONB":
                col.type = JSON()
            elif type_name == "UUID":
                col.type = Text()

_patch_for_sqlite()

# In-memory SQLite for fast tests
SQLALCHEMY_DATABASE_URL = "sqlite://"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

# Register fake PostGIS functions for SQLite
@event.listens_for(engine, "connect")
def _register_functions(dbapi_conn, connection_record):
    dbapi_conn.create_function("ST_DWithin", 4, lambda *a: True)
    dbapi_conn.create_function("ST_MakePoint", 2, lambda x, y: f"POINT({x} {y})")
    dbapi_conn.create_function("ST_SetSRID", 2, lambda geom, srid: geom)
    dbapi_conn.create_function("ST_Y", 1, lambda g: 35.3)
    dbapi_conn.create_function("ST_X", 1, lambda g: -82.8)
    dbapi_conn.create_function("ST_Centroid", 1, lambda g: g)
    dbapi_conn.create_function("ST_GeogFromText", 1, lambda t: t)


TestingSessionLocal = sessionmaker(bind=engine)


@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client(db):
    def override_get_db():
        try:
            yield db
        finally:
            pass

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def sample_plant(db):
    """Insert a sample plant for testing."""
    plant = PlantMetadata(
        id="allium-tricoccum",
        taxon_id=55806,
        common_name="Ramps (Wild Leeks)",
        scientific_name="Allium tricoccum",
        family="Amaryllidaceae",
        edible_parts=[
            {"part": "Leaves", "preparation": "Raw in salads, sautéed, or in pesto."},
            {"part": "Bulbs", "preparation": "Pickle, roast, or use like garlic."},
        ],
        traditional_uses="Spring tonic. Contains vitamins A and C.",
        warnings=[
            {
                "type": "lookalike",
                "severity": "high",
                "title": "Lily of the Valley",
                "description": "Similar broad leaves. Crush a leaf: ramps smell of garlic.",
                "test": "Smell test.",
            },
        ],
        photos=[
            {"url": "/photos/ramps-leaf.jpg", "label": "Leaf", "attribution": "CC-BY"},
        ],
        is_edible=True,
        data_sources=["pfaf.org", "iNaturalist"],
    )
    db.add(plant)
    db.commit()
    return plant


@pytest.fixture
def cached_guide(db):
    """Insert a cached guide for testing."""
    now = datetime.now(timezone.utc)
    guide = GuideCache(
        cache_key="35.3:-82.8:2026-03-29:2026-04-04",
        lat=35.3,
        lng=-82.8,
        date_start=date(2026, 3, 29),
        date_end=date(2026, 4, 4),
        coverage_score=0.72,
        plants=[
            {
                "id": "allium-tricoccum",
                "common_name": "Ramps",
                "scientific_name": "Allium tricoccum",
                "confidence": "high",
                "confidence_score": 0.89,
                "reason": "47 observations within 10km",
                "observation_count": 47,
                "peak_season": {"start": "03-15", "end": "04-15"},
            }
        ],
        expires_at=now + timedelta(hours=24),
    )
    db.add(guide)
    db.commit()
    return guide
