import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NFCPage extends StatefulWidget {
  @override
  _NFCPageState createState() => _NFCPageState();
}

class _NFCPageState extends State<NFCPage> {
  List<String> scannedCards = [];
  bool isScanning = false;
  String navigoId = '';

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _loadNavigoId();
    _loadScannedCards();
  }

  Future<void> _checkNfcAvailability() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _showAlert('NFC non disponible', 'Votre appareil ne supporte pas le NFC ou il est désactivé.');
    }
  }

  Future<void> _startNfcScan() async {
    setState(() {
      isScanning = true;
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          var id = tag.data['nfca']?['identifier'];
          if (id != null) {
            String cardId = id.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
            print('Carte scannée : $cardId');
            setState(() {
              if (!scannedCards.contains(cardId)) {
                scannedCards.add(cardId);
                _saveScannedCards();
              }
            });
          }
          await NfcManager.instance.stopSession();
          setState(() {
            isScanning = false;
          });
        },
      );
    } catch (e) {
      _showAlert('Erreur', 'Une erreur est survenue lors du scan NFC.');
    }
  }

  Future<void> _loadNavigoId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      navigoId = prefs.getString('navigoId') ?? '';
    });
  }

  Future<void> _saveNavigoId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('navigoId', id);
    setState(() {
      navigoId = id;
    });
  }

  Future<void> _deleteNavigoId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('navigoId');
    setState(() {
      navigoId = '';
    });
  }

  Future<void> _loadScannedCards() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      scannedCards = prefs.getStringList('scannedCards') ?? [];
    });
  }

  Future<void> _saveScannedCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scannedCards', scannedCards);
  }

  Future<void> _deleteScannedCard(String cardId) async {
    setState(() {
      scannedCards.remove(cardId);
    });
    await _saveScannedCards();
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC et Navigo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: scannedCards.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  key: Key(scannedCards[index]),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: 20.0),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteScannedCard(scannedCards[index]);
                  },
                  child: ListTile(
                    title: Text('Carte ${index + 1}'),
                    subtitle: Text(scannedCards[index]),
                    leading: Icon(Icons.credit_card),
                    trailing: IconButton(
                      icon: Icon(Icons.save),
                      onPressed: () => _saveNavigoId(scannedCards[index]),
                    ),
                  ),
                );
              },
            ),
          ),
          if (navigoId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Votre Pass Navigo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('ID: $navigoId'),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(navigoId),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _deleteNavigoId,
                    child: Text('Supprimer le Pass Navigo'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: isScanning ? null : _startNfcScan,
              child: Text(isScanning ? 'Scan en cours...' : 'Scanner une carte NFC'),
            ),
          ),
        ],
      ),
    );
  }
}

