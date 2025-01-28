import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swipezone/domains/location_manager.dart';
import 'package:swipezone/screens/widgets/location_card.dart';

class HomePage extends StatefulWidget {
  final String title;

  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true; // Indique si les données sont en cours de chargement
  String _errorMessage = ''; // Message d'erreur à afficher en cas de problème

  @override
  void initState() {
    super.initState();
    _loadData(); // Charge les données lors de l'initialisation
  }

  Future<void> _loadData() async {
    try {
      await LocationManager().loadState(); // Charge l'état des lieux
      setState(() {
        _isLoading = false; // Met à jour l'état pour indiquer que le chargement est terminé
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false; // Met à jour l'état même en cas d'erreur
        _errorMessage = 'Erreur lors du chargement des données. Veuillez réessayer.'; // Définit le message d'erreur
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title), // Affiche le titre de la page
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await GoRouter.of(context).push('/settings'); // Navigue vers la page des paramètres
              setState(() {
                LocationManager().resetCurrentIndex(); // Réinitialise l'index actuel après navigation
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator()) // Affiche un indicateur de chargement si nécessaire
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage)) // Affiche un message d'erreur si présent
          : _buildBody(), // Appelle la méthode pour construire le corps principal de la page
    );
  }

  Widget _buildBody() {
    var visibleLocations = LocationManager().getVisibleLocations(); // Récupère les lieux visibles

    // Vérifiez si la liste des lieux visibles est vide
    if (visibleLocations.isEmpty) {
      return const Center(child: Text("Il n'y a plus de lieux à afficher.")); // Affiche un message si aucun lieu n'est disponible
    }

    // Assurez-vous que currentIndex est valide
    if (LocationManager().currentIndex < 0 || LocationManager().currentIndex >= visibleLocations.length) {
      // Réinitialisez currentIndex si nécessaire
      LocationManager().resetCurrentIndex();
      return const Center(child: Text("Il n'y a plus de lieux à afficher.")); // Affiche un message si aucun lieu n'est disponible
    }

    return Column(
      children: [
        Expanded(
          child: LocationCard(location: visibleLocations[LocationManager().currentIndex]), // Affiche le lieu actuel dans un widget LocationCard
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    LocationManager().dislike(); // Appelle la méthode dislike sur LocationManager
                    // Mettez à jour currentIndex après avoir disliké
                    if (LocationManager().currentIndex >= visibleLocations.length) {
                      LocationManager().resetCurrentIndex();
                    }
                  });
                },
                child: const Text("Dislike"), // Bouton pour disliker un lieu
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    LocationManager().like(); // Appelle la méthode like sur LocationManager
                    // Mettez à jour currentIndex après avoir liké
                    if (LocationManager().currentIndex >= visibleLocations.length) {
                      LocationManager().resetCurrentIndex();
                    }
                  });
                },
                child: const Text("Like"), // Bouton pour liker un lieu
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Disliked: ${LocationManager().dislikedLocations.length}", // Affiche le nombre de lieux dislikés
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(width: 20),
              Text(
                "Liked: ${LocationManager().likedLocations.length}", // Affiche le nombre de lieux likés
                style: const TextStyle(color: Colors.green),
              ),
            ],
          ),
        ),
        Center(
          child: FilledButton(
            onPressed: () => GoRouter.of(context).go('/selectpage'), // Navigue vers la page de sélection des lieux
            child: const Text("Create plan"),
          ),
        )
      ],
    );
  }
}
