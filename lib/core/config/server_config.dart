import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Runtime-configurable API server URL.
///
/// The terminal must be pointed at a server before anyone can log in. Once set
/// the value is persisted, and it survives logout so the operator can review or
/// change it from the login screen.
class ServerConfig {
  static const String _key = 'restora_server_url';

  static String? _cached;

  /// The saved URL, or null when the terminal has not been set up yet.
  static String? get savedUrl => _cached;

  /// The URL requests should actually go to.
  ///
  /// Falls back to the build-time default so a build that ships with a baked-in
  /// production URL works out of the box without a setup step.
  static String get baseUrl => _cached ?? AppConfig.defaultBaseUrl;

  /// True once an operator has confirmed the server for this terminal.
  ///
  /// Deliberately *not* satisfied by the build-time default alone: the terminal
  /// must be set up before anyone can log in. The default is used to pre-fill
  /// the setup screen, so confirming it is a single tap.
  static bool get isConfigured => _cached != null && _cached!.trim().isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    _cached = (stored != null && stored.trim().isNotEmpty) ? stored : null;
  }

  static Future<void> save(String url) async {
    final normalized = normalize(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, normalized);
    _cached = normalized;
  }

  /// Clears the saved URL, reverting to the build-time default.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cached = null;
  }

  /// Accepts what an operator would realistically type — `192.168.0.10:8029`,
  /// `example.com`, or a full URL — and returns a usable API base URL.
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;

    // Default to http:// for bare hosts and IPs, which is what an on-premise
    // terminal on a LAN will almost always be talking to.
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // Let the operator enter just the host; append the API prefix for them.
    if (!url.contains('/api/')) {
      url = '$url/api/v1';
    }

    return url;
  }

  /// Origin of the API server, used to resolve `/storage/...` image paths.
  static String get storageBaseUrl {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) return baseUrl;
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  /// Absolute URL for a media path returned by the API.
  static String mediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$storageBaseUrl/storage/$clean';
  }
}
