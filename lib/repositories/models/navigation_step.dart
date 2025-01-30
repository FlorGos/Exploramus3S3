class NavigationStep {
  final String instruction;
  final double distance;
  final String maneuver;
  final int duration;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.maneuver,
    required this.duration,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    return NavigationStep(
      instruction: json['name'] ?? '',
      distance: (json['distance'] ?? 0.0).toDouble(),
      maneuver: json['maneuver']['type'] ?? '',
      duration: (json['duration'] ?? 0).toInt(),
    );
  }
}

