import 'package:swipezone/repositories/location_repository_implementation.dart';
import 'package:swipezone/repositories/models/location.dart';

class LocationUseCase {
  Future<List<Location>> getLocation() async {
    return ILocationRepository().getLocations();
  }
}
