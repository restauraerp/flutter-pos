import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/api/session.dart';
import '../core/config/server_config.dart';
import '../data/models/models.dart';
import '../data/repositories/auth_repository.dart';

enum AuthStatus {
  /// Restoring persisted state on boot.
  checking,

  /// No server chosen yet — the terminal must be set up first.
  needsServer,

  /// Server is set, nobody signed in.
  loggedOut,

  /// Signed in and cleared for POS use.
  authenticated,
}

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.checking;
  UserModel? _user;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get error => _error;
  bool get busy => _busy;

  Future<void> bootstrap() async {
    await ServerConfig.load();
    await Session.load();

    // A 401 anywhere in the app drops us back to the login screen.
    ApiClient.onUnauthorized = () {
      if (_status == AuthStatus.authenticated) {
        Session.clear();
        _user = null;
        _status = AuthStatus.loggedOut;
        _error = 'Your session expired. Please log in again.';
        notifyListeners();
      }
    };

    if (!ServerConfig.isConfigured) {
      _setStatus(AuthStatus.needsServer);
      return;
    }

    await _resumeStoredSession();
  }

  /// Re-validates a persisted token against the *current* server.
  ///
  /// Never trust a stored token on its own: it may have expired while the
  /// terminal sat idle, the user's permissions may have been revoked, or the
  /// terminal may now be pointed at a different server entirely — where that
  /// token means nothing.
  Future<void> _resumeStoredSession() async {
    if (!Session.isAuthenticated) {
      _setStatus(AuthStatus.loggedOut);
      return;
    }

    try {
      final user = await _repository.me();
      if (!user.canUsePos) {
        await _repository.logout();
        _error = _noPosAccessMessage(user);
        _setStatus(AuthStatus.loggedOut);
        return;
      }
      _user = user;
      _setStatus(AuthStatus.authenticated);
    } catch (_) {
      await Session.clear();
      _user = null;
      _setStatus(AuthStatus.loggedOut);
    }
  }

  Future<void> saveServer(String url) async {
    final changedServer = ServerConfig.savedUrl != ServerConfig.normalize(url);
    await ServerConfig.save(url);
    _error = null;

    // A token issued by the previous server is meaningless on a new one.
    if (changedServer && Session.isAuthenticated) {
      await Session.clear();
      _user = null;
      _setStatus(AuthStatus.loggedOut);
      return;
    }

    await _resumeStoredSession();
  }

  /// Sends the operator back to the setup screen to re-point the terminal.
  void requestServerChange() {
    _error = null;
    _setStatus(AuthStatus.needsServer);
  }

  /// Leaves the setup screen without changing anything.
  void cancelServerChange() {
    if (ServerConfig.isConfigured) {
      _setStatus(
        Session.isAuthenticated
            ? AuthStatus.authenticated
            : AuthStatus.loggedOut,
      );
    }
  }

  Future<bool> login(String email, String password) async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _repository.login(email, password);

      // Any user with POS permission may use this terminal; everyone else is
      // turned away even though their credentials were valid.
      if (!user.canUsePos) {
        await _repository.logout();
        _error = _noPosAccessMessage(user);
        return false;
      }

      _user = user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.isValidation
          ? (e.firstFieldError ?? 'Invalid email or password.')
          : e.message;
      return false;
    } catch (e) {
      _error = 'Login failed: $e';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _busy = true;
    notifyListeners();

    await _repository.logout();
    _user = null;
    _error = null;
    _busy = false;
    // The server URL is intentionally kept so it can be reviewed and edited
    // from the login screen.
    _setStatus(AuthStatus.loggedOut);
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  String _noPosAccessMessage(UserModel user) =>
      '${user.name} does not have POS access. '
      'This terminal requires the "view_pos" permission.';

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
