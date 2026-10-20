import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_access_context.dart';

class OnboardingStepDefinition {
  const OnboardingStepDefinition({
    required this.key,
    required this.path,
    required this.label,
  });

  final String key;
  final String path;
  final String label;
}

class OnboardingProgressState {
  const OnboardingProgressState({
    required this.stepState,
    required this.completed,
    required this.currentStage,
    required this.totalStages,
    required this.nextStep,
    required this.companyId,
  });

  final Map<String, bool> stepState;
  final bool completed;
  final int currentStage;
  final int totalStages;
  final OnboardingStepDefinition? nextStep;
  final String companyId;
}

class OnboardingProgress {
  static const Duration _cacheTtl = Duration(seconds: 45);
  static final Map<String, _OnboardingCacheEntry> _cache = {};
  static final Map<String, Future<OnboardingProgressState>> _pending = {};

  static void invalidate({String? authUid}) {
    final normalizedAuthUid = (authUid ?? '').trim();
    if (normalizedAuthUid.isEmpty) {
      _cache.clear();
      _pending.clear();
      return;
    }
    _cache.removeWhere((key, _) => key.startsWith('$normalizedAuthUid|'));
    _pending.removeWhere((key, _) => key.startsWith('$normalizedAuthUid|'));
  }

  static const orderedSteps = <OnboardingStepDefinition>[
    OnboardingStepDefinition(
      key: 'companies',
      path: '/companySetup',
      label: 'Заполните компанию',
    ),
    OnboardingStepDefinition(
      key: 'roles',
      path: '/orgStructura',
      label: 'Настройте должности',
    ),
    OnboardingStepDefinition(
      key: 'org',
      path: '/orgStructura',
      label: 'Заполните оргструктуру',
    ),
    OnboardingStepDefinition(
      key: 'employees',
      path: '/hrControls',
      label: 'Добавьте сотрудников',
    ),
    OnboardingStepDefinition(
      key: 'accounts',
      path: '/scheta',
      label: 'Заполните счета',
    ),
    OnboardingStepDefinition(
      key: 'warehouses',
      path: '/sclad',
      label: 'Добавьте склады',
    ),
    OnboardingStepDefinition(
      key: 'shops',
      path: '/shop',
      label: 'Добавьте магазины',
    ),
    OnboardingStepDefinition(
      key: 'products',
      path: '/tovar',
      label: 'Добавьте товары',
    ),
    OnboardingStepDefinition(
      key: 'budgets',
      path: '/statRas',
      label: 'Заполните бюджет',
    ),
  ];

