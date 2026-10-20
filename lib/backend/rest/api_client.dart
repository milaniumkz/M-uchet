import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// The independent API transport. Sessions stay in memory; this class never
/// writes bearer credentials to browser localStorage or application preferences.
class BackendException implements Exception {
  const BackendException(this.code, {this.status, this.requestId});
  final String code;
  final int? status;
  final String? requestId;

  String get message {
    const messages = {
      'insufficient_funds': 'Недостаточно средств на денежном счёте.',
      'insufficient_inventory': 'Недостаточно свободного остатка товара.',
      'version_conflict':
          'Данные изменились. Обновите их и повторите действие.',
      'project_not_found': 'Проект не найден или недоступен.',
      'invalid_identifier': 'БИН / ИИН должен содержать 12 цифр.',
      'no_company': 'У аккаунта пока нет доступной фирмы.',
    };
    if (messages.containsKey(code)) return messages[code]!;
    return switch (status) {
      401 => 'Сессия завершена. Войдите снова.',
      403 => 'Недостаточно прав для этого действия.',
      404 => 'Объект не найден или недоступен.',
      409 => 'Данные изменились. Обновите их и повторите действие.',
      429 => 'Слишком много запросов. Повторите немного позже.',
      _ => code == 'network_error'
          ? 'Не удалось связаться с сервером. Проверьте соединение.'
          : 'Сервер не смог выполнить действие.',
    };
  }

  @override
  String toString() => 'BackendException($code, status: $status)';
}

Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const BackendException('invalid_server_response');
  }
  return value;
}

/// Create once per user action and retain for every retry of that action.
class OperationKey {
  OperationKey()
      : value = base64UrlEncode(
          List<int>.generate(32, (_) => Random.secure().nextInt(256)),
        ).replaceAll('=', '');
  final String value;
}

class BackendClient {
  BackendClient({
    required this.origin,
    http.Client? transport,
    this.timeout = const Duration(seconds: 15),
  }) : _transport = transport ?? http.Client() {
    final loopback = {'localhost', '127.0.0.1', '::1'}.contains(origin.host);
    if ((origin.scheme != 'https' && !(origin.scheme == 'http' && loopback)) ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw ArgumentError(
          'API origin must be HTTPS (HTTP loopback for development).');
    }
  }

  final Uri origin;
  final Duration timeout;
  final http.Client _transport;
  String? _token;
  bool get authenticated => _token != null;

  void acceptSession(String token) {
    if (!RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(token)) {
      throw const BackendException('invalid_session_response');
    }
    _token = token;
  }

  void clearSession() => _token = null;
  void close() {
    clearSession();
    _transport.close();
  }

  Future<Object?> request(
    String method,
    List<String> path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    OperationKey? operation,
    bool authenticated = true,
  }) async {
    if (authenticated && _token == null) {
      throw const BackendException('authentication_required', status: 401);
    }
    final uri = origin.replace(pathSegments: path, queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (authenticated) request.headers['Authorization'] = 'Bearer $_token';
    if (operation != null) request.headers['Idempotency-Key'] = operation.value;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await http.Response.fromStream(
        await _transport.send(request).timeout(timeout),
      ).timeout(timeout);
      Object? result;
      try {
        result = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode == 401) clearSession();
        throw BackendException('invalid_server_response',
            status: response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 && authenticated) clearSession();
        final error =
            result is Map<String, dynamic> ? result : const <String, dynamic>{};
        throw BackendException(
          error['error'] is String
              ? error['error'] as String
              : 'request_failed',
          status: response.statusCode,
          requestId: error['requestId'] is String
              ? error['requestId'] as String
              : null,
        );
      }
      return result;
    } on TimeoutException {
      throw const BackendException('network_error');
    } on http.ClientException {
      throw const BackendException('network_error');
    }
  }
}
