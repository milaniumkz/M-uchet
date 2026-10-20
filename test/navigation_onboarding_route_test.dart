import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/company/onboarding/company_onboarding_widget.dart';

void main() {
  test('company onboarding route opens onboarding screen', () {
    expect(CompanyOnboardingWidget.routePath, '/companyOnboarding');

    final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    expect(
      navSource,
      contains(
        'builder: (context, params) => const CompanyOnboardingWidget()',
      ),
    );
    expect(
      navSource,
      isNot(contains(
        'name: CompanyOnboardingWidget.routeName,\n'
        '          path: CompanyOnboardingWidget.routePath,\n'
        '          builder: (context, params) => HomeWidget()',
      )),
    );
  });

  test('router preserves direct browser links', () {
    final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    expect(navSource, contains('initialLocation: _initialLocationFromUriBase(initialUri)'));
    expect(navSource, contains('overridePlatformDefaultLocation: true'));
    expect(navSource, contains('currentBrowserUri()'));
    expect(navSource, isNot(contains("initialLocation: '/'")));
  });

  test('router does not redirect protected direct links before user doc loads', () {
    final navSource = File('lib/flutter_flow/nav/nav.dart').readAsStringSync();
    expect(
      navSource,
      isNot(contains(
        "if (_isAdminPath(path) || permissionKeys.isNotEmpty) {\n"
        "                return HomeWidget.routePath;",
      )),
    );
  });
}
