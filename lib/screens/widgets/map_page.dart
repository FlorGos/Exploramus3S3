import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:swipezone/repositories/models/location.dart';

class MapScreen extends StatelessWidget {
  final LatLng userPosition; // User's current position
  final List<Location> locations; // List of selected locations

  const MapScreen({
    Key? key,
    required this.userPosition,
    required this.locations,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte Flutter Map'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: userPosition, // Center on user's position
          zoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              // Marker for user's current position
              Marker(
                width: 80.0,
                height: 80.0,
                point: userPosition,
                builder: (ctx) => const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 40.0,
                ),
              ),
              // Markers for selected locations
              ...locations.map((location) {
                return Marker(
                  width: 80.0,
                  height: 80.0,
                  point: LatLng(location.localization.lat!, location.localization.lng!),
                  builder: (ctx) => const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40.0,
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }
}
