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
