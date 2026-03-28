import 'dart:convert';
import 'package:http/http.dart' as http;

/// Geocoding service using OpenStreetMap Nominatim (free, no API key).
/// For production, consider Mapbox or Google Places for higher rate limits.
class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  final http.Client _client;

  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  /// Search for a place name and return matching results.
  Future<List<GeocodingResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '5',
      'addressdetails': '1',
    });

    final response = await _client.get(uri, headers: {
      'User-Agent': 'ForageCast/0.1.0',
    }).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw GeocodingException('Search timed out.'),
    );

    if (response.statusCode != 200) {
      throw GeocodingException('Search failed (${response.statusCode}).');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((item) => GeocodingResult.fromJson(item)).toList();
  }
}

class GeocodingResult {
  final double lat;
  final double lng;
  final String displayName;
  final String type;

  GeocodingResult({
    required this.lat,
    required this.lng,
    required this.displayName,
    required this.type,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      lat: double.parse(json['lat']),
      lng: double.parse(json['lon']),
      displayName: json['display_name'] ?? '',
      type: json['type'] ?? '',
    );
  }

  /// Short name: first two parts of the display name.
  String get shortName {
    final parts = displayName.split(', ');
    if (parts.length >= 2) return '${parts[0]}, ${parts[1]}';
    return parts[0];
  }
}

class GeocodingException implements Exception {
  final String message;
  GeocodingException(this.message);

  @override
  String toString() => message;
}
