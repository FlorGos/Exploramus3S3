import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'location_detail_page.dart';
import 'package:swipezone/screens/widgets/map_page.dart';
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
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              'Votre itinéraire (${widget.selectedLocations.length} lieux)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.selectedLocations.length,
              itemBuilder: (context, index) {
                final location = widget.selectedLocations[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text('${index + 1}', style: TextStyle(color: Colors.white)),
                    ),
                    title: Text(location.nom, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location.description ?? 'Pas de description'),
                        SizedBox(height: 4),
                        Text(
                          'Coordonnées: ${location.localization.lat?.toStringAsFixed(4) ?? 'N/A'}, ${location.localization.lng?.toStringAsFixed(4) ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocationDetailPage(location: location),
                        ),
                      );
                    },
                    trailing: Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            Position userPosition = await Geolocator.getCurrentPosition();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapScreen(
                  userPosition: LatLng(userPosition.latitude, userPosition.longitude),
                  locations: widget.selectedLocations,
                ),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Impossible d\'obtenir la localisation. Veuillez activer les services de localisation.'),
              backgroundColor: Colors.red,
            ));
          }
        },
        tooltip: 'Créer le trajet',
        icon: Icon(Icons.directions),
        label: Text('Voir sur la carte'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

