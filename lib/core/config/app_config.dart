/// Build-time configuration.
///
/// The API server this terminal talks to is fixed when the app is built — there
/// is no in-app server picker. A *local* build talks to a locally running
/// core-api; a *production* build talks to https://app.restauraerp.com.
///
/// The base URL is resolved in this order:
///   1. `--dart-define=API_BASE_URL=...`  (explicit override for one-off builds)
///   2. The preset for `--dart-define=APP_ENV=dev|staging|prod`
///   3. The `dev` (local) preset
///
/// The CI release build passes `--dart-define=APP_ENV=prod`; a plain
/// `flutter run` gets the `dev` preset.
class AppConfig {
  const AppConfig._();

  static const String _envName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Presets per build environment.
  ///
  /// `10.0.2.2` is the Android emulator's alias for the host machine's
  /// `127.0.0.1`, so a locally running core-api is reachable from the emulator.
  /// For a desktop build or a physical device on the LAN, override the local
  /// target with `--dart-define=API_BASE_URL=http://<host>:8029/api/v1`.
  static const Map<String, String> _presets = <String, String>{
    'dev': 'http://10.0.2.2:8029/api/v1',
    'staging': 'https://staging.restauraerp.com/api/v1',
    'prod': 'https://app.restauraerp.com/api/v1',
  };

  static String get environment => _envName;

  /// The API base URL compiled into this build.
  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    return _presets[_envName] ?? _presets['dev']!;
  }

  /// True when the build targets the production API, so the UI can badge
  /// anything else as a non-production build.
  static bool get isProduction => _envName == 'prod';

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

  /// Tax rate applied to the order subtotal after discount.
  /// Mirrors the 10% used by the Next.js POS screen.
  /// Removed: the till read a hardcoded 10% VAT while the server computed tax
  /// from the restaurant's own rules, so the total on screen could differ from
  /// the one on the bill. PosController now reads /tax-rules at boot. This is
  /// the same fault TaxCalculator was written to fix on the web POS.
  @Deprecated('Read the rate from PosController.taxRate, which comes from /tax-rules.')
  static const double taxRate = 0.10;
}
