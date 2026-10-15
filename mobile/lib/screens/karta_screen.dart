import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/api_service.dart';


class _TockaKarte {
  final String id;
  final String naziv;
  final LatLng pozicija;
  final String tezina;
  final int? visinaM;
  final String? slikaUrl;
  final String? rutaNaziv;
  final String tip; 

  _TockaKarte({
    required this.id,
    required this.naziv,
    required this.pozicija,
    required this.tezina,
    this.visinaM,
    this.slikaUrl,
    this.rutaNaziv,
    this.tip = 'kontrolna_tocka',
  });
}

class KartaScreen extends StatefulWidget {
  final int? rutaId;
  const KartaScreen({super.key, this.rutaId});

  @override
  State<KartaScreen> createState() => _KartaScreenState();
}

class _KartaScreenState extends State<KartaScreen> {
  final ApiService _api = ApiService();
  GoogleMapController? _mapController;

  final List<_TockaKarte> _sveTocke = [];
  final Set<Polyline> _polyline = {};

  bool _ucitavanje = true;
  String? _nazivRute;


  String? _aktivniFilter;

  static const LatLng _centar = LatLng(44.5, 16.0);

  @override
  void initState() {
    super.initState();
    if (widget.rutaId != null) {
      _ucitajJednuRutu(widget.rutaId!);
    } else {
      _ucitajSveRute();
    }
  }


  Set<Marker> get _filtriraniMarkeri {
    final filtrirane = _aktivniFilter == null
        ? _sveTocke
        : _sveTocke.where((t) => t.tezina == _aktivniFilter).toList();

    return filtrirane.map((t) {
      final hue = t.tip == 'polaziste'
          ? BitmapDescriptor.hueGreen
          : t.tip == 'cilj'
              ? BitmapDescriptor.hueRed
              : t.tezina == 'lagana'
                  ? BitmapDescriptor.hueGreen
                  : t.tezina == 'srednja'
                      ? BitmapDescriptor.hueYellow
                      : BitmapDescriptor.hueRed;

      return Marker(
        markerId: MarkerId(t.id),
        position: t.pozicija,
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: t.tip == 'polaziste'
            ? InfoWindow(title: '🚩 Polazište', snippet: t.naziv)
            : t.tip == 'cilj'
                ? InfoWindow(title: '🏁 Cilj', snippet: t.naziv)
                : InfoWindow.noText,
        onTap: () => _prikaziDetaljeTocke(t),
      );
    }).toSet();
  }


  void _prikaziDetaljeTocke(_TockaKarte t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Oznaka polazišta/cilja
                if (t.tip == 'polaziste' || t.tip == 'cilj')
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: t.tip == 'polaziste'
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t.tip == 'polaziste' ? '🚩 Polazište rute' : '🏁 Cilj rute',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: t.tip == 'polaziste'
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  ),

