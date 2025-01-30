import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeocodingResult {
  final String displayName;
  final double lat;
  final double lon;

  GeocodingResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      displayName: json['display_name'],
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
    );
  }
}

class GeocodingService {
  static Future<List<GeocodingResult>> searchAddress(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results.map((json) => GeocodingResult.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load geocoding results');
      }
    } catch (e) {
      throw Exception('Error during geocoding request: $e');
    }
  }
}

