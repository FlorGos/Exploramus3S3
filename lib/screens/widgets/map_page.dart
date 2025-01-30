import 'package:swipezone/services/open_trip_planner_service.dart';
import 'dart:math' show pi, sin, cos, sqrt, atan2;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:swipezone/repositories/models/categories.dart';
import 'package:swipezone/repositories/models/localization.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:swipezone/screens/widgets/transparent_bottom_bar.dart';
import 'package:swipezone/screens/widgets/location_detail_modal.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/screens/widgets/legend_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swipezone/repositories/models/navigation_step.dart';
import 'package:swipezone/screens/widgets/navigation_instructions.dart';
import 'package:swipezone/screens/widgets/transit_info_panel.dart';
import 'package:swipezone/screens/widgets/add_marker_dialog.dart';
import 'package:swipezone/services/geocoding_service.dart';
import 'package:swipezone/services/ratp_api_service.dart';
import 'package:swipezone/services/prim_api_service.dart';

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

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  bool _isBarVisible = true;
  bool _isAddingMarker = false;
  TransportMode? _selectedMode;
  bool _isLoadingRoute = false;
  Location? _movingLocation;
  late AnimationController _controller;
  late Animation<double> _animation;
  late List<Location> _initialLocations;
  Map<String, List<LatLng>> _routePoints = {};
  String _currentProfile = '';
  List<NavigationStep> _navigationSteps = [];
  double _totalDistance = 0;
  int _totalDuration = 0;
  String _currentStreet = '';
  bool _showNavigationInstructions = false;
  List<LatLng> _osrmRoutePoints = [];
  bool _showTransitInfo = false;
  List<TransitRoute> _transitRoutes = [];
  List<LatLng> _basicPolylinePoints = [];
  bool _isOSRMRouteVisible = false;


  @override
  void initState() {
    super.initState();
    _initialLocations = widget.locations.map((loc) => loc.clone()).toList();
    _updateBasicPolylinePoints();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleVisibility() {
    setState(() {
      _isBarVisible = !_isBarVisible;
      if (_isBarVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _updateBasicPolylinePoints() {
    final sortedLocations = _sortLocationsByDistance();
    _basicPolylinePoints = [widget.userPosition, ...sortedLocations.map((loc) => LatLng(loc.localization.lat!, loc.localization.lng!))];
  }

  Future<void> _fetchOSRMRoute(String profile) async {
    setState(() {
      _isLoadingRoute = true;
    });

    final sortedLocations = _sortLocationsByDistance();
    final List<LatLng> waypoints = [widget.userPosition, ...sortedLocations.map((loc) => LatLng(loc.localization.lat!, loc.localization.lng!))];

    String coordinates = waypoints.map((point) => '${point.longitude},${point.latitude}').join(';');
    final url = Uri.parse('http://router.project-osrm.org/route/v1/$profile/$coordinates?overview=full&geometries=geojson&steps=true&annotations=true');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
        _osrmRoutePoints = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();

        final route = data['routes'][0];
        _totalDistance = route['distance'].toDouble();
        _totalDuration = route['duration'].toInt();

        final List<NavigationStep> steps = [];
        for (final leg in route['legs']) {
          for (final step in leg['steps']) {
            steps.add(NavigationStep.fromJson(step));
          }
        }
        _navigationSteps = steps;

        if (steps.isNotEmpty) {
          _currentStreet = steps[0].instruction;
        }

        setState(() {
          _showNavigationInstructions = true;
          _isOSRMRouteVisible = true;
        });
      } else {
        print('Failed to fetch OSRM route: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching OSRM route: $e');
    }

    setState(() {
      _isLoadingRoute = false;
    });
  }

  Future<void> _fetchTransitRoutes() async {
    setState(() {
      _isLoadingRoute = true;
    });

    try {
      final sortedLocations = _sortLocationsByDistance();
      if (sortedLocations.isNotEmpty) {
        final destination = sortedLocations.first;
        final from = widget.userPosition;
        final to = LatLng(destination.localization.lat!, destination.localization.lng!);

        final routes = await PrimApiService.getJourney(from, to);

        if (routes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aucun itinéraire trouvé pour cette destination.')),
          );
          return;
        }

        setState(() {
          _transitRoutes = routes;
          _showTransitInfo = true;
          _isOSRMRouteVisible = false;
          _showNavigationInstructions = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veuillez sélectionner une destination.')),
        );
      }
    } catch (e) {
      print('Error fetching transit routes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la recherche d\'itinéraire. Veuillez réessayer.')),
      );
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _onTransportModeSelected(TransportMode mode) async {
    if (_selectedMode == mode && _isOSRMRouteVisible) {
      setState(() {
        _isOSRMRouteVisible = false;
        _showNavigationInstructions = false;
        _showTransitInfo = false;
      });
      return;
    }

    setState(() {
      _selectedMode = mode;
      _isLoadingRoute = true;
    });

    String profile;
    switch (mode.name) {
      case 'Walking':
        profile = 'foot';
        _showTransitInfo = false;
        await _fetchOSRMRoute(profile);
        break;
      case 'Cycling':
        profile = 'bike';
        _showTransitInfo = false;
        await _fetchOSRMRoute(profile);
        break;
      case 'Driving':
        profile = 'car';
        _showTransitInfo = false;
        await _fetchOSRMRoute(profile);
        break;
      case 'Transit':
      case 'Metro':
      case 'RER':
      case 'Bus':
        await _fetchTransitRoutes();
        break;
      default:
        _showTransitInfo = false;
        _isOSRMRouteVisible = false;
        _showNavigationInstructions = false;
    }

    setState(() {
      _isLoadingRoute = false;
    });
  }

  List<Location> _sortLocationsByDistance() {
    final sortedLocations = List<Location>.from(widget.locations);
    sortedLocations.sort((a, b) {
      final distA = _calculateDistance(widget.userPosition, LatLng(a.localization.lat!, a.localization.lng!));
      final distB = _calculateDistance(widget.userPosition, LatLng(b.localization.lat!, b.localization.lng!));
      return distA.compareTo(distB);
    });
    return sortedLocations;
  }

  double _calculateDistance(LatLng start, LatLng end) {
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

  double _getTotalDistance() {
    return _totalDistance;
  }

  void _resetMarkers() {
    setState(() {
      for (int i = 0; i < widget.locations.length; i++) {
        widget.locations[i].localization.lat = _initialLocations[i].localization.lat;
        widget.locations[i].localization.lng = _initialLocations[i].localization.lng;
      }
      _movingLocation = null;
      _updateBasicPolylinePoints();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marqueurs réinitialisés à leur position initiale'), backgroundColor: Theme.of(context).primaryColor),
    );
  }

  Color _getMarkerColor(Location location) {
    final locationManager = Provider.of<LocationManager>(context, listen: false);
    if (locationManager.favoriteLocations.contains(location)) {
      return Colors.yellow;
    } else if (locationManager.likedLocations.contains(location)) {
      return Colors.red;
    }
    return Theme.of(context).primaryColor;
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (_isAddingMarker) {
      _addNewMarkerAtPosition(point);
    } else if (_movingLocation != null) {
      _updateMarkerPosition(_movingLocation!, point);
    }
  }

  void _addNewMarkerAtPosition(LatLng point) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Marker'),
          content: Text('Do you want to add a marker at this location?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isAddingMarker = false;
                });
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () async {
                Navigator.of(context).pop();
                final address = await _getStreetNameFromCoordinates(point.latitude, point.longitude);
                Location newLocation = Location(
                  nom: "New Marker",
                  description: " ",
                  schedule: null,
                  contact: null,
                  imageUrl: null,
                  category: Categories.Unknown,
                  website: null,
                  localization: Localization(address, point.latitude, point.longitude),
                );
                setState(() {
                  widget.locations.add(newLocation);
                  _isAddingMarker = false;
                });
                _updateBasicPolylinePoints();
              },
            ),
          ],
        );
      },
    );
  }

  void _updateMarkerPosition(Location location, LatLng newPosition) {
    setState(() {
      location.localization.lat = newPosition.latitude;
      location.localization.lng = newPosition.longitude;
      _movingLocation = null;
    });
    _updateLocationAddress(location);
    _updateBasicPolylinePoints();
  }

  Future<void> _updateLocationAddress(Location location) async {
    final address = await _getStreetNameFromCoordinates(location.localization.lat!, location.localization.lng!);
    setState(() {
      location.localization.adress = address;
    });
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
        return "Coordinates: $lat, $lng";
      }
    } catch (e) {
      print("Error getting address: $e");
      return "$lat, $lng";
    }
  }

  void _showLocationsList() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Selected Locations'),
          content: SingleChildScrollView(
            child: ListBody(
              children: widget.locations.map((location) =>
                  ListTile(
                    title: Text(location.nom),
                    subtitle: Text(location.description ?? ''),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showDeleteConfirmationDialog(location);
                      },
                    ),
                  )
              ).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(Location location) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmation'),
          content: Text('Are you sure you want to delete this location?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Delete'),
              onPressed: () {
                setState(() {
                  widget.locations.remove(location);
                });
                Navigator.of(context).pop();
                _updateBasicPolylinePoints();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Location deleted')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddMarkerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddMarkerDialog(
          onMapSelection: (LatLng point) {
            setState(() {
              _isAddingMarker = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tapez sur la carte pour ajouter un marqueur'),
                duration: Duration(seconds: 2),
                backgroundColor: Theme.of(context).primaryColor,
              ),
            );
          },
          onAddressSelection: (GeocodingResult result) {
            _addNewMarkerAtPosition(LatLng(result.lat, result.lon));
          },
        );
      },
    );
  }

  void _addNewMarker() {
    _showAddMarkerDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Map'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Stack(
        children: [
          FlutterMap(
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
                  if (_isOSRMRouteVisible)
                    Polyline(
                      points: _osrmRoutePoints,
                      color: _getRouteColor(_currentProfile),
                      strokeWidth: 4.0,
                    )
                  else
                    Polyline(
                      points: _basicPolylinePoints,
                      color: Theme.of(context).primaryColor,
                      strokeWidth: 4.0,
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
                          _showLocationDetailModal(location);
                        },
                        onLongPress: () {
                          _startMovingMarker(location);
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          child: Icon(
                            Icons.location_on,
                            color: _movingLocation == location ? Colors.green : _getMarkerColor(location),
                            size: _movingLocation == location ? 50.0 : 40.0,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,  // Distance from the top of the map
            right: 16,  // Distance from the right edge of the map
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: FloatingActionButton(
                heroTag: "toggleVisibility",
                child: Icon(
                  _isBarVisible ? Icons.visibility_off : Icons.visibility,
                  size: 20, // Reduced icon size
                ),
                onPressed: _toggleVisibility,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
                elevation: 4, // Add some elevation for better visibility
                mini: true, // Use a smaller FAB size
              ),
            ),
          ),
          if (_isLoadingRoute)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
              ),
            ),
          SizeTransition(
            sizeFactor: _animation,
            axisAlignment: -1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8, right: 16),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: LegendWidget(),
                  ),
                ),
                TransparentBottomBar(
                  transportModes: [
                    TransportMode(name: 'Walking', icon: Icons.directions_walk, speedKmPerHour: 5),
                    TransportMode(name: 'Cycling', icon: Icons.directions_bike, speedKmPerHour: 15),
                    TransportMode(name: 'Driving', icon: Icons.directions_car, speedKmPerHour: 50),
                    TransportMode(name: 'Metro', icon: Icons.subway, speedKmPerHour: 30),
                    TransportMode(name: 'RER', icon: Icons.train, speedKmPerHour: 40),
                    TransportMode(name: 'Bus', icon: Icons.directions_bus, speedKmPerHour: 20),
                  ],
                  selectedMode: _selectedMode,
                  onListPressed: _showLocationsList,
                  onAddPressed: _addNewMarker,
                  totalDistance: _getTotalDistance(),
                  onTransportModeSelected: _onTransportModeSelected,
                  onResetPressed: _resetMarkers,
                ),
              ],
            ),
          ),
          if (_showNavigationInstructions && _isBarVisible)
            Positioned(
              top: 0,
              right: 0,
              width: 300,
              bottom: 100,
              child: Card(
                margin: EdgeInsets.all(8),
                child: NavigationInstructions(
                  steps: _navigationSteps,
                  totalDistance: _totalDistance,
                  totalDuration: _totalDuration,
                  streetName: _currentStreet,
                  onClose: () => setState(() => _showNavigationInstructions = false),
                ),
              ),
            ),
          if (_showTransitInfo && _isBarVisible)
            Positioned(
              top: 0,
              right: 0,
              width: 300,
              bottom: 100,
              child: TransitInfoPanel(
                routes: _transitRoutes,
                onClose: () => setState(() => _showTransitInfo = false),
              ),
            ),
        ],
      ),
    );
  }

  Color _getRouteColor(String profile) {
    switch (profile) {
      case 'foot':
        return Colors.green[600]!;
      case 'bike':
        return Colors.orange[600]!;
      case 'car':
        return Colors.blue[600]!;
      case 'transit':
        return Colors.purple[600]!;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  void _showLocationDetailModal(Location location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return LocationDetailModal(location: location, scrollController: controller);
          },
        );
      },
    );
  }

  void _startMovingMarker(Location location) {
    setState(() {
      _movingLocation = location;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tap on the map to move the marker'),
        duration: Duration(seconds: 2),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}

