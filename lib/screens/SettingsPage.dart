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
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: Provider.of<ThemeProvider>(context).getThemeMode() == ThemeMode.dark,
            onChanged: (value) {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          ListTile(
            title: Text('Reset Liked Places'),
            trailing: ElevatedButton(
              child: Text('Reset'),
              onPressed: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Confirmation'),
                      content: Text('Are you sure you want to reset the list of liked places?'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: Text('Reset'),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {
                  await Provider.of<LocationManager>(context, listen: false).resetLikedLocations();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('The list of liked places has been reset')),
                  );
                }
              },
            ),
          ),
          ListTile(
            title: Text('Reset Disliked Places'),
            trailing: ElevatedButton(
              child: Text('Reset'),
              onPressed: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Confirmation'),
                      content: Text('Are you sure you want to reset the list of disliked places?'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: Text('Reset'),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {
                  await Provider.of<LocationManager>(context, listen: false).resetDislikedLocations();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('The list of disliked places has been reset')),
                  );
                }
              },
            ),
          ),
          ListTile(
            title: Text('Reset Favorite Places'),
            trailing: ElevatedButton(
              child: Text('Reset'),
              onPressed: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Confirmation'),
                      content: Text('Are you sure you want to reset the list of favorite places?'),
                      actions: <Widget>[
                        TextButton(
                          child: Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: Text('Reset'),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {
                  await Provider.of<LocationManager>(context, listen: false).resetFavoriteLocations();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('The list of favorite places has been reset')),
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

