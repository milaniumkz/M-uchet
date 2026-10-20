import 'package:flutter/material.dart';
import '../backend/rest/repositories.dart';

class CompanyAccess extends InheritedWidget {
  const CompanyAccess({super.key, required this.company, required super.child});
  final CompanyDto? company;
  @override
  bool updateShouldNotify(CompanyAccess oldWidget) =>
      company != oldWidget.company;
}

bool hasCompanyPermission(BuildContext context, String permission) =>
    context
        .dependOnInheritedWidgetOfExactType<CompanyAccess>()
        ?.company
        ?.allows(permission) ??
    true;

Iterable<Map<String, dynamic>> projectChoices(
  List<Map<String, dynamic>> projects,
  String? current,
) sync* {
  yield* projects;
  if (current != null && !projects.any((p) => p['id'] == current)) {
    yield {'id': current, 'name': 'Сохранённый проект'};
  }
}
