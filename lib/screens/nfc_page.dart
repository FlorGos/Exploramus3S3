import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PageNFC extends StatefulWidget {
  @override
  _EtatPageNFC createState() => _EtatPageNFC();
}

class _EtatPageNFC extends State<PageNFC> {
  bool estEnScan = false;
  String idCarteScannee = '';

  @override
  void initState() {
    super.initState();
    _verifierDisponibiliteNfc();
    _chargerCarteScannee();
  }

  Future<void> _verifierDisponibiliteNfc() async {
    bool estDisponible = await NfcManager.instance.isAvailable();
    if (!estDisponible) {
      _afficherAlerte('NFC non disponible', 'Votre appareil ne supporte pas le NFC ou il est désactivé.');
    }
  }

  Future<void> _demarrerScanNfc() async {
    setState(() {
      estEnScan = true;
    });

    try {
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag etiquette) async {
          var id = etiquette.data['nfca']?['identifier'];
          if (id != null) {
            String idCarte = id.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':');
            print('Carte scannée : $idCarte');
            setState(() {
              idCarteScannee = idCarte;
              _sauvegarderCarteScannee();
            });
          }
          await NfcManager.instance.stopSession();
          setState(() {
            estEnScan = false;
          });
        },
      );
    } catch (e) {
      _afficherAlerte('Erreur', 'Une erreur est survenue lors du scan NFC.');
    }
  }

  Future<void> _chargerCarteScannee() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      idCarteScannee = prefs.getString('idCarteScannee') ?? '';
    });
  }

  Future<void> _sauvegarderCarteScannee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idCarteScannee', idCarteScannee);
  }

  Future<void> _supprimerCarteScannee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('idCarteScannee');
    setState(() {
      idCarteScannee = '';
    });
  }

  void _afficherAlerte(String titre, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(titre),
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
        title: Text('Scanner NFC'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (idCarteScannee.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Carte scannée', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('ID: $idCarteScannee'),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(idCarteScannee),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _supprimerCarteScannee,
                      child: Text('Supprimer la carte'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: estEnScan ? null : _demarrerScanNfc,
                child: Text(estEnScan ? 'Scan en cours...' : 'Scanner une carte NFC'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

