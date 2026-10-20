import '../backend/rest/api_client.dart';

class ProjectRepository {
  ProjectRepository(this.api, this.companyId);
  final BackendClient api;
  final String companyId;
  List<String> path(String suffix) => ['v1', 'companies', companyId, suffix];
  Future<List<Map<String, dynamic>>> list() async {
    final result = jsonObject(await api.request('GET', path('projects')));
    return (result['items'] as List).map(jsonObject).toList();
  }

  Future<void> create(String name, OperationKey operation) async {
    await api.request('POST', path('projects'),
        body: {'name': name}, operation: operation);
  }

  Future<void> update(Map<String, dynamic> project, String name, bool archived,
      OperationKey operation) async {
    await api.request('PUT', [...path('projects'), project['id'] as String],
        body: {
          'name': name,
          'archived': archived,
          'version': project['version']
        },
        operation: operation);
  }

  Future<Map<String, dynamic>> report(
          {String? projectId, String? from, String? to}) async =>
      jsonObject(await api.request('GET', [
        ...path('reports'),
        'projects'
      ], query: {
        if (projectId != null) 'projectId': projectId,
        if (from != null) 'from': from,
        if (to != null) 'to': to
      }));
}
