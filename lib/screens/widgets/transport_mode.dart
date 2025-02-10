import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TransportMode {
  final String name;
  final IconData icon;
  final double speedKmPerHour;

  TransportMode({required this.name, required this.icon, required this.speedKmPerHour});

  String getEstimatedTime(double distanceInMeters) {
    double timeInHours = distanceInMeters / 1000 / speedKmPerHour;
    int minutes = (timeInHours * 60).round();
    return '$minutes min';
  }
}

