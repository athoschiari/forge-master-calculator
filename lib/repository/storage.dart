import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local JSON persistence backed by shared_preferences, which works on web,
/// desktop and Android without a server, database or authentication. Each
/// top-level object is stored as a JSON string under a stable key.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static const String _prefix = 'fmo.';

  static Future<Storage> open() async {
    final prefs = await SharedPreferences.getInstance();
    return Storage(prefs);
  }

  Map<String, dynamic>? readObject(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  List<dynamic> readList(String key) {
    final raw = _prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : const [];
  }

  Future<void> writeObject(String key, Map<String, dynamic> value) {
    return _prefs.setString('$_prefix$key', jsonEncode(value));
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) {
    return _prefs.setString('$_prefix$key', jsonEncode(value));
  }

  int? readInt(String key) => _prefs.getInt('$_prefix$key');

  Future<void> writeInt(String key, int value) =>
      _prefs.setInt('$_prefix$key', value);
}
