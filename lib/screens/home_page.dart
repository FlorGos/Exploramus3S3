import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:swipezone/screens/select_page.dart';
import 'package:swipezone/screens/SettingsPage.dart';
import 'package:swipezone/screens/pedometer_page.dart';
import 'package:swipezone/screens/nfc_page.dart';
import 'package:swipezone/screens/location_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required String title}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late LocationManager _locationManager;
  List<Location> _locations = [];
  int _currentIndex = 0;

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
    setState(() {
      _locations = _locationManager.getVisibleLocations();
      if (_locationManager.currentLocationId != null) {
        _currentIndex = _locations.indexWhere(
              (location) => location.nom == _locationManager.currentLocationId,
        );
        if (_currentIndex == -1) _currentIndex = 0;
      }
    });
  }

  void _handleLike() {
    _locationManager.like();
    _moveToNextCard();
  }

  void _handleDislike() {
    _locationManager.dislike();
    _moveToNextCard();
  }

  void _handleFavorite() {
    _locationManager.favorite();
    _moveToNextCard();
  }

  void _moveToNextCard() {
    setState(() {
      if (_currentIndex < _locations.length - 1) {
        _currentIndex++;
      } else {
        _showAllLocationsVisitedDialog();
      }
    });
  }

  void _handleUndo() {
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
      }
      Location? lastLocation = _locationManager.undo();
      if (lastLocation != null) {
        _locations.insert(0, lastLocation);
      }
    });
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
    _loadLocations();
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  location.imageUrl != null
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        ),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location.nom,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Catégorie: ${location.category.toString().split('.').last}',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              location.description ?? 'Aucune description disponible',
              style: TextStyle(fontSize: 16),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: CircleBorder(),
        padding: EdgeInsets.all(16),
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
          child: Column(
            children: [
              AppBar(
                title: Text('SwipeZone', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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
                child: _locations.isEmpty
                    ? Center(child: Text('Aucun lieu disponible'))
                    : GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! > 0) {
                      _handleLike();
                    } else if (details.primaryVelocity! < 0) {
                      _handleDislike();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity! < 0) {
                      _handleFavorite();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildLocationCard(_locations[_currentIndex]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(Icons.thumb_down, 'Pas intéressé', Colors.red, _handleDislike),
                    _buildActionButton(Icons.undo, 'Retour', Colors.orange, _handleUndo),
                    _buildActionButton(Icons.thumb_up, 'Intéressé', Colors.green, _handleLike),
                    _buildActionButton(Icons.star, 'Favori', Colors.blue, _handleFavorite),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

