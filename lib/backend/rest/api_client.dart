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
      'company_settings_required': 'Сначала заполните параметры фирмы.',
      'issuer_identifier_required':
          'Заполните БИН / ИИН фирмы в параметрах и обновите реквизиты документа.',
      'vat_registration_required':
          'Для начисления НДС нужна указанная регистрация фирмы по НДС.',
      'vat_reason_required':
          'Укажите основание документа без НДС или выберите ставку.',
      'vat_rule_version_unavailable':
          'Для выбранной даты ставка ещё не настроена.',
      'unsupported_vat_rate': 'Выберите поддерживаемую ставку НДС.',
      'invalid_pending_input_vat':
          'Проверьте регистрацию по НДС и сумму входящего НДС.',
      'counterparty_not_found': 'Контрагент не найден или недоступен.',
      'overpayment': 'Сумма превышает остаток к оплате.',
      'invalid_quantity':
          'Количество должно быть положительным целым числом базовых единиц.',
      'duplicate_order_line':
          'Объедините одинаковый товар с одного склада в одну строку.',
      'invalid_order_state':
          'Состояние продажи изменилось. Обновите данные и повторите действие.',
      'incompatible_ledger_scope':
          'Выберите денежный счёт с тем же видом учёта, что и документ. Оплаты на действующих счетах сохраняют свой вид учёта.',
      'order_payment_source_missing':
          'Для этой прежней оплаты нужна сверка исходной бухгалтерской записи.',
      'document_not_posted': 'Сначала выставьте счёт или проведите акт.',
      'invalid_service_quantity':
          'Укажите положительное количество, до трёх знаков после запятой.',
      'invalid_total': 'Укажите стоимость услуг: итог должен быть больше нуля.',
      'invalid_bank_iban':
          'Проверьте IBAN: нужен казахстанский счёт с корректной контрольной суммой.',
      'invalid_bank_bic': 'Проверьте БИК банка.',
      'company_creation_forbidden':
          'Создание фирм доступно владельцу системы. Попросите доступ к существующей фирме.',
      'invalid_invitation':
          'Приглашение недействительно, отозвано или срок его действия истёк.',
      'invitation_access_revoked': 'Доступ по этому приглашению уже отозван.',
      'invalid_credentials': 'Неверный логин или пароль.',
      'current_password_incorrect': 'Текущий пароль указан неверно.',
      'bank_existing_entry_mismatch':
          'Выбранная операция изменилась: счёт, дата и сумма должны совпадать с выпиской.',
      'bank_entry_already_matched':
          'Это движение уже сопоставлено с другой строкой выписки.',
      'asset_policy_required':
          'Укажите линейный метод и подтвердите параметры учётной политики.',
      'asset_number_conflict':
          'Этот инвентарный номер уже используется в фирме.',
      'residual_exceeds_cost':
          'Остаточная стоимость не должна превышать первоначальную.',
      'invalid_depreciation_start':
          'Проверьте месяц начала и начисления амортизации.',
      'employee_identifier_conflict': 'Сотрудник с таким ИИН уже есть в фирме.',
      'invalid_employee_dates': 'Проверьте даты рождения, приёма и увольнения.',
      'invalid_employee_profile':
          'Проверьте статус, резидентство и код гражданства.',
      'invalid_recovery_token':
          'Код восстановления недействителен, уже использован или истёк. Получите новый код у администратора.',
      'password_length_12_to_256':
          'Пароль должен содержать от 12 до 256 символов.',
      'invalid_bank_csv':
          'Не удалось разобрать CSV. Проверьте кодировку, разделитель и кавычки.',
      'invalid_bank_csv_columns':
          'Количество колонок в строках CSV не совпадает с заголовком.',
      'invalid_bank_csv_headers':
          'Названия колонок CSV должны быть заполнены и уникальны.',
      'invalid_bank_mapping':
          'Проверьте названия колонок даты, ID, списания, поступления и назначения.',
      'bank_csv_limit':
          'Выписка должна содержать до 500 операций и до 50 колонок.',
      'invalid_bank_amount':
          'Проверьте суммы: нужны положительные значения с точностью до 0,01.',
      'bank_row_requires_one_direction':
          'В строке должно быть заполнено либо списание, либо поступление.',
      'bank_reference_conflict':
          'Этот ID банковской операции уже есть с другими данными. Проверьте выписку и выбранный счёт.',
      'bank_direction_mismatch':
          'Вид операции не соответствует направлению платежа.',
      'bank_edit_source_required':
          'Откройте проведённую оплату или денежную операцию для исправления.',
      'bank_row_not_ready': 'Сначала сопоставьте операцию.',
      'file_too_large': 'Размер файла не должен превышать 10 МБ.',
      'source_document_edit_required':
          'Откройте документ-основание: его изменение пересчитает все связанные движения.',
    };
    if (messages.containsKey(code)) {
      return messages[code]!;
    }
    return switch (status) {
      401 => 'Сессия завершена. Войдите снова.',
      403 => 'Недостаточно прав для этого действия.',
      404 => 'Объект не найден или недоступен.',
      409 => 'Данные изменились. Обновите их и повторите действие.',
      429 => 'Слишком много запросов. Повторите немного позже.',
      _ =>
        code == 'network_error'
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
        'API origin must be HTTPS (HTTP loopback for development).',
      );
    }
  }

  final Uri origin;
  final Duration timeout;
  final http.Client _transport;
  String? _token;
  void Function()? onUnauthorized;
  void _expireSession() {
    final hadSession = _token != null;
    clearSession();
    if (hadSession) {
      onUnauthorized?.call();
    }
  }

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

  Future<Map<String, dynamic>> uploadFile(
    String companyId,
    List<int> bytes,
    String filename,
  ) async {
    if (_token == null) {
      throw const BackendException('authentication_required', status: 401);
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw const BackendException('file_too_large', status: 413);
    }
    final request =
        http.MultipartRequest(
            'POST',
            origin.replace(
              pathSegments: ['v1', 'companies', companyId, 'files'],
            ),
          )
          ..headers['Authorization'] = 'Bearer $_token'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    try {
      final response = await http.Response.fromStream(
        await _transport.send(request).timeout(timeout),
      ).timeout(timeout);
      final result = jsonDecode(response.body);
      if (response.statusCode == 401) {
        _expireSession();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendException(
          result is Map<String, dynamic>
              ? result['error'] as String? ?? 'request_failed'
              : 'request_failed',
          status: response.statusCode,
        );
      }
      return jsonObject(result);
    } on TimeoutException {
      throw const BackendException('network_error');
    } on http.ClientException {
      throw const BackendException('network_error');
    } on FormatException {
      throw const BackendException('invalid_server_response');
    }
  }

  Future<List<int>> downloadFile(String companyId, String id) async {
    if (_token == null) {
      throw const BackendException('authentication_required', status: 401);
    }
    try {
      final response = await _transport
          .get(
            origin.replace(
              pathSegments: ['v1', 'companies', companyId, 'files', id],
            ),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(timeout);
      if (response.statusCode == 401) {
        _expireSession();
      }
      if (response.statusCode != 200) {
        throw BackendException(
          'file_download_failed',
          status: response.statusCode,
        );
      }
      return response.bodyBytes;
    } on TimeoutException {
      throw const BackendException('network_error');
    } on http.ClientException {
      throw const BackendException('network_error');
    }
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
    if (authenticated) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    if (operation != null) {
      request.headers['Idempotency-Key'] = operation.value;
    }
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
        if (response.statusCode == 401) {
          _expireSession();
        }
        throw BackendException(
          'invalid_server_response',
          status: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 && authenticated) {
          _expireSession();
        }
        final error = result is Map<String, dynamic>
            ? result
            : const <String, dynamic>{};
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
