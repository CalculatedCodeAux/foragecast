import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/plant.dart';

/// API client for the foraging prediction service.
class ApiClient {
  static const String baseUrl = 'https://forage.optimizeforllm.com';
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Generate a guide for the given location and date range.
  Future<Guide> predict({
    required double lat,
    required double lng,
    required DateTime start,
    required DateTime end,
  }) async {
    final uri = Uri.parse('$baseUrl/predict').replace(queryParameters: {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'start': _formatDate(start),
      'end': _formatDate(end),
    });

    final response = await _client.get(uri).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw ApiException('Request timed out. Check your connection.'),
    );

    if (response.statusCode == 200) {
      return Guide.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 503) {
      throw ApiException('Service temporarily busy. Try again in a moment.');
    } else if (response.statusCode == 400) {
      final body = jsonDecode(response.body);
      throw ApiException(body['detail'] ?? 'Invalid request.');
    } else {
      throw ApiException('Something went wrong (${response.statusCode}).');
    }
  }

  /// Get full plant detail.
  Future<PlantDetail> getPlantDetail(String plantId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/plants/$plantId'),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw ApiException('Request timed out.'),
    );

    if (response.statusCode == 200) {
      return PlantDetail.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      throw ApiException('Plant not found.');
    } else {
      throw ApiException('Something went wrong (${response.statusCode}).');
    }
  }

  /// Submit per-plant feedback.
  Future<void> submitFeedback({
    required String guideId,
    required String plantId,
    required String deviceId,
    required bool found,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'guide_id': guideId,
        'plant_id': plantId,
        'device_id': deviceId,
        'found': found,
      }),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to submit feedback.');
    }
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
