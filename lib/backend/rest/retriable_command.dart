import 'dart:convert';
import 'api_client.dart';

/// One intent keeps one key and one immutable payload until its outcome is known.
class RetriableCommand {
  RetriableCommand(this.method, List<String> path, Map<String, dynamic> body)
      : path = List.unmodifiable(path),
        _body = jsonEncode(body),
        operation = OperationKey();
  final String method;
  final List<String> path;
  final String _body;
  final OperationKey operation;
  Future<Map<String, dynamic>> execute(BackendClient api) async =>
      jsonObject(await api.request(method, path,
          body: jsonDecode(_body) as Map<String, dynamic>,
          operation: operation));
  static bool uncertain(BackendException error) =>
      error.code == 'network_error' ||
      error.code == 'invalid_server_response' ||
      (error.status ?? 0) >= 500;
}
