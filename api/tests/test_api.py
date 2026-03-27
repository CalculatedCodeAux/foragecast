"""
API endpoint tests.

Covers: /predict, /plants, /feedback, /coverage, /health, /subscribe
"""
import uuid


# ── /health ──────────────────────────────────────────────────────────


def test_health_check(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert data["db_connected"] is True


# ── /plants/:id ──────────────────────────────────────────────────────


def test_get_plant_detail(client, sample_plant):
    resp = client.get("/plants/allium-tricoccum")
    assert resp.status_code == 200
    data = resp.json()
    assert data["common_name"] == "Ramps (Wild Leeks)"
    assert data["scientific_name"] == "Allium tricoccum"
    assert data["family"] == "Amaryllidaceae"
    # Warnings should be present
    assert len(data["warnings"]) == 1
    assert data["warnings"][0]["type"] == "lookalike"
    assert data["warnings"][0]["severity"] == "high"
    # Edible parts
    assert len(data["edible_parts"]) == 2
    assert data["edible_parts"][0]["part"] == "Leaves"
    # Traditional uses (renamed from medicinal)
    assert "Spring tonic" in data["traditional_uses"]
    # Photos
    assert len(data["photos"]) == 1


def test_get_plant_not_found(client):
    resp = client.get("/plants/nonexistent-plant")
    assert resp.status_code == 404


# ── /predict ─────────────────────────────────────────────────────────


def test_predict_returns_cached_guide(client, cached_guide):
    resp = client.get("/predict", params={
        "lat": 35.3, "lng": -82.8,
        "start": "2026-03-29", "end": "2026-04-04",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["coverage_score"] == 0.72
    assert len(data["plants"]) == 1
    assert data["plants"][0]["common_name"] == "Ramps"


def test_predict_invalid_coords(client):
    resp = client.get("/predict", params={
        "lat": 999, "lng": -82.8,
        "start": "2026-03-29", "end": "2026-04-04",
    })
    assert resp.status_code == 422  # validation error


def test_predict_end_before_start(client):
    resp = client.get("/predict", params={
        "lat": 35.3, "lng": -82.8,
        "start": "2026-04-04", "end": "2026-03-29",
    })
    assert resp.status_code == 400


def test_predict_missing_params(client):
    resp = client.get("/predict", params={"lat": 35.3})
    assert resp.status_code == 422


# ── /feedback ────────────────────────────────────────────────────────


def test_submit_feedback(client, cached_guide):
    guide_id = str(cached_guide.id)
    resp = client.post("/feedback", json={
        "guide_id": guide_id,
        "plant_id": "allium-tricoccum",
        "device_id": "test-device-123",
        "found": True,
    })
    assert resp.status_code == 200
    assert resp.json()["status"] == "saved"


def test_submit_duplicate_feedback(client, cached_guide):
    guide_id = str(cached_guide.id)
    payload = {
        "guide_id": guide_id,
        "plant_id": "allium-tricoccum",
        "device_id": "test-device-456",
        "found": True,
    }
    resp1 = client.post("/feedback", json=payload)
    assert resp1.json()["status"] == "saved"

    resp2 = client.post("/feedback", json=payload)
    assert resp2.json()["status"] == "duplicate"


# ── /subscribe ───────────────────────────────────────────────────────


def test_subscribe_email(client):
    resp = client.post("/subscribe", json={
        "email": "forager@test.com",
        "location_text": "Pisgah National Forest",
    })
    assert resp.status_code == 200
    assert resp.json()["status"] == "subscribed"


def test_subscribe_duplicate_email(client):
    payload = {"email": "dupe@test.com"}
    client.post("/subscribe", json=payload)
    resp = client.post("/subscribe", json=payload)
    assert resp.json()["status"] == "already_subscribed"
