import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/domains/locations_usecase.dart';
import 'package:swipezone/screens/widgets/location_card.dart';
import 'package:swipezone/theme/theme_provider.dart';

class HomePage extends StatefulWidget {
  final String title;

  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: LocationUseCase().getLocation(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            var data = snapshot.data;
            if (data == null || data.isEmpty) {
              return const Center(child: Text("No data"));
            }

            LocationManager().locations = data;

            return ListView(children: [
              LocationCard(location: data[LocationManager().currentIndex]),
              Center(
                child: Switch(
                  value: Provider.of<ThemeProvider>(context).getThemeMode() == ThemeMode.dark,
                  onChanged: (value) {
                    Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                  },
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          LocationManager().Idontwant();
                        });
                      },
                      child: const Text("Nope"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          LocationManager().Iwant();
                        });
                      },
                      child: const Text("Yep"),
                    ),
                    Text(
                      "Don't like: ${LocationManager().unwantedLocations.length}",
                      style: const TextStyle(color: Colors.red, fontSize: 20),
                    ),
                    Text(
                      "Like: ${LocationManager().filters.length}",
                      style: const TextStyle(color: Colors.green, fontSize: 20),
                    ),
                  ],
                ),
              ),
              Center(
                child: FilledButton(
                  onPressed: () {
                    GoRouter.of(context).go('/selectpage');
                  },
                  child: const Text("Create plan"),
                ),
              )
            ]);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Add plan',
        child: const Icon(Icons.add),
      ),
    );
  }
}
