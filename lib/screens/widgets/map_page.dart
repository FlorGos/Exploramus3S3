import 'dart:math' show pi, sin, cos, sqrt, atan2, Random;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:swipezone/repositories/models/categories.dart';
import 'package:swipezone/repositories/models/localization.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:osrm/osrm.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class MapScreen extends StatefulWidget {
  final LatLng userPosition;
  final List<Location> locations;

  const MapScreen({
    Key? key,
    required this.userPosition,
    required this.locations,
  }) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _isBarVisible = true;
  List<LatLng> _polylinePoints = [];
  bool _isAddingMarker = false;
  TransportMode? _selectedMode;
  // Add this variable to the _MapScreenState class
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _updatePolylinePoints();
  }

  void _toggleBarVisibility() {
    setState(() {
      _isBarVisible = !_isBarVisible;
    });
  }

  void _onMapMoved() {
    if (_isBarVisible) {
      setState(() {
        _isBarVisible = false;
      });
    }
    _resetBarVisibilityTimer();
  }

  void _resetBarVisibilityTimer() {
    Future.delayed(Duration(seconds: 2), () {
      if (mounted && !_isBarVisible) {
        setState(() {
          _isBarVisible = true;
        });
      }
    });
  }


  //TEST LOCATION***********************************************************************************************
  //CALCULATED FOR OSMR
  /*
  void _updatePolylinePoints() async {
    setState(() {
      _isLoadingRoute = true; // Affiche le loader
    });

    _polylinePoints = await _calculateSimulatedRoute(_selectedMode);

    setState(() {
      _isLoadingRoute = false; // Cache le loader
    });
  }*/


  void _updatePolylinePoints() {
    _polylinePoints = _calculateSimulatedRoute(_selectedMode);
    setState(() {});
  }

  //TEST LOCATION***********************************************************************************************

  void _addNewMarker() {
    setState(() {
      _isAddingMarker = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cliquez sur la carte pour placer un nouveau marqueur')),
    );
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_isAddingMarker) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Ajouter un marqueur'),
            content: Text('Voulez-vous ajouter un marqueur à cet endroit ?'),
            actions: <Widget>[
              TextButton(
                child: Text('Annuler'),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _isAddingMarker = false;
                  });
                },
              ),
              TextButton(
                child: Text('Ajouter'),
                onPressed: () async {
                  Navigator.of(context).pop();
                  final address = await _getStreetNameFromCoordinates(point.latitude, point.longitude);
                  Location newLocation = Location(
                    "Nouveau Marqueur",
                    null,
                    null,
                    null,
                    null,
                    Categories.Unknown,
                    null,
                    Localization(address, point.latitude, point.longitude),
                  );
                  setState(() {
                    widget.locations.add(newLocation);
                    _isAddingMarker = false;
                  });
                  _updatePolylinePoints();
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<String> _getStreetNameFromCoordinates(double lat, double lng) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks[0];
        String streetNumber = place.subThoroughfare ?? '';
        String street = place.thoroughfare ?? '';
        String city = place.locality ?? '';
        String postalCode = place.postalCode ?? '';
        String country = place.country ?? '';
        return "$streetNumber $street, $postalCode $city, $country".trim();
      } else {
        return "Coordonnées: $lat, $lng";
      }
    } catch (e) {
      print("Erreur lors de l'obtention de l'adresse: $e");
      return " $lat, $lng";
    }
  }

  void _showLocationsList() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Lieux sélectionnés'),
          content: SingleChildScrollView(
            child: ListBody(
              children: widget.locations.map((location) =>
                  ListTile(
                    title: Text(location.nom),
                    subtitle: Text(location.description ?? ''),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext confirmContext) {
                            return AlertDialog(
                              title: Text('Confirmation'),
                              content: Text('Voulez-vous vraiment supprimer ce lieu ?'),
                              actions: <Widget>[
                                TextButton(
                                  child: Text('Annuler'),
                                  onPressed: () {
                                    Navigator.of(confirmContext).pop();
                                  },
                                ),
                                TextButton(
                                  child: Text('Supprimer'),
                                  onPressed: () {
                                    setState(() {
                                      widget.locations.remove(location);
                                    });
                                    _updatePolylinePoints();
                                    Navigator.of(confirmContext).pop();
                                    Navigator.of(context).pop();
                                    _showLocationsList();
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  )
              ).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Fermer'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  double calculateDistance(LatLng start, LatLng end) {
    const R = 6371e3;
    final phi1 = start.latitude * pi / 180;
    final phi2 = end.latitude * pi / 180;
    final deltaPhi = (end.latitude - start.latitude) * pi / 180;
    final deltaLambda = (end.longitude - start.longitude) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  List<Location> sortLocationsByDistance() {
    final sortedLocations = List<Location>.from(widget.locations);
    sortedLocations.sort((a, b) {
      final distA = calculateDistance(widget.userPosition, LatLng(a.localization.lat!, a.localization.lng!));
      final distB = calculateDistance(widget.userPosition, LatLng(b.localization.lat!, b.localization.lng!));
      return distA.compareTo(distB);
    });
    return sortedLocations;
  }

//TEST LOCATION***********************************************************************************************
//CALCULATED POUR OSRM
  /*
  Future<List<LatLng>> _getRoutePoints(LatLng start, LatLng end) async {
    final url = 'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(data); // Debugging: Check API response structure

        if (data['routes'].isEmpty) {
          throw Exception('No route found');
        }

        String encodedPolyline = data['routes'][0]['geometry'];
        List<LatLng> coordinates = decodePolyline(encodedPolyline);
        return coordinates;
      } else {
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } catch (e) {
      print("Error fetching route points: $e");
      return []; // Return an empty list on error
    }
  }



  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result >> 1) ^ -(result & 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result >> 1) ^ -(result & 1));
      lng += dlng;

      LatLng p = LatLng(lat / 1E5, lng / 1E5);
      poly.add(p);
    }

    return poly;
  }
//CALCULATED POUR OSRM

  Future<List<LatLng>> _calculateSimulatedRoute(TransportMode? mode) async {
    final sortedLocations = sortLocationsByDistance();
    final points = <LatLng>[widget.userPosition];

    for (final location in sortedLocations) {
      final end = LatLng(location.localization.lat!, location.localization.lng!);

      // Obtenez les points d'itinéraire en utilisant l'API
      List<LatLng> routePoints = await _getRoutePoints(points.last, end);

      // Ajoutez les points de l'itinéraire à la liste
      points.addAll(routePoints);
    }

    return points;
  }
*/



  List<LatLng> _calculateSimulatedRoute(TransportMode? mode) {
    final sortedLocations = sortLocationsByDistance();
    final points = <LatLng>[widget.userPosition];

    for (final location in sortedLocations) {
      final end = LatLng(location.localization.lat!, location.localization.lng!);
      points.add(end); // Ajoute directement le point final
    }

    return points;
  }
  /*
  List<LatLng> _calculateSimulatedRoute(TransportMode? mode) {
    final sortedLocations = sortLocationsByDistance();
    final points = <LatLng>[widget.userPosition];
    final random = Random();

    for (int i = 0; i < sortedLocations.length; i++) {
      final location = sortedLocations[i];
      final start = points.last;
      final end = LatLng(location.localization.lat!, location.localization.lng!);

      // Générer des points intermédiaires pour simuler un itinéraire
      //final intermediatePoints = _generateIntermediatePoints(start, end, mode, random);
      //points.addAll(intermediatePoints);
    }

    return points;
  }*/

 /* List<LatLng> _generateIntermediatePoints(LatLng start, LatLng end, TransportMode? mode, Random random) {
    final points = <LatLng>[];
    final distance = calculateDistance(start, end);

    // Définir la taille de la grille en fonction du mode de transport
    double gridSize;
    switch (mode?.name ?? 'À pied') {
      case 'À pied':
        gridSize = 0.0001; // Environ 11 mètres à l'équateur
        break;
      case 'Vélo':
        gridSize = 0.0002;
        break;
      case 'Voiture':
        gridSize = 0.0005;
        break;
      case 'Transport en commun':
        gridSize = 0.001;
        break;
      default:
        gridSize = 0.0002;
    }

    // Calculer le nombre de cellules de la grille entre le début et la fin
    int gridCellsX = ((end.longitude - start.longitude) / gridSize).abs().ceil();
    int gridCellsY = ((end.latitude - start.latitude) / gridSize).abs().ceil();

    // Initialiser la position actuelle
    LatLng current = start;
    points.add(current);

    while (current != end) {
      // Déterminer la direction générale
      double dx = end.longitude - current.longitude;
      double dy = end.latitude - current.latitude;

      // Choisir un mouvement horizontal ou vertical en fonction de la distance restante
      if (random.nextBool() && dx.abs() > gridSize / 2) {
        // Mouvement horizontal
        current = LatLng(
          current.latitude,
          current.longitude + (dx > 0 ? gridSize : -gridSize),
        );
      } else if (dy.abs() > gridSize / 2) {
        // Mouvement vertical
        current = LatLng(
          current.latitude + (dy > 0 ? gridSize : -gridSize),
          current.longitude,
        );
      } else {
        // Si on est proche de la destination, on y va directement
        current = end;
      }

      // Ajouter une petite variation aléatoire pour simuler des virages
      if (current != end) {
        current = LatLng(
          current.latitude + (random.nextDouble() - 0.5) * gridSize * 0.2,
          current.longitude + (random.nextDouble() - 0.5) * gridSize * 0.2,
        );
      }

      points.add(current);
    }

    return points;
  }*/

  //TEST LOCATION***********************************************************************************************

  double _getTotalDistance() {
    double totalDistance = 0;
    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      totalDistance += calculateDistance(_polylinePoints[i], _polylinePoints[i + 1]);
    }
    return totalDistance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte Flutter Map'),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onPanUpdate: (_) => _onMapMoved(),
            child: FlutterMap(
              options: MapOptions(
                center: widget.userPosition,
                zoom: 13.0,
                onTap: _handleMapTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      color: Colors.blue,
                      strokeWidth: 3.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: widget.userPosition,
                      builder: (ctx) => const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40.0,
                      ),
                    ),
                    ...widget.locations.map((location) {
                      return Marker(
                        width: 80.0,
                        height: 80.0,
                        point: LatLng(location.localization.lat!, location.localization.lng!),
                        builder: (ctx) => GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (BuildContext context) {
                                return DraggableScrollableSheet(
                                  initialChildSize: 0.6,
                                  minChildSize: 0.3,
                                  maxChildSize: 0.9,
                                  expand: false,
                                  builder: (_, controller) {
                                    return LocationDetailModal(location: location, scrollController: controller);
                                  },
                                );
                              },
                            );
                          },
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40.0,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              child: Icon(_isBarVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: _toggleBarVisibility,
            ),
          ),
          if (_isLoadingRoute)
            Center(
              child: CircularProgressIndicator(),
            ),
          if (_isBarVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: TransparentBottomBar(
                transportModes: [
                  TransportMode(name: 'À pied', icon: Icons.directions_walk, speedKmPerHour: 5),
                  TransportMode(name: 'Vélo', icon: Icons.directions_bike, speedKmPerHour: 15),
                  TransportMode(name: 'Voiture', icon: Icons.directions_car, speedKmPerHour: 50),
                  TransportMode(name: 'Transport en commun', icon: Icons.directions_bus, speedKmPerHour: 30),
                ],
                selectedMode: _selectedMode,
                onListPressed: _showLocationsList,
                onAddPressed: _addNewMarker,
                totalDistance: _getTotalDistance(),
                onTransportModeSelected: (mode) async {
                  setState(() {
                    _selectedMode = mode;
                    _isLoadingRoute = true;
                  });
                  final newPoints = await Future.sync(() => _calculateSimulatedRoute(mode));
                  setState(() {
                    _polylinePoints = newPoints;
                    _isLoadingRoute = false;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class TransparentBottomBar extends StatelessWidget {
  final List<TransportMode> transportModes;
  final VoidCallback onListPressed;
  final VoidCallback onAddPressed;
  final double totalDistance;
  final Function(TransportMode) onTransportModeSelected;
  final TransportMode? selectedMode;

  TransparentBottomBar({
    required this.transportModes,
    required this.onListPressed,
    required this.onAddPressed,
    required this.totalDistance,
    required this.onTransportModeSelected,
    this.selectedMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ...transportModes.map((mode) =>
              ElevatedButton.icon(
                icon: Icon(mode.icon),
                label: Text('${mode.name}\n${mode.getEstimatedTime(totalDistance)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mode == selectedMode ? Colors.blue : null,
                ),
                onPressed: () {
                  onTransportModeSelected(mode);
                },
              )
          ).toList(),
          ElevatedButton.icon(
            icon: Icon(Icons.list),
            label: Text('Liste'),
            onPressed: onListPressed,
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.add_location),
            label: Text('Ajouter'),
            onPressed: onAddPressed,
          ),
        ],
      ),
    );
  }
}

class TransportMode {
  final String name;
  final IconData icon;
  final double speedKmPerHour;

  TransportMode({required this.name, required this.icon, required this.speedKmPerHour});

  String getEstimatedTime(double distanceInMeters) {
    double timeInHours = distanceInMeters / 1000 / speedKmPerHour;
    int minutes = (timeInHours * 60).round();
    return '$minutes min';
  }
}

class LocationDetailModal extends StatefulWidget {
  final Location location;
  final ScrollController scrollController;

  const LocationDetailModal({
    Key? key,
    required this.location,
    required this.scrollController
  }) : super(key: key);

  @override
  _LocationDetailModalState createState() => _LocationDetailModalState();
}

class _LocationDetailModalState extends State<LocationDetailModal> {
  TextEditingController _notesController = TextEditingController();
  String? _savedNotes;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedNotes = prefs.getString('notes_${widget.location.nom}') ?? '';
      _notesController.text = _savedNotes!;
    });
  }

  Future<void> _saveNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_${widget.location.nom}', _notesController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Text(
            widget.location.nom,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(widget.location.description ?? 'Pas de description disponible'),
          SizedBox(height: 10),
          Text(
            'Adresse: ${widget.location.localization.adress ?? 'Adresse non disponible'}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _saveNotes();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notes enregistrées !')),
              );
            },
            child: Text('Enregistrer les notes'),
          ),
        ],
      ),
    );
  }
}

