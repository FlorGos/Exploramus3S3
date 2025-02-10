import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:swipezone/screens/widgets/transit_info_panel.dart';

class PrimApiService {
  static const String baseUrl = 'https://prim.iledefrance-mobilites.fr/marketplace/navitia';
  static const String apiKey = 'VOTRE_CLE_API_ICI'; // Remplacez par votre clé API PRIM

  static Future<List<TransitRoute>> getJourney(LatLng from, LatLng to) async {
    final url = Uri.parse('$baseUrl/v1/coverage/fr-idf/journeys?from=${from.longitude};${from.latitude}&to=${to.longitude};${to.latitude}');

    try {
      final response = await http.get(
        url,
        headers: {'Authorization': apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseJourneys(data['journeys']);
      } else {
        print('Failed to fetch journey: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching journey: $e');
      return [];
    }
  }

  static List<TransitRoute> _parseJourneys(List<dynamic> journeys) {
    List<TransitRoute> routes = [];

    for (var journey in journeys) {
      for (var section in journey['sections']) {
        if (section['type'] == 'public_transport') {
          routes.add(TransitRoute(
            type: _getTransportType(section['display_informations']['commercial_mode']),
            line: section['display_informations']['code'],
            direction: section['display_informations']['direction'],
            startStation: section['from']['name'],
            endStation: section['to']['name'],
            duration: section['duration'] ~/ 60,  // Convert seconds to minutes
          ));
        }
      }
    }

    return routes;
  }

  static String _getTransportType(String commercialMode) {
    switch (commercialMode.toLowerCase()) {
      case 'métro':
        return 'metro';
      case 'rer':
        return 'rer';
      case 'bus':
        return 'bus';
      case 'tramway':
        return 'tram';
      default:
        return 'unknown';
    }
  }

// Vous pouvez ajouter d'autres méthodes ici pour récupérer des informations spécifiques
// comme les horaires en temps réel, les perturbations, etc.
}

