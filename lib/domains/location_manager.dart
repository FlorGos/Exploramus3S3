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
  int currentIndex = 0;

  Map<Location, bool> get filters {
    return Map.fromIterable(
      locations,
      key: (location) => location,
      value: (location) => likedLocations.contains(location),
    );
  }

  Future<void> loadLocations() async {
    locations = await ILocationRepository().getLocations();
    notifyListeners();
  }

  void like() {
    if (currentIndex < locations.length) {
      Location likedLocation = locations[currentIndex]..isLiked = true;
      if (!likedLocations.contains(likedLocation)) {
        likedLocations.add(likedLocation);
      }
      next();
      saveState();
      notifyListeners();
    }
  }

  void dislike() {
    if (currentIndex < locations.length) {
      dislikedLocations.add(locations[currentIndex]);
      next();
      saveState();
      notifyListeners();
    }
  }

  void unlikeLocation(Location location) {
    likedLocations.remove(location);
    location.isLiked = false;
    saveState();
    notifyListeners();
  }

  void next() {
    if (currentIndex < locations.length - 1) {
      currentIndex++;
    }
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('likedLocations', jsonEncode(likedLocations.map((e) => e.toJson()).toList()));
    await prefs.setString('dislikedLocations', jsonEncode(dislikedLocations.map((e) => e.toJson()).toList()));
  }

  Future<void> loadState() async {
    await loadLocations();
    final prefs = await SharedPreferences.getInstance();
    final likedJson = prefs.getString('likedLocations');
    final dislikedJson = prefs.getString('dislikedLocations');

    if (likedJson != null) {
      final List<dynamic> likedList = jsonDecode(likedJson);
      likedLocations = likedList.map((json) => Location.fromJson(json)).toList();
      for (var location in likedLocations) {
        location = location..isLiked = true;
      }
    }

    if (dislikedJson != null) {
      final List<dynamic> dislikedList = jsonDecode(dislikedJson);
      dislikedLocations = dislikedList.map((json) => Location.fromJson(json)).toList();
    }

    notifyListeners();
  }

  Future<void> resetLikedLocations() async {
    for (var location in likedLocations) {
      location = location..isLiked = false;
    }
    likedLocations.clear();
    await saveState();
    notifyListeners();
  }

  Future<void> resetDislikedLocations() async {
    dislikedLocations.clear();
    await saveState();
    notifyListeners();
  }

  List<Location> getVisibleLocations() {
    return locations.where((location) =>
    !dislikedLocations.contains(location) && !likedLocations.contains(location)
    ).toList();
  }

  void resetCurrentIndex() {
    currentIndex = 0;
    notifyListeners();
  }
}

