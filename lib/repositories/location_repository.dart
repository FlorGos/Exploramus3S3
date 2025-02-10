import 'models/location.dart';

abstract class LocationRepository {
  Future<List<Location>> getLocations();
}
