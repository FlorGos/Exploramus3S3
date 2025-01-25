import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swipezone/repositories/models/location.dart';

class LocationDetailModal extends StatefulWidget {
  final Location location;
  final ScrollController scrollController;

  const LocationDetailModal({
    Key? key,
    required this.location,
    required this.scrollController
  }) : super(key: key);

  @override
  _LocationDetailModalState createState() => _LocationDetailModalState();
}

class _LocationDetailModalState extends State<LocationDetailModal> {
  TextEditingController _notesController = TextEditingController();
  String? _savedNotes;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedNotes = prefs.getString('notes_${widget.location.nom}') ?? '';
      _notesController.text = _savedNotes!;
    });
  }

  Future<void> _saveNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_${widget.location.nom}', _notesController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: ListView(
        controller: widget.scrollController,
        children: [
          Text(
            widget.location.nom,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(widget.location.description ?? 'Pas de description disponible'),
          SizedBox(height: 10),
          Text(
            'Adresse: ${widget.location.localization.adress ?? 'Adresse non disponible'}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              _saveNotes();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notes enregistrées !')),
              );
            },
            child: Text('Enregistrer les notes'),
          ),
        ],
      ),
    );
  }
}
