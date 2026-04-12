from datetime import date
from pydantic import BaseModel, Field


class PeakSeason(BaseModel):
    start: str  # "03-15"
    end: str    # "04-15"


class PredictedPlant(BaseModel):
    id: str
    common_name: str
    scientific_name: str
    confidence: str  # "high", "medium", "low"
    confidence_score: float = Field(ge=0, le=1)
    reason: str
    observation_count: int
    peak_season: PeakSeason | None = None
    thumbnail_url: str | None = None
    edibility_rating: int = 0
    medicinal_rating: int = 0


class Location(BaseModel):
    lat: float
    lng: float
    name: str | None = None


class DateRange(BaseModel):
    start: date
    end: date


class GuideResponse(BaseModel):
    id: str
    location: Location
    date_range: DateRange
    coverage_score: float
    plants: list[PredictedPlant]


class EdiblePart(BaseModel):
    part: str
    preparation: str


class Warning(BaseModel):
    type: str  # "lookalike" or "conservation"
    severity: str  # "high", "medium", "low"
    title: str
    description: str
    test: str | None = None


class Photo(BaseModel):
    url: str
    label: str
    attribution: str


class PhysicalCharacteristics(BaseModel):
    habit: str | None = None
    height: str | None = None
    width: str | None = None
    deciduous_evergreen: str | None = None
    flowering_time: str | None = None
    habitat: str | None = None
    native_range: str | None = None
    hardiness_zone: int | None = None
    pollinators: str | None = None


class PlantDetailResponse(BaseModel):
    id: str
    common_name: str
    scientific_name: str
    family: str | None = None
    edibility_rating: int = 0
    medicinal_rating: int = 0
    physical: PhysicalCharacteristics | None = None
    edible_parts: list[EdiblePart]
    traditional_uses: str | None = None
    warnings: list[Warning]
    photos: list[Photo]
    data_sources: list[str]


class FeedbackRequest(BaseModel):
    guide_id: str
    plant_id: str
    device_id: str
    found: bool


class FeedbackResponse(BaseModel):
    status: str  # "saved" or "duplicate"


class CoverageHexBin(BaseModel):
    lat: float
    lng: float
    count: int
    density: float  # 0.0 to 1.0


class CoverageResponse(BaseModel):
    hex_bins: list[CoverageHexBin]
    total_observations: int


class EmailSubscribeRequest(BaseModel):
    email: str
    location_text: str | None = None
    lat: float | None = None
    lng: float | None = None


class HealthResponse(BaseModel):
    status: str
    db_connected: bool
    observation_count: int | None = None
