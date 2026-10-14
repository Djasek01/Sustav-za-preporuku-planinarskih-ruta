import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/config.dart';
import '../models/ruta.dart';
import '../models/oprema.dart';
import '../models/weather.dart';

class PreporukaRezultat {
  final List<Ruta> rute;
  final Map<String, dynamic> ogranicenja;
  final int brojRezultata;

  PreporukaRezultat({
    required this.rute,
    required this.ogranicenja,
    required this.brojRezultata,
  });
}

class ApiService {

  Future<Map<String, dynamic>> zdravlje() async {
    final response = await http.get(Uri.parse(ApiConfig.zdravlje));
    return jsonDecode(response.body);
  }


  Future<List<Ruta>> getRute({
    String? tezina,
    String? regija,
    double? maxTrajanje,
    int limit = 65,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (tezina != null) params['tezina'] = tezina;
    if (regija != null) params['regija'] = regija;
    if (maxTrajanje != null) params['max_trajanje'] = maxTrajanje.toString();

    final uri = Uri.parse(ApiConfig.rute).replace(queryParameters: params);
    final response = await http.get(uri);
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Ruta.fromJson(json)).toList();
  }


  Future<Ruta> getRuta(int id) async {
    final response = await http.get(Uri.parse('${ApiConfig.rute}/$id'));
    return Ruta.fromJson(jsonDecode(response.body));
  }

 
  Future<PreporukaRezultat> preporukaRuta({
    int? dob,
    String? godisnjeDoba,
    String? tezina,
    String? tipTerena,
    String? vremenskiUvjet,
    String? regija,
    int limit = 20,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (dob != null) params['dob'] = dob.toString();
    if (godisnjeDoba != null) params['godisnje_doba'] = godisnjeDoba;
    if (tezina != null) params['tezina'] = tezina;
    if (tipTerena != null) params['tip_terena'] = tipTerena;
    if (vremenskiUvjet != null) params['vremenski_uvjet'] = vremenskiUvjet;
    if (regija != null) params['regija'] = regija;

    final uri = Uri.parse(ApiConfig.preporuka).replace(queryParameters: params);
    final response = await http.get(uri);
    final data = jsonDecode(response.body);

    final List<dynamic> ruteJson = data['rute'] ?? [];
    return PreporukaRezultat(
      rute: ruteJson.map((json) => Ruta.fromJson(json)).toList(),
      ogranicenja: data['ogranicenja'] as Map<String, dynamic>? ?? {},
      brojRezultata: data['broj_rezultata'] as int? ?? 0,
    );
  }

  Future<List<OpremaItem>> getOpremaZaRutu(int rutaId) async {
    final response =
        await http.get(Uri.parse('${ApiConfig.oprema}/za-rutu/$rutaId'));
    final data = jsonDecode(response.body);
    final List<dynamic> opremaList = data['oprema'] ?? [];
    return opremaList.map((json) => OpremaItem.fromJson(json)).toList();
  }

  Future<ProcjenaTroska> procjenaTroska(
    int rutaId, {
    int brojSudionika = 1,
    bool vlastitaOprema = false,
  }) async {
    final params = <String, String>{
      'broj_sudionika': brojSudionika.toString(),
      'vlastita_oprema': vlastitaOprema.toString(),
    };
    final uri = Uri.parse('${ApiConfig.oprema}/procjena-troska/$rutaId')
        .replace(queryParameters: params);
    final response = await http.get(uri);
    return ProcjenaTroska.fromJson(jsonDecode(response.body));
  }

  Future<Map<String, dynamic>> kartaRute(int rutaId) async {
    final response =
        await http.get(Uri.parse('${ApiConfig.karta}/ruta/$rutaId'));
    return jsonDecode(response.body);
  }

  Future<List<Map<String, dynamic>>> sveRuteZaKartu({String? regija}) async {
    var uri = Uri.parse('${ApiConfig.karta}/sve-rute');
    if (regija != null) {
      uri = uri.replace(queryParameters: {'regija': regija});
    }
    final response = await http.get(uri);
    final List<dynamic> data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Ruta>> rutePoUvjetu(String uvjet, {String? tezina}) async {
    final params = <String, String>{'uvjet': uvjet};
    if (tezina != null) params['tezina'] = tezina;

    final uri = Uri.parse('${ApiConfig.vrijeme}/preporuka')
        .replace(queryParameters: params);
    final response = await http.get(uri);
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Ruta.fromJson(json)).toList();
  }
    // ─── Weather: trenutno vrijeme za rutu ───
  Future<WeatherRuta> getWeatherRuta(int rutaId) async {
    final response =
        await http.get(Uri.parse('${ApiConfig.weatherRuta}/$rutaId'));
    if (response.statusCode != 200) {
      throw Exception('Greška pri dohvatu vremena');
    }
    return WeatherRuta.fromJson(jsonDecode(response.body));
  }
 
  // ─── Weather: pametna preporuka ───
  Future<PametnaPreporuka> getPametnaPreporuka({
    double lat = 45.815,
    double lng = 15.982,
    int? dob,
    String? tezina,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'lat': lat.toString(),
      'lng': lng.toString(),
      'limit': limit.toString(),
    };
    if (dob != null) params['dob'] = dob.toString();
    if (tezina != null) params['tezina'] = tezina;
 
    final uri =
        Uri.parse(ApiConfig.weatherPametna).replace(queryParameters: params);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Greška pri dohvatu pametne preporuke');
    }
    return PametnaPreporuka.fromJson(jsonDecode(response.body));
  }
 
