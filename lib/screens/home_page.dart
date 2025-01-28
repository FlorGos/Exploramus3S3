import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:swipezone/screens/select_page.dart';
import 'package:swipezone/screens/SettingsPage.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late LocationManager _locationManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationManager = Provider.of<LocationManager>(context, listen: false);
    _loadLocations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _locationManager.saveState();
    } else if (state == AppLifecycleState.resumed) {
      _loadLocations();
    }
  }

  Future<void> _loadLocations() async {
    await _locationManager.loadState();
  }

  void _handleLike() {
    _locationManager.like();
    if (_locationManager.allLocationsVisited) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous avez vu tous les lieux ! Allez dans les paramètres pour réinitialiser.')),
      );
    }
  }

  void _handleDislike() {
    _locationManager.dislike();
    if (_locationManager.allLocationsVisited) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vous avez vu tous les lieux ! Allez dans les paramètres pour réinitialiser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SwipeZone'),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SelectPage(title: 'Sélection')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              ).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Consumer<LocationManager>(
        builder: (context, locationManager, child) {
          if (locationManager.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (locationManager.allLocationsVisited) {
            return Center(child: Text('Vous avez vu tous les lieux ! Réinitialisez les listes pour recommencer.'));
          }

          Location? currentLocation = locationManager.getCurrentVisibleLocation();

          if (currentLocation == null) {
            return Center(child: Text('Aucun lieu disponible'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  currentLocation.nom,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: currentLocation.imageUrl != null && currentLocation.imageUrl!.isNotEmpty
                        ? Image.network(
                      currentLocation.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(child: Text('Impossible de charger l\'image'));
                      },
                    )
                        : Center(child: Text('Aucune image disponible')),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Catégorie: ${currentLocation.category.toString().split('.').last}',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  currentLocation.description ?? 'Aucune description disponible',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _handleDislike,
                      icon: Icon(Icons.thumb_down),
                      label: Text('Pas intéressé'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _handleLike,
                      icon: Icon(Icons.thumb_up),
                      label: Text('Intéressé'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

