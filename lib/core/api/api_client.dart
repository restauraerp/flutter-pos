import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'session.dart';

/// A failed API call, carrying enough detail for the UI to show something
/// useful rather than a generic error.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;

  /// Laravel-style field errors: `{"email": ["The ... is invalid."]}`.
  final Map<String, List<String>>? errors;

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;

  /// The first field-level message, when the server sent one.
  String? get firstFieldError {
    final e = errors;
    if (e == null || e.isEmpty) return null;
    for (final list in e.values) {
      if (list.isNotEmpty) return list.first;
    }
    return null;
  }

  @override
  String toString() => message;
}

/// Thin wrapper over `http` mirroring the Next.js `fetchApi` helper: bearer
/// auth, JSON in/out, and unwrapping of the `{data: ...}` envelope.
class ApiClient {
  ApiClient({http.Client? client, this.timeout = const Duration(seconds: 20)})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Invoked when the server rejects our token, so the app can log out.
  static void Function()? onUnauthorized;

  Uri _uri(String endpoint, [Map<String, dynamic>? query]) {
    final base = AppConfig.baseUrl;
    final uri = Uri.parse('$base$endpoint');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        for (final entry in query.entries) entry.key: '${entry.value}',
      },
    );
  }

  Map<String, String> _headers() {
    final token = Session.token;
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? query}) {
    return _send(() => _client.get(_uri(endpoint, query), headers: _headers()));
  }

  Future<dynamic> post(String endpoint, {Object? body}) {
    return _send(
      () => _client.post(
        _uri(endpoint),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(String endpoint, {Object? body}) {
    return _send(
      () => _client.put(
        _uri(endpoint),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String endpoint) {
    return _send(() => _client.delete(_uri(endpoint), headers: _headers()));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'The server took too long to respond. Check the connection and try again.',
      );
    } catch (e) {
      throw ApiException(
        'Could not reach the server at ${AppConfig.baseUrl}.\n$e',
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      if (response.statusCode >= 400) {
        throw ApiException(
          'Server returned ${response.statusCode}.',
          statusCode: response.statusCode,
        );
      }
      throw ApiException('Server returned a response we could not read.');
    }

    if (response.statusCode >= 400) {
      throw _errorFrom(response.statusCode, decoded);
    }

    return decoded;
  }

  ApiException _errorFrom(int status, dynamic decoded) {
    String message = 'Request failed ($status).';
    Map<String, List<String>>? errors;

    if (decoded is Map) {
      if (decoded['message'] is String &&
          (decoded['message'] as String).isNotEmpty) {
        message = decoded['message'] as String;
      }
      final rawErrors = decoded['errors'];
      if (rawErrors is Map) {
        errors = rawErrors.map(
          (key, value) => MapEntry(
            '$key',
            value is List
                ? value.map((v) => '$v').toList()
                : <String>['$value'],
          ),
        );
      }
    }

    if (status == 401) {
      onUnauthorized?.call();
      message = 'Your session has expired. Please log in again.';
    }

    return ApiException(message, statusCode: status, errors: errors);
  }

  /// Unwraps `{"data": [...]}` / `{"data": {...}}` envelopes, matching the
  /// `res.data || res` pattern the web frontend uses everywhere.
  static dynamic unwrap(dynamic response) {
    if (response is Map && response.containsKey('data')) return response['data'];
    return response;
  }

  /// Unwraps to a list, tolerating both plain arrays and paginated envelopes.
  static List<Map<String, dynamic>> unwrapList(dynamic response) {
    final data = unwrap(response);
    if (data is List) {
      return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
    }
    return const [];
  }

  /// Unwraps to a single object.
  static Map<String, dynamic> unwrapMap(dynamic response) {
    final data = unwrap(response);
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
