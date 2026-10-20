import '../backend/rest/api_client.dart';

const payrollStatuses = {
  'DRAFT': 'Черновик',
  'POSTED': 'Проведён',
  'CANCELLED': 'Зарплата отменена',
};
const payrollChargeLabels = {
  'OPV': 'ОПВ работника',
  'VOSMS': 'ВОСМС работника',
  'IPN': 'ИПН работника',
  'SO': 'Социальные отчисления',
  'OOSMS': 'ОСМС работодателя',
  'OPVR': 'ОПВР работодателя',
  'SN': 'Социальный налог',
};
String payrollMoneyInput(num amount) =>
    '${amount.toInt() ~/ 100}.${(amount.toInt() % 100).toString().padLeft(2, '0')}';

class PayrollRepository {
  PayrollRepository(this.api, this.companyId);
  final BackendClient api;
  final String companyId;
  List<String> path([String? id, String? action]) => [
    'v1',
    'companies',
    companyId,
    'payroll',
    if (id != null) id,
    if (action != null) action,
  ];
  Future<Map<String, dynamic>> get(String id) async =>
      jsonObject(await api.request('GET', path(id)));
  Future<List<Map<String, dynamic>>> employees() async {
    final rows = <Map<String, dynamic>>[];
    String? after;
    do {
      final data = jsonObject(
        await api.request(
          'GET',
          ['v1', 'companies', companyId, 'employees'],
          query: {'limit': '200', if (after != null) 'after': after},
        ),
      );
      final next = (data['items'] as List).map(jsonObject).toList();
      rows.addAll(next);
      after = next.length < 200 ? null : next.last['id'] as String;
    } while (after != null);
    return rows;
  }
}
