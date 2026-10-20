import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/utils/security_hash.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:async';
import '/index.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'reg_page_model.dart';
export 'reg_page_model.dart';

class RegPageWidget extends StatefulWidget {
  const RegPageWidget({super.key});

  static String routeName = 'regPage';
  static String routePath = '/regPage';

  @override
  State<RegPageWidget> createState() => _RegPageWidgetState();
}

class _RegPageWidgetState extends State<RegPageWidget> {
  static const String _pendingSignupUidKey = 'ff_pending_signup_uid';
  static const String _pendingSignupRoleKey = 'ff_pending_signup_role';
  static const String _pendingSignupPasswordHashKey =
      'ff_pending_signup_password_hash';

  late RegPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final List<Map<String, dynamic>> _companyPositions = [];
  bool _loadingPositions = false;
  String _lastCompanyId = '';
  StreamSubscription<User?>? _authRecoverySub;
  bool _recoveringPendingSignup = false;

  bool _looksLikeRole(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    if (type == 'position') return false;
    if (type == 'role') return true;
    if (data['permissions'] is List) return true;
    if (data['allowed_company_ids'] is List) return true;
    return false;
  }

  bool _looksLikePosition(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().toLowerCase().trim();
    return type == 'position';
  }

  String _tokenErrorMessage(String errorCode) {
    switch (errorCode.trim()) {
      case 'account_already_exists':
        return 'Аккаунт уже существует';
      case 'account_not_found':
        return 'Аккаунт не найден';
      case 'invalid_credentials':
        return 'Неверные данные для входа';
      case 'password_is_required':
        return 'Введите пароль';
      case 'phone_is_required':
        return 'Введите номер телефона';
      case 'token_creation_failed':
        return 'Не удалось создать токен. Повторите попытку.';
      default:
        return 'Не удалось выполнить регистрацию. Повторите попытку.';
    }
  }

  String? _extractCustomToken(ApiCallResponse? response) {
    final body = response?.jsonBody ?? const {};
    final token = getJsonField(body, r'''$.token''').toString().trim();
    if (!(response?.succeeded ?? false) || token.isEmpty || token == 'null') {
      return null;
    }
    return token.split('.').length == 3 ? token : null;
  }