                // Slika s fallbackom
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: t.slikaUrl != null
                      ? Image.network(
                          t.slikaUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: Colors.grey.shade100,
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            );
                          },
                          // errorBuilder fallback ako slika ne postoji
                          errorBuilder: (context, error, stackTrace) =>
                              _slikaFallback(),
                        )
                      : _slikaFallback(),
                ),

                const SizedBox(height: 16),

                // Naziv i težina
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.naziv,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _tezinaBadge(t.tezina),
                  ],
                ),

                const SizedBox(height: 12),

                if (t.visinaM != null)
                  _detaljRed(Icons.height, 'Nadmorska visina',
                      '${t.visinaM} m n.v.'),
                if (t.rutaNaziv != null)
                  _detaljRed(Icons.route, 'Ruta', t.rutaNaziv!),
                _detaljRed(
                    Icons.place,
                    'Koordinate',
                    '${t.pozicija.latitude.toStringAsFixed(5)}, '
                    '${t.pozicija.longitude.toStringAsFixed(5)}'),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slikaFallback() {
    return Container(
      height: 200,
      width: double.infinity,
      color: Colors.green.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.landscape, size: 64, color: Colors.green.shade300),
          const SizedBox(height: 8),
          Text(
            'Slika nije dostupna',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _tezinaBadge(String tezina) {
    final boja = tezina == 'lagana'
        ? Colors.green
        : tezina == 'srednja'
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: boja.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tezina,
        style: TextStyle(
            color: boja, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _detaljRed(IconData ikona, String label, String vrijednost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(ikona, size: 20, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Expanded(
            child: Text(vrijednost,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _ucitajJednuRutu(int id) async {
    try {
      final data = await _api.kartaRute(id);
      final waypoints = data['waypoints'] as List<dynamic>? ?? [];
      _nazivRute = data['ruta'] as String?;
      final rutaTezina = data['tezina'] as String? ?? 'srednja';

      final List<LatLng> tockeLinije = [];

      for (int i = 0; i < waypoints.length; i++) {
        final wp = waypoints[i];
        final lat = (wp['lat'] as num?)?.toDouble();
        final lng = (wp['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final pozicija = LatLng(lat, lng);
        tockeLinije.add(pozicija);

        // Odredi tip: prvi = polazište, zadnji = cilj, ostali = kontrolna točka
        String tip;
        if (i == 0) {
          tip = 'polaziste';
        } else if (i == waypoints.length - 1 && waypoints.length > 1) {
          tip = 'cilj';
        } else {
          tip = wp['tip'] as String? ?? 'kontrolna_tocka';
        }

        _sveTocke.add(_TockaKarte(
          id: 'wp_$i',
          naziv: wp['naziv'] as String? ?? '',
          pozicija: pozicija,
          tezina: (wp['tezina'] as String?) ?? rutaTezina,
          visinaM: (wp['visina_m'] as num?)?.toInt(),
          slikaUrl: wp['slika_url'] as String?,
          rutaNaziv: _nazivRute,
          tip: tip,
        ));
      }

      if (tockeLinije.length >= 2) {
        _polyline.add(Polyline(
          polylineId: const PolylineId('ruta'),
          points: tockeLinije,
          color: const Color(0xFF2E7D32),
          width: 4,
        ));
      }

      setState(() => _ucitavanje = false);
    } catch (e) {
      setState(() => _ucitavanje = false);
    }
  }

  Future<void> _ucitajSveRute() async {
    try {
      final data = await _api.sveRuteZaKartu();

      for (final ruta in data) {
        final tocke = ruta['tocke'] as List<dynamic>? ?? [];
        final rutaTezina = ruta['tezina'] as String? ?? 'srednja';
        for (final t in tocke) {
          final lat = (t['lat'] as num?)?.toDouble();
          final lng = (t['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;

          _sveTocke.add(_TockaKarte(
            id: '${ruta['id']}_${t['naziv']}',
            naziv: t['naziv'] as String? ?? '',
            pozicija: LatLng(lat, lng),
            tezina: (t['tezina'] as String?) ?? rutaTezina,
            visinaM: (t['visina'] as num?)?.toInt(),
            slikaUrl: t['slika_url'] as String?,
            rutaNaziv: ruta['naziv'] as String?,
          ));
        }
      }

      setState(() => _ucitavanje = false);
    } catch (e) {
      setState(() => _ucitavanje = false);
    }
  }

  LatLngBounds _izracunajGranice(List<LatLng> tocke) {
    double minLat = tocke.first.latitude, maxLat = tocke.first.latitude;
    double minLng = tocke.first.longitude, maxLng = tocke.first.longitude;
    for (final t in tocke) {
      if (t.latitude < minLat) minLat = t.latitude;
      if (t.latitude > maxLat) maxLat = t.latitude;
      if (t.longitude < minLng) minLng = t.longitude;
      if (t.longitude > maxLng) maxLng = t.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markeri = _filtriraniMarkeri;

    return Scaffold(
      appBar: AppBar(title: Text(_nazivRute ?? 'Karta ruta')),
      body: _ucitavanje
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: markeri.isNotEmpty
                        ? markeri.first.position
                        : _centar,
                    zoom: markeri.length == 1 ? 13 : 7,
                  ),
                  markers: markeri,
                  polylines: _polyline,
                  mapType: MapType.terrain,
                  zoomControlsEnabled: true,

                  onMapCreated: (controller) {
                    _mapController = controller;
                    if (markeri.length > 1) {
                      final tocke =
                          markeri.map((m) => m.position).toList();
                      controller.animateCamera(
                        CameraUpdate.newLatLngBounds(
                            _izracunajGranice(tocke), 50),
                      );
                    }
                  },
                ),


                // Legenda za početak/kraj (kad je jedna ruta)
                if (widget.rutaId != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: SafeArea(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, color: Colors.green.shade700, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Polazište', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.flag, color: Colors.red.shade700, size: 18),
                                  const SizedBox(width: 6),
                                  const Text('Cilj', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Colors.blue.shade400, size: 14),
                                  const SizedBox(width: 8),
                                  const Text('Kontrolna točka', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Filter legenda (kad su sve rute)
                if (widget.rutaId == null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: SafeArea(
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _legendaFilter('lagana', '🟢', 'Lagane'),
                              _legendaFilter('srednja', '🟡', 'Srednje'),
                              _legendaFilter('teska', '🔴', 'Teške'),
                              const Divider(height: 12),
                              _legendaFilter(null, '🗺', 'Sve'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Brojač prikazanih markera
                Positioned(
                  bottom: 24,
                  left: 12,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        '${markeri.length} točaka',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legendaFilter(String? tezina, String ikona, String tekst) {
    final aktivan = _aktivniFilter == tezina;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {

          _aktivniFilter = aktivan ? null : tezina;
        });
      },
      child: Container(

        constraints: const BoxConstraints(minHeight: 44, minWidth: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: aktivan
              ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: aktivan
              ? Border.all(color: const Color(0xFF2E7D32), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ikona, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              tekst,
              style: TextStyle(
                fontSize: 14,
                fontWeight: aktivan ? FontWeight.bold : FontWeight.normal,
                color: aktivan ? const Color(0xFF2E7D32) : Colors.black87,
              ),
            ),
            if (aktivan) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check, size: 16, color: Color(0xFF2E7D32)),
            ],
          ],
        ),
      ),
    );
  }
}