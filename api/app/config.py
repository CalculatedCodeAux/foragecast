from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://forage:forage@localhost:5432/foragedb"
    prediction_radius_km: float = 10.0
    prediction_date_window_weeks: int = 2
    guide_cache_ttl_hours: int = 24
    max_plants_per_guide: int = 20
    coord_precision: int = 3  # round lat/lng to 3 decimals (~111m) for cache keys
    photos_dir: str = "/var/lib/forage/photos"
    confidence_high_threshold: int = 20
    confidence_medium_threshold: int = 5

    model_config = {"env_prefix": "FORAGE_"}


settings = Settings()
