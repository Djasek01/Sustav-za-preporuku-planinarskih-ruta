class TrenutnoVrijeme {
  final double? temperatura;
  final double? osjetTemperature;
  final int? vlaznost;
  final double? vjetarKmh;
  final double? udariVjetraKmh;
  final double? oborineMm;
  final int wmoKod;
  final String opis;
  final String ikona;
  final String uvjet;

  TrenutnoVrijeme({
    this.temperatura,
    this.osjetTemperature,
    this.vlaznost,
    this.vjetarKmh,
    this.udariVjetraKmh,
    this.oborineMm,
    this.wmoKod = 0,
    this.opis = '',
    this.ikona = '',
    this.uvjet = '',
  });

  factory TrenutnoVrijeme.fromJson(Map<String, dynamic> json) {
    return TrenutnoVrijeme(
      temperatura: (json['temperatura'] as num?)?.toDouble(),
      osjetTemperature: (json['osjet_temperature'] as num?)?.toDouble(),
      vlaznost: json['vlaznost'] as int?,
      vjetarKmh: (json['vjetar_kmh'] as num?)?.toDouble(),
      udariVjetraKmh: (json['udari_vjetra_kmh'] as num?)?.toDouble(),
      oborineMm: (json['oborine_mm'] as num?)?.toDouble(),
      wmoKod: json['wmo_kod'] as int? ?? 0,
      opis: json['opis'] as String? ?? '',
      ikona: json['ikona'] as String? ?? '',
      uvjet: json['uvjet'] as String? ?? '',
    );
  }
}

class PrognozaDan {
  final String datum;
  final double? tempMin;
  final double? tempMax;
  final double? oborineMm;
  final double? vjetarMaxKmh;
  final int wmoKod;
  final String opis;
  final String ikona;
  final String uvjet;
  final String? izlazakSunca;
  final String? zalazakSunca;

  PrognozaDan({
    required this.datum,
    this.tempMin,
    this.tempMax,
    this.oborineMm,
    this.vjetarMaxKmh,
    this.wmoKod = 0,
    this.opis = '',
    this.ikona = '',
    this.uvjet = '',
    this.izlazakSunca,
    this.zalazakSunca,
  });

  factory PrognozaDan.fromJson(Map<String, dynamic> json) {
    return PrognozaDan(
      datum: json['datum'] as String? ?? '',
      tempMin: (json['temp_min'] as num?)?.toDouble(),
      tempMax: (json['temp_max'] as num?)?.toDouble(),
      oborineMm: (json['oborine_mm'] as num?)?.toDouble(),
      vjetarMaxKmh: (json['vjetar_max_kmh'] as num?)?.toDouble(),
      wmoKod: json['wmo_kod'] as int? ?? 0,
      opis: json['opis'] as String? ?? '',
      ikona: json['ikona'] as String? ?? '',
      uvjet: json['uvjet'] as String? ?? '',
      izlazakSunca: json['izlazak_sunca'] as String?,
      zalazakSunca: json['zalazak_sunca'] as String?,
    );
  }

  /// Skraćeni dan (Pon, Uto, ...)
  String get danSkraceni {
    try {
      final dt = DateTime.parse(datum);
      const dani = ['Pon', 'Uto', 'Sri', 'Čet', 'Pet', 'Sub', 'Ned'];
      return dani[dt.weekday - 1];
    } catch (_) {
      return datum;
    }
  }
}

class WeatherRuta {
  final String ruta;
  final String? lokacija;
  final double lat;
  final double lng;
  final TrenutnoVrijeme trenutno;
  final List<PrognozaDan> prognoza;
  final bool sigurno;
  final String sigurnostPoruka;

  WeatherRuta({
    required this.ruta,
    this.lokacija,
    required this.lat,
    required this.lng,
    required this.trenutno,
    required this.prognoza,
    required this.sigurno,
    required this.sigurnostPoruka,
  });

  factory WeatherRuta.fromJson(Map<String, dynamic> json) {
    return WeatherRuta(
      ruta: json['ruta'] as String? ?? '',
      lokacija: json['lokacija'] as String?,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      trenutno: TrenutnoVrijeme.fromJson(json['trenutno'] ?? {}),
      prognoza: (json['prognoza'] as List<dynamic>?)
              ?.map((p) => PrognozaDan.fromJson(p))
              .toList() ??
          [],
      sigurno: json['sigurnost']?['sigurno'] as bool? ?? true,
      sigurnostPoruka: json['sigurnost']?['poruka'] as String? ?? '',
    );
  }
}

class PametnaPreporuka {
  final TrenutnoVrijeme vrijeme;
  final String godisnjeDoba;
  final int ukupnoRuta;
  final List<Map<String, dynamic>> rute;

  PametnaPreporuka({
    required this.vrijeme,
    required this.godisnjeDoba,
    required this.ukupnoRuta,
    required this.rute,
  });

  factory PametnaPreporuka.fromJson(Map<String, dynamic> json) {
    final vrijemeData = json['vrijeme'] as Map<String, dynamic>? ?? {};
    return PametnaPreporuka(
      vrijeme: TrenutnoVrijeme(
        temperatura: (vrijemeData['temperatura'] as num?)?.toDouble(),
        opis: vrijemeData['opis'] as String? ?? '',
        ikona: vrijemeData['ikona'] as String? ?? '',
        uvjet: vrijemeData['uvjet'] as String? ?? '',
        vjetarKmh: (vrijemeData['vjetar_kmh'] as num?)?.toDouble(),
      ),
      godisnjeDoba: json['godisnje_doba'] as String? ?? '',
      ukupnoRuta: json['ukupno_ruta'] as int? ?? 0,
      rute: (json['rute'] as List<dynamic>?)
              ?.map((r) => Map<String, dynamic>.from(r))
              .toList() ??
          [],
    );
  }
}

class WeatherOverlay {
  final String regija;
  final double lat;
  final double lng;
  final double? temperatura;
  final String opis;
  final String ikona;
  final String uvjet;

  WeatherOverlay({
    required this.regija,
    required this.lat,
    required this.lng,
    this.temperatura,
    this.opis = '',
    this.ikona = '',
    this.uvjet = '',
  });

  factory WeatherOverlay.fromJson(Map<String, dynamic> json) {
    return WeatherOverlay(
      regija: json['regija'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      temperatura: (json['temperatura'] as num?)?.toDouble(),
      opis: json['opis'] as String? ?? '',
      ikona: json['ikona'] as String? ?? '',
      uvjet: json['uvjet'] as String? ?? '',
    );
  }
}