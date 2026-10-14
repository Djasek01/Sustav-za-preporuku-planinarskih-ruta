import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'detalji_screen.dart';

/// Ikone za regije — mapiranje regija na Material ikone
const Map<String, IconData> _regijaIkone = {
  'Gorski kotar': Icons.forest,
  'Velebit': Icons.terrain,
  'Lika': Icons.landscape,
  'Istra': Icons.sailing,
  'Kvarner': Icons.water,
  'Žumberak i Samoborsko gorje': Icons.park,
  'Medvednica': Icons.nature_people,
  'Bilogora i Kalnik': Icons.grass,
  'Papuk': Icons.filter_hdr,
  'Slavonija': Icons.agriculture,
  'Dalmacija': Icons.wb_sunny,
  'Dinara': Icons.hiking,
  'Mosor': Icons.terrain,
  'Biokovo': Icons.landscape,
  'Učka i Ćićarija': Icons.filter_hdr,
  'Plješivica': Icons.forest,
  'Risnjak': Icons.park,
  'Hrvatsko zagorje': Icons.villa,
  'Moslavačka gora': Icons.grass,
  'Požeška gora': Icons.filter_hdr,
};

/// Boje za težinu
Color _tezinaColor(String? tezina) {
  switch (tezina) {
    case 'lagana':
      return Colors.green;
    case 'srednja':
      return Colors.orange;
    case 'teska':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String _tezinaIkona(String? tezina) {
  switch (tezina) {
    case 'lagana':
      return '🟢';
    case 'srednja':
      return '🟡';
    case 'teska':
      return '🔴';
    default:
      return '⚪';
  }
}


class RegijeScreen extends StatefulWidget {
  const RegijeScreen({super.key});

  @override
  State<RegijeScreen> createState() => _RegijeScreenState();
}

class _RegijeScreenState extends State<RegijeScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _regije = [];
  bool _ucitavanje = true;
  String? _greska;

  @override
  void initState() {
    super.initState();
    _ucitaj();
  }

  Future<void> _ucitaj() async {
    setState(() {
      _ucitavanje = true;
      _greska = null;
    });
    try {
      final regije = await _api.getSveRegije();
      setState(() {
        _regije = regije;
        _ucitavanje = false;
      });
    } catch (e) {
      setState(() {
        _greska = e.toString();
        _ucitavanje = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Regije Hrvatske'),
      ),
      body: _ucitavanje
          ? const Center(child: CircularProgressIndicator())
          : _greska != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text('Greška: $_greska',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _ucitaj,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Pokušaj ponovo'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _ucitaj,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _regije.length + 1, // +1 za header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Header kartica sa statistikom
                        final ukupnoRuta = _regije.fold<int>(
                          0,
                          (sum, r) => sum + ((r['broj_ruta'] as num?)?.toInt() ?? 0),
                        );
                        return Card(
                          color: theme.colorScheme.primaryContainer,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(Icons.map,
                                    size: 40,
                                    color: theme.colorScheme.onPrimaryContainer),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_regije.length} regija',
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      Text(
                                        '$ukupnoRuta planinarskih ruta',
                                        style: TextStyle(
                                          color: theme.colorScheme.onPrimaryContainer
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final regija = _regije[index - 1];
                      final naziv = regija['regija'] ?.toString() ?? 'Nepoznato';
                      final brojRuta =
                          (regija['broj_ruta'] as num?)?.toInt() ?? 0;
                      final ikona = _regijaIkone[naziv] ?? Icons.place;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(ikona,
                                color: theme.colorScheme.primary),
                          ),
                          title: Text(naziv,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('$brojRuta ruta'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RegijaDetaljiScreen(regija: naziv),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ═══════════════════════════════════════
// EKRAN 2: Detalji regije — podregije + rute
// ═══════════════════════════════════════
class RegijaDetaljiScreen extends StatefulWidget {
  final String regija;
  const RegijaDetaljiScreen({super.key, required this.regija});

  @override
  State<RegijaDetaljiScreen> createState() => _RegijaDetaljiScreenState();
}

class _RegijaDetaljiScreenState extends State<RegijaDetaljiScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  List<Map<String, dynamic>> _podregije = [];
  List<Map<String, dynamic>> _rute = [];
  int _ukupnoRuta = 0;
  bool _ucitavanjePodregija = true;
  bool _ucitavanjeRuta = true;

  String? _odabranaPodregija;
  String? _odabranaTezina;
  String _sortiraj = 'naziv';
  int _offset = 0;
  final int _limit = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _ucitajPodregije();
    _ucitajRute();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _ucitajPodregije() async {
    try {
      final podregije = await _api.getPodregije(widget.regija);
      setState(() {
        _podregije = podregije;
        _ucitavanjePodregija = false;
      });
    } catch (_) {
      setState(() => _ucitavanjePodregija = false);
    }
  }

  Future<void> _ucitajRute({bool resetOffset = true}) async {
    if (resetOffset) _offset = 0;
    setState(() => _ucitavanjeRuta = true);
    try {
      final result = await _api.pretraziRute(
        regija: widget.regija,
        podregija: _odabranaPodregija,
        tezina: _odabranaTezina,
        sortiraj: _sortiraj,
        limit: _limit,
        offset: _offset,
      );
      setState(() {
        _rute = (result['rute'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        _ukupnoRuta = (result['ukupno'] as num?)?.toInt() ?? 0;
        _ucitavanjeRuta = false;
      });
    } catch (_) {
      setState(() => _ucitavanjeRuta = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.regija),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Rute'),
            Tab(icon: Icon(Icons.map_outlined), text: 'Podregije'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Rute
          Column(
            children: [
              // Filteri
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                child: Row(
                  children: [
                    // Filter po težini
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: _odabranaTezina,
                        decoration: const InputDecoration(
                          labelText: 'Težina',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: null, child: Text('Sve')),
                          DropdownMenuItem(
                              value: 'lagana', child: Text('🟢 Lagana')),
                          DropdownMenuItem(
                              value: 'srednja',
                              child: Text('🟡 Srednja')),
                          DropdownMenuItem(
                              value: 'teska', child: Text('🔴 Teška')),
                        ],
                        onChanged: (val) {
                          _odabranaTezina = val;
                          _ucitajRute();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sortiranje
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortiraj,
                        decoration: const InputDecoration(
                          labelText: 'Sortiraj',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'naziv', child: Text('Naziv')),
                          DropdownMenuItem(
                              value: 'trajanje',
                              child: Text('Trajanje')),
                          DropdownMenuItem(
                              value: 'duljina',
                              child: Text('Duljina')),
                        ],
                        onChanged: (val) {
                          _sortiraj = val ?? 'naziv';
                          _ucitajRute();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Podregija filter chips
              if (_podregije.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    children: [
                      FilterChip(
                        label: const Text('Sve'),
                        selected: _odabranaPodregija == null,
                        onSelected: (_) {
                          setState(() => _odabranaPodregija = null);
                          _ucitajRute();
                        },
                      ),
                      const SizedBox(width: 6),
                      ..._podregije.map((p) {
                        final naziv =
                            p['podregija'] ?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(naziv,
                                style: const TextStyle(fontSize: 12)),
                            selected:
                                _odabranaPodregija == naziv,
                            onSelected: (_) {
                              setState(() {
                                _odabranaPodregija =
                                    _odabranaPodregija == naziv
                                        ? null
                                        : naziv;
                              });
                              _ucitajRute();
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              // Broj rezultata
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '$_ukupnoRuta ruta',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    if (_ukupnoRuta > _limit)
                      Text(
                        'Str. ${(_offset ~/ _limit) + 1} / ${((_ukupnoRuta - 1) ~/ _limit) + 1}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),

              // Lista ruta
              Expanded(
                child: _ucitavanjeRuta
                    ? const Center(
                        child: CircularProgressIndicator())
                    : _rute.isEmpty
                        ? const Center(
                            child: Text('Nema ruta za odabrane filtere'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            itemCount: _rute.length,
                            itemBuilder: (context, index) {
                              final ruta = _rute[index];
                              return _rutaKartica(ruta);
                            },
                          ),
              ),

              // Paginacija
              if (_ukupnoRuta > _limit)
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
                                _ucitajRute(resetOffset: false);
                              }
                            : null,
                      ),
                      Text(
                          'Str. ${(_offset ~/ _limit) + 1} / ${((_ukupnoRuta - 1) ~/ _limit) + 1}'),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed:
                            _offset + _limit < _ukupnoRuta
                                ? () {
                                    _offset += _limit;
                                    _ucitajRute(
                                        resetOffset: false);
                                  }
                                : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // TAB 2: Podregije
          _ucitavanjePodregija
              ? const Center(child: CircularProgressIndicator())
              : _podregije.isEmpty
                  ? const Center(
                      child: Text('Nema podregija za ovu regiju'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _podregije.length,
                      itemBuilder: (context, index) {
                        final pod = _podregije[index];
                        final naziv =
                            pod['podregija'] ?.toString() ?? '';
                        final broj =
                            (pod['broj_ruta'] as num?)?.toInt() ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text('$broj',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme
                                          .colorScheme.primary)),
                            ),
                            title: Text(naziv),
                            subtitle: Text('$broj ruta'),
                            trailing:
                                const Icon(Icons.chevron_right),
                            onTap: () {
                              setState(() {
                                _odabranaPodregija = naziv;
                                _tabController.animateTo(0);
                              });
                              _ucitajRute();
                            },
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _rutaKartica(Map<String, dynamic> ruta) {
    final id = (ruta['id'] as num?)?.toInt() ?? 0;
    final naziv = ruta['naziv'] ?.toString() ?? 'Nepoznata ruta';
    final tezina = ruta['tezina'] ?.toString();
    final trajanje = ruta['trajanje_h'];
    final duljina = ruta['duljina_km'];
    final visinska = ruta['visinska_razlika_m'];
    final podregija = ruta['podregija'] ?.toString() ?? '';
    final hpsBroj = ruta['hps_broj'] ?.toString();
    final hpd = ruta['hpd'] ?.toString();
    final tipTerena = (ruta['tip_terena'] as List<dynamic>?)
            ?.cast<String>()
            .join(', ') ??
        '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetaljiScreen(rutaId: id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_tezinaIkona(tezina),
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(naziv,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                  if (hpsBroj != null && hpsBroj.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('HPS $hpsBroj',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (trajanje != null)
                    _infoChip(Icons.timer, '${trajanje}h'),
                  if (duljina != null)
                    _infoChip(Icons.straighten, '${duljina} km'),
                  if (visinska != null)
                    _infoChip(Icons.height,
                        '${(visinska as num).toInt()} m'),
                  if (tezina != null)
                    _infoChip(Icons.trending_up, tezina,
                        color: _tezinaColor(tezina)),
                ],
              ),
              if (podregija.isNotEmpty || hpd != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (podregija.isNotEmpty) podregija,
                    if (hpd != null) 'HPD $hpd',
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
              if (tipTerena.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(tipTerena,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                fontSize: 12, color: color ?? Colors.grey.shade700)),
      ],
    );
  }
}