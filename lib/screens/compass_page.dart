import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;

class CompassPage extends StatefulWidget {
  @override
  _CompassPageState createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Compass'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Error reading heading: ${snapshot.error}');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            }

            double? direction = snapshot.data?.heading;

            if (direction == null) {
              return Text("Device does not have sensors !");
            }

            return Transform.rotate(
              angle: (direction * (math.pi / 180) * -1),
              child: Image.asset('lib/assets/images/compass.png'),
            );
          },
        ),
      ),
    );
  }
}