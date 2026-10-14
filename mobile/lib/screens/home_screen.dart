import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import 'about_screen.dart';
import 'detalji_screen.dart';
import 'preporuka_screen.dart';
import 'regije_screen.dart';
import 'pretraga_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _status;
  Map<String, dynamic>? _statistika;
  bool _ucitavanje = true;
  int _brojOmiljenih = 0;

  @override
  void initState() {
    super.initState();
    _ucitaj();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _osvjeziOmiljene();
  }

  Future<void> _osvjeziOmiljene() async {
    final omiljene = await FavoritesService.getFavorites();
    if (mounted) {
      setState(() => _brojOmiljenih = omiljene.length);
    }
  }

  Future<void> _ucitaj() async {
    try {
      final status = await _api.zdravlje();
      final omiljene = await FavoritesService.getFavorites();

      // Dohvati statistiku za detaljnije info
      Map<String, dynamic>? statistika;
      try {
        statistika = await _api.getStatistika();
      } catch (_) {
        // Ako /regije/statistika nije dostupna, nastavi bez nje
      }

      setState(() {
        _status = status;
        _statistika = statistika;
        _brojOmiljenih = omiljene.length;
        _ucitavanje = false;
      });
    } catch (e) {
      setState(() {
        _status = {'status': 'greška', 'detalji': e.toString()};
        _ucitavanje = false;
      });
    }
  }

  Future<void> _toggleDarkMode() async {
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', !isDark);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan&GO'),
        actions: [
          // ═══════ NOVO: Pretraživanje ═══════
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Pretraži rute',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PretragaScreen()),
            ),
          ),

          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Svijetla tema' : 'Tamna tema',
            onPressed: _toggleDarkMode,
          ),

          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
        ],
      ),
      body: _ucitavanje
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _ucitaj,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_status?['status'] == 'ok') ...[
                      // ═══════ NOVO: Statistika kartica ═══════
                      _statistikaHeader(theme),

                      const SizedBox(height: 16),

                      // Stat kartice
                      Row(
                        children: [
                          Expanded(
                            child: _statKartica(
                              Icons.route,
                              '${_statistika?['ukupno_ruta'] ?? _status?['ukupno_ruta'] ?? 0}',
                              'Ruta',
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statKartica(
                              Icons.map,
                              '${_statistika?['broj_regija'] ?? 20}',
                              'Regija',
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _statKartica(
                              Icons.favorite,
                              '$_brojOmiljenih',
                              'Omiljenih',
                              Colors.red,
                            ),
                          ),
                        ],
                      ),

                      // ═══════ NOVO: Težina raspodijela ═══════
                      if (_statistika != null) ...[
                        const SizedBox(height: 12),
                        _tezinaBar(theme),
                      ],

                      const SizedBox(height: 24),

                      // ═══════ NOVO: Brzi pristupi ═══════
                      Text(
                        'Istraži',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _brzaPlocica(
                              Icons.map_outlined,
                              'Regije',
                              'Pregledaj po regijama',
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.onPrimaryContainer,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const RegijeScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _brzaPlocica(
                              Icons.search,
                              'Pretraga',
                              'Filtriraj i pretraži',
                              theme.colorScheme.secondaryContainer,
                              theme.colorScheme.onSecondaryContainer,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const PretragaScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      Text(
                        'Brze preporuke',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _brzaAkcija(
                        Icons.child_care,
                        'S djecom',
                        'Lagane rute prikladne za obitelj',
                        Colors.orange,
                        () => _otvoriPreporuku(dob: 8),
                      ),
                      const SizedBox(height: 8),
                      _brzaAkcija(
                        Icons.wb_sunny,
                        'Za lijepo vrijeme',
                        'Srednje rute za sunčan dan',
                        Colors.amber,
                        () => _otvoriPreporuku(
                            tezina: 'srednja', uvjet: 'suncano'),
                      ),
                      const SizedBox(height: 8),
                      _brzaAkcija(
                        Icons.fitness_center,
                        'Izazov',
                        'Teške rute za iskusne planinare',
                        Colors.red,
                        () => _otvoriPreporuku(tezina: 'teska'),
                      ),
                      const SizedBox(height: 8),
                      _brzaAkcija(
                        Icons.ac_unit,
                        'Zimske rute',
                        'Rute pogodne za zimsko planinarenje',
                        Colors.blue,
                        () => _otvoriPreporuku(godisnjeDoba: 'zima'),
                      ),
                      const SizedBox(height: 8),
                      _brzaAkcija(
                        Icons.cloud,
                        'Prema vremenu',
                        'Rute sigurne za trenutno vrijeme',
                        Colors.teal,
                        () => _otvoriPreporuku(uvjet: 'suncano'),
                      ),

                      if (_brojOmiljenih > 0) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Omiljene rute',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<List<int>>(
                          future: FavoritesService.getFavorites(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            final ids = snapshot.data!;
                            return SizedBox(
                              height: 40,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: ids.length,
                                itemBuilder: (context, index) {
                                  final id = ids[index];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      avatar: const Icon(Icons.favorite,
                                          size: 16, color: Colors.red),
                                      label: Text('Ruta #$id'),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                DetaljiScreen(rutaId: id),
                                          ),
                                        );
                                        _osvjeziOmiljene();
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],

                      // ═══════ NOVO: HPS info ═══════
                      const SizedBox(height: 24),
                      Card(
                        color: isDark
                            ? Colors.green.shade900
                            : Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.verified,
                                  color: Colors.green.shade700, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Službeni HPS registar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                    Text(
                                      'Podaci iz registra putova Hrvatskog planinarskog saveza',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ═══════ NOVI WIDGETI ═══════

  Widget _statistikaHeader(ThemeData theme) {
    final hpsRute = (_statistika?['hps_rute'] as num?)?.toInt();

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.hiking, size: 40, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plan&GO',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    hpsRute != null
                        ? 'Sve planinarske rute Hrvatske na jednom mjestu'
                        : 'Tvoj planer za planinarenje',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
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

  Widget _tezinaBar(ThemeData theme) {
    final lagane = (_statistika?['lagane'] as num?)?.toInt() ?? 0;
    final srednje = (_statistika?['srednje'] as num?)?.toInt() ?? 0;
    final teske = (_statistika?['teske'] as num?)?.toInt() ?? 0;
    final ukupno = lagane + srednje + teske;
    if (ukupno == 0) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Raspodjela po težini',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  _tezinaSegment(
                      lagane / ukupno, Colors.green, '$lagane laganih'),
                  _tezinaSegment(
                      srednje / ukupno, Colors.orange, '$srednje srednjih'),
                  _tezinaSegment(
                      teske / ukupno, Colors.red, '$teske teških'),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tezinaLegenda('Lagana', lagane, Colors.green),
                _tezinaLegenda('Srednja', srednje, Colors.orange),
                _tezinaLegenda('Teška', teske, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tezinaSegment(double ratio, Color color, String tooltip) {
    return Expanded(
      flex: (ratio * 100).round().clamp(1, 100),
      child: Tooltip(
        message: tooltip,
        child: Container(height: 12, color: color),
      ),
    );
  }

  Widget _tezinaLegenda(String label, int broj, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$label ($broj)',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _brzaPlocica(IconData ikona, String naslov, String opis,
      Color bgColor, Color fgColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ikona, color: fgColor, size: 28),
            const SizedBox(height: 8),
            Text(naslov,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: fgColor)),
            Text(opis,
                style: TextStyle(fontSize: 11, color: fgColor.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  // ═══════ POSTOJEĆI WIDGETI ═══════

  void _otvoriPreporuku({
    int? dob,
    String? tezina,
    String? uvjet,
    String? godisnjeDoba,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PreporukaScreen(
          pocetniDob: dob,
          pocetnaTezina: tezina,
          pocetniUvjet: uvjet,
          pocetnoGodisnjeDoba: godisnjeDoba,
        ),
      ),
    );
    _osvjeziOmiljene();
  }

  Widget _statKartica(
      IconData ikona, String vrijednost, String label, Color boja) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(ikona, color: boja, size: 24),
            const SizedBox(height: 6),
            Text(vrijednost,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _brzaAkcija(IconData ikona, String naslov, String opis, Color boja,
      VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: boja.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ikona, color: boja, size: 24),
        ),
        title:
            Text(naslov, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(opis, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}