import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/ruta.dart';
import '../widgets/empty_state.dart';
import 'detalji_screen.dart';

class PreporukaScreen extends StatefulWidget {
  final int? pocetniDob;
  final String? pocetnaTezina;
  final String? pocetniUvjet;
  final String? pocetnoGodisnjeDoba;

  const PreporukaScreen({
    super.key,
    this.pocetniDob,
    this.pocetnaTezina,
    this.pocetniUvjet,
    this.pocetnoGodisnjeDoba,
  });

  @override
  State<PreporukaScreen> createState() => _PreporukaScreenState();
}

class _PreporukaScreenState extends State<PreporukaScreen> {
  final ApiService _api = ApiService();

  int? _dob;
  String? _tezina;
  String? _godisnjeDoba;
  String? _vremenskiUvjet;

  List<Ruta> _rezultati = [];
  Map<String, dynamic> _ogranicenja = {};
  bool _ucitavanje = false;
  bool _pretrazeno = false;

  late TextEditingController _dobController;

  @override
  void initState() {
    super.initState();
    _dob = widget.pocetniDob;
    _tezina = widget.pocetnaTezina;
    _vremenskiUvjet = widget.pocetniUvjet;
    _godisnjeDoba = widget.pocetnoGodisnjeDoba;
    _dobController = TextEditingController(
      text: _dob != null ? _dob.toString() : '',
    );

    
    if (widget.pocetniDob != null ||
        widget.pocetnaTezina != null ||
        widget.pocetniUvjet != null ||
        widget.pocetnoGodisnjeDoba != null) {
      // Mali delay da se widget stigne buildati
      WidgetsBinding.instance.addPostFrameCallback((_) => _pretrazi());
    }
  }

  Future<void> _pretrazi() async {
    setState(() {
      _ucitavanje = true;
      _pretrazeno = true;
    });

    try {
      final rezultat = await _api.preporukaRuta(
        dob: _dob,
        tezina: _tezina,
        godisnjeDoba: _godisnjeDoba,
        vremenskiUvjet: _vremenskiUvjet,
      );
      setState(() {
        _rezultati = rezultat.rute;
        _ogranicenja = rezultat.ogranicenja;
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

  @override
  void dispose() {
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preporuka ruta')),
      body: Column(
        children: [
          // Filteri
          Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade900
                : Colors.grey.shade50,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dobController,
                        decoration: const InputDecoration(
                          labelText: 'Dob',
                          hintText: 'npr. 25',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.person),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (val) => _dob = int.tryParse(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _tezina,
                        decoration: const InputDecoration(
                          labelText: 'Težina',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.terrain),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Sve')),
                          DropdownMenuItem(
                              value: 'lagana', child: Text('🟢 Lagana')),
                          DropdownMenuItem(
                              value: 'srednja', child: Text('🟡 Srednja')),
                          DropdownMenuItem(
                              value: 'teska', child: Text('🔴 Teška')),
                        ],
                        onChanged: (val) => setState(() => _tezina = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _godisnjeDoba,
                        decoration: const InputDecoration(
                          labelText: 'Godišnje doba',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Sve')),
                          DropdownMenuItem(
                              value: 'proljece', child: Text('🌱 Proljeće')),
                          DropdownMenuItem(
                              value: 'ljeto', child: Text('☀️ Ljeto')),
                          DropdownMenuItem(
                              value: 'jesen', child: Text('🍂 Jesen')),
                          DropdownMenuItem(
                              value: 'zima', child: Text('❄️ Zima')),
                        ],
                        onChanged: (val) =>
                            setState(() => _godisnjeDoba = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _vremenskiUvjet,
                        decoration: const InputDecoration(
                          labelText: 'Vrijeme',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.cloud),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Sve')),
                          DropdownMenuItem(
                              value: 'suncano', child: Text('☀️ Sunčano')),
                          DropdownMenuItem(
                              value: 'kisovito', child: Text('🌧 Kišovito')),
                          DropdownMenuItem(
                              value: 'vjetar', child: Text('💨 Vjetar')),
                          DropdownMenuItem(
                              value: 'magla', child: Text('🌫 Magla')),
                        ],
                        onChanged: (val) =>
                            setState(() => _vremenskiUvjet = val),
                      ),
                    ),
                  ],
                ),
                Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '* Vrijeme označava idealno vrijeme za pojedine rute, a ne trenutne vremenske uvjete.',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
        ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _pretrazi,
                    icon: const Icon(Icons.search),
                    label: const Text('Pretraži',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),

          
          if (_ogranicenja.isNotEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.blue.shade50,
              child: Text(
                'Dob ${_ogranicenja['dob']}: '
                '${(_ogranicenja['dozvoljene_tezine'] as List?)?.join(", ") ?? ""}'
                '${_ogranicenja['max_duljina_km'] != null ? " · do ${_ogranicenja['max_duljina_km']} km" : ""}'
                '${_ogranicenja['max_visinska_m'] != null ? " · do ${_ogranicenja['max_visinska_m']} m↑" : ""}',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
              ),
            ),

          
          Expanded(
            child: _ucitavanje
                ? const Center(child: CircularProgressIndicator())
                : !_pretrazeno
                    ? const EmptyState(
                        ikona: Icons.search,
                        naslov: 'Odaberi filtere i klikni Pretraži',
                        opis:
                            'Sustav će predložiti rute prilagođene tvojim kriterijima',
                      )
                    : _rezultati.isEmpty
                        ? const EmptyState(
                            ikona: Icons.hiking,
                            naslov: 'Nema ruta za odabrane kriterije',
                            opis: 'Pokušaj s drugim filterima',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: _rezultati.length,
                            itemBuilder: (context, index) =>
                                _rutaKartica(_rezultati[index]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _rutaKartica(Ruta ruta) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        minVerticalPadding: 12,
        leading: Text(ruta.tezinaIkona, style: const TextStyle(fontSize: 24)),
        title: Text(ruta.naziv,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${ruta.regija ?? ''} · ${ruta.trajanjeH ?? '?'}h · ${ruta.duljinaKm ?? '?'} km · ${ruta.visinskaRazlikaM?.toInt() ?? '?'} m↑',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          if (ruta.id != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => DetaljiScreen(rutaId: ruta.id!)),
            );
          }
        },
      ),
    );
  }
}