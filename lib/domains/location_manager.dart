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
  List<Location> favoriteLocations = [];
  List<Location> _history = [];
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
      _history.add(currentLocation);
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
      _history.add(currentLocation);
      _moveToNextLocation();
      saveState();
      notifyListeners();
    }
  }

  void favorite() {
    Location? currentLocation = getCurrentVisibleLocation();
    if (currentLocation != null) {
      if (!favoriteLocations.contains(currentLocation)) {
        favoriteLocations.add(currentLocation);
        locations.remove(currentLocation);
        likedLocations.remove(currentLocation);
        _history.add(currentLocation);
        _moveToNextLocation();
        saveState();
        notifyListeners();
      }
    }
  }

  Location? undo() {
    if (_history.isNotEmpty) {
      Location lastLocation = _history.removeLast();
      if (likedLocations.remove(lastLocation)) {
        lastLocation.isLiked = false;
      } else if (dislikedLocations.remove(lastLocation)) {
        // Do nothing, just remove from disliked
      } else if (favoriteLocations.remove(lastLocation)) {
        // Remove from favorites
      }
      locations.insert(0, lastLocation);
      currentLocationId = lastLocation.nom;
      saveState();
      notifyListeners();
      return lastLocation;
    }
    return null;
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
    await prefs.setString('favoriteLocations', jsonEncode(favoriteLocations.map((e) => e.toJson()).toList()));
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
    final favoriteJson = prefs.getString('favoriteLocations');
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

    if (favoriteJson != null) {
      final List<dynamic> favoriteList = jsonDecode(favoriteJson);
      favoriteLocations = favoriteList.map((json) => Location.fromJson(json)).toList();
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
    !likedLocations.contains(location) &&
        !dislikedLocations.contains(location) &&
        !favoriteLocations.contains(location)).toList();
  }

  void unlikeLocation(Location location) {
    likedLocations.remove(location);
    locations.add(location);
    location.isLiked = false;
    saveState();
    notifyListeners();
  }

  void removeFromDisliked(Location location) {
    dislikedLocations.remove(location);
    locations.add(location);
    saveState();
    notifyListeners();
  }

  void removeFromFavorites(Location location) {
    favoriteLocations.remove(location);
    if (!likedLocations.contains(location)) {
      locations.add(location);
    }
    saveState();
    notifyListeners();
  }

  bool get allLocationsVisited {
    return locations.isEmpty && (likedLocations.isNotEmpty || dislikedLocations.isNotEmpty || favoriteLocations.isNotEmpty);
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

  void toggleFavorite(Location location) {
    if (favoriteLocations.contains(location)) {
      favoriteLocations.remove(location);
      if (!likedLocations.contains(location)) {
        likedLocations.add(location);
        location.isLiked = true;
      }
    } else {
      favoriteLocations.add(location);
      likedLocations.remove(location);
    }
    saveState();
    notifyListeners();
  }

  List<Location> getLikedButNotFavoriteLocations() {
    return likedLocations.where((location) => !favoriteLocations.contains(location)).toList();
  }

  Future<void> resetFavoriteLocations() async {
    locations.addAll(favoriteLocations);
    favoriteLocations.clear();
    _moveToNextLocation();
    await saveState();
    notifyListeners();
  }
}

