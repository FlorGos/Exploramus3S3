import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/theme/theme_provider.dart';
import 'package:swipezone/domains/location_manager.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Mode Sombre'),
            value: Provider.of<ThemeProvider>(context).getThemeMode() == ThemeMode.dark,
            onChanged: (value) {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          ListTile(
            title: Text('Réinitialiser les lieux likés'),
            trailing: ElevatedButton(
              child: Text('Réinitialiser'),
                // Inside SettingsPage
                onPressed: () async {
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Confirmation'),
                        content: Text('Êtes-vous sûr de vouloir réinitialiser la liste des lieux likés ?'),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Annuler'),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                          TextButton(
                            child: Text('Réinitialiser'),
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirm == true) {
                    await LocationManager().resetLikedLocations();
                    // Notify HomePage and SelectPage to refresh their data
                    Provider.of<LocationManager>(context, listen: false).notifyListeners();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('La liste des lieux likés a été réinitialisée')),
                    );
                  }
                }
            ),
          ),
          ListTile(
            title: Text('Réinitialiser les lieux dislikés'),
            trailing: ElevatedButton(
              child: Text('Réinitialiser les lieux dislikés'),
              onPressed: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Confirmation'),
                      content: Text('Êtes-vous sûr de vouloir réinitialiser la liste des lieux dislikés ?'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('Annuler'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: Text('Réinitialiser'),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {
                  await Provider.of<LocationManager>(context, listen: false).resetLikedLocations();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('La liste des lieux dislikés a été réinitialisée')),
                  );
                }
              },
            ),

          ),
        ],
      ),
    );
  }
}

