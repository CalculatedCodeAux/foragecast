# Foraging App

Predictive foraging trip planner. Enter a location + date, get a guide of likely edible plants with confidence scores, identification photos, look-alike warnings, and traditional uses.

## Architecture

- **Flutter app** (iOS + Android): `flutter_app/`
- **FastAPI prediction API** (Python): `api/`
- **Astro landing page**: `landing/`
- **API domain**: `forage.optimizeforllm.com` (Hostinger VPS, Caddy reverse proxy)
- **Database**: PostgreSQL + PostGIS on VPS
- **Data**: GBIF iNaturalist observations filtered to PFAF ~7K species

## Commands

```bash
# API (local dev)
cd api && pip install -r requirements.txt && uvicorn app.main:app --reload

# Landing page
cd landing && npm install && npm run dev

# Flutter app
cd flutter_app && flutter run

# Tests
cd api && pytest
cd flutter_app && flutter test
```

## Design System

- Primary: #2D5016 (forest green)
- Secondary: #8B6914 (warm bark)
- Background: #FAFAF5 (off-white)
- Danger: #B33A3A (warnings)
- Font: DM Sans (headings bold, body regular, Latin names italic)
- Spacing: 4px base grid

## Safety

This is a safety-critical app. Warnings and look-alike information ALWAYS appear above edibility info in plant detail. First-launch safety acknowledgment gate is required.
