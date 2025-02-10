/*import 'dart:convert';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:swipezone/screens/widgets/transit_info_panel.dart';
import 'package:latlong2/latlong.dart';

class RatpApiService {
  static const String baseUrl = 'https://data.ratp.fr/api/explore/v2.1';

  // Récupère toutes les lignes pour un type de transport donné
  static Future<List<Map<String, dynamic>>> getLines(String type) async {
    try {
      final url = Uri.parse('$baseUrl/catalog/datasets/ratp-${type}-lignes/records');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['records'] ?? []);
      } else {
        print('Failed to get $type lines: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting $type lines: $e');
      return [];
    }
  }

  // Récupère toutes les stations pour une ligne donnée
  static Future<List<Map<String, dynamic>>> getStations(String type, String line) async {
    try {
      final url = Uri.parse('$baseUrl/catalog/datasets/ratp-${type}-stations/records?where=ligne="${line}"');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['records'] ?? []);
      } else {
        print('Failed to get stations: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting stations: $e');
      return [];
    }
  }

  // Récupère les horaires en temps réel pour une station donnée
  static Future<List<Map<String, dynamic>>> getRealTimeSchedules(String type, String line, String station) async {
    try {
      final url = Uri.parse('$baseUrl/catalog/datasets/ratp-${type}-temps-reel/records?where=ligne="${line}" AND station="${station}"');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['records'] ?? []);
      } else {
        print('Failed to get schedules: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting schedules: $e');
      return [];
    }
  }

  // Récupère les informations de trafic pour une ligne donnée
  static Future<Map<String, dynamic>> getTrafficInfo(String type, String line) async {
    try {
      final url = Uri.parse('$baseUrl/catalog/datasets/trafic-${type}/records?where=ligne="${line}"');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['records']?.isNotEmpty) {
          return data['records'][0];
        }
        return {};
      } else {
        print('Failed to get traffic info: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error getting traffic info: $e');
      return {};
    }
  }

  // Récupère les prochains passages à une station donnée
  static Future<List<Map<String, dynamic>>> getNextDepartures(String type, String line, String station) async {
    try {
      final url = Uri.parse('$baseUrl/catalog/datasets/ratp-${type}-prochains-passages/records?where=ligne="${line}" AND station="${station}"');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['records'] ?? []);
      } else {
        print('Failed to get next departures: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting next departures: $e');
      return [];
    }
  }

  // Récupère la liste des destinations pour une ligne donnée
  static Future<List<String>> getDestinations(String type, String line) async {
    try {
      final url = Uri.parse('$baseUrl/catalog/datasets/ratp-${type}-destinations/records?where=ligne="${line}"');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final records = List<Map<String, dynamic>>.from(data['records'] ?? []);
        return records.map((record) => record['fields']['destination'] as String).toList();
      } else {
        print('Failed to get destinations: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error getting destinations: $e');
      return [];
    }
  }

  // Trouve la station la plus proche
  static Future<Map<String, dynamic>> findNearestStation(LatLng point, String type) async {
    final stations = await getStations(type, '');
    double minDistance = double.infinity;
    Map<String, dynamic> nearestStation = {};

    for (var station in stations) {
      final stationLat = station['fields']['coord']['lat'];
      final stationLon = station['fields']['coord']['lon'];
      final distance = _calculateDistance(point, LatLng(stationLat, stationLon));
      if (distance < minDistance) {
        minDistance = distance;
        nearestStation = station;
      }
    }

    return nearestStation;
  }

  static double _calculateDistance(LatLng point1, LatLng point2) {
    const R = 6371e3; // Earth's radius in meters
    final phi1 = point1.latitude * pi / 180;
    final phi2 = point2.latitude * pi / 180;
    final deltaPhi = (point2.latitude - point1.latitude) * pi / 180;
    final deltaLambda = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }


  // Simule un itinéraire en utilisant les informations des lignes et des stations
  static Future<List<TransitRoute>> simulateJourney(LatLng from, LatLng to) async {
    List<TransitRoute> routes = [];

    try {
      final transportTypes = ['metros', 'rer'];

      for (var type in transportTypes) {
        final nearestFromStation = await findNearestStation(from, type);
        final nearestToStation = await findNearestStation(to, type);

        if (nearestFromStation.isNotEmpty && nearestToStation.isNotEmpty) {
          final lineCode = nearestFromStation['fields']['ligne'];

          // Vérifiez si les deux stations sont sur la même ligne
          if (nearestToStation['fields']['ligne'] == lineCode) {
            final trafficInfo = await getTrafficInfo(type, lineCode);

            routes.add(TransitRoute(
              type: type,
              line: lineCode,
              direction: nearestToStation['fields']['nom_station'],
              startStation: nearestFromStation['fields']['nom_station'],
              endStation: nearestToStation['fields']['nom_station'],
              duration: _estimateDuration(nearestFromStation, nearestToStation),
            ));
          }
        }
      }
    } catch (e) {
      print('Error simulating journey: $e');
    }

    // Si aucun itinéraire n'a été trouvé, retourner un itinéraire par défaut
    if (routes.isEmpty) {
      routes.add(TransitRoute(
        type: 'metro',
        line: '1',
        direction: 'La Défense',
        startStation: 'Château de Vincennes',
        endStation: 'La Défense',
        duration: 60,
      ));
    }

    return routes;
  }

  static int _estimateDuration(Map<String, dynamic> fromStation, Map<String, dynamic> toStation) {
    final fromLat = fromStation['fields']['coord']['lat'];
    final fromLon = fromStation['fields']['coord']['lon'];
    final toLat = toStation['fields']['coord']['lat'];
    final toLon = toStation['fields']['coord']['lon'];

    final distance = _calculateDistance(LatLng(fromLat, fromLon), LatLng(toLat, toLon));

    // Estimation grossière : 1 minute par kilomètre, plus 2 minutes par station
    return (distance / 1000).round() + 2;
  }
}*/

