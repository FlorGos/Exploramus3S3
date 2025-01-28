import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:swipezone/screens/select_page.dart';
import 'package:swipezone/screens/SettingsPage.dart';
import 'package:swipezone/screens/widgets/map_page.dart';
import 'package:latlong2/latlong.dart'; // Import for LatLng
import 'package:swipezone/screens/pedometer_page.dart';
import 'package:swipezone/screens/nfc_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({Key? key, required String title}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late LocationManager _locationManager;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationManager = Provider.of<LocationManager>(context, listen: false);
    _pageController = PageController(viewportFraction: 0.85);
    _loadLocations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
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
    if (_locationManager.currentLocationId != null) {
      int index = _locationManager.getVisibleLocations().indexWhere(
            (location) => location.nom == _locationManager.currentLocationId,
      );
      if (index != -1) {
        _pageController.jumpToPage(index);
      }
    }
    setState(() {});
  }

  void _handleLike() {
    _locationManager.like();
    if (_locationManager.allLocationsVisited) {
      _showAllLocationsVisitedDialog();
    } else {
      _pageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _handleDislike() {
    _locationManager.dislike();
    if (_locationManager.allLocationsVisited) {
      _showAllLocationsVisitedDialog();
    } else {
      _pageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _showAllLocationsVisitedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Félicitations !'),
          content: Text('Vous avez vu tous les lieux ! Voulez-vous réinitialiser et recommencer ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Non'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Oui'),
              onPressed: () {
                Navigator.of(context).pop();
                _resetLocations();
              },
            ),
          ],
        );
      },
    );
  }

  void _resetLocations() async {
    await _locationManager.resetLikedLocations();
    await _locationManager.resetDislikedLocations();
    setState(() {});
  }

  Widget _buildLocationCard(Location location) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              child: location.imageUrl != null
                  ? Image.network(
                location.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey[600]),
                  );
                },
              )
                  : Container(
                color: Colors.grey[300],
                child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey[600]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.nom,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Catégorie: ${location.category.toString().split('.').last}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 8),
                Text(
                  location.description ?? 'Aucune description disponible',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[100]!, Colors.purple[100]!],
          ),
        ),
        child: SafeArea(
          child: Consumer<LocationManager>(
            builder: (context, locationManager, child) {
              if (locationManager.isLoading) {
                return Center(child: CircularProgressIndicator());
              }

              if (locationManager.allLocationsVisited) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Vous avez vu tous les lieux !',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                        child: Text('Réinitialiser et recommencer'),
                        onPressed: _resetLocations,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }

              List<Location> visibleLocations = locationManager.getVisibleLocations();

              return Column(
                children: [
                  AppBar(
                    title: Text('SwipeZone', style: TextStyle(color: Colors.black87)),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      IconButton(
                        icon: Icon(Icons.directions_walk, color: Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PedometerPage()),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.nfc, color: Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => NFCPage()),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.map, color: Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SelectPage(title: 'Sélection')),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: Colors.black87),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SettingsPage()),
                          ).then((_) => setState(() {}));
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: visibleLocations.length,
                      itemBuilder: (context, index) {
                        return _buildLocationCard(visibleLocations[index]);
                      },
                      onPageChanged: (index) {
                        locationManager.currentLocationId = visibleLocations[index].nom;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _handleDislike,
                          icon: Icon(Icons.thumb_down, color: Colors.white),
                          label: Text('Pas intéressé'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _handleLike,
                          icon: Icon(Icons.thumb_up, color: Colors.white),
                          label: Text('Intéressé'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

