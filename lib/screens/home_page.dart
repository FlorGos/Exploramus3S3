import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:swipezone/screens/select_page.dart';
import 'package:swipezone/screens/SettingsPage.dart';
import 'package:swipezone/screens/pedometer_page.dart';
import 'package:swipezone/screens/nfc_page.dart';
import 'package:swipezone/screens/location_detail_page.dart';
import 'package:swipezone/screens/action.dart' as custom;

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required String title}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late LocationManager _locationManager;
  List<Location> _locations = [];
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<Offset> _animation;
  double _dragPercent = 0;
  Offset _dragStart = Offset.zero;
  final List<custom.Action> _actionHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationManager = Provider.of<LocationManager>(context, listen: false);
    _loadLocations();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLocations(); // Reload locations when app is resumed
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
    _animateCard(Offset(1, 0)).then((_) {
      _locationManager.like();
      _actionHistory.add(custom.Action('like', _locations[_currentIndex].nom));
      _moveToNextCard();
    });
  }

  void _handleDislike() {
    _animateCard(Offset(-1, 0)).then((_) {
      _locationManager.dislike();
      _actionHistory.add(custom.Action('dislike', _locations[_currentIndex].nom));
      _moveToNextCard();
    });
  }

  void _handleFavorite() {
    _animateCard(Offset(0, -1)).then((_) {
      _locationManager.favorite();
      _actionHistory.add(custom.Action('favorite', _locations[_currentIndex].nom));
      _moveToNextCard();
    });
  }

  Future<void> _animateCard(Offset end) async {
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: end,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    await _animationController.forward(from: 0);
    _animationController.reset();
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
    if (_actionHistory.isNotEmpty) {
      final lastAction = _actionHistory.removeLast();
      Location? lastLocation = _locationManager.undo();
      if (lastLocation != null) {
        setState(() {
          _locations.insert(_currentIndex, lastLocation);
          _currentIndex = _locations.indexOf(lastLocation); // Update current index
        });
        _locationManager.saveState(); // Save state after undo
      }
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
    _loadLocations();
  }

  Widget _buildLocationCard(Location location) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: _animation.value * MediaQuery.of(context).size.width,
          child: Transform.rotate(
            angle: _animation.value.dx * 0.2,
            child: Opacity(
              opacity: 1 - _animationController.value.abs(),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onPanStart: (details) {
          _dragStart = details.localPosition;
        },
        onPanUpdate: (details) {
          setState(() {
            _dragPercent = (details.localPosition.dx - _dragStart.dx) / MediaQuery.of(context).size.width;
            _animationController.value = _dragPercent;
          });
        },
        onPanEnd: (details) {
          if (_dragPercent.abs() > 0.5) {
            if (_dragPercent > 0) {
              _handleLike();
            } else {
              _handleDislike();
            }
          } else if (details.velocity.pixelsPerSecond.dy < -1000) {
            _handleFavorite();
          } else {
            _animationController.reverse();
          }
          _dragPercent = 0;
        },
        child: Stack(
          children: [
            Card(
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
                          location.imagePath != null
                              ? Image.asset(
                            location.imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
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
            ),
            if (_dragPercent != 0)
              Positioned(
                top: 20,
                left: _dragPercent > 0 ? 20 : null,
                right: _dragPercent < 0 ? 20 : null,
                child: Transform.rotate(
                  angle: _dragPercent > 0 ? -0.5 : 0.5,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _dragPercent > 0 ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _dragPercent > 0 ? 'LIKE' : 'NOPE',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback? onPressed) {
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
                    onPressed: () async {
                      await _locationManager.saveState(); // Save state before navigating
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SelectPage(title: 'Sélection')),
                      ).then((_) => _loadLocations()); // Reload locations after returning
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
                    : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildLocationCard(_locations[_currentIndex]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(Icons.thumb_down, 'Pas intéressé', Colors.red, _handleDislike),
                    _buildActionButton(Icons.undo, 'Retour', Colors.orange, _actionHistory.isNotEmpty ? _handleUndo : null),
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

