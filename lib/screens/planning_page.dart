import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'location_detail_page.dart';
import 'package:latlong2/latlong.dart';
import 'package:swipezone/screens/widgets/map_page.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';

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
  late List<Location> favoriteLocations;

  @override
  void initState() {
    super.initState();
    _loadFavoriteLocations();
  }

  void _loadFavoriteLocations() {
    final locationManager = Provider.of<LocationManager>(context, listen: false);
    setState(() {
      favoriteLocations = locationManager.favoriteLocations;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          elevation: 0,
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Sélectionnés'),
              Tab(text: 'Favoris'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLocationList(widget.selectedLocations),
            _buildLocationList(favoriteLocations),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            try {
              Position userPosition = await Geolocator.getCurrentPosition();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MapScreen(
                    userPosition: LatLng(userPosition.latitude, userPosition.longitude),
                    locations: [...widget.selectedLocations, ...favoriteLocations],
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
          tooltip: 'Voir sur la carte',
          icon: Icon(Icons.map),
          label: Text('Voir sur la carte'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLocationList(List<Location> locations) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Text(
            'Votre itinéraire (${locations.length} lieux)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
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
    );
  }
}

