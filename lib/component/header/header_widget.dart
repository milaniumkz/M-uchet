import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import '/utils/app_money_format.dart';
import '/utils/effective_company_support.dart';
import '/utils/onboarding_progress.dart';
import '/utils/user_access_context.dart';
import '/user_design/user_design.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'header_model.dart';
export 'header_model.dart';

class HeaderWidget extends StatefulWidget {
  const HeaderWidget({
    super.key,
    required this.title,
    this.trailing,
  });

  final String? title;
  final Widget? trailing;

  @override
  State<HeaderWidget> createState() => _HeaderWidgetState();
}

class _CompanyOption {
  final String id;
  final String name;

  const _CompanyOption({required this.id, required this.name});
}

class CompanySwitcherInline extends StatelessWidget {
  const CompanySwitcherInline({super.key});

  String _optionNameFromData(Map<String, dynamic> data) {
    const fields = [
      'name',
      'nameCompany',
      'name_Company',
      'company_name',
      'title',
      'companyTitle',
    ];
    for (final field in fields) {
      final name = (data[field] ?? '').toString().trim();
      if (name.isNotEmpty && name.toLowerCase() != 'компания') {
        return name;
      }
    }
    return 'Компания';
  }

  Future<List<_CompanyOption>> _loadMissingCompanies(
    Set<String> ids,
    Set<String> allowedCompanies,
  ) async {
    if (ids.isEmpty) {
      return const <_CompanyOption>[];
    }
    final options = <_CompanyOption>[];
    for (final chunk in splitCompanyIdsForWhereIn(ids.toList()..sort())) {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(const GetOptions(source: Source.server));
      for (final doc in snap.docs) {
        if (allowedCompanies.isNotEmpty && !allowedCompanies.contains(doc.id)) {
          continue;
        }
        final data = doc.data();
        options.add(
          _CompanyOption(
            id: doc.id,
            name: _optionNameFromData(data),
          ),
        );
      }
    }
    return options;
  }

  Future<List<_CompanyOption>> _loadCompanyProfileNames(Set<String> ids) async {
    if (ids.isEmpty) {
      return const <_CompanyOption>[];
    }
    final options = <_CompanyOption>[];
    for (final chunk in splitCompanyIdsForWhereIn(ids.toList()..sort())) {
      final snap = await FirebaseFirestore.instance
          .collection('company_profile')
          .where('idCompany', whereIn: chunk)
          .get(const GetOptions(source: Source.server));
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = (data['idCompany'] ?? doc.id).toString().trim();
        final name = _optionNameFromData(data);
        if (id.isNotEmpty && name.isNotEmpty && name != 'Компания') {
          options.add(_CompanyOption(id: id, name: name));
        }
      }
    }
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final userId = currentUserUid;
    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }
    final access =
        UserAccessContext.fromData(currentUserDocument?.snapshotData);
    final allowedCompanies = access.effectiveAllowedCompanyIds;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .where('members', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        final seedIds = <String>{
          ...access.companyIds,
          ...allowedCompanies,
          access.selectedCompanyId,
          valueOrDefault<String>(currentUserDocument?.idCompany, '').trim(),
        }..removeWhere((id) => id.trim().isEmpty);
        final streamedOptions = docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          return _CompanyOption(
            id: doc.id,
            name: _optionNameFromData(data),
          );
        }).where((opt) {
          if (allowedCompanies.isEmpty) return true;
          return allowedCompanies.contains(opt.id);
        }).toList();
        final streamedIds = streamedOptions.map((item) => item.id).toSet();
        final missingIds = seedIds.difference(streamedIds);

        if (seedIds.isEmpty && streamedOptions.isEmpty) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<List<List<_CompanyOption>>>(
          future: Future.wait([
            _loadMissingCompanies(missingIds, allowedCompanies),
            _loadCompanyProfileNames(seedIds.union(streamedIds)),
          ]),
          builder: (context, companySnap) {
            final loaded = companySnap.data ?? const <List<_CompanyOption>>[];
            final missingCompanies =
                loaded.isNotEmpty ? loaded[0] : const <_CompanyOption>[];
            final profileNames =
                loaded.length > 1 ? loaded[1] : const <_CompanyOption>[];
            final merged = <String, _CompanyOption>{
              for (final option in streamedOptions) option.id: option,
              for (final option in missingCompanies) option.id: option,
              for (final option in profileNames) option.id: option,
            };
            if (!companySnap.hasData && streamedOptions.isNotEmpty) {
              merged.addAll({
                for (final option in streamedOptions) option.id: option,
                for (final option in missingCompanies) option.id: option,
              });
            }
            final availableIds = {
              ...seedIds,
              ...streamedOptions.map((item) => item.id),
              ...missingCompanies.map((item) => item.id),
              ...profileNames.map((item) => item.id),
            };
            final orderedIds = availableIds.toList()..sort();
            final options = orderedIds
                .map((id) => merged[id])
                .whereType<_CompanyOption>()
                .toList();
            if (options.isEmpty) {
              return const SizedBox.shrink();
            }
            return _CompanyDropdown(
              options: options,
              companyIds: options.map((item) => item.id).toList(),
            );
          },
        );
      },
    );
  }
}

