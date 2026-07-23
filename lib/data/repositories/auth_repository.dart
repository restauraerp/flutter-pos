import '../../core/api/api_client.dart';
import '../../core/api/session.dart';
import '../models/models.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Logs in and returns the fully-loaded user.
  ///
  /// `/auth/login` returns the bare user record without permissions, so we
  /// follow up with `/auth/me` — that endpoint appends `all_permissions`, which
  /// is what the POS gate needs.
  Future<UserModel> login(String email, String password) async {
    final response = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );

    final data = ApiClient.unwrapMap(response);
    final token = asStringOrNull(data['token']);
    if (token == null) {
      throw ApiException('The server did not return a login token.');
    }

    await Session.save(token);
    return me();
  }

  Future<UserModel> me() async {
    final response = await _api.get('/auth/me');
    return UserModel.fromJson(ApiClient.unwrapMap(response));
  }

  /// Clears the local session. The server call is best-effort: if the token is
  /// already invalid or the terminal is offline, the user still gets logged out
  /// locally, which is what they asked for.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {
      // Ignored on purpose.
    }
    await Session.clear();
  }
}
