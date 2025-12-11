import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles secure persistence of the API token.
class TokenStorage {
  TokenStorage._();

  static const _secureKey = 'customer_api_token';
  static const _legacyPrefsKey = 'auth_token';

  static final TokenStorage instance = TokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Save the raw Sanctum token securely.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _secureKey, value: token);
    // Ensure legacy copy is removed to avoid drift.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  /// Returns the token, migrating from legacy SharedPreferences if needed.
  Future<String?> getToken() async {
    final existing = await _storage.read(key: _secureKey);
    if (existing != null && existing.isNotEmpty) return existing;

    // Migrate from legacy storage for existing installs.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _storage.write(key: _secureKey, value: legacy);
      await prefs.remove(_legacyPrefsKey);
      return legacy;
    }

    return null;
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _secureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }
}
