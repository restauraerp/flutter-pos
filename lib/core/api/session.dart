import 'package:shared_preferences/shared_preferences.dart';

/// Holds the bearer token for the signed-in user.
///
/// Note: this uses `shared_preferences`, which is *not* encrypted at rest. It
/// is adequate for a dedicated, physically controlled POS terminal; if these
/// terminals ever run on shared or personal devices, swap the implementation
/// here for `flutter_secure_storage` — nothing outside this class needs to
/// change.
class Session {
  static const String _tokenKey = 'restora_token';

  static String? _token;

  static String? get token => _token;
  static bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _token = token;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
  }
}
