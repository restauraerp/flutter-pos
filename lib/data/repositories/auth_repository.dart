import '../../core/api/api_client.dart';
import '../../core/api/session.dart';
import '../../core/config/tenant_config.dart';
import '../models/models.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Logs in and returns the fully-loaded user.
  ///
  /// [tenant] is the restaurant code (slug or numeric id). Emails are unique per
  /// restaurant, not globally, so it is required to look the user up — it is
  /// saved before the request so the `X-Tenant-ID` header carries it on this
  /// unauthenticated call, and also sent in the body as a fallback.
  ///
  /// `/auth/login` returns the bare user record without permissions, so we
  /// follow up with `/auth/me` — that endpoint appends `all_permissions`, which
  /// is what the POS gate needs.
  Future<UserModel> login(String email, String password, String tenant) async {
    await TenantConfig.save(tenant);

    final response = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password, 'tenant': tenant},
    );

    final data = ApiClient.unwrapMap(response);
    final token = asStringOrNull(data['token']);
    if (token == null) {
      throw ApiException('The server did not return a login token.');
    }

    // Persist the tenant the API actually resolved (it may differ in case, or
    // have been given as a numeric id) so every later request agrees with the
    // token — a mismatched X-Tenant-ID is rejected with a 403.
    final resolved = data['tenant'];
    if (resolved is Map) {
      final slug = asStringOrNull(resolved['slug']);
      if (slug != null) await TenantConfig.save(slug);
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
