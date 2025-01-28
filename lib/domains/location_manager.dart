import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:swipezone/repositories/models/location.dart';
import 'package:swipezone/repositories/location_repository_implementation.dart';

class LocationManager extends ChangeNotifier {
  static final LocationManager _instance = LocationManager._internal();

  LocationManager._internal();

  factory LocationManager() {
    return _instance;
  }

  List<Location> locations = [];
  List<Location> likedLocations = [];
  List<Location> dislikedLocations = [];
  String? currentLocationId;
  bool isLoading = true;

  Map<Location, bool> get filters {
    return Map.fromIterable(
      locations,
      key: (location) => location,
      value: (location) => likedLocations.contains(location),
    );
  }

  Future<void> loadLocations() async {
    if (locations.isEmpty) {
      List<Location> allLocations = await ILocationRepository().getLocations();
      // Éliminer les doublons basés sur le nom du lieu
      locations = allLocations.toSet().toList();
    }
    notifyListeners();
  }

  void like() {
    Location? currentLocation = getCurrentVisibleLocation();
    if (currentLocation != null) {
      currentLocation.isLiked = true;
      likedLocations.add(currentLocation);
      locations.remove(currentLocation);
      _moveToNextLocation();
      saveState();
      notifyListeners();
    }
  }

  void dislike() {
    Location? currentLocation = getCurrentVisibleLocation();
    if (currentLocation != null) {
      dislikedLocations.add(currentLocation);
      locations.remove(currentLocation);
      _moveToNextLocation();
      saveState();
      notifyListeners();
    }
  }

  void _moveToNextLocation() {
    List<Location> visibleLocations = getVisibleLocations();
    if (visibleLocations.isNotEmpty) {
      currentLocationId = visibleLocations.first.nom;
    } else {
      currentLocationId = null;
    }
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('likedLocations', jsonEncode(likedLocations.map((e) => e.toJson()).toList()));
    await prefs.setString('dislikedLocations', jsonEncode(dislikedLocations.map((e) => e.toJson()).toList()));
    await prefs.setString('locations', jsonEncode(locations.map((e) => e.toJson()).toList()));
    if (currentLocationId != null) {
      await prefs.setString('currentLocationId', currentLocationId!);
    } else {
      await prefs.remove('currentLocationId');
    }
  }

  Future<void> loadState() async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final likedJson = prefs.getString('likedLocations');
    final dislikedJson = prefs.getString('dislikedLocations');
    final locationsJson = prefs.getString('locations');
    currentLocationId = prefs.getString('currentLocationId');

    if (likedJson != null) {
      final List<dynamic> likedList = jsonDecode(likedJson);
      likedLocations = likedList.map((json) => Location.fromJson(json)).toList();
      for (var location in likedLocations) {
        location.isLiked = true;
      }
    }

    if (dislikedJson != null) {
      final List<dynamic> dislikedList = jsonDecode(dislikedJson);
      dislikedLocations = dislikedList.map((json) => Location.fromJson(json)).toList();
    }

    if (locationsJson != null) {
      final List<dynamic> locationsList = jsonDecode(locationsJson);
      locations = locationsList.map((json) => Location.fromJson(json)).toList();
    } else {
      await loadLocations();
    }

    if (currentLocationId == null && locations.isNotEmpty) {
      currentLocationId = locations.first.nom;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> resetLikedLocations() async {
    locations.addAll(likedLocations);
    for (var location in likedLocations) {
      location.isLiked = false;
    }
    likedLocations.clear();
    _moveToNextLocation();
    await saveState();
    notifyListeners();
  }

  Future<void> resetDislikedLocations() async {
    locations.addAll(dislikedLocations);
    dislikedLocations.clear();
    _moveToNextLocation();
    await saveState();
    notifyListeners();
  }

  List<Location> getVisibleLocations() {
    return locations.where((location) =>
    !likedLocations.contains(location) && !dislikedLocations.contains(location)
    ).toList();
  }

  void unlikeLocation(Location location) {
    likedLocations.remove(location);
    locations.add(location);
    location.isLiked = false;
    saveState();
    notifyListeners();
  }

  bool get allLocationsVisited {
    return locations.isEmpty && (likedLocations.isNotEmpty || dislikedLocations.isNotEmpty);
  }

  Location? getCurrentVisibleLocation() {
    List<Location> visibleLocations = getVisibleLocations();
    if (visibleLocations.isEmpty) {
      return null;
    }
    if (currentLocationId != null) {
      return visibleLocations.firstWhere(
            (location) => location.nom == currentLocationId,
        orElse: () => visibleLocations.first,
      );
    }
    return visibleLocations.first;
  }
}
