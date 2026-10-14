import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'detalji_screen.dart';

/// Ekran za pretraživanje svih ruta — search bar + filteri + rezultati
class PretragaScreen extends StatefulWidget {
  const PretragaScreen({super.key});

  @override
  State<PretragaScreen> createState() => _PretragaScreenState();
}

class _PretragaScreenState extends State<PretragaScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _rezultati = [];
  int _ukupno = 0;
  bool _ucitavanje = false;
  bool _prvoPokretanje = true;

  // Filteri
  String? _regija;
  String? _tezina;
  double? _minTrajanje;
  double? _maxTrajanje;
  String _sortiraj = 'naziv';
  int _offset = 0;
  final int _limit = 30;

  // Dostupne regije (učitane jednom)
  List<String> _dostupneRegije = [];

  @override
  void initState() {
    super.initState();
    _ucitajRegije();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ucitajRegije() async {
    try {
      final regije = await _api.getSveRegije();
      setState(() {
        _dostupneRegije = regije
            .map((r) => r['regija'] as String? ?? '')
            .where((r) => r.isNotEmpty)
            .toList()
          ..sort();
      });
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _pretrazi();
    });
  }

  Future<void> _pretrazi({bool resetOffset = true}) async {
    if (resetOffset) _offset = 0;
    setState(() {
      _ucitavanje = true;
      _prvoPokretanje = false;
    });
    try {
      final result = await _api.pretraziRute(
        pretraga: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        regija: _regija,
        tezina: _tezina,
        minTrajanje: _minTrajanje,
        maxTrajanje: _maxTrajanje,
        sortiraj: _sortiraj,
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _rezultati = (result['rute'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _ukupno = (result['ukupno'] as num?)?.toInt() ?? 0;
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

  void _prikaziFiltere() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterSheet(
        regija: _regija,
        tezina: _tezina,
        minTrajanje: _minTrajanje,
        maxTrajanje: _maxTrajanje,
        sortiraj: _sortiraj,
        dostupneRegije: _dostupneRegije,
        onApply: (regija, tezina, minT, maxT, sort) {
          setState(() {
            _regija = regija;
            _tezina = tezina;
            _minTrajanje = minT;
            _maxTrajanje = maxT;
            _sortiraj = sort;
          });
          _pretrazi();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _resetFiltere() {
    setState(() {
      _regija = null;
      _tezina = null;
      _minTrajanje = null;
      _maxTrajanje = null;
      _sortiraj = 'naziv';
      _searchController.clear();
    });
    _pretrazi();
  }

  bool get _imaAktivneFiltere =>
      _regija != null ||
      _tezina != null ||
      _minTrajanje != null ||
      _maxTrajanje != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pretraži rute'),
        actions: [
          if (_imaAktivneFiltere)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Očisti filtere',
              onPressed: _resetFiltere,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: (_) => _pretrazi(),
                    decoration: InputDecoration(
                      hintText: 'Pretraži po nazivu rute...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _pretrazi();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: _imaAktivneFiltere,
                  child: IconButton.filled(
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filteri',
                    onPressed: _prikaziFiltere,
                  ),
                ),
              ],
            ),
          ),

          // Aktivni filteri kao chipovi
          if (_imaAktivneFiltere)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  if (_regija != null)
                    _filterChip('Regija: $_regija',
                        () => setState(() => _regija = null)),
                  if (_tezina != null)
                    _filterChip('Težina: $_tezina',
                        () => setState(() => _tezina = null)),
                  if (_minTrajanje != null)
                    _filterChip('Min: ${_minTrajanje}h',
                        () => setState(() => _minTrajanje = null)),
                  if (_maxTrajanje != null)
                    _filterChip('Max: ${_maxTrajanje}h',
                        () => setState(() => _maxTrajanje = null)),
                ],
              ),
            ),

          // Broj rezultata
          if (!_prvoPokretanje)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '$_ukupno rezultata',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (_ukupno > _limit)
                    Text(
                      'Str. ${(_offset ~/ _limit) + 1}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),

          // Rezultati
          Expanded(
            child: _prvoPokretanje
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'Pretraži preko 1600 planinarskih ruta',
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upiši naziv ili koristi filtere',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : _ucitavanje
                    ? const Center(
                        child: CircularProgressIndicator())
                    : _rezultati.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off,
                                    size: 48,
                                    color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                const Text(
                                    'Nema rezultata za zadane uvjete'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            itemCount: _rezultati.length,
                            itemBuilder: (context, index) {
                              final ruta = _rezultati[index];
                              return _rutaKartica(ruta);
                            },
                          ),
          ),

          // Paginacija
          if (!_prvoPokretanje && _ukupno > _limit)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _offset > 0
                        ? () {
                            _offset -= _limit;
                            _pretrazi(resetOffset: false);
                          }
                        : null,
                  ),
                  Text(
                      'Str. ${(_offset ~/ _limit) + 1} / ${((_ukupno - 1) ~/ _limit) + 1}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _offset + _limit < _ukupno
                        ? () {
                            _offset += _limit;
                            _pretrazi(resetOffset: false);
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onDeleted: () {
          onRemove();
          _pretrazi();
        },
      ),
    );
  }

  Widget _rutaKartica(Map<String, dynamic> ruta) {
    final id = (ruta['id'] as num?)?.toInt() ?? 0;
    final naziv = ruta['naziv'] as String? ?? 'Nepoznata ruta';
    final tezina = ruta['tezina'] as String?;
    final trajanje = ruta['trajanje_h'];
    final duljina = ruta['duljina_km'];
    final visinska = ruta['visinska_razlika_m'];
    final regija = ruta['regija'] as String? ?? '';
    final podregija = ruta['podregija'] as String? ?? '';
    final hpsBroj = ruta['hps_broj'] as String?;
    final hpd = ruta['hpd'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _tezinaAvatar(tezina),
        title: Text(naziv,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              children: [
                if (trajanje != null) Text('⏱ ${trajanje}h'),
                if (duljina != null) Text('📏 ${duljina} km'),
                if (visinska != null)
                  Text('⬆ ${(visinska as num).toInt()} m'),
              ],
            ),
            Text(
              [regija, podregija, if (hpd != null) 'HPD $hpd']
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hpsBroj != null && hpsBroj.isNotEmpty)
              Text(hpsBroj,
                  style: TextStyle(
                      fontSize: 10, color: Colors.blue.shade700)),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
        isThreeLine: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetaljiScreen(rutaId: id)),
        ),
      ),
    );
  }

  Widget _tezinaAvatar(String? tezina) {
    Color bg;
    String text;
    switch (tezina) {
      case 'lagana':
        bg = Colors.green.shade100;
        text = '🟢';
        break;
      case 'srednja':
        bg = Colors.orange.shade100;
        text = '🟡';
        break;
      case 'teska':
        bg = Colors.red.shade100;
        text = '🔴';
        break;
      default:
        bg = Colors.grey.shade100;
        text = '⚪';
    }
    return CircleAvatar(
      backgroundColor: bg,
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }
}

