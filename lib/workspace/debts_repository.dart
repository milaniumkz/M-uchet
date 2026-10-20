import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';
import '../backend/rest/retriable_command.dart';

const debtTypes = {'AR': 'Нам должны', 'AP': 'Мы должны'};
const debtStatuses = {
  'ACTIVE': 'Начальный остаток действует',
  'CANCELLED': 'Начальный остаток отменён',
};

class DebtsRepository {
  DebtsRepository(this.api, this.companyId);
  final BackendClient api;
  final String companyId;
  List<String> path([List<String> tail = const []]) => [
    'v1',
    'companies',
    companyId,
    'debts',
    ...tail,
  ];
  Future<Map<String, dynamic>> get(String id) async =>
      jsonObject(await api.request('GET', path([id])));
  Future<Map<String, dynamic>> list(Map<String, String> query) async =>
      jsonObject(await api.request('GET', path(), query: query));
  Future<List<Map<String, dynamic>>> history(String id) async =>
      (jsonObject(await api.request('GET', path([id, 'history'])))['items']
              as List)
          .map(jsonObject)
          .toList();
  RetriableCommand command(
    String method,
    List<String> tail,
    Map<String, dynamic> body,
  ) => RetriableCommand(method, path(tail), body);
  Future<List<ResourceDto>> parties(String kind) async {
    final rows = <ResourceDto>[], ids = <String>{};
    String? cursor;
    do {
      final data = jsonObject(
        await api.request(
          'GET',
          ['v1', 'companies', companyId, 'resources', kind],
          query: {'limit': '200', if (cursor != null) 'after': cursor},
        ),
      );
      final page = (data['items'] as List).map(ResourceDto.fromJson).toList();
      for (final item in page) {
        if (!ids.add(item.id)) {
          throw const BackendException('invalid_server_response');
        }
        rows.add(item);
      }
      cursor = page.length < 200 ? null : page.last.id;
    } while (cursor != null);
    return rows;
  }
}
