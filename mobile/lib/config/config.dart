import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Produkcijski URL (Render.com)
  static const String _produkcijskiUrl = 'https://planinarhr-api.onrender.com';

  static String get baseUrl {
    // Web build uvijek koristi produkcijski URL
    if (kIsWeb) return _produkcijskiUrl;

    // Android emulator koristi 10.0.2.2 za localhost
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';

    // iOS simulator i desktop koriste localhost
    return 'http://127.0.0.1:8000';
  }

  // Endpointi
  static String get rute => '$baseUrl/rute';
  static String get preporuka => '$baseUrl/rute/preporuka/rute';
  static String get oprema => '$baseUrl/oprema';
  static String get karta => '$baseUrl/karta';
  static String get vrijeme => '$baseUrl/vrijeme';
  static String get zdravlje => '$baseUrl/zdravlje';
  static String get slike => '$baseUrl/slike';

  // ← NOVO: Weather (Open-Meteo real-time)
  static String get weather => '$baseUrl/weather';
  static String get weatherLokacija => '$baseUrl/weather/lokacija';
  static String get weatherRuta => '$baseUrl/weather/ruta';
  static String get weatherPametna => '$baseUrl/weather/pametna-preporuka';
  static String get weatherKarta => '$baseUrl/weather/karta-overlay';
  static String get weatherPrognoza => '$baseUrl/weather/prognoza';
  
  // Regije
  static String get regijeSve => '$baseUrl/regije/sve';
  static String get regijePodregije => '$baseUrl/regije/podregije';
  static String get regijeRute => '$baseUrl/regije/rute';
  static String get regijeStatistika => '$baseUrl/regije/statistika';

  
}

