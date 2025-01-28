import 'package:flutter/material.dart';

class TransparentBottomBar extends StatelessWidget {
  final List<TransportMode> transportModes;
  final VoidCallback onListPressed;
  final VoidCallback onAddPressed;
  final double totalDistance;
  final Function(TransportMode) onTransportModeSelected;
  final TransportMode? selectedMode;
  final VoidCallback onResetPressed;

  TransparentBottomBar({
    required this.transportModes,
    required this.onListPressed,
    required this.onAddPressed,
    required this.totalDistance,
    required this.onTransportModeSelected,
    this.selectedMode,
    required this.onResetPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ...transportModes.map((mode) =>
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton.icon(
                    icon: Icon(mode.icon, size: 20),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mode.name,
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          mode.getEstimatedTime(totalDistance),
                          style: TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mode == selectedMode ? Theme.of(context).primaryColor : Colors.grey[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      onTransportModeSelected(mode);
                    },
                  ),
                )
            ).toList(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                icon: Icon(Icons.list, size: 20),
                label: Text('List', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onListPressed,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                icon: Icon(Icons.add_location, size: 20),
                label: Text('Add', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onAddPressed,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                icon: Icon(Icons.refresh, size: 20),
                label: Text('Réinitialiser', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: onResetPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

