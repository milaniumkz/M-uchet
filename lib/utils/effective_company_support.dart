import '/utils/user_access_context.dart';

const int firestoreWhereInLimit = 10;

String resolveEffectiveCompanyId({
  required Map<String, dynamic>? userData,
  required String fallbackUserId,
}) {
  final trimmedFallback = fallbackUserId.trim();
  final context = UserAccessContext.fromData(userData);
  final selected = context.selectedCompanyId.trim();
  if (selected.isNotEmpty) {
    return selected;
  }

  final allowed = context.effectiveAllowedCompanyIds.toList()..sort();
  if (allowed.isNotEmpty) {
    return allowed.first;
  }

  final companyIds = context.companyIds.toList()..sort();
  if (companyIds.isNotEmpty) {
    return companyIds.first;
  }

  return trimmedFallback;
}

List<String> resolveQueryCompanyIds({
  required Map<String, dynamic>? userData,
  required String fallbackUserId,
}) {
  final context = UserAccessContext.fromData(userData);
  final ids = context
      .queryCompanyIds()
      .where((e) => e.trim().isNotEmpty)
      .toList()
    ..sort();
  if (ids.isNotEmpty) {
    return ids;
  }
  final fallback = fallbackUserId.trim();
  return fallback.isEmpty ? const <String>[] : <String>[fallback];
}

List<List<String>> splitCompanyIdsForWhereIn(
  List<String> ids, {
  int chunkSize = firestoreWhereInLimit,
}) {
  final normalized = ids
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  if (normalized.isEmpty) {
    return const <List<String>>[];
  }
  final chunks = <List<String>>[];
  for (var index = 0; index < normalized.length; index += chunkSize) {
    final end = (index + chunkSize < normalized.length)
        ? index + chunkSize
        : normalized.length;
    chunks.add(normalized.sublist(index, end));
  }
  return chunks;
}
