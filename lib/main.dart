import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

String firebaseUrl = "https://MON-PROJET-DEFAULT-RTDB.firebaseio.com/";

void main() {
  runApp(const PrincipalApp());
}

class PrincipalApp extends StatelessWidget {
  const PrincipalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Radar d\'Appareils',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class AppareilDistant {
  final String id;
  final String nom;
  final double latitude;
  final double longitude;
  final String derniereVue;

  AppareilDistant({
    required this.id,
    required this.nom,
    required this.latitude,
    required this.longitude,
    required this.derniereVue,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  Position? _maPosition;
  List<AppareilDistant> _listeAppareils = [];
  bool _chargement = false;
  String _messageStatut = "Appuyez sur rafraîchir pour calculer";

  @override
  void initState() {
    super.initState();
    _initialiserMaPosition();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _initialiserMaPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _maPosition = pos;
    });

    _actualiserAppareils();
  }

  double _calculerDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = (lat2 - lat1) * (pi / 180);
    double dLon = (lon2 - lon1) * (pi / 180);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> _actualiserAppareils() async {
    setState(() {
      _chargement = true;
      _messageStatut = "Chargement des données...";
    });

    if (_maPosition == null) {
      await _initialiserMaPosition();
    }

    String urlBase = _urlController.text.trim().isEmpty
        ? firebaseUrl
        : _urlController.text.trim();

    if (!urlBase.endsWith('/')) {
      urlBase += '/';
    }

    try {
      final response = await http.get(Uri.parse('${urlBase}appareils.json'));

      if (response.statusCode == 200 && response.body != 'null') {
        final Map<String, dynamic> data = json.decode(response.body);
        List<AppareilDistant> recup = [];

        data.forEach((key, value) {
          recup.add(AppareilDistant(
            id: key,
            nom: value['nom'] ?? key,
            latitude: (value['latitude'] as num).toDouble(),
            longitude: (value['longitude'] as num).toDouble(),
            derniereVue: value['derniere_mise_a_jour'] ?? 'Inconnue',
          ));
        });

        setState(() {
          _listeAppareils = recup;
          _messageStatut = "Mis à jour avec succès";
        });
      } else {
        setState(() {
          _messageStatut = "Aucune donnée disponible sur le serveur";
        });
      }
    } catch (e) {
      setState(() {
        _messageStatut = "Erreur de connexion : $e";
      });
    } finally {
      setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radar Mes Appareils'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargement ? null : _actualiserAppareils,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL Serveur Firebase (optionnel)',
                hintText: 'https://votre-projet.firebasedatabase.app',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 15),

            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_messageStatut)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),

            Expanded(
              child: _listeAppareils.isEmpty
                  ? const Center(child: Text('Aucun appareil détecté.'))
                  : ListView.builder(
                      itemCount: _listeAppareils.length,
                      itemBuilder: (context, index) {
                        final item = _listeAppareils[index];
                        double? distance;

                        if (_maPosition != null) {
                          distance = _calculerDistanceKm(
                            _maPosition!.latitude,
                            _maPosition!.longitude,
                            item.latitude,
                            item.longitude,
                          );
                        }

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.tablet_mac, color: Colors.white),
                            ),
                            title: Text(
                              item.nom,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text('Dernière vue : ${item.derniereVue}'),
                            trailing: Text(
                              distance != null
                                  ? '${distance.toStringAsFixed(1)} km'
                                  : 'Calcul...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: (distance ?? 0) < 1.0
                                    ? Colors.green
                                    : Colors.deepOrange,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
