// Plant prediction and detail models.

class PredictedPlant {
  final String id;
  final String commonName;
  final String scientificName;
  final String confidence;
  final double confidenceScore;
  final String reason;
  final int observationCount;
  final PeakSeason? peakSeason;

  PredictedPlant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.confidence,
    required this.confidenceScore,
    required this.reason,
    required this.observationCount,
    this.peakSeason,
  });

  factory PredictedPlant.fromJson(Map<String, dynamic> json) {
    return PredictedPlant(
      id: json['id'],
      commonName: json['common_name'],
      scientificName: json['scientific_name'],
      confidence: json['confidence'],
      confidenceScore: (json['confidence_score'] as num).toDouble(),
      reason: json['reason'],
      observationCount: json['observation_count'],
      peakSeason: json['peak_season'] != null
          ? PeakSeason.fromJson(json['peak_season'])
          : null,
    );
  }
}

class PeakSeason {
  final String start;
  final String end;

  PeakSeason({required this.start, required this.end});

  factory PeakSeason.fromJson(Map<String, dynamic> json) {
    return PeakSeason(start: json['start'], end: json['end']);
  }
}

class Guide {
  final String id;
  final double lat;
  final double lng;
  final String? locationName;
  final DateTime dateStart;
  final DateTime dateEnd;
  final double coverageScore;
  final List<PredictedPlant> plants;

  Guide({
    required this.id,
    required this.lat,
    required this.lng,
    this.locationName,
    required this.dateStart,
    required this.dateEnd,
    required this.coverageScore,
    required this.plants,
  });

  factory Guide.fromJson(Map<String, dynamic> json) {
    return Guide(
      id: json['id'],
      lat: (json['location']['lat'] as num).toDouble(),
      lng: (json['location']['lng'] as num).toDouble(),
      locationName: json['location']['name'],
      dateStart: DateTime.parse(json['date_range']['start']),
      dateEnd: DateTime.parse(json['date_range']['end']),
      coverageScore: (json['coverage_score'] as num).toDouble(),
      plants: (json['plants'] as List)
          .map((p) => PredictedPlant.fromJson(p))
          .toList(),
    );
  }
}

class PlantDetail {
  final String id;
  final String commonName;
  final String scientificName;
  final String? family;
  final List<EdiblePart> edibleParts;
  final String? traditionalUses;
  final List<PlantWarning> warnings;
  final List<PlantPhoto> photos;
  final List<String> dataSources;

  PlantDetail({
    required this.id,
    required this.commonName,
    required this.scientificName,
    this.family,
    required this.edibleParts,
    this.traditionalUses,
    required this.warnings,
    required this.photos,
    required this.dataSources,
  });

  factory PlantDetail.fromJson(Map<String, dynamic> json) {
    return PlantDetail(
      id: json['id'],
      commonName: json['common_name'],
      scientificName: json['scientific_name'],
      family: json['family'],
      edibleParts: (json['edible_parts'] as List)
          .map((e) => EdiblePart.fromJson(e))
          .toList(),
      traditionalUses: json['traditional_uses'],
      warnings: (json['warnings'] as List)
          .map((w) => PlantWarning.fromJson(w))
          .toList(),
      photos: (json['photos'] as List)
          .map((p) => PlantPhoto.fromJson(p))
          .toList(),
      dataSources: List<String>.from(json['data_sources'] ?? []),
    );
  }
}

class EdiblePart {
  final String part;
  final String preparation;

  EdiblePart({required this.part, required this.preparation});

  factory EdiblePart.fromJson(Map<String, dynamic> json) {
    return EdiblePart(part: json['part'], preparation: json['preparation']);
  }
}

class PlantWarning {
  final String type;
  final String severity;
  final String title;
  final String description;
  final String? test;

  PlantWarning({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.test,
  });

  factory PlantWarning.fromJson(Map<String, dynamic> json) {
    return PlantWarning(
      type: json['type'],
      severity: json['severity'],
      title: json['title'],
      description: json['description'],
      test: json['test'],
    );
  }
}

class PlantPhoto {
  final String url;
  final String label;
  final String attribution;

  PlantPhoto({
    required this.url,
    required this.label,
    required this.attribution,
  });

  factory PlantPhoto.fromJson(Map<String, dynamic> json) {
    return PlantPhoto(
      url: json['url'],
      label: json['label'],
      attribution: json['attribution'],
    );
  }
}
