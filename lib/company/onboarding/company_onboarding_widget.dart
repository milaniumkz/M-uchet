import '/auth/firebase_auth/auth_util.dart';
import '/component/header/header_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/utils/onboarding_progress.dart';
import '/utils/user_access_context.dart';
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CompanyOnboardingWidget extends StatefulWidget {
  const CompanyOnboardingWidget({super.key});

  static String routeName = 'companyOnboarding';
  static String routePath = '/companyOnboarding';

  @override
  State<CompanyOnboardingWidget> createState() =>
      _CompanyOnboardingWidgetState();
}

class _CompanyOnboardingWidgetState extends State<CompanyOnboardingWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  String _companyId = '';
  bool _locked = false;
  int _companiesCount = 0;
  int _accountsCount = 0;
  int _warehousesCount = 0;
  int _shopsCount = 0;
  int _productsCount = 0;
  int _budgetsCount = 0;
  int _rolesCount = 0;
  int _employeesCount = 0;
  int _orgStructCount = 0;
  bool _onboardingComplete = false;
  Map<String, bool> _skipped = {};
  String? _requestedStepKey;
  bool _requestedStepHandled = false;

  Map<String, bool> _savedSteps() {
    return OnboardingProgress.normalizeStepMap(
      currentUserDocument?.snapshotData['onboarding_steps'],
    );
  }

  String _effectiveCompanyId() {
    return UserAccessContext.fromData(currentUserDocument?.snapshotData)
        .selectedCompanyId;
  }

  List<String> get _requiredStepKeys =>
      OnboardingProgress.orderedSteps.map((e) => e.key).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final requested =
        GoRouterState.of(context).uri.queryParameters['step']?.trim() ?? '';
    final next = requested.isEmpty ? null : requested;
    if (_requestedStepKey != next) {
      _requestedStepKey = next;
      _requestedStepHandled = false;
    }
    _tryAutoOpenRequestedStep();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = currentUserUid;
      final companyId = _effectiveCompanyId();
      _companyId = companyId;

      if (uid.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final companiesSnap = await FirebaseFirestore.instance
          .collection('companies')
          .where('ownerId', isEqualTo: uid)
          .get();
      _companiesCount = companiesSnap.docs.length;

      if (_companiesCount == 0) {
        final memberSnap = await FirebaseFirestore.instance
            .collection('companies')
            .where('members', arrayContains: uid)
            .get();
        _companiesCount = memberSnap.docs.length;
        if (_companyId.isEmpty && memberSnap.docs.isNotEmpty) {
          final firstId = memberSnap.docs.first.id;
          _companyId = firstId;
          if (currentUserReference != null) {
            await currentUserReference!.update({
              'idCompany': firstId,
              'activeCompanyId': firstId,
              'companyIds': FieldValue.arrayUnion([firstId]),
            });
          }
        }
      }

      if (_companiesCount == 0) {
        final ids = (currentUserDocument?.companyIds ?? const [])
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (ids.isNotEmpty) {
          _companiesCount = ids.length;
        }
      }

      if (_companiesCount == 0) {
        final rawId = (currentUserDocument?.idCompany ?? '').trim();
        if (rawId.isNotEmpty && rawId != '__all__') {
          _companiesCount = 1;
        }
      }

      final companiesDoneFlag =
          currentUserDocument?.snapshotData['onboarding_companies_done'] ==
              true;
      if (_companiesCount > 0 &&
          !companiesDoneFlag &&
          currentUserReference != null) {
        await currentUserReference!.update({'onboarding_companies_done': true});
      }

      if (companyId.isEmpty && companiesSnap.docs.isNotEmpty) {
        final firstId = companiesSnap.docs.first.id;
        _companyId = firstId;
        if (currentUserReference != null) {
          await currentUserReference!.update({
            'idCompany': firstId,
            'activeCompanyId': firstId,
            'companyIds': FieldValue.arrayUnion([firstId]),
          });
        }
      }

      if (_companyId.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final companySnap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(_companyId)
          .get();
      final companyData = companySnap.data() ?? {};
      _locked = companyData['data_locked'] == true;
      _onboardingComplete =
          currentUserDocument?.snapshotData['onboarding_complete'] == true;
      final skippedRaw =
          currentUserDocument?.snapshotData['onboarding_skipped'];
      if (skippedRaw is Map) {
        _skipped = skippedRaw
            .map((key, value) => MapEntry(key.toString(), value == true));
      } else {
        _skipped = {};
      }

      await _ensureDefaultFirstEntryData();

      final accountsSnap = await FirebaseFirestore.instance
          .collection('sheta')
          .where('idCompany', isEqualTo: companyId)
          .get();
      _accountsCount = accountsSnap.docs.length;

      final rolesSnap = await FirebaseFirestore.instance
          .collection('roles')
          .where('idCompany', isEqualTo: companyId)
          .get();
      _rolesCount = rolesSnap.docs.where((d) {
        final data = d.data();
        return (data['type'] ?? '').toString() == 'position';
      }).length;

      final employeesSnap = await FirebaseFirestore.instance
          .collection('employees')
          .where('idCompany', isEqualTo: companyId)
          .get();
      _employeesCount = employeesSnap.docs.length;
      _orgStructCount = employeesSnap.docs.where((d) {
        final data = d.data();
        final role = (data['role'] ?? '').toString().trim();
        final dept = (data['department'] ?? '').toString().trim();
        return role.isNotEmpty || dept.isNotEmpty;
      }).length;

      final warehousesSnap = await FirebaseFirestore.instance
          .collection('warehouses')
          .where('idCompany', isEqualTo: companyId)
          .get();
      _warehousesCount = warehousesSnap.docs.length;

      final shopsSnap = await FirebaseFirestore.instance
          .collection('shops')
          .where('idCompany', isEqualTo: companyId)
          .get();
      _shopsCount = shopsSnap.docs.length;

      final productsSnap = await FirebaseFirestore.instance
          .collection('nomenklatura')
          .where('idCompany', isEqualTo: companyId)
          .get();
      _productsCount = productsSnap.docs.length;

      final budgetSnap = await FirebaseFirestore.instance
          .collection('statRashod')
          .where('idCompany', isEqualTo: companyId)
          .get();
      _budgetsCount = budgetSnap.docs.length;

      final saved = _savedSteps();
      final steps = OnboardingProgress.mergedStepState(
        savedSteps: saved,
        skippedSteps: _skipped,
        counts: {
          'companies': _companiesCount,
          'roles': _rolesCount,
          'org': _orgStructCount,
          'employees': _employeesCount,
          'accounts': _accountsCount,
          'warehouses': _warehousesCount,
          'shops': _shopsCount,
          'products': _productsCount,
          'budgets': _budgetsCount,
        },
      );
      final same = steps.length == saved.length &&
          steps.entries.every((e) => saved[e.key] == e.value);
      if (currentUserReference != null) {
        final userData = Map<String, dynamic>.from(
          currentUserDocument?.snapshotData ?? const {},
        );
        userData['idCompany'] = _companyId;
        userData['activeCompanyId'] = _companyId;
        userData['companyScope'] = 'single';
        final companyIds =
            List<String>.from((userData['companyIds'] as List?) ?? const [])
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty && e != '__all__')
                .toSet()
                .toList();
        if (!companyIds.contains(_companyId)) {
          companyIds.add(_companyId);
        }
        userData['companyIds'] = companyIds;
        userData['onboarding_steps'] = same ? saved : steps;
        await currentUserReference!.update({
          'idCompany': _companyId,
          'activeCompanyId': _companyId,
          'companyScope': 'single',
          'companyIds': companyIds,
          if (!same) 'onboarding_steps': steps,
        });
        OnboardingProgress.invalidate(authUid: currentUserUid);
        final progress = await OnboardingProgress.loadAndSync(
          db: FirebaseFirestore.instance,
          authUid: currentUserUid,
          userData: userData,
          userRef: currentUserReference,
        );
        _onboardingComplete = progress.completed;
      }
    } catch (e) {
      debugPrint('Onboarding load error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }

    if (_locked && !_onboardingComplete && currentUserReference != null) {
      await currentUserReference!
          .update({'onboarding_complete': true, 'data_locked': true});
      if (mounted) {
        setState(() => _onboardingComplete = true);
      }
    }
    _tryAutoOpenRequestedStep();
  }

  void _tryAutoOpenRequestedStep() {
    if (!mounted || _loading || _requestedStepHandled) return;
    final stepKey = _requestedStepKey;
    if (stepKey == null || stepKey.isEmpty) return;
    final valid = _requiredStepKeys.contains(stepKey);
    if (!valid) {
      _requestedStepHandled = true;
      return;
    }
    _requestedStepHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _openStepByKey(stepKey);
      if (!mounted) return;
      final uri = GoRouterState.of(context).uri;
      if (uri.queryParameters.containsKey('step')) {
        final cleaned = Map<String, String>.from(uri.queryParameters)
          ..remove('step');
        context.goNamed(
          CompanyOnboardingWidget.routeName,
          queryParameters: cleaned,
        );
      }
    });
  }

  Future<void> _openStepByKey(String stepKey) async {
    switch (stepKey) {
      case 'companies':
        await _openStepDialog(
          const CompanySetupWidget(),
          stepKey: 'companies',
        );
        return;
      case 'roles':
        await _openStepDialog(
          const OrgStructuraWidget(),
          stepKey: 'roles',
        );
        return;
      case 'org':
        await _openStepDialog(
          const OrgStructuraWidget(),
          stepKey: 'org',
        );
        return;
      case 'employees':
        await _openStepDialog(
          const HrControlsWidget(),
          stepKey: 'employees',
        );
        return;
      case 'accounts':
        await _openStepDialog(
          const SchetaWidget(embedded: true),
          stepKey: 'accounts',
        );
        return;
      case 'warehouses':
        await _openStepDialog(
          const ScladWidget(embedded: true),
          stepKey: 'warehouses',
        );
        return;
      case 'shops':
        await _openStepDialog(
          const ShopWidget(embedded: true),
          stepKey: 'shops',
        );
        return;
      case 'products':
        await _openStepDialog(
          const TovarWidget(embedded: true),
          stepKey: 'products',
        );
        return;
      case 'budgets':
        await _openStepDialog(
          const StatRasWidget(embedded: true),
          stepKey: 'budgets',
        );
        return;
    }
  }

  bool get _allStepsDone {
    if (_companyId.isEmpty) return false;
    return _stepDone('companies', _companiesCount) &&
        _stepDone('roles', _rolesCount) &&
        _stepDone('org', _orgStructCount) &&
        _stepDone('employees', _employeesCount) &&
        _stepDone('accounts', _accountsCount) &&
        _stepDone('warehouses', _warehousesCount) &&
        _stepDone('shops', _shopsCount) &&
        _stepDone('products', _productsCount) &&
        _stepDone('budgets', _budgetsCount);
  }

  bool _stepDone(String key, int count) {
    final saved = _savedSteps();
    if (saved[key] == true) return true;
    return count > 0;
  }

  bool _stepSkippedAndIncomplete(String key, int count) {
    return (_skipped[key] == true) && !_stepDoneByActualData(key, count);
  }

  int _countForStep(String key) {
    return switch (key) {
      'companies' => _companiesCount,
      'roles' => _rolesCount,
      'org' => _orgStructCount,
      'employees' => _employeesCount,
      'accounts' => _accountsCount,
      'warehouses' => _warehousesCount,
      'shops' => _shopsCount,
      'products' => _productsCount,
      'budgets' => _budgetsCount,
      _ => 0,
    };
  }

  bool _stepSkippedAndIncompleteByKey(String key) {
    return _stepSkippedAndIncomplete(key, _countForStep(key));
  }

  bool _stepDoneByActualData(String key, int count) {
    if (key == 'companies') return _companiesCount > 0;
    if (key == 'roles') return _rolesCount > 0;
    if (key == 'org') return _orgStructCount > 0;
    if (key == 'employees') return _employeesCount > 0;
    return count > 0;
  }

  List<String> get _unfilledSkippedStepTitles {
    final result = <String>[];
    final defs = <MapEntry<String, String>>[
      const MapEntry('companies', 'Компании'),
      const MapEntry('roles', 'Должности'),
      const MapEntry('org', 'Оргструктура'),
      const MapEntry('employees', 'Сотрудники'),
      const MapEntry('accounts', 'Счета'),
      const MapEntry('warehouses', 'Склады'),
      const MapEntry('shops', 'Магазины'),
      const MapEntry('products', 'Товары'),
      const MapEntry('budgets', 'Бюджет'),
    ];
    for (final def in defs) {
      final count = switch (def.key) {
        'companies' => _companiesCount,
        'roles' => _rolesCount,
        'org' => _orgStructCount,
        'employees' => _employeesCount,
        'accounts' => _accountsCount,
        'warehouses' => _warehousesCount,
        'shops' => _shopsCount,
        'products' => _productsCount,
        'budgets' => _budgetsCount,
        _ => 0,
      };
      if (_stepSkippedAndIncomplete(def.key, count)) {
        result.add(def.value);
      }
    }
    return result;
  }

  Future<void> _skipStep(String key) async {
    _skipped[key] = true;
    if (currentUserReference != null) {
      final steps = _savedSteps();
      steps[key] = false;
      await currentUserReference!.update({
        'onboarding_skipped': _skipped,
        'onboarding_steps': steps,
      });
    }
    if (mounted) {
      final labels = _unfilledSkippedStepTitles;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1D4ED8),
          content: Text(
            labels.isEmpty
                ? 'Блок можно заполнить позже.'
                : 'Можно заполнить позже: ${labels.join(', ')}.',
          ),
        ),
      );
    }
  }

  Future<void> _markStepDone(String key) async {
    final steps = _savedSteps();
    steps[key] = true;
    if (mounted) {
      setState(() {
        _skipped[key] = false;
      });
    } else {
      _skipped[key] = false;
    }
    if (currentUserReference != null) {
      await currentUserReference!.update({
        'onboarding_steps': steps,
        'onboarding_skipped': _skipped,
      });
    }
  }

  Future<void> _finishOnboarding() async {
    if (_companyId.isEmpty) return;
    final stepsByData = <String, bool>{
      'companies': _companiesCount > 0,
      'roles': _rolesCount > 0,
      'org': _orgStructCount > 0,
      'employees': _employeesCount > 0,
      'accounts': _accountsCount > 0,
      'warehouses': _warehousesCount > 0,
      'shops': _shopsCount > 0,
      'products': _productsCount > 0,
      'budgets': _budgetsCount > 0,
    };
    final lockedSteps = <String, bool>{
      for (final entry in stepsByData.entries) entry.key: entry.value,
    };
    final unlockedTitles = _unfilledSkippedStepTitles;
    final unlockedHint = unlockedTitles.isEmpty
        ? 'Незаполненные блоки можно заполнить позже.'
        : 'Незаполненные блоки останутся доступными: ${unlockedTitles.join(', ')}.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Завершить первый вход'),
          content: Text(
            'После завершения будут заблокированы только заполненные блоки. $unlockedHint Продолжить?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Завершить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('companies')
        .doc(_companyId)
        .set({
      'data_locked': true,
      'locked_steps': lockedSteps,
      'lockedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      setState(() {
        _locked = true;
        _onboardingComplete = true;
      });
    }
    if (currentUserReference != null) {
      await currentUserReference!.update({
        'onboarding_complete': true,
        'data_locked': true,
        'onboarding_locked_steps': lockedSteps,
        'onboarding_steps': stepsByData,
      });
    }
    if (mounted) {
      context.goNamed(SchetaWidget.routeName);
    }
  }

  Future<void> _openStepDialog(
    Widget child, {
    String? stepKey,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        final size = MediaQuery.of(dialogContext).size;
        final dialogWidth = (size.width - 32).clamp(280.0, 1400.0);
        final dialogHeight = size.height * 0.92;
        final topInset = stepKey != null ? 44.0 : 0.0;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: FlutterFlowTheme.of(dialogContext).primaryBackground,
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topInset),
                    child: SizedBox(
                      width: dialogWidth,
                      height: dialogHeight - topInset,
                      child: MediaQuery(
                        data: MediaQuery.of(dialogContext).copyWith(
                          size: Size(
                            dialogWidth,
                            dialogHeight,
                          ),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ),
                  if (stepKey != null)
                    Positioned(
                      right: 52,
                      top: 8,
                      child: FFButtonWidget(
                        onPressed: () async {
                          await _markStepDone(stepKey);
                          if (Navigator.of(dialogContext).canPop()) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        text: 'Готов',
                        options: FFButtonOptions(
                          height: 32,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              12, 0, 12, 0),
                          color: FlutterFlowTheme.of(dialogContext).primary,
                          textStyle: FlutterFlowTheme.of(dialogContext)
                              .labelMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: Colors.white,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                              ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _ensureDefaultFirstEntryData() async {
    if (_companyId.isEmpty || currentUserUid.isEmpty) return;
    if (_locked) return;

    final db = FirebaseFirestore.instance;

    final rolesSnap = await db
        .collection('roles')
        .where('idCompany', isEqualTo: _companyId)
        .get();
    _rolesCount = rolesSnap.docs.where((d) {
      final data = d.data();
      return (data['type'] ?? '').toString() == 'position';
    }).length;

    if (_employeesCount == 0) {
      final displayName = currentUserDisplayName.trim();
      final email = currentUserEmail.trim();
      await db.collection('employees').add({
        'idCompany': _companyId,
        'user_id': currentUserUid,
        'name': displayName.isNotEmpty
            ? displayName
            : (email.isNotEmpty ? email : 'Владелец'),
        'role': 'Владелец',
        'department': 'Руководство',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      _employeesCount = 1;
      _orgStructCount = 1;
    }
  }

  Widget _stepCard({
    String? stepKey,
    required String title,
    required String subtitle,
    required bool done,
    required Future<void> Function() onTap,
    required String actionText,
    bool enabled = true,
    String? blockedHint,
    bool allowSkip = false,
    Future<void> Function()? onSkip,
  }) {
    final isWarning =
        stepKey != null && !done && _stepSkippedAndIncompleteByKey(stepKey);
    final isDisabled = !enabled || (_locked && !isWarning);
    final color = done
        ? const Color(0xFFE6F4EA)
        : isWarning
            ? const Color(0xFFFEF3F2)
            : isDisabled
                ? const Color(0xFFF3F4F6)
                : FlutterFlowTheme.of(context).secondaryBackground;
    final border = done
        ? const Color(0xFF34A853)
        : isWarning
            ? const Color(0xFFF04438)
            : isDisabled
                ? const Color(0xFFE5E7EB)
                : const Color(0xFFE5E7EB);
    final buttonColor = isDisabled
        ? const Color(0xFFCBD5E1)
        : FlutterFlowTheme.of(context).primary;
    final buttonTextColor = isDisabled ? const Color(0xFF64748B) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            done
                ? Icons.check_circle
                : isWarning
                    ? Icons.error_outline_rounded
                    : Icons.radio_button_unchecked,
            color: done
                ? const Color(0xFF34A853)
                : isWarning
                    ? const Color(0xFFB42318)
                    : const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                        fontSize: 18,
                        color: isWarning ? const Color(0xFFB42318) : null,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        letterSpacing: 0.0,
                      ),
                ),
                if (isWarning) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Блок пропущен и не заполнен',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(),
                          color: const Color(0xFFB42318),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
                if (isDisabled && blockedHint != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    blockedHint,
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(),
                          color: const Color(0xFFB42318),
                          letterSpacing: 0.0,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (allowSkip && !_locked)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isWarning ? const Color(0xFFB42318) : null,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: isDisabled
                      ? null
                      : () async {
                          if (onSkip != null) {
                            await onSkip();
                          }
                          await _load();
                        },
                  child: const Text('Пропустить'),
                ),
              FFButtonWidget(
                onPressed: isDisabled
                    ? null
                    : () async {
                        await onTap();
                        await _load();
                      },
                text: isWarning ? 'Заполнить' : actionText,
                options: FFButtonOptions(
                  height: 42,
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 0),
                  color: buttonColor,
                  textStyle: FlutterFlowTheme.of(context).labelMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                        ),
                        color: buttonTextColor,
                        fontSize: 14,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w700,
                      ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCompany = _companyId.isNotEmpty;
    return WillPopScope(
      onWillPop: () async => true,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          body: SafeArea(
            top: true,
            child: Column(
              children: [
                const HeaderWidget(
                  title: 'Первый вход',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_loading)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: FlutterFlowTheme.of(context).primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Обновляем данные...',
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.inter(),
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        if (_companyId.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF0B429),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFF0B429)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Сначала создайте компанию. Затем вернитесь к первому входу.',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(),
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                                FFButtonWidget(
                                  onPressed: () async {
                                    await _openStepDialog(
                                      const CompanySetupWidget(),
                                      stepKey: 'companies',
                                    );
                                  },
                                  text: 'Создать компанию',
                                  options: FFButtonOptions(
                                    height: 36,
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            16, 0, 16, 0),
                                    color: FlutterFlowTheme.of(context).primary,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          color: Colors.white,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Шаги настройки',
                          style:
                              FlutterFlowTheme.of(context).titleLarge.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        _stepCard(
                          stepKey: 'companies',
                          title: 'Компании',
                          subtitle: 'Создайте компанию и заполните реквизиты.',
                          done: _stepDone('companies', _companiesCount),
                          enabled: true,
                          onTap: () async {
                            await _openStepDialog(
                              const CompanySetupWidget(),
                              stepKey: 'companies',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('companies'),
                        ),
                        _stepCard(
                          stepKey: 'roles',
                          title: 'Должности',
                          subtitle:
                              'Добавьте должности и настройте роли через оргструктуру.',
                          done: _stepDone('roles', _rolesCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const OrgStructuraWidget(),
                              stepKey: 'roles',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('roles'),
                        ),
                        _stepCard(
                          stepKey: 'org',
                          title: 'Оргструктура',
                          subtitle:
                              'Добавьте должности и выстройте оргструктуру.',
                          done: _stepDone('org', _orgStructCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const OrgStructuraWidget(),
                              stepKey: 'org',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('org'),
                        ),
                        _stepCard(
                          stepKey: 'employees',
                          title: 'Сотрудники',
                          subtitle:
                              'Зарегистрируйте сотрудников и назначьте им роли.',
                          done: _stepDone('employees', _employeesCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const HrControlsWidget(),
                              stepKey: 'employees',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('employees'),
                        ),
                        _stepCard(
                          stepKey: 'accounts',
                          title: 'Первичные остатки счетов',
                          subtitle:
                              'Добавьте счета и внесите начальные остатки.',
                          done: _stepDone('accounts', _accountsCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const SchetaWidget(embedded: true),
                              stepKey: 'accounts',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('accounts'),
                        ),
                        _stepCard(
                          stepKey: 'warehouses',
                          title: 'Склады',
                          subtitle: 'Создайте склады и распределите остатки.',
                          done: _stepDone('warehouses', _warehousesCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const ScladWidget(embedded: true),
                              stepKey: 'warehouses',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('warehouses'),
                        ),
                        _stepCard(
                          stepKey: 'shops',
                          title: 'Магазины и кассиры',
                          subtitle: 'Создайте магазины и добавьте кассиров.',
                          done: _stepDone('shops', _shopsCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const ShopWidget(embedded: true),
                              stepKey: 'shops',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('shops'),
                        ),
                        _stepCard(
                          stepKey: 'products',
                          title: 'Товары',
                          subtitle: 'Добавьте товары и остатки на складах.',
                          done: _stepDone('products', _productsCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const TovarWidget(embedded: true),
                              stepKey: 'products',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('products'),
                        ),
                        _stepCard(
                          stepKey: 'budgets',
                          title: 'Бюджет расходов',
                          subtitle: 'Заполните бюджет на месяц/год.',
                          done: _stepDone('budgets', _budgetsCount),
                          enabled: hasCompany,
                          blockedHint: hasCompany
                              ? null
                              : 'Сначала завершите шаг «Компании».',
                          onTap: () async {
                            await _openStepDialog(
                              const StatRasWidget(embedded: true),
                              stepKey: 'budgets',
                            );
                          },
                          actionText: 'Далее',
                          allowSkip: true,
                          onSkip: () => _skipStep('budgets'),
                        ),
                        const SizedBox(height: 16),
                        if (_locked)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFF34A853)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock,
                                    color: Color(0xFF34A853)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Заполненные блоки зафиксированы. Пропущенные блоки можно заполнить позже.',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(),
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          FFButtonWidget(
                            onPressed: hasCompany ? _finishOnboarding : null,
                            text:
                                'Завершить первый вход и заблокировать изменения',
                            options: FFButtonOptions(
                              height: 44,
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  20, 0, 20, 0),
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        if (!_allStepsDone && !_locked)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Можно пропустить часть шагов и завершить. Незаполненные блоки останутся доступными для заполнения позже.',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    font: GoogleFonts.inter(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
