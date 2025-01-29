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
  List<Location> filteredLikedLocations = [];
  List<Location> filteredFavoriteLocations = [];
  String searchQueryLiked = '';
  String searchQueryFavorite = '';
  SortOption currentSortOptionLiked = SortOption.NameAZ;
  SortOption currentSortOptionFavorite = SortOption.NameAZ;
  Set<Categories> selectedCategoriesLiked = Set<Categories>();
  Set<Categories> selectedCategoriesFavorite = Set<Categories>();
  Position? userPosition;
  double maxDistanceLiked = double.infinity;
  double maxDistanceFavorite = double.infinity;
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
    final locationManager = Provider.of<LocationManager>(context, listen: false);

    // Filter and sort liked locations
    filteredLikedLocations = locationManager.getLikedButNotFavoriteLocations().where((location) {
      bool matchesSearch = location.nom.toLowerCase().contains(searchQueryLiked.toLowerCase()) ||
          location.category.toString().toLowerCase().contains(searchQueryLiked.toLowerCase());
      bool matchesCategory = selectedCategoriesLiked.isEmpty || selectedCategoriesLiked.contains(location.category);
      bool matchesProximity = _checkProximity(location, maxDistanceLiked);
      return matchesSearch && matchesCategory && matchesProximity;
    }).toList();

    _sortLocations(filteredLikedLocations, currentSortOptionLiked);

    // Filter and sort favorite locations
    filteredFavoriteLocations = locationManager.favoriteLocations.where((location) {
      bool matchesSearch = location.nom.toLowerCase().contains(searchQueryFavorite.toLowerCase()) ||
          location.category.toString().toLowerCase().contains(searchQueryFavorite.toLowerCase());
      bool matchesCategory = selectedCategoriesFavorite.isEmpty || selectedCategoriesFavorite.contains(location.category);
      bool matchesProximity = _checkProximity(location, maxDistanceFavorite);
      return matchesSearch && matchesCategory && matchesProximity;
    }).toList();

    _sortLocations(filteredFavoriteLocations, currentSortOptionFavorite);

    setState(() {});
  }

  bool _checkProximity(Location location, double maxDistance) {
    if (userPosition != null && maxDistance != double.infinity) {
      double distance = Geolocator.distanceBetween(
          userPosition!.latitude, userPosition!.longitude,
          location.localization.lat!, location.localization.lng!
      );
      return distance <= maxDistance;
    }
    return true;
  }

  void _sortLocations(List<Location> locations, SortOption sortOption) {
    locations.sort((a, b) {
      switch (sortOption) {
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
  }

  void _toggleAllLocations(bool? value, bool isLikedTab) {
    setState(() {
      List<Location> locationsToToggle = isLikedTab ? filteredLikedLocations : filteredFavoriteLocations;
      for (var location in locationsToToggle) {
        plans[location] = value ?? false;
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
            Builder(
              builder: (context) {
                final tabController = DefaultTabController.of(context);
                return PopupMenuButton<SortOption>(
                  icon: Icon(Icons.sort),
                  onSelected: (SortOption value) {
                    setState(() {
                      if (tabController?.index == 0) {
                        currentSortOptionLiked = value;
                      } else {
                        currentSortOptionFavorite = value;
                      }
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
                );
              },
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
            _buildLocationList(filteredLikedLocations, true),
            _buildLocationList(filteredFavoriteLocations, false),
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

  Widget _buildLocationList(List<Location> locations, bool isLikedTab) {
    return FadeTransition(
      opacity: _animation,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  if (isLikedTab) {
                    searchQueryLiked = value;
                  } else {
                    searchQueryFavorite = value;
                  }
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
                    selected: isLikedTab
                        ? selectedCategoriesLiked.contains(category)
                        : selectedCategoriesFavorite.contains(category),
                    onSelected: (bool selected) {
                      setState(() {
                        if (isLikedTab) {
                          if (selected) {
                            selectedCategoriesLiked.add(category);
                          } else {
                            selectedCategoriesLiked.remove(category);
                          }
                        } else {
                          if (selected) {
                            selectedCategoriesFavorite.add(category);
                          } else {
                            selectedCategoriesFavorite.remove(category);
                          }
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
                  'Distance maximale : ${isLikedTab ? (maxDistanceLiked == double.infinity ? "Illimité" : "${(maxDistanceLiked / 1000).toStringAsFixed(1)} km") : (maxDistanceFavorite == double.infinity ? "Illimité" : "${(maxDistanceFavorite / 1000).toStringAsFixed(1)} km")}',
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
                    value: isLikedTab
                        ? (maxDistanceLiked == double.infinity ? 100000 : maxDistanceLiked)
                        : (maxDistanceFavorite == double.infinity ? 100000 : maxDistanceFavorite),
                    min: 0,
                    max: 100000,
                    divisions: 100,
                    label: isLikedTab
                        ? (maxDistanceLiked == double.infinity ? 'Illimité' : '${(maxDistanceLiked / 1000).toStringAsFixed(1)} km')
                        : (maxDistanceFavorite == double.infinity ? 'Illimité' : '${(maxDistanceFavorite / 1000).toStringAsFixed(1)} km'),
                    onChanged: (value) {
                      setState(() {
                        if (isLikedTab) {
                          maxDistanceLiked = value == 100000 ? double.infinity : value;
                        } else {
                          maxDistanceFavorite = value == 100000 ? double.infinity : value;
                        }
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
            value: locations.isNotEmpty && locations.every((location) => plans[location] == true),
            onChanged: locations.isEmpty ? null : (value) => _toggleAllLocations(value, isLikedTab),
            activeColor: Theme.of(context).primaryColor,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                Location location = locations[index];
                bool isCheck = plans[location] ?? false;
                bool isFavorite = Provider.of<LocationManager>(context, listen: false).favoriteLocations.contains(location);
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(isFavorite ? Icons.star : Icons.star_border),
                          onPressed: () {
                            final locationManager = Provider.of<LocationManager>(context, listen: false);
                            locationManager.toggleFavorite(location);
                            _sortAndFilterLocations();
                          },
                        ),
                        if (!isFavorite || !isLikedTab)
                          Checkbox(
                            value: isCheck,
                            onChanged: (val) {
                              setState(() {
                                plans[location] = val ?? false;
                              });
                            },
                            activeColor: Theme.of(context).primaryColor,
                          ),
                      ],
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

