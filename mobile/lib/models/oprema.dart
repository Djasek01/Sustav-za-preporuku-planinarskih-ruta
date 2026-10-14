class OpremaItem {
  final String? ruta;
  final String? tezina;
  final String oprema;
  final String? opis;
  final double? trosakKn;

  OpremaItem({
    this.ruta,
    this.tezina,
    required this.oprema,
    this.opis,
    this.trosakKn,
  });

  factory OpremaItem.fromJson(Map<String, dynamic> json) {
    return OpremaItem(
      ruta: json['ruta'] as String?,
      tezina: json['tezina'] as String?,
      oprema: json['oprema'] as String? ?? '',
      opis: json['opis'] as String?,
      trosakKn: (json['trosak_kn'] as num?)?.toDouble(),
    );
  }
}

class ProcjenaTroska {
  final String ruta;
  final String? tezina;
  final String? regija;
  final double? trajanjeH;
  final double? duljinaKm;
  final String? polaziste;
  final int brojSudionika;
  final bool vlastitaOprema;
  final double? udaljenostKm;
  final double ulaznica;
  final double ulaznicaUkupno;
  final double trosakOpreme;
  final double gorivo;
  final double cestarina;
  final double trosakPrijevoza;
  final double trosakPrijevozaPoOsobi;
  final double ukupnoPoOsobi;
  final double ukupnoGrupa;
  final List<Map<String, dynamic>> opremaStavke;
  final String? napomena;

  ProcjenaTroska({
    required this.ruta,
    this.tezina,
    this.regija,
    this.trajanjeH,
    this.duljinaKm,
    this.polaziste,
    required this.brojSudionika,
    required this.vlastitaOprema,
    this.udaljenostKm,
    required this.ulaznica,
    required this.ulaznicaUkupno,
    required this.trosakOpreme,
    required this.gorivo,
    required this.cestarina,
    required this.trosakPrijevoza,
    required this.trosakPrijevozaPoOsobi,
    required this.ukupnoPoOsobi,
    required this.ukupnoGrupa,
    required this.opremaStavke,
    this.napomena,
  });

  factory ProcjenaTroska.fromJson(Map<String, dynamic> json) {
    final troskovi = json['troskovi'] as Map<String, dynamic>? ?? {};
    final opremaRaw = json['oprema'] as List<dynamic>? ?? [];

    return ProcjenaTroska(
      ruta: json['ruta'] as String? ?? '',
      tezina: json['tezina'] as String?,
      regija: json['regija'] as String?,
      trajanjeH: (json['trajanje_h'] as num?)?.toDouble(),
      duljinaKm: (json['duljina_km'] as num?)?.toDouble(),
      polaziste: json['polaziste'] as String?,
      brojSudionika: json['broj_sudionika'] as int? ?? 1,
      vlastitaOprema: json['vlastita_oprema'] as bool? ?? false,
      udaljenostKm: (json['udaljenost_km'] as num?)?.toDouble(),
      ulaznica: (troskovi['ulaznica_eur'] as num?)?.toDouble() ?? 0,
      ulaznicaUkupno:
          (troskovi['ulaznica_ukupno_eur'] as num?)?.toDouble() ?? 0,
      trosakOpreme:
          (troskovi['trosak_opreme_eur'] as num?)?.toDouble() ?? 0,
      gorivo: (troskovi['gorivo_eur'] as num?)?.toDouble() ?? 0,
      cestarina: (troskovi['cestarina_eur'] as num?)?.toDouble() ?? 0,
      trosakPrijevoza:
          (troskovi['trosak_prijevoza_eur'] as num?)?.toDouble() ?? 0,
      trosakPrijevozaPoOsobi:
          (troskovi['trosak_prijevoza_po_osobi_eur'] as num?)?.toDouble() ?? 0,
      ukupnoPoOsobi:
          (troskovi['ukupno_po_osobi_eur'] as num?)?.toDouble() ?? 0,
      ukupnoGrupa:
          (troskovi['ukupno_grupa_eur'] as num?)?.toDouble() ?? 0,
      opremaStavke: opremaRaw.map((e) => e as Map<String, dynamic>).toList(),
      napomena: json['napomena'] as String?,
    );
  }
}