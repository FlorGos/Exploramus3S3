import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:swipezone/repositories/models/categories.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

enum SortOption { NameAZ, NameZA, TypeAZ, TypeZA, Proximity }

class SelectPage extends StatefulWidget {
  final String title;

  const SelectPage({Key? key, required this.title}) : super(key: key);

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> with SingleTickerProviderStateMixin {
  bool _permissionsChecked = false;
  Map<Location, bool> plans = {};
  List<Location> filteredLocations = [];
  List<Location> favoriteLocations = [];
  String searchQuery = '';
  SortOption currentSortOption = SortOption.NameAZ;
  Set<Categories> selectedCategories = Set<Categories>();
  Position? userPosition;
  double maxDistance = double.infinity;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndProceed();
    }
  }

  Future<void> _initializeApp() async {
    bool firstLaunch = await _isFirstLaunch();
    if (firstLaunch) {
      await _showPermissionDialog();
    } else {
      await _checkPermissionsAndProceed();
    }
  }

  Future<bool> _isFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('first_launch') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('first_launch', false);
    }
    return isFirstLaunch;
  }

  Future<bool> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
    ].request();
    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _checkPermissionsAndProceed() async {
    bool permissionsGranted = await _checkPermissions();
    if (permissionsGranted) {
      await _loadPlans();
      await _getUserLocation();
      setState(() => _permissionsChecked = true);
      _animationController.forward();
    } else {
      await _showPermissionDialog();
    }
  }

  Future<void> _showPermissionDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Autorisations nécessaires'),
          content: Text('Cette application nécessite des autorisations pour fonctionner.'),
          actions: <Widget>[
            TextButton(
              child: Text('Quitter'),
              onPressed: () => SystemNavigator.pop(),
            ),
            TextButton(
              child: Text('Accorder'),
              onPressed: () async {
                Navigator.of(context).pop();
                bool granted = await _checkPermissions();
                if (!granted) {
                  await _showOpenSettingsDialog();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOpenSettingsDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions requises'),
          content: Text('Vous devez accorder les permissions pour utiliser cette fonctionnalité. Voulez-vous accéder aux paramètres de l\'application ?'),
          actions: <Widget>[
            TextButton(
              child: Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Ouvrir les paramètres'),
              onPressed: () async {
                Navigator.of(context).pop();
                await AppSettings.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadPlans() async {
    final locationManager = Provider.of<LocationManager>(context, listen: false);
    await locationManager.loadState();
    setState(() {
      plans = Map.fromIterable(
        locationManager.likedLocations,
        key: (location) => location,
        value: (location) => true,
      );
      filteredLocations = locationManager.likedLocations;
      favoriteLocations = locationManager.favoriteLocations;
      _sortAndFilterLocations();
    });
  }

  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        userPosition = position;
        _sortAndFilterLocations();
      });
    } catch (e) {
      print("Error getting user location: $e");
    }
  }

  void _sortAndFilterLocations() {
    filteredLocations = plans.keys.where((location) {
      bool matchesSearch = location.nom.toLowerCase().contains(searchQuery.toLowerCase()) ||
          location.category.toString().toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesCategory = selectedCategories.isEmpty || selectedCategories.contains(location.category);

      bool matchesProximity = true;
      if (userPosition != null && maxDistance != double.infinity) {
        double distance = Geolocator.distanceBetween(
            userPosition!.latitude, userPosition!.longitude,
            location.localization.lat!, location.localization.lng!
        );
        matchesProximity = distance <= maxDistance;
      }

      return matchesSearch && matchesCategory && matchesProximity;
    }).toList();

    filteredLocations.sort((a, b) {
      switch (currentSortOption) {
        case SortOption.NameAZ:
          return a.nom.compareTo(b.nom);
        case SortOption.NameZA:
          return b.nom.compareTo(a.nom);
        case SortOption.TypeAZ:
          return a.category.toString().compareTo(b.category.toString());
        case SortOption.TypeZA:
          return b.category.toString().compareTo(a.category.toString());
        case SortOption.Proximity:
          if (userPosition != null) {
            double distanceA = Geolocator.distanceBetween(
                userPosition!.latitude, userPosition!.longitude,
                a.localization.lat!, a.localization.lng!
            );
            double distanceB = Geolocator.distanceBetween(
                userPosition!.latitude, userPosition!.longitude,
                b.localization.lat!, b.localization.lng!
            );
            return distanceA.compareTo(distanceB);
          }
          return 0;
      }
    });

    setState(() {});
  }

  void _toggleAllLocations(bool? value) {
    setState(() {
      for (var key in filteredLocations) {
        plans[key] = value ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_permissionsChecked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Permissions nécessaires', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermissionsAndProceed,
                child: Text('Vérifier les permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            PopupMenuButton<SortOption>(
              icon: Icon(Icons.sort),
              onSelected: (SortOption value) {
                setState(() {
                  currentSortOption = value;
                  _sortAndFilterLocations();
                });
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOption>>[
                const PopupMenuItem<SortOption>(
                  value: SortOption.NameAZ,
                  child: Text('Nom A-Z'),
                ),
                const PopupMenuItem<SortOption>(
                  value: SortOption.NameZA,
                  child: Text('Nom Z-A'),
                ),
                const PopupMenuItem<SortOption>(
                  value: SortOption.TypeAZ,
                  child: Text('Type A-Z'),
                ),
                const PopupMenuItem<SortOption>(
                  value: SortOption.TypeZA,
                  child: Text('Type Z-A'),
                ),
                const PopupMenuItem<SortOption>(
                  value: SortOption.Proximity,
                  child: Text('Par proximité'),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Lieux likés'),
              Tab(text: 'Favoris'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLocationList(filteredLocations),
            _buildLocationList(favoriteLocations),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            List<Location> selectedLocations = plans.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();

            context.go('/planningpage', extra: selectedLocations);
          },
          tooltip: 'Créer un plan',
          icon: Icon(Icons.map),
          label: Text('Créer un plan'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLocationList(List<Location> locations) {
    return FadeTransition(
      opacity: _animation,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                  _sortAndFilterLocations();
                });
              },
              decoration: InputDecoration(
                labelText: 'Rechercher',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: Categories.values.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category.toString().split('.').last),
                    selected: selectedCategories.contains(category),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          selectedCategories.add(category);
                        } else {
                          selectedCategories.remove(category);
                        }
                        _sortAndFilterLocations();
                      });
                    },
                    backgroundColor: Colors.grey[200],
                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).primaryColor,
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Distance maximale : ${maxDistance == double.infinity ? "Illimité" : (maxDistance / 1000).toStringAsFixed(1)} km',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Theme.of(context).primaryColor,
                    inactiveTrackColor: Theme.of(context).primaryColor.withOpacity(0.3),
                    thumbColor: Theme.of(context).primaryColor,
                    overlayColor: Theme.of(context).primaryColor.withOpacity(0.4),
                    valueIndicatorColor: Theme.of(context).primaryColor,
                    valueIndicatorTextStyle: TextStyle(color: Colors.white),
                  ),
                  child: Slider(
                    value: maxDistance == double.infinity ? 100000 : maxDistance,
                    min: 0,
                    max: 100000,
                    divisions: 100,
                    label: maxDistance == double.infinity ? 'Illimité' : '${(maxDistance / 1000).toStringAsFixed(1)} km',
                    onChanged: (value) {
                      setState(() {
                        maxDistance = value == 100000 ? double.infinity : value;
                        _sortAndFilterLocations();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          CheckboxListTile(
            title: Text('Sélectionner/Désélectionner tout', style: TextStyle(fontWeight: FontWeight.bold)),
            value: filteredLocations.isNotEmpty && filteredLocations.every((location) => plans[location] == true),
            onChanged: filteredLocations.isEmpty ? null : _toggleAllLocations,
            activeColor: Theme.of(context).primaryColor,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                Location location = locations[index];
                bool isCheck = plans[location] ?? false;
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16),
                    title: Text(location.nom, style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 4),
                        Text(location.category.toString().split('.').last),
                        if (userPosition != null)
                          Text(
                            'Distance: ${(Geolocator.distanceBetween(
                                userPosition!.latitude,
                                userPosition!.longitude,
                                location.localization.lat!,
                                location.localization.lng!
                            ) / 1000).toStringAsFixed(2)} km',
                          ),
                      ],
                    ),
                    trailing: Checkbox(
                      value: isCheck,
                      onChanged: (val) {
                        setState(() {
                          plans[location] = val ?? false;
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

