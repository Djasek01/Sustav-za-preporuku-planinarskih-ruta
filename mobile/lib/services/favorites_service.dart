import 'package:shared_preferences/shared_preferences.dart';


class FavoritesService {
  static const String _key = 'omiljene_rute';

  static Future<List<int>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_key) ?? [];
    return lista.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList();
  }

  static Future<void> toggleFavorite(int rutaId) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_key) ?? [];
    final idStr = rutaId.toString();

    if (lista.contains(idStr)) {
      lista.remove(idStr);
    } else {
      lista.add(idStr);
    }

    await prefs.setStringList(_key, lista);
  }

  static Future<bool> isFavorite(int rutaId) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_key) ?? [];
    return lista.contains(rutaId.toString());
  }
}