  Future<bool> _completeSignupAuth(ApiCallResponse? response) async {
    final body = response?.jsonBody ?? const {};
    final token = _extractCustomToken(response);
    if (token == null) {
      final errorCode = getJsonField(body, r'''$.error''').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tokenErrorMessage(errorCode))),
      );
      return false;
    }

    try {
      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithJwtToken(context, token);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка входа. Повторите попытку.'),
          ),
        );
        return false;
      }
      return true;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось выполнить вход после регистрации.'),
        ),
      );
      return false;
    }
  }

  Future<void> _syncCurrentUserDocument(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    try {
      final userRecord = await UsersRecord.getDocumentOnce(
          UsersRecord.collection.doc(normalizedUid));
      currentUserDocument = userRecord;
    } catch (_) {
      // Keep signup resilient even if the document stream has not caught up yet.
    }
  }

  Future<void> _ensureSignedInUserReady() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) return;
    try {
      await authUser.getIdToken(true);
    } catch (_) {
      // Best-effort only.
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _storePendingSignup({
    required String uid,
    required String role,
    required String passwordHash,
  }) async {
    final prefs = FFAppState().prefs;
    await prefs?.setString(_pendingSignupUidKey, uid.trim());
    await prefs?.setString(_pendingSignupRoleKey, role.trim());
    await prefs?.setString(
      _pendingSignupPasswordHashKey,
      passwordHash.trim(),
    );
  }

  Future<void> _clearPendingSignup() async {
    final prefs = FFAppState().prefs;
    await prefs?.remove(_pendingSignupUidKey);
    await prefs?.remove(_pendingSignupRoleKey);
    await prefs?.remove(_pendingSignupPasswordHashKey);
  }

  Future<void> _finalizeSignedInOwner({
    required String ownerUid,
    required String role,
    String? password,
    String? passwordHash,
  }) async {
    final resolvedHash = (passwordHash ?? '').trim().isNotEmpty
        ? passwordHash!.trim()
        : hashSensitiveValue(password ?? '');
    if (resolvedHash.isEmpty) {
      throw Exception('Пустой хэш пароля');
    }
    await _ensureSignedInUserReady();
    final userRef = UsersRecord.collection.doc(ownerUid);
    await userRef.set({
      ...createUsersRecordData(
        uid: ownerUid,
        createdTime: getCurrentTimestamp,
        phoneNumber: ownerUid,
        role: role,
        bloc: false,
      ),
      'password_hash': resolvedHash,
      'password_migrated_at': FieldValue.serverTimestamp(),
      if (role == 'owner') 'onboarding_complete': false,
    }, SetOptions(merge: true));
    await _syncCurrentUserDocument(ownerUid);
    await _clearPendingSignup();
    FFAppState().role = role;
    safeSetState(() {});
    GoRouter.of(context).clearRedirectLocation();
    if (!context.mounted) {
      return;
    }
    context.go(
      role == 'owner' ? CompanySetupWidget.routePath : HomeWidget.routePath,
    );
  }

  Future<void> _recoverPendingSignupIfNeeded() async {
    if (_recoveringPendingSignup || !mounted) return;
    final prefs = FFAppState().prefs;
    final pendingUid = (prefs?.getString(_pendingSignupUidKey) ?? '').trim();
    final pendingRole = (prefs?.getString(_pendingSignupRoleKey) ?? '').trim();
    final pendingPasswordHash =
        (prefs?.getString(_pendingSignupPasswordHashKey) ?? '').trim();
    final authUid = (FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (pendingUid.isEmpty ||
        pendingPasswordHash.isEmpty ||
        authUid.isEmpty ||
        authUid != pendingUid) {
      return;
    }

    _recoveringPendingSignup = true;
    try {
      await _finalizeSignedInOwner(
        ownerUid: pendingUid,
        role: pendingRole.isEmpty ? 'owner' : pendingRole,
        passwordHash: pendingPasswordHash,
      );
    } catch (_) {
      // Silent retry path for partially completed signup.
    } finally {
      _recoveringPendingSignup = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RegPageModel());
    _model.passwordVisibility1 = false;
    _model.passwordVisibility2 = false;

    _model.emailAddressTextController1 ??= TextEditingController();
    _model.emailAddressFocusNode1 ??= FocusNode();

    _model.emailAddressMask1 = MaskTextInputFormatter(mask: '+7 ### ### ## ##');
    _model.passwordTextController1 ??= TextEditingController();
    _model.passwordFocusNode1 ??= FocusNode();

    _model.emailAddressTextController2 ??= TextEditingController();
    _model.emailAddressFocusNode2 ??= FocusNode();

    _model.emailAddressMask2 = MaskTextInputFormatter(mask: '+7 ### ### ## ##');
    _model.idTextController ??= TextEditingController();
    _model.idFocusNode ??= FocusNode();

    _model.passwordTextController2 ??= TextEditingController();
    _model.passwordFocusNode2 ??= FocusNode();

    _model.idTextController?.addListener(_onCompanyIdChanged);
    _authRecoverySub = FirebaseAuth.instance.authStateChanges().listen((_) {
      unawaited(_recoverPendingSignupIfNeeded());
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      safeSetState(() {});
      unawaited(_recoverPendingSignupIfNeeded());
    });
  }

  @override
  void dispose() {
    _authRecoverySub?.cancel();
    _model.idTextController?.removeListener(_onCompanyIdChanged);
    _model.dispose();

    super.dispose();
  }

  Future<void> _onCompanyIdChanged() async {
    final companyId = _model.idTextController?.text.trim() ?? '';
    if (companyId.isEmpty) {
      if (_lastCompanyId.isNotEmpty) {
        setState(() {
          _lastCompanyId = '';
          _companyPositions.clear();
          _model.dropDownValue2 = null;
        });
      }
      return;
    }
    if (companyId == _lastCompanyId) return;
    _lastCompanyId = companyId;
    setState(() {
      _loadingPositions = true;
      _companyPositions.clear();
      _model.dropDownValue2 = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('roles')
          .where('idCompany', isEqualTo: companyId)
          .get();
      final allRows = snap.docs.map((d) {
        final data = d.data();
        return {'id': d.id, ...data};
      }).toList();
      final positions = allRows.where(_looksLikePosition).toList();
      final roles = allRows.where(_looksLikeRole).toList();
      final normalizedPositions = positions.map((position) {
        final roleId = (position['role_id'] ?? '').toString().trim();
        final linkedRole = roles.firstWhere(
          (role) => (role['id'] ?? '').toString() == roleId,
          orElse: () => {},
        );
        final roleName = (position['role_name'] ?? '').toString().trim();
        final linkedRoleName = (linkedRole['name'] ?? '').toString().trim();
        final rolePermissions = (position['role_permissions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            (linkedRole['permissions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        final roleCompanyIds = (position['role_allowed_company_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            (linkedRole['allowed_company_ids'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[];
        return {
          'id': position['id'],
          'type': 'position',
          'name': position['name'],
          'role_id': roleId.isNotEmpty ? roleId : (linkedRole['id'] ?? ''),
          'role_name': roleName.isNotEmpty ? roleName : linkedRoleName,
          'role_permissions': rolePermissions,
          'role_allowed_company_ids': roleCompanyIds,
        };
      }).toList();
      if (normalizedPositions.isEmpty) {
        normalizedPositions.addAll(
          roles.map(
            (role) => {
              'id': role['id'],
              'type': 'position',
              'name': role['name'],
              'role_id': role['id'],
              'role_name': role['name'],
              'role_permissions': (role['permissions'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[],
              'role_allowed_company_ids': (role['allowed_company_ids'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const <String>[],
            },
          ),
        );
      }
      normalizedPositions.sort((a, b) =>
          (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      if (mounted) {
        setState(() {
          _companyPositions
            ..clear()
            ..addAll(normalizedPositions);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки должностей')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPositions = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SafeArea(
          top: true,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 8,
                child: Container(
                  width: 100.0,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  alignment: AlignmentDirectional(0.0, -1.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  FFLocalizations.of(context).getText(
                                    'atishnqh' /* Добро пожаловать */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .displaySmall
                                      .override(
                                        font: GoogleFonts.interTight(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .displaySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .displaySmall
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .displaySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .displaySmall
                                            .fontStyle,
                                      ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 12.0, 0.0, 24.0),
                                  child: Text(
                                    FFLocalizations.of(context).getText(
                                      'kiwqvnc9' /* Создайте аккаунт */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 10.0),
                                  child: FlutterFlowDropDown<String>(
                                    controller:
                                        _model.dropDownValueController1 ??=
                                            FormFieldController<String>(
                                      _model.dropDownValue1 ??= 'owner',
                                    ),
                                    options:
                                        List<String>.from(['owner', 'emp']),
                                    optionLabels: [
                                      FFLocalizations.of(context).getText(
                                        '02o5g2ck' /* Владелец бизнеса */,
                                      ),
                                      FFLocalizations.of(context).getText(
                                        'hsdl2yh6' /* Сотрудник */,
                                      )
                                    ],
                                    onChanged: (val) => safeSetState(
                                        () => _model.dropDownValue1 = val),
                                    width:
                                        MediaQuery.sizeOf(context).width * 0.95,
                                    height: 45.0,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                    hintText:
                                        FFLocalizations.of(context).getText(
                                      '1vlgmsq3' /* Выберите роль */,
                                    ),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).primary,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 0.0, 12.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: false,
                                    isMultiSelect: false,
                                  ),
                                ),
                                Stack(
                                  children: [
                                    if (_model.dropDownValue1 == 'owner')
                                      Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 16.0),
                                            child: Container(
                                              width: 370.0,
                                              child: TextFormField(
                                                controller: _model
                                                    .emailAddressTextController1,
                                                focusNode: _model
                                                    .emailAddressFocusNode1,
                                                autofocus: true,
                                                autofillHints: [
                                                  AutofillHints.telephoneNumber
                                                ],
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  labelText: FFLocalizations.of(
                                                          context)
                                                      .getText(
                                                    'w3ks1z7n' /* Номер телефона */,
                                                  ),
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                keyboardType:
                                                    TextInputType.phone,
                                                validator: _model
                                                    .emailAddressTextController1Validator
                                                    .asValidator(context),
                                                inputFormatters: [
                                                  _model.emailAddressMask1
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 16.0),
                                            child: Container(
                                              width: 370.0,
                                              child: TextFormField(
                                                controller: _model
                                                    .passwordTextController1,
                                                focusNode:
                                                    _model.passwordFocusNode1,
                                                autofocus: true,
                                                autofillHints: [
                                                  AutofillHints.password
                                                ],
                                                obscureText:
                                                    !_model.passwordVisibility1,
                                                decoration: InputDecoration(
                                                  labelText: FFLocalizations.of(
                                                          context)
                                                      .getText(
                                                    '52jngx1b' /* Пароль */,
                                                  ),
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                  suffixIcon: InkWell(
                                                    onTap: () async {
                                                      safeSetState(() => _model
                                                              .passwordVisibility1 =
                                                          !_model
                                                              .passwordVisibility1);
                                                    },
                                                    focusNode: FocusNode(
                                                        skipTraversal: true),
                                                    child: Icon(
                                                      _model.passwordVisibility1
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      size: 24.0,
                                                    ),
                                                  ),
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                validator: _model
                                                    .passwordTextController1Validator
                                                    .asValidator(context),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 16.0),
                                            child: FFButtonWidget(
                                              onPressed: () async {
                                                final ownerUid = _model
                                                    .emailAddressTextController1
                                                    .text
                                                    .trim();
                                                final ownerPassword = _model
                                                    .passwordTextController1
                                                    .text;
                                                final role =
                                                    _model.dropDownValue1 ==
                                                            'owner'
                                                        ? 'owner'
                                                        : 'emp';
                                                final authUid = FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid
                                                        .trim() ??
                                                    '';
                                                if (authUid.isNotEmpty &&
                                                    authUid == ownerUid) {
                                                  try {
                                                    await _finalizeSignedInOwner(
                                                      ownerUid: ownerUid,
                                                      role: role,
                                                      passwordHash:
                                                          hashSensitiveValue(
                                                        ownerPassword,
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Ошибка восстановления регистрации: $e',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                  return;
                                                }
                                                try {
                                                  await _storePendingSignup(
                                                    uid: ownerUid,
                                                    role: role,
                                                    passwordHash:
                                                        hashSensitiveValue(
                                                      ownerPassword,
                                                    ),
                                                  );
                                                  _model.token =
                                                      await TokenCall.call(
                                                    phone: ownerUid,
                                                    password: ownerPassword,
                                                    mode: 'signup',
                                                    role: role,
                                                  );

                                                  final signedIn =
                                                      await _completeSignupAuth(
                                                    _model.token,
                                                  );
                                                  if (!signedIn) {
                                                    return;
                                                  }
                                                  await _finalizeSignedInOwner(
                                                    ownerUid: ownerUid,
                                                    role: role,
                                                    passwordHash:
                                                        hashSensitiveValue(
                                                      ownerPassword,
                                                    ),
                                                  );
                                                  safeSetState(() {});
                                                } catch (e) {
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Ошибка завершения регистрации: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'diaru9tk' /* Далее */,
                                              ),
                                              options: FFButtonOptions(
                                                width: 370.0,
                                                height: 44.0,
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                textStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: Colors.white,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                elevation: 3.0,
                                                borderSide: BorderSide(
                                                  color: Colors.transparent,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_model.dropDownValue1 == 'emp')
                                      Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 16.0),
                                            child: Container(
                                              width: 370.0,
                                              child: TextFormField(
                                                controller: _model
                                                    .emailAddressTextController2,
                                                focusNode: _model
                                                    .emailAddressFocusNode2,
                                                autofocus: true,
                                                autofillHints: [
                                                  AutofillHints.telephoneNumber
                                                ],
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  labelText: FFLocalizations.of(
                                                          context)
                                                      .getText(
                                                    'q4url6dh' /* Номер телефона */,
                                                  ),
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                keyboardType:
                                                    TextInputType.phone,
                                                validator: _model
                                                    .emailAddressTextController2Validator
                                                    .asValidator(context),
                                                inputFormatters: [
                                                  _model.emailAddressMask2
                                                ],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 16.0),
                                            child: Container(
                                              width: 370.0,
                                              child: TextFormField(
                                                controller:
                                                    _model.idTextController,
                                                focusNode: _model.idFocusNode,
                                                autofocus: true,
                                                autofillHints: [
                                                  AutofillHints.telephoneNumber
                                                ],
                                                obscureText: false,
                                                decoration: InputDecoration(
                                                  labelText: FFLocalizations.of(
                                                          context)
                                                      .getText(
                                                    'v6lesc6j' /* Индификатор компании */,
                                                  ),
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .alternate,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                keyboardType:
                                                    TextInputType.phone,
                                                validator: _model
                                                    .idTextControllerValidator
                                                    .asValidator(context),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 16.0),
                                            child: Container(
                                              width: 370.0,
                                              child: TextFormField(
                                                controller: _model
                                                    .passwordTextController2,
                                                focusNode:
                                                    _model.passwordFocusNode2,
                                                autofocus: true,
                                                autofillHints: [
                                                  AutofillHints.password
                                                ],
                                                obscureText:
                                                    !_model.passwordVisibility2,
                                                decoration: InputDecoration(
                                                  labelText: FFLocalizations.of(
                                                          context)
                                                      .getText(
                                                    'yscz3zly' /* Пароль */,
                                                  ),
                                                  labelStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  errorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  focusedErrorBorder:
                                                      OutlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      width: 1.0,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  filled: true,
                                                  fillColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                  suffixIcon: InkWell(
                                                    onTap: () async {
                                                      safeSetState(() => _model
                                                              .passwordVisibility2 =
                                                          !_model
                                                              .passwordVisibility2);
                                                    },
                                                    focusNode: FocusNode(
                                                        skipTraversal: true),
                                                    child: Icon(
                                                      _model.passwordVisibility2
                                                          ? Icons
                                                              .visibility_outlined
                                                          : Icons
                                                              .visibility_off_outlined,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      size: 24.0,
                                                    ),
                                                  ),
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                keyboardType: TextInputType
                                                    .visiblePassword,
                                                validator: _model
                                                    .passwordTextController2Validator
                                                    .asValidator(context),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 10.0),
                                            child: FlutterFlowDropDown<String>(
                                              controller: _model
                                                      .dropDownValueController2 ??=
                                                  FormFieldController<String>(
                                                      null),
                                              options: _companyPositions
                                                  .map((r) => (r['name'] ?? '')
                                                      .toString())
                                                  .where((e) =>
                                                      e.trim().isNotEmpty)
                                                  .toList(),
                                              onChanged: (val) => safeSetState(
                                                  () => _model.dropDownValue2 =
                                                      val),
                                              width: MediaQuery.sizeOf(context)
                                                      .width *
                                                  0.95,
                                              height: 45.0,
                                              textStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                              hintText: _loadingPositions
                                                  ? 'Загрузка должностей...'
                                                  : (_companyPositions.isEmpty
                                                      ? 'Должность (нет)'
                                                      : FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                          'ya2xwme6' /* Должность */,
                                                        )),
                                              icon: Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 24.0,
                                              ),
                                              fillColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                              elevation: 2.0,
                                              borderColor:
                                                  FlutterFlowTheme.of(context)
                                                      .primary,
                                              borderWidth: 1.0,
                                              borderRadius: 8.0,
                                              margin: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      12.0, 0.0, 12.0, 0.0),
                                              hidesUnderline: true,
                                              isOverButton: false,
                                              isSearchable: false,
                                              isMultiSelect: false,
                                            ),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 16.0),
                                            child: FFButtonWidget(
                                              onPressed: () async {
                                                final phone = _model
                                                    .emailAddressTextController2
                                                    .text
                                                    .trim();
                                                final pass = _model
                                                    .passwordTextController2
                                                    .text
                                                    .trim();
                                                if (phone.isEmpty ||
                                                    pass.isEmpty) {
                                                  await showDialog(
                                                    context: context,
                                                    builder:
                                                        (alertDialogContext) {
                                                      return AlertDialog(
                                                        content: Text(
                                                            'Введите номер телефона и пароль'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    alertDialogContext),
                                                            child: Text('Ok'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  return;
                                                }
                                                final companyId = _model
                                                    .idTextController.text
                                                    .trim();
                                                if (companyId.isEmpty) {
                                                  await showDialog(
                                                    context: context,
                                                    builder:
                                                        (alertDialogContext) {
                                                      return AlertDialog(
                                                        content: Text(
                                                            'Введите идентификатор компании'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    alertDialogContext),
                                                            child: Text('Ok'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  return;
                                                }

                                                final selectedPositionName =
                                                    (_model.dropDownValue2 ??
                                                            '')
                                                        .trim();
                                                if (selectedPositionName
                                                    .isEmpty) {
                                                  await showDialog(
                                                    context: context,
                                                    builder:
                                                        (alertDialogContext) {
                                                      return AlertDialog(
                                                        content: Text(
                                                            'Выберите должность'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    alertDialogContext),
                                                            child: Text('Ok'),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                  return;
                                                }

                                                final selectedPosition =
                                                    _companyPositions
                                                        .firstWhere(
                                                  (r) =>
                                                      (r['name'] ?? '')
                                                          .toString()
                                                          .trim() ==
                                                      selectedPositionName,
                                                  orElse: () => {},
                                                );
                                                final selectedRoleId =
                                                    (selectedPosition[
                                                                'role_id'] ??
                                                            '')
                                                        .toString();
                                                final selectedRoleName =
                                                    ((selectedPosition['role_name'] ??
                                                                    '')
                                                                .toString()
                                                                .trim()
                                                                .isNotEmpty
                                                            ? (selectedPosition[
                                                                    'role_name'] ??
                                                                '')
                                                            : selectedPositionName)
                                                        .toString();
                                                final selectedPermissions =
                                                    (selectedPosition[
                                                                    'role_permissions']
                                                                as List?)
                                                            ?.map((e) =>
                                                                e.toString())
                                                            .toList() ??
                                                        [];
                                                final selectedRoleCompanies =
                                                    (selectedPosition[
                                                                    'role_allowed_company_ids']
                                                                as List?)
                                                            ?.map((e) =>
                                                                e.toString())
                                                            .where((e) => e
                                                                .trim()
                                                                .isNotEmpty)
                                                            .toList() ??
                                                        [];
                                                final roleCompanyIds =
                                                    selectedRoleCompanies
                                                            .isNotEmpty
                                                        ? {
                                                            ...selectedRoleCompanies,
                                                            companyId,
                                                          }.toList()
                                                        : [companyId];

                                                try {
                                                  _model.token =
                                                      await TokenCall.call(
                                                    phone: phone,
                                                    password: pass,
                                                    mode: 'signup',
                                                    role: 'emp',
                                                  );
                                                  final signedIn =
                                                      await _completeSignupAuth(
                                                    _model.token,
                                                  );
                                                  if (!signedIn) {
                                                    return;
                                                  }
                                                  await _ensureSignedInUserReady();

                                                  final employeeUid = phone;
                                                  final userRef = UsersRecord
                                                      .collection
                                                      .doc(employeeUid);
                                                  await userRef.set(
                                                    {
                                                      ...createUsersRecordData(
                                                        uid: employeeUid,
                                                        createdTime:
                                                            getCurrentTimestamp,
                                                        role: 'emp',
                                                        phoneNumber: phone,
                                                        bloc: false,
                                                        idCompany: companyId,
                                                        activeCompanyId:
                                                            companyId,
                                                        companyIds:
                                                            roleCompanyIds,
                                                      ),
                                                      'password_hash':
                                                          hashSensitiveValue(
                                                        pass,
                                                      ),
                                                      'password_migrated_at':
                                                          FieldValue
                                                              .serverTimestamp(),
                                                      if (selectedRoleId
                                                          .isNotEmpty)
                                                        'role_id':
                                                            selectedRoleId,
                                                      if (selectedRoleName
                                                          .isNotEmpty)
                                                        'role_name':
                                                            selectedRoleName,
                                                      if (selectedPermissions
                                                          .isNotEmpty)
                                                        'role_permissions':
                                                            selectedPermissions,
                                                      if (roleCompanyIds
                                                          .isNotEmpty)
                                                        'role_allowed_company_ids':
                                                            roleCompanyIds,
                                                      if (selectedRoleName
                                                          .isNotEmpty)
                                                        'position':
                                                            selectedPositionName,
                                                      'onboarding_complete':
                                                          true,
                                                      'onboarding_skipped':
                                                          <String, bool>{},
                                                      'onboarding_steps':
                                                          <String, bool>{},
                                                    },
                                                    SetOptions(merge: true),
                                                  );

                                                  try {
                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('companies')
                                                        .doc(companyId)
                                                        .update({
                                                      'members':
                                                          FieldValue.arrayUnion(
                                                              [employeeUid]),
                                                    });
                                                  } on FirebaseException catch (e) {
                                                    final message = e.code ==
                                                            'not-found'
                                                        ? 'Компания не найдена'
                                                        : (e.code ==
                                                                'permission-denied'
                                                            ? 'Нет доступа к компании'
                                                            : 'Ошибка добавления сотрудника в компанию');
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(message),
                                                      ),
                                                    );
                                                    GoRouter.of(context)
                                                        .prepareAuthEvent();
                                                    await authManager.signOut();
                                                    GoRouter.of(context)
                                                        .clearRedirectLocation();
                                                    return;
                                                  }
                                                  if (roleCompanyIds
                                                      .isNotEmpty) {
                                                    for (final cid
                                                        in roleCompanyIds) {
                                                      if (cid == companyId) {
                                                        continue;
                                                      }
                                                      try {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'companies')
                                                            .doc(cid)
                                                            .update({
                                                          'members': FieldValue
                                                              .arrayUnion([
                                                            employeeUid
                                                          ]),
                                                        });
                                                      } catch (_) {}
                                                    }
                                                  }
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          'Сотрудник зарегистрирован'),
                                                    ),
                                                  );
                                                  FFAppState().role = 'emp';
                                                  GoRouter.of(context)
                                                      .clearRedirectLocation();
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  context.go(
                                                    HomeWidget.routePath,
                                                  );
                                                } catch (e) {
                                                  final message = (e
                                                              is FirebaseException &&
                                                          e.code ==
                                                              'permission-denied')
                                                      ? 'Нет доступа или сотрудник уже зарегистрирован'
                                                      : 'Ошибка регистрации сотрудника';
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(message),
                                                    ),
                                                  );
                                                  GoRouter.of(context)
                                                      .prepareAuthEvent();
                                                  await authManager.signOut();
                                                  GoRouter.of(context)
                                                      .clearRedirectLocation();
                                                }
                                              },
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                '1z5za0uy' /* Далее */,
                                              ),
                                              options: FFButtonOptions(
                                                width: 370.0,
                                                height: 44.0,
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 0.0),
                                                iconPadding:
                                                    EdgeInsetsDirectional
                                                        .fromSTEB(
                                                            0.0, 0.0, 0.0, 0.0),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                textStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: Colors.white,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                elevation: 3.0,
                                                borderSide: BorderSide(
                                                  color: Colors.transparent,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),

                                // You will have to add an action on this rich text to go to your login page.
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 12.0, 0.0, 12.0),
                                  child: RichText(
                                    textScaler:
                                        MediaQuery.of(context).textScaler,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: FFLocalizations.of(context)
                                              .getText(
                                            'gb3tybbs' /* Уже есть аккаунт?  */,
                                          ),
                                          style: TextStyle(),
                                        ),
                                        TextSpan(
                                          text: FFLocalizations.of(context)
                                              .getText(
                                            'l34i6gd5' /* Войти */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                          mouseCursor: SystemMouseCursors.click,
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () async {
                                              context.goNamed(
                                                LoginWidget.routeName,
                                                extra: <String, dynamic>{
                                                  kTransitionInfoKey:
                                                      TransitionInfo(
                                                    hasTransition: true,
                                                    transitionType:
                                                        PageTransitionType
                                                            .scale,
                                                    alignment:
                                                        Alignment.bottomCenter,
                                                  ),
                                                },
                                              );
                                            },
                                        )
                                      ],
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
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
              if (responsiveVisibility(
                context: context,
                phone: false,
                tablet: false,
              ))
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Container(
                      width: 100.0,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: Image.network(
                            'https://images.unsplash.com/photo-1514924013411-cbf25faa35bb?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1380&q=80',
                          ).image,
                        ),
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
