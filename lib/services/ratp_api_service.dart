import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swipezone/screens/widgets/transit_info_panel.dart';

class RatpApiService {
  static const String baseUrl = 'https://api-ratp.pierre-grimaud.fr/v4';

  static Future<List<TransitRoute>> getJourney(String from, String to) async {
    try {
      // Get all available lines
      final lines = await _getLines();
      if (lines.isEmpty) {
        print('No transit lines available');
        return [];
      }

      // Create a list to store all possible routes
      List<TransitRoute> routes = [];

      // For each line type (metro, rer, bus), get the stations and create routes
      for (var line in lines) {
        try {
          final stations = await _getStations(line['type'], line['code']);
          if (stations.isNotEmpty) {
            // Create a route for this line
            routes.add(
              TransitRoute(
                type: line['type'],
                line: line['code'],
                direction: stations.last['name'],
                startStation: stations.first['name'],
                endStation: stations.last['name'],
                duration: _estimateDuration(stations.length),
              ),
            );
          }
        } catch (e) {
          print('Error getting stations for line ${line['code']}: $e');
          continue;
        }
      }

      return routes;
    } catch (e) {
      print('Error in getJourney: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getLines() async {
    List<Map<String, dynamic>> allLines = [];

    final lineTypes = ['metros', 'rers', 'buses'];

    for (var type in lineTypes) {
      try {
        final url = Uri.parse('$baseUrl/lines/$type');
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final lines = List<Map<String, dynamic>>.from(data['result'][type] ?? []);
          for (var line in lines) {
            allLines.add({
              'type': type.substring(0, type.length - 1), // Remove 's' from type
              'code': line['code'],
              'name': line['name'],
            });
          }
        } else {
          print('Failed to get $type lines: ${response.statusCode}');
        }
      } catch (e) {
        print('Error getting $type lines: $e');
      }
    }

    return allLines;
  }

  static Future<List<Map<String, dynamic>>> _getStations(String type, String lineCode) async {
    try {
      final url = Uri.parse('$baseUrl/stations/$type/$lineCode');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['result']['stations'] ?? []);
      } else {
        print('Failed to get stations: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting stations: $e');
      return [];
    }
  }

  static int _estimateDuration(int numberOfStations) {
    // Rough estimation: 2 minutes per station
    return numberOfStations * 2;
  }
}