// ═══════════════════════════════════════
// Filter Bottom Sheet
// ═══════════════════════════════════════
class _FilterSheet extends StatefulWidget {
  final String? regija;
  final String? tezina;
  final double? minTrajanje;
  final double? maxTrajanje;
  final String sortiraj;
  final List<String> dostupneRegije;
  final void Function(
    String? regija,
    String? tezina,
    double? minTrajanje,
    double? maxTrajanje,
    String sortiraj,
  ) onApply;

  const _FilterSheet({
    required this.regija,
    required this.tezina,
    required this.minTrajanje,
    required this.maxTrajanje,
    required this.sortiraj,
    required this.dostupneRegije,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _regija;
  late String? _tezina;
  late double? _minTrajanje;
  late double? _maxTrajanje;
  late String _sortiraj;

  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _regija = widget.regija;
    _tezina = widget.tezina;
    _minTrajanje = widget.minTrajanje;
    _maxTrajanje = widget.maxTrajanje;
    _sortiraj = widget.sortiraj;
    if (_minTrajanje != null) {
      _minController.text = _minTrajanje.toString();
    }
    if (_maxTrajanje != null) {
      _maxController.text = _maxTrajanje.toString();
    }
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Filteri',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _regija = null;
                      _tezina = null;
                      _minTrajanje = null;
                      _maxTrajanje = null;
                      _sortiraj = 'naziv';
                      _minController.clear();
                      _maxController.clear();
                    });
                  },
                  child: const Text('Očisti sve'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Regija
            DropdownButtonFormField<String?>(
              value: _regija,
              decoration: const InputDecoration(
                labelText: 'Regija',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sve regije')),
                ...widget.dostupneRegije.map((r) =>
                    DropdownMenuItem(value: r, child: Text(r))),
              ],
              onChanged: (val) => setState(() => _regija = val),
            ),
            const SizedBox(height: 12),

            // Težina
            const Text('Težina', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Sve'),
                  selected: _tezina == null,
                  onSelected: (_) => setState(() => _tezina = null),
                ),
                ChoiceChip(
                  label: const Text('🟢 Lagana'),
                  selected: _tezina == 'lagana',
                  onSelected: (_) =>
                      setState(() => _tezina = 'lagana'),
                ),
                ChoiceChip(
                  label: const Text('🟡 Srednja'),
                  selected: _tezina == 'srednja',
                  onSelected: (_) =>
                      setState(() => _tezina = 'srednja'),
                ),
                ChoiceChip(
                  label: const Text('🔴 Teška'),
                  selected: _tezina == 'teska',
                  onSelected: (_) =>
                      setState(() => _tezina = 'teska'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Trajanje
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min trajanje (h)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _minTrajanje = double.tryParse(val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max trajanje (h)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) =>
                        _maxTrajanje = double.tryParse(val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sortiranje
            DropdownButtonFormField<String>(
              value: _sortiraj,
              decoration: const InputDecoration(
                labelText: 'Sortiraj po',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'naziv', child: Text('Naziv (A-Z)')),
                DropdownMenuItem(
                    value: 'trajanje', child: Text('Trajanje')),
                DropdownMenuItem(
                    value: 'duljina', child: Text('Duljina')),
              ],
              onChanged: (val) =>
                  setState(() => _sortiraj = val ?? 'naziv'),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () => widget.onApply(
                _regija,
                _tezina,
                _minTrajanje,
                _maxTrajanje,
                _sortiraj,
              ),
              icon: const Icon(Icons.search),
              label: const Text('Primijeni'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}