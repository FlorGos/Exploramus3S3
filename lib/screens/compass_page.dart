import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;

class CompassPage extends StatefulWidget {
  const CompassPage({Key? key}) : super(key: key);

  @override
  State<CompassPage> createState() => _CompassPageState();
}

class _CompassPageState extends State<CompassPage> with TickerProviderStateMixin {
  double _direction = 0;
  late AnimationController _animationController;
  bool _hasCompass = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _checkCompassAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkCompassAvailability() {
    FlutterCompass.events?.listen((event) {
      setState(() {
        _hasCompass = true;
        _direction = event.heading ?? 0;
      });
      _animationController.forward(from: 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Compass'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _hasCompass ? _buildCompass() : _buildNoCompassWarning(),
    );
  }

  Widget _buildCompass() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "${_direction.toStringAsFixed(0)}°",
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 50),
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: -(_direction * (math.pi / 180)),
                child: Image.asset(
                  'lib/assets/images/compass_needle.png',
                  width: 200,
                  height: 200,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoCompassWarning() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.compass_calibration, size: 100, color: Colors.white54),
          SizedBox(height: 20),
          Text(
            'Compass not available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Your device might not have a compass sensor or it might be temporarily unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

