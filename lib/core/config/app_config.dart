/// Build-time configuration.
///
/// The base URL is resolved in this order:
///   1. `--dart-define=API_BASE_URL=...`  (explicit override, wins over everything)
///   2. The preset for `--dart-define=APP_ENV=dev|staging|prod`
///   3. The `dev` preset
///
/// A URL saved by the user on the login screen overrides all of the above at
/// runtime — see `ServerConfig`. The values here are only the *defaults* baked
/// into a given build.
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
  static const Map<String, String> _presets = <String, String>{
    'dev': 'http://10.0.2.2:8029/api/v1',
    'staging': 'https://staging.restauraerp.com/api/v1',
    'prod': 'https://restauraerp.com/api/v1',
  };

  static String get environment => _envName;

  /// The base URL compiled into this build.
  static String get defaultBaseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    return _presets[_envName] ?? _presets['dev']!;
  }

  /// True when the build targets a non-production API, so the UI can badge it.
  static bool get isProduction => _envName == 'prod';

  /// Whether the user may change the server URL at runtime. Locked-down
  /// production builds can be compiled with `--dart-define=LOCK_SERVER_URL=true`
  /// so terminals in the field cannot be pointed elsewhere.
  static const bool lockServerUrl = bool.fromEnvironment(
    'LOCK_SERVER_URL',
    defaultValue: false,
  );

  /// Tax rate applied to the order subtotal after discount.
  /// Mirrors the 10% used by the Next.js POS screen.
  static const double taxRate = 0.10;
}
