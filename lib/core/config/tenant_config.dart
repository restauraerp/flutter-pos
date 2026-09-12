import 'package:shared_preferences/shared_preferences.dart';

/// The restaurant (tenant) this terminal signs into.
///
/// Email addresses are unique *per restaurant*, not across the platform, so the
/// credentials alone do not identify a user — a restaurant code has to travel
/// with them. The API reads it from the `X-Tenant-ID` header (see
/// [tenant]), accepting either the restaurant's slug or its numeric id.
///
/// The value is persisted so returning staff get their restaurant back on the
/// login screen, and survives logout for the same reason. After a successful
/// login it is overwritten with the slug the API actually resolved, so every
/// later authenticated request agrees with the token (a mismatched header is
/// rejected with a 403).
class TenantConfig {
  static const String _key = 'restora_tenant';

  static String? _cached;

  /// The restaurant code sent with requests, or null when none is set yet.
  static String? get tenant => _cached;

  /// The restaurant this terminal last signed into, used to prefill the login
  /// form.
  static String? get savedTenant => _cached;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    _cached = (stored != null && stored.trim().isNotEmpty) ? stored : null;
  }

  static Future<void> save(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalized);
    _cached = normalized;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cached = null;
  }
}
