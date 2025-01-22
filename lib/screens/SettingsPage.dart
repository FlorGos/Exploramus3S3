import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/theme/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: Center(
        child: SwitchListTile(
          title: const Text('Mode Sombre'),
          value: Provider.of<ThemeProvider>(context).getThemeMode() == ThemeMode.dark,
          onChanged: (value) {
            Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
          },
        ),
      ),
    );
  }
}
