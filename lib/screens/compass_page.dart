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
    return OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          builder: (context, constraints) {
            double availableHeight = constraints.maxHeight;
            double availableWidth = constraints.maxWidth;
            double compassSize = math.min(availableWidth, availableHeight) * 0.7;

            return SingleChildScrollView(
              child: Container(
                height: availableHeight,
                width: availableWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${_direction.toStringAsFixed(0)}°",
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: -(_direction * (math.pi / 180)),
                          child: CustomPaint(
                            size: Size(compassSize, compassSize),
                            painter: CompassPainter(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

class CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Draw the outer circle
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, paint);

    // Draw the inner circle
    canvas.drawCircle(center, radius * 0.8, paint);

    // Draw the cardinal directions
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final directions = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      textPainter.text = TextSpan(
        text: directions[i],
        style: TextStyle(color: Colors.white, fontSize: radius * 0.15),
      );
      textPainter.layout();
      final angle = i * (math.pi / 2);
      final x = center.dx + (radius * 0.9) * math.sin(angle) - textPainter.width / 2;
      final y = center.dy - (radius * 0.9) * math.cos(angle) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(x, y));
    }

    // Draw the compass needle
    final needlePaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius * 0.7)
      ..lineTo(center.dx - radius * 0.05, center.dy)
      ..lineTo(center.dx + radius * 0.05, center.dy)
      ..close();
    canvas.drawPath(path, needlePaint);

    // Draw the south part of the needle
    needlePaint.color = Colors.white;
    final southPath = Path()
      ..moveTo(center.dx, center.dy + radius * 0.7)
      ..lineTo(center.dx - radius * 0.05, center.dy)
      ..lineTo(center.dx + radius * 0.05, center.dy)
      ..close();
    canvas.drawPath(southPath, needlePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

