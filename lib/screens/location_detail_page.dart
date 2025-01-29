import 'package:flutter/material.dart';
import 'package:swipezone/repositories/models/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:swipezone/domains/location_manager.dart';

class _LocationDetailPageState extends State<LocationDetailPage> {
  late Location location;
  late TextEditingController _notesController;
  bool _isEditing = false;

  _LocationDetailPageState({required this.location});

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notes = prefs.getString('notes_${widget.location.nom}');
    if (notes != null) {
      setState(() {
        _notesController.text = notes;
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_${widget.location.nom}', _notesController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location.nom),
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          Text(
            widget.location.nom,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            widget.location.description ?? 'No description available',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 20),
          Text(
            'Address',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            widget.location.localization.adress ?? 'Address not available',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          Text(
            'Coordinates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            'Lat: ${widget.location.localization.lat}, Lng: ${widget.location.localization.lng}',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          Text(
            'Category',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Text(
            widget.location.category.toString().split('.').last,
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 20),
          if (widget.location.website != null) ...[
            Text(
              'Website',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text(
              widget.location.website!,
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
            SizedBox(height: 20),
          ],
          Text(
            'Notes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          _isEditing
              ? TextField(
            controller: _notesController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Add your notes here...',
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
            ),
          )
              : Text(_notesController.text),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _saveNotes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Notes saved!'), backgroundColor: Theme.of(context).primaryColor),
                  );
                }
              });
            },
            child: Text(_isEditing ? 'Save' : 'Edit Notes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

class LocationDetailPage extends StatefulWidget {
  final Location location;

  LocationDetailPage({required this.location});

  @override
  _LocationDetailPageState createState() => _LocationDetailPageState(location: location);
}

