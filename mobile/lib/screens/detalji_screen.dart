import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import '../models/ruta.dart';
import '../models/oprema.dart';
import 'karta_screen.dart';

import '../models/weather.dart';
import '../widgets/weather_widget.dart';

class DetaljiScreen extends StatefulWidget {
  final int rutaId;
  const DetaljiScreen({super.key, required this.rutaId});

  @override
  State<DetaljiScreen> createState() => _DetaljiScreenState();
}

class _DetaljiScreenState extends State<DetaljiScreen> {
  final ApiService _api = ApiService();
  Ruta? _ruta;
  ProcjenaTroska? _trosak;
  bool _ucitavanje = true;
  bool _jeOmiljena = false;
  int _brojSudionika = 1;
  bool _vlastitaOprema = false;
  WeatherRuta? _weather;
  bool _weatherUcitavanje = true;

  @override
  void initState() {
    super.initState();
    _ucitaj();
  }

  Future<void> _ucitajWeather() async {
    try {
      final weather = await _api.getWeatherRuta(widget.rutaId);
      setState(() {
        _weather = weather;
        _weatherUcitavanje = false;
      });
    } catch (e) {
      setState(() => _weatherUcitavanje = false);
    }
  }

  Future<void> _ucitaj() async {
    try {
      final ruta = await _api.getRuta(widget.rutaId);
      final trosak = await _api.procjenaTroska(
        widget.rutaId,
        brojSudionika: _brojSudionika,
        vlastitaOprema: _vlastitaOprema,
      );
      final omiljena = await FavoritesService.isFavorite(widget.rutaId);
      setState(() {
        _ruta = ruta;
        _trosak = trosak;
        _jeOmiljena = omiljena;
        _ucitavanje = false;
      });

      // Dohvati weather NAKON što se ruta učitala
      _ucitajWeather();
    } catch (e) {
      setState(() => _ucitavanje = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  Future<void> _azurirajTrosak() async {
    try {
      final trosak = await _api.procjenaTroska(
        widget.rutaId,
        brojSudionika: _brojSudionika,
        vlastitaOprema: _vlastitaOprema,
      );
      setState(() => _trosak = trosak);
    } catch (_) {}
  }

  Future<void> _toggleOmiljena() async {
    await FavoritesService.toggleFavorite(widget.rutaId);
    setState(() => _jeOmiljena = !_jeOmiljena);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _jeOmiljena ? 'Dodano u omiljene' : 'Uklonjeno iz omiljenih'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _podijeli() {
    if (_ruta == null) return;
    Share.share(
      '${_ruta!.naziv}\n'
      '${_ruta!.tezina ?? ''} · ${_ruta!.trajanjeH ?? '?'}h · ${_ruta!.duljinaKm ?? '?'} km\n'
      'Regija: ${_ruta!.regija ?? ''}\n\n'
      'Preporuči planinarski izlet!',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ucitavanje) {
      return Scaffold(
        appBar: AppBar(title: const Text('Učitavanje...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ruta = _ruta!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(ruta.naziv),
        actions: [
          IconButton(
            icon: Icon(
              _jeOmiljena ? Icons.favorite : Icons.favorite_border,
              color: _jeOmiljena ? Colors.red : Colors.white,
            ),
            onPressed: _toggleOmiljena,
          ),
          IconButton(icon: const Icon(Icons.share), onPressed: _podijeli),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _ucitaj,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: 'tezina_${ruta.id}',
                            child: Text(ruta.tezinaIkona,
                                style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Hero(
                                  tag: 'naziv_${ruta.id}',
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Text(ruta.naziv,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                Text(ruta.regija ?? '',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _infoRed(Icons.timer, 'Trajanje',
                          '${ruta.trajanjeH ?? '?'} sati'),
                      _infoRed(Icons.straighten, 'Duljina',
                          '${ruta.duljinaKm ?? '?'} km'),
                      _infoRed(Icons.height, 'Visinska razlika',
                          '${ruta.visinskaRazlikaM?.toInt() ?? '?'} m'),
                      _infoRed(
                          Icons.landscape, 'Područje', ruta.podrucje ?? 'N/A'),
                      if (ruta.polazisteNaziv != null)
                        _infoRed(Icons.location_on, 'Polazište',
                            ruta.polazisteNaziv!),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ═══════ WEATHER KARTICA ═══════
              if (_weatherUcitavanje)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Učitavanje vremena...',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_weather != null)
                WeatherKartica(weather: _weather!),

              const SizedBox(height: 12),
              // ═══════ KRAJ WEATHER ═══════

              if (ruta.kontrolneTocke.isNotEmpty)
                _sekcija('Kontrolne točke', Icons.flag, ruta.kontrolneTocke,
                    Colors.green.shade50),
              if (ruta.tipTerena.isNotEmpty)
                _sekcija('Tip terena', Icons.terrain, ruta.tipTerena,
                    Colors.brown.shade50),
              if (ruta.oprema.isNotEmpty)
                _sekcija('Potrebna oprema', Icons.backpack, ruta.oprema,
                    Colors.blue.shade50),
              if (ruta.godisnjadoba.isNotEmpty)
                _sekcija('Pogodna u', Icons.calendar_month, ruta.godisnjadoba,
                    Colors.amber.shade50),

              const SizedBox(height: 12),

              if (_trosak != null)
                Card(
                  color: isDark ? Colors.green.shade900 : Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Procjena troška izleta',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            const Text('Broj sudionika: '),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _brojSudionika > 1
                                  ? () {
                                      setState(() => _brojSudionika--);
                                      _azurirajTrosak();
                                    }
                                  : null,
                            ),
                            Text('$_brojSudionika',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                setState(() => _brojSudionika++);
                                _azurirajTrosak();
                              },
                            ),
                          ],
                        ),

                        SwitchListTile(
                          title: const Text('Imam vlastitu opremu'),
                          subtitle: Text(
                            _vlastitaOprema
                                ? 'Oprema nije uračunata'
                                : 'Cijene prema Decathlon HR katalogu',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          value: _vlastitaOprema,
                          onChanged: (val) {
                            setState(() => _vlastitaOprema = val);
                            _azurirajTrosak();
                          },
                          contentPadding: EdgeInsets.zero,
                        ),

                        if (!_vlastitaOprema &&
                            _trosak!.opremaStavke.isNotEmpty) ...[
                          const Divider(),
                          const Text('Oprema (Decathlon HR):',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          ..._trosak!.opremaStavke.map((o) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '  ${o['naziv'] ?? ''}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700),
                                      ),
                                    ),
                                    Text(
                                      '${(o['trosak'] as num?)?.toStringAsFixed(0) ?? '0'} €',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700),
                                    ),
                                  ],
                                ),
                              )),
                        ],

                        const Divider(),

                        if (_trosak!.ulaznica > 0)
                          _trosakRed(
                              'Ulaznica (NP/PP)',
                              '${_trosak!.ulaznica.toStringAsFixed(0)} €/os'),
                        _trosakRed('Oprema',
                            '${_trosak!.trosakOpreme.toStringAsFixed(0)} €'),

                        _trosakRed(
                          'Gorivo (${_trosak!.udaljenostKm?.toInt() ?? '?'} km × 2)',
                          '${_trosak!.gorivo.toStringAsFixed(1)} €',
                        ),
                        if (_trosak!.cestarina > 0)
                          _trosakRed(
                            'Cestarina (tamo-natrag)',
                            '${_trosak!.cestarina.toStringAsFixed(0)} €',
                          ),

                        const Divider(),
                        _trosakRed(
                          'Po osobi',
                          '${_trosak!.ukupnoPoOsobi.toStringAsFixed(1)} €',
                          bold: true,
                        ),
                        _trosakRed(
                          'Ukupno ($_brojSudionika os.)',
                          '${_trosak!.ukupnoGrupa.toStringAsFixed(1)} €',
                          bold: true,
                          boja: Colors.green.shade700,
                        ),

                        if (_trosak!.napomena != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _trosak!.napomena!,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KartaScreen(rutaId: widget.rutaId),
                    ),
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Prikaži na karti'),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRed(IconData ikona, String label, String vrijednost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(ikona, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Expanded(
            child: Text(vrijednost,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _sekcija(
      String naslov, IconData ikona, List<String> items, Color bgColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(ikona, size: 18, color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Text(naslov,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: items
                    .map((item) => Chip(
                          label:
                              Text(item, style: const TextStyle(fontSize: 12)),
                          backgroundColor: bgColor,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trosakRed(String label, String vrijednost,
      {bool bold = false, Color? boja}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: boja)),
          Text(vrijednost,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: boja)),
        ],
      ),
    );
  }
}