import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'location_detail_page.dart';
import 'package:swipezone/screens/widgets/map_page.dart'; // Import your updated MapScreen class
import 'package:latlong2/latlong.dart';

class PlanningPage extends StatefulWidget {
  final String title;
  final List<Location> selectedLocations;

  const PlanningPage({
    Key? key,
    required this.title,
    required this.selectedLocations,
  }) : super(key: key);

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.builder(
        itemCount: widget.selectedLocations.length,
        itemBuilder: (context, index) {
          final location = widget.selectedLocations[index];
          return ListTile(
            title: Text(location.nom),
            subtitle: Text(location.description ?? 'No description'),
            trailing: Text(
              '${location.localization.lat ?? 'N/A'}, ${location.localization.lng ?? 'N/A'}',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationDetailPage(location: location),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            Position userPosition = await Geolocator.getCurrentPosition();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapScreen(
                  userPosition:
                  LatLng(userPosition.latitude, userPosition.longitude),
                  locations: widget.selectedLocations,
                ),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
              const Text('Unable to get location. Please enable location services.'),
            ));
          }
        },
        tooltip: 'Créer le trajet',
        child: const Icon(Icons.directions),
      ),
    );
  }
}
