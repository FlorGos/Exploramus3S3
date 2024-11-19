import 'package:swipezone/repositories/models/location.dart';

class LocationManager {
  static final LocationManager _instance = LocationManager._internal();

  LocationManager._internal();

  factory LocationManager() {
    return _instance;
  }

  List<Location> locations = [];
  List<Location> unwantedLocations = [];
  List<Map<Location, bool>> wantedLocations = [];
  int currentIndex = 0;

  void Iwant() {
    wantedLocations.add(Map<Location, bool>(locations[currentIndex],false));
    next();
  }

  void Idontwant() {
    unwantedLocations.add(locations[currentIndex]);
    next();
  }

  void next() {
    if (currentIndex != locations.length - 1) {
      currentIndex++;
    }
  }
}