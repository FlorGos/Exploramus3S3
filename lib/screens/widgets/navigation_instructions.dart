import 'package:flutter/material.dart';
import 'package:swipezone/repositories/models/navigation_step.dart';

class NavigationInstructions extends StatelessWidget {
  final List<NavigationStep> steps;
  final double totalDistance;
  final int totalDuration;
  final String streetName;
  final VoidCallback onClose;

  const NavigationInstructions({
    Key? key,
    required this.steps,
    required this.totalDistance,
    required this.totalDuration,
    required this.streetName,
    required this.onClose,
  }) : super(key: key);

  String _formatDistance(double distance) {
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.round()} m';
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver) {
      case 'turn':
        return Icons.turn_right;
      case 'depart':
        return Icons.directions_walk;
      case 'arrive':
        return Icons.place;
      case 'roundabout':
        return Icons.roundabout_left;
      case 'merge':
        return Icons.merge;
      case 'fork':
        return Icons.fork_right;
      default:
        return Icons.arrow_forward;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            streetName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${_formatDistance(totalDistance)}, ${(totalDuration / 60).round()} min',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _getManeuverIcon(step.maneuver),
                        color: Colors.blue,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step.instruction.isEmpty ? 'Continue straight' : step.instruction,
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        _formatDistance(step.distance),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
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

