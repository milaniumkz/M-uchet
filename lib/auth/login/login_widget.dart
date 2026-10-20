import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import '/utils/security_hash.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'login_model.dart';
export 'login_model.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({
    super.key,
    this.adminMode = false,
  });

  static String routeName = 'Login';
  static String routePath = '/login';
  static String adminRouteName = 'AdminLogin';
  static String adminRoutePath = '/admin-login';

  final bool adminMode;

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  late LoginModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginModel());

    _model.emailAddressTextController ??= TextEditingController();
    _model.emailAddressFocusNode ??= FocusNode();
    _model.passwordTextController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _showTextDialog(String text) async {
    await showDialog(
      context: context,
      builder: (alertDialogContext) {
        return AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(alertDialogContext),
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _showChangePasswordDialog() async {
    final newPassword = TextEditingController();
    final repeatPassword = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Смените временный пароль'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Для безопасности задайте новый пароль перед продолжением.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Новый пароль'),
                  validator: (value) => (value ?? '').trim().length < 6
                      ? 'Минимум 6 символов'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: repeatPassword,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Повторите пароль'),
                  validator: (value) {
                    if ((value ?? '').trim() != newPassword.text.trim()) {
                      return 'Пароли не совпадают';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (saved != true || currentUserReference == null) return false;
      await currentUserReference!.update({
        'password_hash': hashSensitiveValue(newPassword.text.trim()),
        'password_migrated_at': FieldValue.serverTimestamp(),
        'force_password_change': FieldValue.delete(),
        'password_change_required': FieldValue.delete(),
        'temp_password_set_at': FieldValue.delete(),
      });
      return true;
    } finally {
      newPassword.dispose();
      repeatPassword.dispose();
    }
  }

  Future<void> _handleLogin() async {
    if (_model.emailAddressTextController.text == '') {
      await _showTextDialog('Введите номер телефона');
    } else if (_model.passwordTextController.text == '') {
      await _showTextDialog('Введите пароль');
    } else {
      _model.token = await TokenCall.call(
        phone: _model.emailAddressTextController.text,
        password: _model.passwordTextController.text,
        mode: 'login',
      );

      final tokenBody = _model.token?.jsonBody;
      final tokenValue = getJsonField(
        tokenBody,
        r'''$.token''',
      ).toString();
      final tokenError = getJsonField(
        tokenBody,
        r'''$.error''',
      ).toString();

      if (!(_model.token?.succeeded ?? false) ||
          tokenValue.isEmpty ||
          tokenValue == 'null') {
        final message = switch (tokenError) {
          'account_not_found' => 'Аккаунт не найден',
          'invalid_credentials' => 'Неверный номер или пароль',
          'password_is_required' => 'Введите пароль',
          'phone_is_required' => 'Введите телефон или email',
          _ => 'Не удалось выполнить вход. Повторите попытку.',
        };
        await _showTextDialog(message);
        return;
      }

      GoRouter.of(context).prepareAuthEvent();
      final user = await authManager.signInWithJwtToken(
        context,
        tokenValue,
      );
      if (user == null) {
        await _showTextDialog(
            'Ошибка входа. Проверьте данные и попробуйте снова.');
        return;
      }

      if (valueOrDefault<bool>(currentUserDocument?.bloc, false) == true) {
        await _showTextDialog('Сбой в работе Приложения. Ошибка 69');
      } else {
        FFAppState().role = valueOrDefault(currentUserDocument?.role, '');
        safeSetState(() {});
        final mustChangePassword =
            currentUserDocument?.snapshotData['force_password_change'] ==
                    true ||
                currentUserDocument?.snapshotData['password_change_required'] ==
                    true;
        if (mustChangePassword) {
          final changed = await _showChangePasswordDialog();
          if (!changed) {
            GoRouter.of(context).prepareAuthEvent();
            await authManager.signOut();
            GoRouter.of(context).clearRedirectLocation();
            return;
          }
        }
        final role = valueOrDefault<String>(currentUserDocument?.role, '');
        final companyId =
            valueOrDefault<String>(currentUserDocument?.idCompany, '').trim();
        if (companyId.isEmpty) {
          if (role == 'owner') {
            context.goNamedAuth(CompanySetupWidget.routeName, context.mounted);
          } else {
            await _showTextDialog(
              'Доступ к компании не назначен. Обратитесь к владельцу.',
            );
            GoRouter.of(context).prepareAuthEvent();
            await authManager.signOut();
            GoRouter.of(context).clearRedirectLocation();
          }
        } else {
          final adminLogin = widget.adminMode ||
              GoRouterState.of(context).uri.queryParameters['admin'] == '1';
          if (adminLogin) {
            context.goNamedAuth(HomeAdminWidget.routeName, context.mounted);
          } else {
            context.goNamedAuth(HomeWidget.routeName, context.mounted);
          }
        }
      }
    }

    safeSetState(() {});
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    final theme = FlutterFlowTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = MediaQuery.sizeOf(context).width < 1100.0;
    final accent = const Color(0xFFC8A06A);
    final bgGradient = isDark
        ? const [
            Color(0xFF0B0E14),
            Color(0xFF111722),
            Color(0xFF090B10),
          ]
        : const [
            Color(0xFFFFFCF7),
            Color(0xFFF6EFE4),
            Color(0xFFF1E4D2),
          ];
    final cardColor = isDark ? const Color(0xFF141922) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF252B37) : const Color(0xFFE7D8C4);
    final titleColor = isDark ? Colors.white : const Color(0xFF1F1A16);
    final subtitleColor =
        isDark ? const Color(0xFFAFB6C2) : const Color(0xFF74685C);
    final fieldFill =
        isDark ? const Color(0xFF191F2A) : const Color(0xFFFFFBF5);
    final fieldBorder =
        isDark ? const Color(0xFF2D3645) : const Color(0xFFDCCCB7);

    InputDecoration inputDecoration(String label, {Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: subtitleColor),
        filled: true,
        fillColor: fieldFill,
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.0),
          borderSide: BorderSide(color: fieldBorder, width: 1.6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.0),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.0),
          borderSide: BorderSide(color: theme.error, width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18.0),
          borderSide: BorderSide(color: theme.error, width: 1.8),
        ),
      );
    }

    Widget heroPanel() {
      return Container(
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34.0),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x5A000000) : const Color(0x14000000),
              blurRadius: 44.0,
              offset: const Offset(0.0, 18.0),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1400&q=80',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [
                          Color(0xE6121620),
                          Color(0xCC151922),
                          Color(0x99151922),
                        ]
                      : const [
                          Color(0xFFF6E7D0),
                          Color(0xEAFDF8EF),
                          Color(0xD8F8F1E7),
                        ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: bgGradient.first,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            top: true,
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 16.0 : 24.0),
              child: Row(
                children: [
                  Expanded(
                    flex: isCompact ? 10 : 6,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 540.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32.0),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(30.0),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? const Color(0x52000000)
                                          : const Color(0x12000000),
                                      blurRadius: 42.0,
                                      offset: const Offset(0.0, 20.0),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        '5c0uhmth' /* Добро пожаловать */,
                                      ),
                                      style: theme.displaySmall.override(
                                        font: GoogleFonts.interTight(
                                          fontWeight: FontWeight.w800,
                                          fontStyle:
                                              theme.displaySmall.fontStyle,
                                        ),
                                        color: titleColor,
                                        fontSize: isCompact ? 36.0 : 42.0,
                                        letterSpacing: -0.8,
                                        lineHeight: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 12.0),
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        'm69w17go' /* Войдите в аккаунт */,
                                      ),
                                      style: theme.labelMedium.override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w500,
                                          fontStyle:
                                              theme.labelMedium.fontStyle,
                                        ),
                                        color: subtitleColor,
                                        fontSize: 18.0,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                    const SizedBox(height: 24.0),
                                    TextFormField(
                                      controller:
                                          _model.emailAddressTextController,
                                      focusNode: _model.emailAddressFocusNode,
                                      autofocus: true,
                                      autofillHints: const [
                                        AutofillHints.username
                                      ],
                                      obscureText: false,
                                      decoration: inputDecoration(
                                        'Телефон или email',
                                      ),
                                      style: theme.bodyMedium.override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontStyle: theme.bodyMedium.fontStyle,
                                        ),
                                        color: titleColor,
                                        letterSpacing: 0.0,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _model
                                          .emailAddressTextControllerValidator
                                          .asValidator(context),
                                    ),
                                    const SizedBox(height: 16.0),
                                    TextFormField(
                                      controller: _model.passwordTextController,
                                      focusNode: _model.passwordFocusNode,
                                      autofocus: true,
                                      autofillHints: const [
                                        AutofillHints.password
                                      ],
                                      obscureText: !_model.passwordVisibility,
                                      decoration: inputDecoration(
                                        FFLocalizations.of(context).getText(
                                          'dbx6n1gd' /* Пароль */,
                                        ),
                                        suffixIcon: InkWell(
                                          onTap: () async {
                                            safeSetState(() =>
                                                _model.passwordVisibility =
                                                    !_model.passwordVisibility);
                                          },
                                          focusNode:
                                              FocusNode(skipTraversal: true),
                                          child: Icon(
                                            _model.passwordVisibility
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: subtitleColor,
                                            size: 24.0,
                                          ),
                                        ),
                                      ),
                                      style: theme.bodyMedium.override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontStyle: theme.bodyMedium.fontStyle,
                                        ),
                                        color: titleColor,
                                        letterSpacing: 0.0,
                                      ),
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      validator: _model
                                          .passwordTextControllerValidator
                                          .asValidator(context),
                                    ),
                                    const SizedBox(height: 16.0),
                                    FFButtonWidget(
                                      onPressed: _handleLogin,
                                      text: FFLocalizations.of(context).getText(
                                        'rvgqhe8k' /* Войти */,
                                      ),
                                      options: FFButtonOptions(
                                        width: double.infinity,
                                        height: 54.0,
                                        padding: EdgeInsets.zero,
                                        iconPadding: EdgeInsets.zero,
                                        color: accent,
                                        textStyle: theme.titleSmall.override(
                                          font: GoogleFonts.interTight(
                                            fontWeight: FontWeight.w700,
                                            fontStyle:
                                                theme.titleSmall.fontStyle,
                                          ),
                                          color: isDark
                                              ? const Color(0xFF16120D)
                                              : Colors.white,
                                          letterSpacing: 0.0,
                                        ),
                                        elevation: 0.0,
                                        borderSide: BorderSide.none,
                                        borderRadius:
                                            BorderRadius.circular(18.0),
                                      ),
                                    ),
                                    const SizedBox(height: 18.0),
                                    RichText(
                                      textScaler:
                                          MediaQuery.of(context).textScaler,
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'h91bvvf3' /* Нету аккаунта?  */,
                                            ),
                                          ),
                                          TextSpan(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'eoyp6qd1' /* Создать аккаунт */,
                                            ),
                                            style: TextStyle(
                                              color: accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () async {
                                                context.pushNamed(
                                                  RegPageWidget.routeName,
                                                  extra: <String, dynamic>{
                                                    kTransitionInfoKey:
                                                        TransitionInfo(
                                                      hasTransition: true,
                                                      transitionType:
                                                          PageTransitionType
                                                              .topToBottom,
                                                    ),
                                                  },
                                                );
                                              },
                                          ),
                                        ],
                                        style: theme.bodyMedium.override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w500,
                                            fontStyle:
                                                theme.bodyMedium.fontStyle,
                                          ),
                                          color: subtitleColor,
                                          letterSpacing: 0.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: 24.0),
                    Expanded(
                      flex: 4,
                      child: heroPanel(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
