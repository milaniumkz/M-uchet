import '../backend/rest/api_client.dart';
import '../backend/rest/repositories.dart';

const goodsStatuses = {
  'NEW': 'Черновик',
  'RESERVED': 'Зарезервирован',
  'SHIPPED': 'Отгружен',
  'CLOSED': 'Оплачен',
  'CANCELLED': 'Отменён',
};

class GoodsRepository {
  GoodsRepository(this.api, this.companyId);
  final BackendClient api;
  final String companyId;
  List<String> path([String? id, String? action]) => [
    'v1',
    'companies',
    companyId,
    'orders',
    if (id != null) id,
    if (action != null) action,
  ];
  Future<Map<String, dynamic>> get(String id) async =>
      jsonObject(await api.request('GET', path(id)));
  Future<List<ResourceDto>> resources(String kind) async {
    final items = <ResourceDto>[];
    String? after;
    do {
      final data = jsonObject(
        await api.request(
          'GET',
          ['v1', 'companies', companyId, 'resources', kind],
          query: {'limit': '200', if (after != null) 'after': after},
        ),
      );
      final rows = (data['items'] as List).map(ResourceDto.fromJson).toList();
      items.addAll(rows);
      after = rows.length < 200 ? null : rows.last.id;
    } while (after != null);
    return items;
  }
}

const goodsEvents = {
  'order.create': 'Создан черновик',
  'order.reserve': 'Товары зарезервированы',
  'order.ship': 'Товары отгружены',
  'order.cancel': 'Черновик отменён, резерв снят',
  'order.restore': 'Черновик восстановлен',
  'order.edit': 'Продажа исправлена',
  'order.payment': 'Оплата внесена',
  'order.payment.edit': 'Оплата исправлена',
  'order.payment.void': 'Запись оплаты отменена',
  'order.payment.restore': 'Запись оплаты восстановлена',
};
