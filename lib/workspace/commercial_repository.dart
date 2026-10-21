import '../backend/rest/api_client.dart';
import '../backend/rest/retriable_command.dart';

const documentLabels = {
  'SALE_INVOICE': 'Счёт на оплату',
  'SALE_ACT': 'Акт оказанных услуг',
  'PURCHASE_ACT': 'Поступление услуг',
};
const documentStatuses = {
  'DRAFT': 'Черновик',
  'ISSUED': 'Выставлен',
  'POSTED': 'Проведён',
  'CANCELLED': 'Отменён',
};
String moneyText(num minor, String currency) {
  final value = minor.toInt(), absolute = value.abs();
  final whole = (absolute ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
  return '${value < 0 ? '-' : ''}$whole,${(absolute % 100).toString().padLeft(2, '0')} ${currency == 'KZT' ? '₸' : currency}';
}

int parseMoney(String input) {
  final normalized = input
      .trim()
      .replaceAll(RegExp(r'\s'), '')
      .replaceAll(',', '.');
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(normalized)) {
    throw const FormatException('Введите сумму с точностью до двух знаков');
  }
  final parts = normalized.split('.'),
      value =
          int.parse(parts[0]) * 100 +
          int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  if (value > 1000000000000) {
    throw const FormatException('Сумма слишком велика');
  }
  return value;
}

class CommercialRepository {
  CommercialRepository(this.api, this.companyId);
  final BackendClient api;
  final String companyId;
  List<String> path([String? id, String? action]) => [
    'v1',
    'companies',
    companyId,
    'commercial-documents',
    if (id != null) id,
    if (action != null) action,
  ];
  Future<Map<String, dynamic>> list({
    required String direction,
    String? kind,
    String? status,
    String? projectId,
    String? after,
    String? query,
    String? counterpartyId,
    String? scope,
    String? from,
    String? to,
  }) async => jsonObject(
    await api.request(
      'GET',
      path(),
      query: {
        'direction': direction,
        if (counterpartyId != null) 'counterpartyId': counterpartyId,
        if (scope != null) 'scope': scope,
        'limit': '50',
        if (kind != null) 'kind': kind,
        if (status != null) 'status': status,
        if (projectId != null) 'projectId': projectId,
        if (after != null) 'after': after,
        if (query != null && query.isNotEmpty) 'q': query,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    ),
  );
  Future<Map<String, dynamic>> get(String id) async =>
      jsonObject(await api.request('GET', path(id)));
  Future<Map<String, dynamic>> preview(Map<String, dynamic> body) async =>
      jsonObject(await api.request('POST', path('preview'), body: body));
  RetriableCommand save(Map<String, dynamic> body, {String? id}) =>
      RetriableCommand(id == null ? 'POST' : 'PUT', path(id), body);
  RetriableCommand action(
    String id,
    String action, [
    Map<String, dynamic> body = const {},
  ]) => RetriableCommand('POST', path(id, action), body);
  Future<List<Map<String, dynamic>>> related(String id, String type) async {
    final result = jsonObject(await api.request('GET', path(id, type)));
    return (result['items'] as List).map(jsonObject).toList();
  }
}
