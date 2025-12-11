import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorite_service_ids';

  static Future<Set<String>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.toSet();
  }

  static Future<bool> isFavorite(String id) async {
    final set = await _load();
    return set.contains(id);
  }

  static Future<Set<String>> loadSet() => _load();

  static Future<void> setAll(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }

  static Future<void> toggle(String id) async {
    final set = await _load();
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    await setAll(set);
  }

  static Future<List<String>> all() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }
}
