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

  const SelectPage({super.key, required this.title});

  @override
  State<SelectPage> createState() => _SelectPageState();
}

class _SelectPageState extends State<SelectPage> {
  bool _permissionsChecked = false;
  Map<Location, bool> plans = {};
  List<Location> filteredLocations = [];
  String searchQuery = '';
  SortOption currentSortOption = SortOption.NameAZ;
  Set<Categories> selectedCategories = Set<Categories>();
  Position? userPosition;
  double maxDistance = double.infinity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
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
              Text('Permissions nécessaires'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkPermissionsAndProceed,
                child: Text('Vérifier les permissions'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<SortOption>(
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
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
              ),
            ),
          ),
          Wrap(
            spacing: 8.0,
            children: Categories.values.map((category) {
              return FilterChip(
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
              );
            }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                Text('Distance maximale : ${maxDistance == double.infinity ? "Illimité" : (maxDistance / 1000).toStringAsFixed(1)} km'),
                Slider(
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
              ],
            ),
          ),
          CheckboxListTile(
            title: Text('Sélectionner/Désélectionner tout'),
            value: filteredLocations.isNotEmpty && filteredLocations.every((location) => plans[location] == true),
            onChanged: filteredLocations.isEmpty ? null : _toggleAllLocations,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredLocations.length,
              itemBuilder: (context, index) {
                Location location = filteredLocations[index];
                bool isCheck = plans[location] ?? false;
                return ListTile(
                  title: Text(location.nom),
                  subtitle: Text(location.category.toString().split('.').last),
                  trailing: Checkbox(
                    value: isCheck,
                    onChanged: (val) {
                      if (val == false) {
                        Provider.of<LocationManager>(context, listen: false).unlikeLocation(location);
                      }
                      setState(() {
                        plans[location] = val ?? false;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          List<Location> selectedLocations = plans.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();

          context.push('/planningpage', extra: selectedLocations);
        },
        tooltip: 'Add plan',
        child: const Icon(Icons.map),
      ),
    );
  }
}

