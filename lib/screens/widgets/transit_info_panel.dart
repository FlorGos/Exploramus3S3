import 'package:flutter/material.dart';

class TransitRoute {
  final String type; // 'metro', 'bus', 'rer', 'ter', 'tgv'
  final String line;
  final String direction;
  final String startStation;
  final String endStation;
  final int duration; // en minutes

  TransitRoute({
    required this.type,
    required this.line,
    required this.direction,
    required this.startStation,
    required this.endStation,
    required this.duration,
  });
}

class TransitInfoPanel extends StatelessWidget {
  final List<TransitRoute> routes;
  final VoidCallback onClose;

  const TransitInfoPanel({
    Key? key,
    required this.routes,
    required this.onClose,
  }) : super(key: key);

  IconData _getTransitIcon(String type) {
    switch (type) {
      case 'metro':
        return Icons.subway;
      case 'bus':
        return Icons.directions_bus;
      case 'rer':
      case 'ter':
        return Icons.train;
      case 'tgv':
        return Icons.directions_railway;
      default:
        return Icons.commute;
    }
  }

  Color _getTransitColor(String type) {
    switch (type) {
      case 'metro':
        return Colors.purple[600]!;
      case 'bus':
        return Colors.blue[600]!;
      case 'rer':
        return Colors.red[600]!;
      case 'ter':
        return Colors.green[600]!;
      case 'tgv':
        return Colors.orange[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  String _getTransitTypeName(String type) {
    switch (type) {
      case 'metro':
        return 'Métro';
      case 'bus':
        return 'Bus';
      case 'rer':
        return 'RER';
      case 'ter':
        return 'TER';
      case 'tgv':
        return 'TGV';
      default:
        return 'Transport';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text('Transports en commun'),
            trailing: IconButton(
              icon: Icon(Icons.close),
              onPressed: onClose,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return ListTile(
                  leading: Icon(
                    _getTransitIcon(route.type),
                    color: _getTransitColor(route.type),
                  ),
                  title: Text('${_getTransitTypeName(route.type)} ${route.line}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Direction: ${route.direction}'),
                      Text('De: ${route.startStation}'),
                      Text('À: ${route.endStation}'),
                      Text('Durée: ${route.duration} min'),
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

