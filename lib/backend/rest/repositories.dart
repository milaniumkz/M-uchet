import 'api_client.dart';

class CompanyDto {
  const CompanyDto(
    this.id,
    this.name,
    this.currency, {
    this.role,
    this.permissions = const [],
  });
  factory CompanyDto.fromJson(Object? input) {
    final data = jsonObject(input);
    if (data['id'] is! String ||
        data['name'] is! String ||
        data['currency'] is! String ||
        (data['role'] != null && !['owner', 'member'].contains(data['role'])) ||
        (data['permissions'] != null &&
            (data['permissions'] is! List ||
                (data['permissions'] as List).any((p) => p is! String)))) {
      throw const BackendException('invalid_company_response');
    }
    return CompanyDto(
      data['id'] as String,
      data['name'] as String,
      data['currency'] as String,
      role: data['role'] as String?,
      permissions: List.unmodifiable(
        (data['permissions'] as List? ?? []).cast<String>(),
      ),
    );
  }
  final String id;
  final String name;
  final String currency;
  final String? role;
  final List<String> permissions;
  bool allows(String permission) =>
      role == null || role == 'owner' || permissions.contains(permission);
}

class ResourceDto {
  ResourceDto(this.id, Map<String, dynamic> data, this.version)
    : data = Map.unmodifiable(data);
  factory ResourceDto.fromJson(Object? input) {
    final data = jsonObject(input);
    if (data['id'] is! String || data['version'] is! int) {
      throw const BackendException('invalid_resource_response');
    }
    return ResourceDto(
      data['id'] as String,
      jsonObject(data['data']),
      data['version'] as int,
    );
  }
  final String id;
  final Map<String, dynamic> data;
  final int version;
}

class IdentityRepository {
  IdentityRepository(this.api);
  final BackendClient api;

  Future<Map<String, dynamic>> login(String login, String password) async {
    api.clearSession();
    final result = jsonObject(
      await api.request(
        'POST',
        ['v1', 'auth', 'login'],
        authenticated: false,
        body: {'login': login, 'password': password},
      ),
    );
    final user = jsonObject(result['user']);
    if (result['token'] is! String || user['id'] is! String) {
      throw const BackendException('invalid_session_response');
    }
    api.acceptSession(result['token'] as String);
    return user;
  }

  Future<void> logout() async {
    try {
      if (api.authenticated) {
        await api.request('POST', ['v1', 'auth', 'logout']);
      }
    } finally {
      api.clearSession();
    }
  }

  Future<List<CompanyDto>> companies() async {
    final result = await api.request('GET', ['v1', 'companies']);
    if (result is! List) {
      throw const BackendException('invalid_companies_response');
    }
    return result.map(CompanyDto.fromJson).toList(growable: false);
  }
}

class CatalogRepository {
  CatalogRepository(this.api, this.companyId);
  final BackendClient api;
  final String companyId;
  List<String> _path(String kind, [String? id]) => [
    'v1',
    'companies',
    companyId,
    'resources',
    kind,
    if (id != null) id,
  ];

  Future<List<ResourceDto>> list(String kind, {String? after}) async {
    final result = jsonObject(
      await api.request(
        'GET',
        _path(kind),
        query: {'limit': '50', if (after != null) 'after': after},
      ),
    );
    if (result['items'] is! List) {
      throw const BackendException('invalid_resource_response');
    }
    return (result['items'] as List)
        .map(ResourceDto.fromJson)
        .toList(growable: false);
  }

  Future<ResourceDto> create(String kind, Map<String, dynamic> data) async =>
      ResourceDto.fromJson(
        await api.request('POST', _path(kind), body: {'data': data}),
      );

  Future<ResourceDto> save(
    String kind,
    ResourceDto previous,
    Map<String, dynamic> data,
  ) async => ResourceDto.fromJson(
    await api.request(
      'PUT',
      _path(kind, previous.id),
      body: {'data': data, 'version': previous.version},
    ),
  );
}

class DealRepository {
  DealRepository(this.api, this.companyId);
  final BackendClient api;
  final String companyId;

  Future<Map<String, dynamic>> edit(
    String id,
    Map<String, dynamic> order, {
    required OperationKey operation,
  }) async => jsonObject(
    await api.request(
      'PUT',
      ['v1', 'companies', companyId, 'orders', id],
      body: order,
      operation: operation,
    ),
  );
}

/// Read every selectable account, retaining the company business date from the
/// first page. Financial mutations still recheck the current account on server.
Future<Map<String, dynamic>> loadCompanyWallets(
  BackendClient api,
  String companyId,
) async {
  final items = <Map<String, dynamic>>[], seen = <String>{};
  String? after, date;
  do {
    final data = jsonObject(
      await api.request(
        'GET',
        ['v1', 'companies', companyId, 'wallets'],
        query: {'limit': '200', if (after != null) 'after': after},
      ),
    );
    date ??= data['businessDate'] as String?;
    if (data['items'] is! List) {
      throw const BackendException('invalid_server_response');
    }
    final rows = (data['items'] as List).map(jsonObject).toList();
    for (final row in rows) {
      if (row['id'] is! String || !seen.add(row['id'] as String)) {
        throw const BackendException('invalid_server_response');
      }
    }
    items.addAll(rows);
    after = rows.length < 200 ? null : rows.last['id'] as String;
  } while (after != null);
  return {'items': items, if (date != null) 'businessDate': date};
}
