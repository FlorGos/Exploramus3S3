import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:swipezone/services/geocoding_service.dart';

class AddMarkerDialog extends StatefulWidget {
  final Function(LatLng) onMapSelection;
  final Function(GeocodingResult) onAddressSelection;

  const AddMarkerDialog({
    Key? key,
    required this.onMapSelection,
    required this.onAddressSelection,
  }) : super(key: key);

  @override
  _AddMarkerDialogState createState() => _AddMarkerDialogState();
}

class _AddMarkerDialogState extends State<AddMarkerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<GeocodingResult> _searchResults = [];
  bool _isLoading = false;

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await GeocodingService.searchAddress(query);
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during search: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add a marker',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onMapSelection(LatLng(0, 0)); // Temporary coordinates
              },
              child: Text('Select on map'),
            ),
            SizedBox(height: 16),
            Text('Or search for an address:'),
            SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter an address...',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchAddress(_searchController.text),
                ),
              ),
              onSubmitted: (value) => _searchAddress(value),
            ),
            SizedBox(height: 8),
            if (_isLoading)
              CircularProgressIndicator()
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      title: Text(result.displayName),
                      onTap: () {
                        Navigator.pop(context);
                        widget.onAddressSelection(result);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

