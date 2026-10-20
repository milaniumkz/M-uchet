import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

class TokenCall {
  static Future<ApiCallResponse> call({
    String? phone = '',
    String? password = '',
    String? mode = 'login',
    String? role = '',
    String? companyId,
    String? displayName,
    String? roleId,
    String? roleName,
    List<String>? rolePermissions,
    List<String>? roleAllowedCompanyIds,
    String? position,
    String? department,
    bool? forcePasswordChange,
  }) async {
    throw StateError(
      'M-uchet: authentication backend is not configured. '
      'Implement the new API contract before enabling sign-in.',
    );
  }
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String? escapeStringForJson(String? input) {
  if (input == null) {
    return null;
  }
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}