  // ─── Weather: overlay za kartu ───
  Future<List<WeatherOverlay>> getWeatherKarta() async {
    final response = await http.get(Uri.parse(ApiConfig.weatherKarta));
    if (response.statusCode != 200) {
      throw Exception('Greška pri dohvatu weather overlaya');
    }
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => WeatherOverlay.fromJson(json)).toList();
  }

  /// Dohvati sve regije s brojem ruta
Future<List<Map<String, dynamic>>> getSveRegije() async {
  final response = await http.get(Uri.parse(ApiConfig.regijeSve));
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }
  throw Exception('Greška pri dohvatu regija');
}

/// Dohvati podregije za određenu regiju
Future<List<Map<String, dynamic>>> getPodregije(String regija) async {
  final response = await http.get(
    Uri.parse('${ApiConfig.regijePodregije}/${Uri.encodeComponent(regija)}'),
  );
  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }
  throw Exception('Greška pri dohvatu podregija');
}

/// Pretraži rute s filterima
Future<Map<String, dynamic>> pretraziRute({
  String? regija,
  String? podregija,
  String? tezina,
  double? minTrajanje,
  double? maxTrajanje,
  String? hpd,
  String? pretraga,
  String sortiraj = 'naziv',
  int limit = 50,
  int offset = 0,
}) async {
  final params = <String, String>{
    'sortiraj': sortiraj,
    'limit': limit.toString(),
    'offset': offset.toString(),
  };
  if (regija != null) params['regija'] = regija;
  if (podregija != null) params['podregija'] = podregija;
  if (tezina != null) params['tezina'] = tezina;
  if (minTrajanje != null) params['min_trajanje'] = minTrajanje.toString();
  if (maxTrajanje != null) params['max_trajanje'] = maxTrajanje.toString();
  if (hpd != null) params['hpd'] = hpd;
  if (pretraga != null) params['pretraga'] = pretraga;

  final uri = Uri.parse(ApiConfig.regijeRute)
      .replace(queryParameters: params);
  final response = await http.get(uri);
  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  throw Exception('Greška pri pretraživanju ruta');
}

/// Dohvati statistiku baze
Future<Map<String, dynamic>> getStatistika() async {
  final response = await http.get(Uri.parse(ApiConfig.regijeStatistika));
  if (response.statusCode == 200) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  throw Exception('Greška pri dohvatu statistike');
}
 
}


