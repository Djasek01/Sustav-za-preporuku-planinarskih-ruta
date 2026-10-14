  class Ruta {
    final int? id;
    final String naziv;
    final String? tezina;
    final String? regija;
    final double? duljinaKm;
    final double? trajanjeH;
    final double? visinskaRazlikaM;
    final double? trosak;
    final String? podrucje;
    final double? polazisteLat;
    final double? polazisteLng;
    final String? polazisteNaziv;
    final List<String> kontrolneTocke;
    final List<String> tipTerena;
    final List<String> oprema;
    final List<String> godisnjadoba;
    final List<String> dobneSkupine;

    Ruta({
      this.id,
      required this.naziv,
      this.tezina,
      this.regija,
      this.duljinaKm,
      this.trajanjeH,
      this.visinskaRazlikaM,
      this.trosak,
      this.podrucje,
      this.polazisteLat,
      this.polazisteLng,
      this.polazisteNaziv,
      this.kontrolneTocke = const [],
      this.tipTerena = const [],
      this.oprema = const [],
      this.godisnjadoba = const [],
      this.dobneSkupine = const [],
    });

        factory Ruta.fromJson(Map<String, dynamic> json) {
      return Ruta(
        id: json['id'] as int?,
        naziv: json['naziv']?.toString() ?? '',
        tezina: json['tezina']?.toString(),
        regija: json['regija']?.toString(),
        duljinaKm: (json['duljina_km'] as num?)?.toDouble(),
        trajanjeH: (json['trajanje_h'] as num?)?.toDouble(),
        visinskaRazlikaM: (json['visinska_razlika_m'] as num?)?.toDouble(),
        trosak: (json['trosak'] as num?)?.toDouble(),
        podrucje: json['podrucje']?.toString(),
        polazisteLat: (json['polaziste_lat'] as num?)?.toDouble(),
        polazisteLng: (json['polaziste_lng'] as num?)?.toDouble(),
        polazisteNaziv: json['polaziste_naziv']?.toString(),
        kontrolneTocke: _toStringList(json['kontrolne_tocke']),
        tipTerena: _toStringList(json['tip_terena']),
        oprema: _toStringList(json['oprema']),
        godisnjadoba: _toStringList(json['godisnja_doba']),
        dobneSkupine: _toStringList(json['dobne_skupine']),
      );
    }

    static List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.where((e) => e != null).map((e) => e.toString()).toList();
      }
      return [];
    }

    String get tezinaIkona {
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
  }