class _CompanyDropdown extends StatelessWidget {
  final List<_CompanyOption> options;
  final List<String> companyIds;
  static final Map<String, String> _symbolCache = <String, String>{};

  const _CompanyDropdown({
    required this.options,
    required this.companyIds,
  });

  Future<void> _syncCompanyCurrency(String companyId) async {
    if (companyId.isEmpty || companyId == '__all__') return;
    final cached = _symbolCache[companyId];
    if (cached != null) {
      if (cached.isNotEmpty && FFAppState().valutaSimvol != cached) {
        FFAppState().valutaSimvol = cached;
      }
      return;
    }
    Map<String, dynamic>? data;
    final direct = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    data = direct.data();
    if (data == null) {
      final query = await FirebaseFirestore.instance
          .collection('company_profile')
          .where('idCompany', isEqualTo: companyId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      if (query.docs.isNotEmpty) {
        data = query.docs.first.data();
      }
    }
    final symbol = moneySymbolFromProfileData(data);
    _symbolCache[companyId] = symbol;
    if (symbol.isNotEmpty && FFAppState().valutaSimvol != symbol) {
      FFAppState().valutaSimvol = symbol;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inherited = UserDesignScope.maybeOf(context);
    if (inherited == null) {
      return const UserDesignScopeLoader(
        child: CompanySwitcherInline(),
      );
    }
    final design = inherited;

    final access =
        UserAccessContext.fromData(currentUserDocument?.snapshotData);
    final selectedId = access.selectedCompanyId;
    final scope = access.companyScope.isEmpty ? 'single' : access.companyScope;
    final value = scope == 'all'
        ? '__all__'
        : (companyIds.contains(selectedId) ? selectedId : companyIds.first);
    final currencyCompanyId = value == '__all__'
        ? (selectedId.isNotEmpty ? selectedId : companyIds.first)
        : value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCompanyCurrency(currencyCompanyId);
    });

    final screenWidth = MediaQuery.sizeOf(context).width;
    final dropdownWidth = screenWidth >= 1500
        ? 360.0
        : screenWidth >= 1200
            ? 320.0
            : screenWidth >= 900
                ? 280.0
                : 220.0;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
      child: SizedBox(
        width: dropdownWidth,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 12.0, 10.0),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: design.surfaceBorder,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: design.buttonColor,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
            filled: true,
            fillColor: design.surfaceColor,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: '__all__',
              child: Text(
                'Все компании',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...options.map((o) {
              return DropdownMenuItem<String>(
                value: o.id,
                child: Text(
                  o.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          selectedItemBuilder: (context) {
            return [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Все компании',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...options.map(
                (o) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    o.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ];
          },
          onChanged: (val) async {
            if (val == null || currentUserReference == null) {
              return;
            }
            if (val == '__all__') {
              final effectiveActive = access.selectedCompanyId.isNotEmpty
                  ? access.selectedCompanyId
                  : companyIds.first;
              await _syncCompanyCurrency(effectiveActive);
              await currentUserReference!.update(
                access.companySelectionUpdate(
                  companyId: effectiveActive,
                  allCompanies: true,
                ),
              );
            } else {
              await _syncCompanyCurrency(val);
              await currentUserReference!.update(
                access.companySelectionUpdate(
                  companyId: val,
                  allCompanies: false,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class _HeaderWidgetState extends State<HeaderWidget> {
  late HeaderModel _model;
  Future<OnboardingProgressState>? _onboardingFuture;
  String _onboardingFutureKey = '';

  String _roleLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'owner':
        return 'Владелец';
      case 'admin':
        return 'Администратор';
      case 'director':
        return 'Директор';
      case 'emp':
        return 'Сотрудник';
      default:
        return role.trim().isEmpty ? 'Пользователь' : role.trim();
    }
  }

  Future<void> _openProfileDialog() async {
    final design = UserDesignScope.of(context);
    final displayName = currentUserDisplayName.trim().isNotEmpty
        ? currentUserDisplayName.trim()
        : currentPhoneNumber.trim().isNotEmpty
            ? currentPhoneNumber.trim()
            : currentUserUid.trim();
    final role = _roleLabel(currentUserDocument?.role ?? '');
    final phone = currentPhoneNumber.trim();
    final email = currentUserEmail.trim();
    final userId = currentUserUid.trim();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
          child: Container(
            width: 420.0,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: design.surfaceColor,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: design.surfaceBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54.0,
                      height: 54.0,
                      decoration: BoxDecoration(
                        color: design.buttonColor,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_sharp,
                        color: design.buttonTextColor,
                        size: 28.0,
                      ),
                    ),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Профиль',
                            style: FlutterFlowTheme.of(context)
                                .titleLarge
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  color: design.textColor,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            role,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: design.mutedTextColor,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18.0),
                _profileInfoRow('Имя', displayName, design),
                if (phone.isNotEmpty) _profileInfoRow('Телефон', phone, design),
                if (email.isNotEmpty) _profileInfoRow('Email', email, design),
                if (userId.isNotEmpty) _profileInfoRow('ID', userId, design),
                const SizedBox(height: 20.0),
                Row(
                  children: [
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          if (!mounted) {
                            return;
                          }
                          context.go(CompanySetupWidget.routePath);
                        },
                        text: 'Данные компании',
                        options: FFButtonOptions(
                          height: 42.0,
                          color: design.surfaceColor,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: design.textColor,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                          borderSide: BorderSide(color: design.surfaceBorder),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          if (!mounted) {
                            return;
                          }
                          context.go(HomeWidget.routePath);
                        },
                        text: 'На главную',
                        options: FFButtonOptions(
                          height: 42.0,
                          color: design.buttonColor,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: design.buttonTextColor,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                        },
                        text: 'Закрыть',
                        options: FFButtonOptions(
                          height: 42.0,
                          color: design.surfaceColor,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: design.textColor,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                          borderSide: BorderSide(color: design.surfaceBorder),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileInfoRow(
    String label,
    String value,
    UserDesignData design,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            design.buttonColor.withValues(alpha: 0.06),
            design.surfaceColor,
          ),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: design.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: FlutterFlowTheme.of(context).labelSmall.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    color: design.mutedTextColor,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4.0),
            Text(
              value,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    color: design.textColor,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HeaderModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  Widget _buildCompanySwitcher() {
    return const CompanySwitcherInline();
  }

  String _buildOnboardingFutureKey(Map<String, dynamic> userData) {
    final access = UserAccessContext.fromData(userData);
    final savedSteps = OnboardingProgress.normalizeStepMap(
      userData['onboarding_steps'],
    );
    final skippedSteps = OnboardingProgress.normalizeStepMap(
      userData['onboarding_skipped'],
    );
    final companyIds = [...access.companyIds]..sort();
    final allowedCompanyIds = [...access.allowedCompanyIds]..sort();
    final savedParts = savedSteps.entries
        .map((e) => '${e.key}:${e.value ? 1 : 0}')
        .toList()
      ..sort();
    final skippedParts = skippedSteps.entries
        .map((e) => '${e.key}:${e.value ? 1 : 0}')
        .toList()
      ..sort();
    return <String>[
      currentUserUid,
      access.selectedCompanyId,
      access.companyScope,
      companyIds.join(','),
      allowedCompanyIds.join(','),
      savedParts.join(','),
      skippedParts.join(','),
      userData['onboarding_complete'] == true ? '1' : '0',
    ].join('|');
  }

  Future<OnboardingProgressState>? _getOnboardingFuture(
    Map<String, dynamic> userData,
  ) {
    final nextKey = _buildOnboardingFutureKey(userData);
    if (_onboardingFuture != null && _onboardingFutureKey == nextKey) {
      return _onboardingFuture;
    }
    _onboardingFutureKey = nextKey;
    _onboardingFuture = OnboardingProgress.loadAndSync(
      db: FirebaseFirestore.instance,
      authUid: currentUserUid,
      userData: userData,
      userRef: currentUserReference,
    );
    return _onboardingFuture;
  }

  Future<void> _skipOnboardingStep(
    BuildContext context,
    OnboardingProgressState progress,
  ) async {
    final step = progress.nextStep;
    if (step == null ||
        currentUserReference == null ||
        currentUserDocument == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);

    final savedSteps = OnboardingProgress.normalizeStepMap(
      currentUserDocument!.snapshotData['onboarding_steps'],
    );
    final skippedSteps = OnboardingProgress.normalizeStepMap(
      currentUserDocument!.snapshotData['onboarding_skipped'],
    );
    savedSteps[step.key] = false;
    skippedSteps[step.key] = true;

    await currentUserReference!.update({
      'onboarding_steps': savedSteps,
      'onboarding_skipped': skippedSteps,
    });

    OnboardingProgress.invalidate(authUid: currentUserUid);
    if (!mounted) return;
    setState(() {
      _onboardingFuture = null;
      _onboardingFutureKey = '';
    });
    messenger.showSnackBar(
      SnackBar(content: Text('Шаг "${step.label}" можно заполнить позже.')),
    );
  }

  Future<void> _openOnboardingStepsDialog(
    BuildContext context,
    OnboardingProgressState progress,
  ) async {
    final design = UserDesignScope.of(context);
    final nextStepKey = progress.nextStep?.key ?? '';

    String statusLabel(String key, bool done) {
      if (done) return 'Заполнено';
      if (key == nextStepKey) return 'Текущий этап';
      return 'Не заполнено';
    }

    Color statusColor(String key, bool done) {
      if (done) return const Color(0xFF059669);
      if (key == nextStepKey) return const Color(0xFFDC2626);
      return const Color(0xFF6B7280);
    }

    IconData statusIcon(String key, bool done) {
      if (done) return Icons.check_circle_outline_rounded;
      if (key == nextStepKey) return Icons.radio_button_checked_rounded;
      return Icons.radio_button_unchecked_rounded;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18.0),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: design.surfaceColor,
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: design.surfaceBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Этапы первого входа',
                            style: FlutterFlowTheme.of(context)
                                .headlineSmall
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  color: design.textColor,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Заполняйте этапы по порядку. К каждому этапу можно перейти прямо отсюда.',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(),
                                  color:
                                      design.textColor.withValues(alpha: 0.72),
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: OnboardingProgress.orderedSteps.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final step = OnboardingProgress.orderedSteps[index];
                      final done = progress.stepState[step.key] == true;
                      final active = step.key == nextStepKey;
                      final color = statusColor(step.key, done);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: design.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active
                                ? const Color(0x66DC2626)
                                : design.surfaceBorder,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                statusIcon(step.key, done),
                                color: color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${index + 1}. ${step.label}',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyLarge
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          color: design.textColor,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    statusLabel(step.key, done),
                                    style: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          color: color,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            FFButtonWidget(
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                if (context.mounted) {
                                  context.go(step.path);
                                }
                              },
                              text: done ? 'Открыть' : 'Заполнить',
                              options: FFButtonOptions(
                                height: 36,
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                  12,
                                  0,
                                  12,
                                  0,
                                ),
                                color: done
                                    ? design.surfaceColor
                                    : const Color(0xFFDC2626),
                                textStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: done
                                          ? design.textColor
                                          : Colors.white,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                borderSide: done
                                    ? BorderSide(color: design.surfaceBorder)
                                    : BorderSide.none,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnboardingNextButton(BuildContext context) {
    final user = currentUserDocument;
    if (user == null || currentUserReference == null) {
      return const SizedBox.shrink();
    }
    final userData = user.snapshotData;
    final access = UserAccessContext.fromData(userData);
    if (!access.isOwner) {
      return const SizedBox.shrink();
    }
    final design = UserDesignScope.of(context);
    final completed = user.snapshotData['onboarding_complete'] == true ||
        user.snapshotData['data_locked'] == true;
    if (completed) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<OnboardingProgressState>(
      future: _getOnboardingFuture(userData),
      builder: (context, snapshot) {
        final progress = snapshot.data;
        if (progress == null ||
            progress.completed ||
            progress.nextStep == null) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              const Color(0x14DC2626),
              design.surfaceColor,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0x66DC2626),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Первый вход · Этап ${progress.currentStage} из ${progress.totalStages}',
                          style:
                              FlutterFlowTheme.of(context).labelSmall.override(
                                    font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700),
                                    color: const Color(0xFFDC2626),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          progress.nextStep!.label,
                          style:
                              FlutterFlowTheme.of(context).labelMedium.override(
                                    font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600),
                                    color: design.textColor,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FFButtonWidget(
                    onPressed: () =>
                        _openOnboardingStepsDialog(context, progress),
                    text: 'Этапы',
                    options: FFButtonOptions(
                      height: 34,
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                      color: design.surfaceColor,
                      textStyle:
                          FlutterFlowTheme.of(context).labelMedium.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: design.textColor,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                              ),
                      borderSide: BorderSide(color: design.surfaceBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FFButtonWidget(
                    onPressed: () => _skipOnboardingStep(context, progress),
                    text: 'Пропустить',
                    options: FFButtonOptions(
                      height: 34,
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                      color: Colors.transparent,
                      textStyle:
                          FlutterFlowTheme.of(context).labelMedium.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: const Color(0xFFDC2626),
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                              ),
                      borderSide: const BorderSide(color: Color(0x66DC2626)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  FFButtonWidget(
                    onPressed: () async {
                      if (context.mounted) {
                        context.go(progress.nextStep!.path);
                      }
                    },
                    text: 'Заполнить',
                    options: FFButtonOptions(
                      height: 34,
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 0),
                      color: const Color(0xFFDC2626),
                      textStyle:
                          FlutterFlowTheme.of(context).labelMedium.override(
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final inherited = UserDesignScope.maybeOf(context);
    if (inherited == null) {
      return UserDesignScopeLoader(
        child: HeaderWidget(
          title: widget.title,
          trailing: widget.trailing,
        ),
      );
    }
    final design = inherited;
    final onboardingNext = AuthUserStreamWidget(
      builder: (context) => _buildOnboardingNextButton(context),
    );
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 1170.0,
      ),
      decoration: BoxDecoration(
        color: design.surfaceColor,
        border: Border.all(color: design.surfaceBorder),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: design.buttonColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      28.0, 10.0, 12.0, 10.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Text(
                          valueOrDefault<String>(
                            widget.title,
                            'title',
                          ),
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .override(
                                font: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineSmall
                                      .fontStyle,
                                ),
                                color: design.textColor,
                                fontSize: 22.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineSmall
                                    .fontStyle,
                              ),
                        ),
                      ),
                      if (currentUserUid.isNotEmpty) ...[
                        const SizedBox(width: 12.0),
                        Flexible(
                          flex: 0,
                          child: AuthUserStreamWidget(
                            builder: (context) => _buildCompanySwitcher(),
                          ),
                        ),
                      ],
                      if (widget.trailing != null) ...[
                        const SizedBox(width: 12.0),
                        Flexible(
                          flex: 0,
                          child: widget.trailing!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Stack(
                        children: [
                          if ((Theme.of(context).brightness ==
                                  Brightness.light) ==
                              true)
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 40.0,
                                fillColor: design.buttonColor,
                                icon: Icon(
                                  Icons.dark_mode,
                                  color: design.buttonTextColor,
                                  size: 24.0,
                                ),
                                onPressed: () async {
                                  setDarkModeSetting(context, ThemeMode.dark);
                                },
                              ),
                            ),
                          if ((Theme.of(context).brightness ==
                                  Brightness.dark) ==
                              true)
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: FlutterFlowIconButton(
                                borderRadius: 8.0,
                                buttonSize: 40.0,
                                fillColor: design.buttonColor,
                                icon: Icon(
                                  Icons.light_mode,
                                  color: design.buttonTextColor,
                                  size: 24.0,
                                ),
                                onPressed: () async {
                                  setDarkModeSetting(context, ThemeMode.light);
                                },
                              ),
                            ),
                        ],
                      ),
                      FlutterFlowIconButton(
                        borderRadius: 8.0,
                        buttonSize: 40.0,
                        fillColor: design.buttonColor,
                        icon: Icon(
                          Icons.notifications_sharp,
                          color: design.buttonTextColor,
                          size: 24.0,
                        ),
                        onPressed: () {},
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            10.0, 0.0, 10.0, 0.0),
                        child: FlutterFlowIconButton(
                          borderRadius: 8.0,
                          buttonSize: 40.0,
                          fillColor: design.buttonColor,
                          icon: Icon(
                            Icons.person_sharp,
                            color: design.buttonTextColor,
                            size: 24.0,
                          ),
                          onPressed: () async {
                            await _openProfileDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (onboardingNext is! SizedBox)
            Padding(
              padding: const EdgeInsets.fromLTRB(18.0, 0.0, 18.0, 14.0),
              child: onboardingNext,
            ),
        ],
      ),
    );
  }
}
