import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NFCPage extends StatefulWidget {
  @override
  _NFCPageState createState() => _NFCPageState();
}

class _NFCPageState extends State<NFCPage> {
  bool isScanning = false;
  String scannedCardId = '';

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
    _loadScannedCard();
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
              scannedCardId = cardId;
              _saveScannedCard();
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

  Future<void> _loadScannedCard() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      scannedCardId = prefs.getString('scannedCardId') ?? '';
    });
  }

  Future<void> _saveScannedCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scannedCardId', scannedCardId);
  }

  Future<void> _deleteScannedCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scannedCardId');
    setState(() {
      scannedCardId = '';
    });
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
        title: Text('NFC Scanner'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (scannedCardId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Carte scannée', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('ID: $scannedCardId'),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(scannedCardId),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _deleteScannedCard,
                      child: Text('Supprimer la carte'),
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
      ),
    );
  }
}

