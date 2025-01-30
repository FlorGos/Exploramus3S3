import 'package:flutter/material.dart';

class TransitRoute {
  final String type; // 'metro' ou 'bus'
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
    return type == 'metro' ? Icons.subway : Icons.directions_bus;
  }

  Color _getTransitColor(String type) {
    return type == 'metro' ? Colors.purple[600]! : Colors.blue[600]!;
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
                  title: Text('${route.type == 'metro' ? 'Métro' : 'Bus'} ${route.line}'),
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

