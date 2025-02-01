import 'package:flutter/material.dart';

class CompassPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Compass'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: Text('Compass functionality will be implemented here'),
      ),
    );
  }
}

