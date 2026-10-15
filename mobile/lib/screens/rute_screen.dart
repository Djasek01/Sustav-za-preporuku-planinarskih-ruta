import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/ruta.dart';
import '../widgets/empty_state.dart';
import 'detalji_screen.dart';

class RuteScreen extends StatefulWidget {
  const RuteScreen({super.key});

  @override
  State<RuteScreen> createState() => _RuteScreenState();
}

class _RuteScreenState extends State<RuteScreen> {
  final ApiService _api = ApiService();
  List<Ruta> _rute = [];
  List<Ruta> _filtriraneRute = [];
  bool _ucitavanje = true;
  String _pretragaTekst = '';
  String? _filterTezina;

  @override
  void initState() {
    super.initState();
    _ucitajRute();
  }

  Future<void> _ucitajRute() async {
    try {
      final rute = await _api.getRute(limit: 65);
      setState(() {
        _rute = rute;
        _filtriraneRute = rute;
        _ucitavanje = false;
      });
    } catch (e) {
      setState(() => _ucitavanje = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  void _filtriraj() {
    setState(() {
      _filtriraneRute = _rute.where((ruta) {
        final odgovaraTekst = _pretragaTekst.isEmpty ||
            ruta.naziv.toLowerCase().contains(_pretragaTekst.toLowerCase()) ||
            (ruta.regija?.toLowerCase().contains(_pretragaTekst.toLowerCase()) ?? false);
        final odgovaraTezina = _filterTezina == null || ruta.tezina == _filterTezina;
        return odgovaraTekst && odgovaraTezina;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sve rute')),
      body: _ucitavanje
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Pretraži po nazivu ili regiji...',
                            border: OutlineInputBorder(),
                            isDense: true,
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (val) {
                            _pretragaTekst = val;
                            _filtriraj();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _filterTezina,
                        hint: const Text('Težina'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Sve')),
                          DropdownMenuItem(value: 'lagana', child: Text('🟢')),
                          DropdownMenuItem(value: 'srednja', child: Text('🟡')),
                          DropdownMenuItem(value: 'teska', child: Text('🔴')),
                        ],
                        onChanged: (val) {
                          _filterTezina = val;
                          _filtriraj();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_filtriraneRute.length} ruta',
                        style: TextStyle(color: const Color.fromARGB(255, 241, 238, 238), fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _filtriraneRute.isEmpty
                      ? const EmptyState(
                          ikona: Icons.search_off,
                          naslov: 'Nema rezultata',
                          opis: 'Pokušaj s drugim pojmom ili filterom',
                        )
                      : RefreshIndicator(
                          onRefresh: _ucitajRute,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: _filtriraneRute.length,
                            itemBuilder: (context, index) {
                              final ruta = _filtriraneRute[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                child: ListTile(
                                  leading: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // HERO animacija na ikoni težine
                                      Hero(
                                        tag: 'tezina_${ruta.id}',
                                        child: Text(ruta.tezinaIkona,
                                            style: const TextStyle(fontSize: 20)),
                                      ),
                                      Text('${ruta.trajanjeH ?? '?'}h',
                                          style: const TextStyle(fontSize: 11)),
                                    ],
                                  ),
                                  title: Hero(
                                    tag: 'naziv_${ruta.id}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Text(ruta.naziv,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600, fontSize: 13)),
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${ruta.regija ?? ''} · ${ruta.duljinaKm ?? '?'} km · ${ruta.visinskaRazlikaM?.toInt() ?? '?'} m↑',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  trailing: const Icon(Icons.chevron_right, size: 20),
                                  onTap: () {
                                    if (ruta.id != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DetaljiScreen(rutaId: ruta.id!),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}