  static Map<String, bool> normalizeStepMap(dynamic raw) {
    if (raw is! Map) return <String, bool>{};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value == true),
    );
  }

  static Map<String, bool> mergedStepState({
    required Map<String, bool> savedSteps,
    required Map<String, bool> skippedSteps,
    required Map<String, int> counts,
  }) {
    return <String, bool>{
      'companies': (savedSteps['companies'] == true) ||
          (skippedSteps['companies'] == true) ||
          ((counts['companies'] ?? 0) > 0),
      'roles': (savedSteps['roles'] == true) ||
          (skippedSteps['roles'] == true) ||
          ((counts['roles'] ?? 0) > 0),
      'org': (savedSteps['org'] == true) ||
          (skippedSteps['org'] == true) ||
          ((counts['org'] ?? 0) > 0),
      'employees': (savedSteps['employees'] == true) ||
          (skippedSteps['employees'] == true) ||
          ((counts['employees'] ?? 0) > 0),
      'accounts': (savedSteps['accounts'] == true) ||
          (skippedSteps['accounts'] == true) ||
          ((counts['accounts'] ?? 0) > 0),
      'warehouses': (savedSteps['warehouses'] == true) ||
          (skippedSteps['warehouses'] == true) ||
          ((counts['warehouses'] ?? 0) > 0),
      'shops': (savedSteps['shops'] == true) ||
          (skippedSteps['shops'] == true) ||
          ((counts['shops'] ?? 0) > 0),
      'products': (savedSteps['products'] == true) ||
          (skippedSteps['products'] == true) ||
          ((counts['products'] ?? 0) > 0),
      'budgets': (savedSteps['budgets'] == true) ||
          (skippedSteps['budgets'] == true) ||
          ((counts['budgets'] ?? 0) > 0),
    };
  }

  static Future<OnboardingProgressState> load({
    required FirebaseFirestore db,
    required String authUid,
    required Map<String, dynamic> userData,
  }) async {
    final cacheKey = _cacheKey(authUid: authUid, userData: userData);
    final now = DateTime.now();
    final cached = _cache[cacheKey];
    if (cached != null && now.difference(cached.timestamp) <= _cacheTtl) {
      return cached.data;
    }

    final pending = _pending[cacheKey];
    if (pending != null) {
      return pending;
    }

    final request = _loadFresh(
      db: db,
      authUid: authUid,
      userData: userData,
    );
    _pending[cacheKey] = request;

    try {
      final result = await request;
      _cache[cacheKey] = _OnboardingCacheEntry(result, DateTime.now());
      return result;
    } finally {
      if (identical(_pending[cacheKey], request)) {
        _pending.remove(cacheKey);
      }
    }
  }

  static Future<OnboardingProgressState> _loadFresh({
    required FirebaseFirestore db,
    required String authUid,
    required Map<String, dynamic> userData,
  }) async {
    final context = UserAccessContext.fromData(userData);
    final companyId = context.selectedCompanyId;
    final savedSteps = normalizeStepMap(userData['onboarding_steps']);
    final skippedSteps = normalizeStepMap(userData['onboarding_skipped']);

    final counts = <String, int>{
      'companies': 0,
      'roles': 0,
      'org': 0,
      'employees': 0,
      'accounts': 0,
      'warehouses': 0,
      'shops': 0,
      'products': 0,
      'budgets': 0,
    };

    final normalizedAuthUid = authUid.trim();
    if (normalizedAuthUid.isNotEmpty) {
      final owned = await db
          .collection('companies')
          .where('ownerId', isEqualTo: normalizedAuthUid)
          .count()
          .get();
      var companiesCount = owned.count ?? 0;
      if (companiesCount == 0) {
        final member = await db
            .collection('companies')
            .where('members', arrayContains: normalizedAuthUid)
            .count()
            .get();
        companiesCount = member.count ?? 0;
      }
      if (companiesCount == 0 && context.companyIds.isNotEmpty) {
        companiesCount = context.companyIds.length;
      }
      counts['companies'] = companiesCount;
    }

    if (companyId.isNotEmpty) {
      final rolesFuture =
          db.collection('roles').where('idCompany', isEqualTo: companyId).get();
      final employeesFuture = db
          .collection('employees')
          .where('idCompany', isEqualTo: companyId)
          .get();
      final accountsFuture = db
          .collection('sheta')
          .where('idCompany', isEqualTo: companyId)
          .count()
          .get();
      final warehousesFuture = db
          .collection('warehouses')
          .where('idCompany', isEqualTo: companyId)
          .count()
          .get();
      final shopsFuture = db
          .collection('shops')
          .where('idCompany', isEqualTo: companyId)
          .count()
          .get();
      final productsFuture = db
          .collection('nomenklatura')
          .where('idCompany', isEqualTo: companyId)
          .count()
          .get();
      final budgetsFuture = db
          .collection('statRashod')
          .where('idCompany', isEqualTo: companyId)
          .count()
          .get();

      final results = await Future.wait([
        rolesFuture,
        employeesFuture,
        accountsFuture,
        warehousesFuture,
        shopsFuture,
        productsFuture,
        budgetsFuture,
      ]);

      final rolesSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final employeesSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final accountsSnap = results[2] as AggregateQuerySnapshot;
      final warehousesSnap = results[3] as AggregateQuerySnapshot;
      final shopsSnap = results[4] as AggregateQuerySnapshot;
      final productsSnap = results[5] as AggregateQuerySnapshot;
      final budgetsSnap = results[6] as AggregateQuerySnapshot;

      counts['roles'] = rolesSnap.docs.where((doc) {
        return (doc.data()['type'] ?? '').toString() == 'position';
      }).length;
      counts['employees'] = employeesSnap.docs.length;
      counts['org'] = employeesSnap.docs.where((doc) {
        final data = doc.data();
        final role = (data['role'] ?? '').toString().trim();
        final department = (data['department'] ?? '').toString().trim();
        return role.isNotEmpty || department.isNotEmpty;
      }).length;
      counts['accounts'] = accountsSnap.count ?? 0;
      counts['warehouses'] = warehousesSnap.count ?? 0;
      counts['shops'] = shopsSnap.count ?? 0;
      counts['products'] = productsSnap.count ?? 0;
      counts['budgets'] = budgetsSnap.count ?? 0;
    }

    final stepState = mergedStepState(
      savedSteps: savedSteps,
      skippedSteps: skippedSteps,
      counts: counts,
    );
    final nextIndex = orderedSteps.indexWhere(
      (step) => stepState[step.key] != true,
    );
    final completed = nextIndex < 0;
    return OnboardingProgressState(
      stepState: stepState,
      completed: completed,
      currentStage: completed ? orderedSteps.length : nextIndex + 1,
      totalStages: orderedSteps.length,
      nextStep: completed ? null : orderedSteps[nextIndex],
      companyId: companyId,
    );
  }

  static Future<OnboardingProgressState> loadAndSync({
    required FirebaseFirestore db,
    required String authUid,
    required Map<String, dynamic> userData,
    required DocumentReference? userRef,
  }) async {
    final progress = await load(
      db: db,
      authUid: authUid,
      userData: userData,
    );
    if (userRef != null) {
      final savedSteps = normalizeStepMap(userData['onboarding_steps']);
      final savedComplete = userData['onboarding_complete'] == true;
      final sameSteps = savedSteps.length == progress.stepState.length &&
          progress.stepState.entries.every(
            (entry) => savedSteps[entry.key] == entry.value,
          );
      if (!sameSteps || savedComplete != progress.completed) {
        await userRef.update({
          'onboarding_steps': progress.stepState,
          'onboarding_complete': progress.completed,
        });
      }
    }
    return progress;
  }

  static String _cacheKey({
    required String authUid,
    required Map<String, dynamic> userData,
  }) {
    final context = UserAccessContext.fromData(userData);
    final savedSteps = normalizeStepMap(userData['onboarding_steps']);
    final skippedSteps = normalizeStepMap(userData['onboarding_skipped']);
    final companyIds = [...context.companyIds]..sort();
    final allowedCompanyIds = [...context.allowedCompanyIds]..sort();
    final savedParts = savedSteps.entries
        .map((e) => '${e.key}:${e.value ? 1 : 0}')
        .toList()
      ..sort();
    final skippedParts = skippedSteps.entries
        .map((e) => '${e.key}:${e.value ? 1 : 0}')
        .toList()
      ..sort();
    final parts = <String>[
      authUid.trim(),
      context.selectedCompanyId,
      context.companyScope,
      companyIds.join(','),
      allowedCompanyIds.join(','),
      savedParts.join(','),
      skippedParts.join(','),
      userData['onboarding_complete'] == true ? '1' : '0',
    ];
    return parts.join('|');
  }
}

class _OnboardingCacheEntry {
  const _OnboardingCacheEntry(this.data, this.timestamp);

  final OnboardingProgressState data;
  final DateTime timestamp;
}
