String firstCompanyAdminText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

bool isValidAdminCompanyId(String value, {String? allCompaniesValue}) {
  final id = value.trim();
  return id.isNotEmpty && !id.startsWith('+') && id != allCompaniesValue;
}

String companyAdminIdFromData(
  String docId,
  Map<String, dynamic> data, {
  String? allCompaniesValue,
  bool allowDocId = true,
}) {
  for (final key in const [
    'idCompany',
    'companyId',
    'company_id',
    'id_company',
    'id',
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (isValidAdminCompanyId(value, allCompaniesValue: allCompaniesValue)) {
      return value;
    }
  }
  final id = docId.trim();
  if (allowDocId &&
      isValidAdminCompanyId(id, allCompaniesValue: allCompaniesValue)) {
    return id;
  }
  return '';
}

bool _isCompanyNamePlaceholder(String value) {
  return value.trim().toLowerCase() == 'компания';
}

String companyAdminDisplayName(Map<String, dynamic> data) {
  for (final key in const [
    'nameCompany',
    'name_Company',
    'company_name',
    'name',
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && !_isCompanyNamePlaceholder(value)) return value;
  }
  final name = (data['name'] ?? '').toString().trim();
  return name.isEmpty ? 'Без названия' : name;
}
