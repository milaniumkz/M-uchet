import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/custom_code/widgets/editing_helper.dart';
import '/utils/audit_log_service.dart';
import '/utils/app_money_format.dart';
import '/utils/country_profile.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_schet_model.dart';
export 'edit_schet_model.dart';

class EditSchetWidget extends StatefulWidget {
  const EditSchetWidget({
    super.key,
    required this.tip,
    required this.title,
    required this.summa,
    required this.coment,
    required this.id,
  });

  final String? tip;
  final String? title;
  final double? summa;
  final String? coment;
  final DocumentReference? id;

  @override
  State<EditSchetWidget> createState() => _EditSchetWidgetState();
}

class _EditSchetWidgetState extends State<EditSchetWidget> {
  late EditSchetModel _model;
  DateTime? _openingBalanceDate;
  String _companyId = '';
  String _companyCountryCode = 'KZ';
  String _companyCurrencyCode = 'KZT';
  String _accountCurrencyCode = 'KZT';
  String _accountCurrencySymbol = '₸';

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditSchetModel());

    _model.textController1 ??= TextEditingController(text: widget!.title);
    _model.textFieldFocusNode1 ??= FocusNode();

    _model.textController2 ??=
        TextEditingController(text: widget!.summa?.toString());
    _model.textFieldFocusNode2 ??= FocusNode();

    _model.textController3 ??= TextEditingController(text: widget!.coment);
    _model.textFieldFocusNode3 ??= FocusNode();

    _loadOpeningBalanceDate();
  }

  Future<void> _loadOpeningBalanceDate() async {
    final ref = widget.id;
    if (ref == null) return;
    final snap = await ref.get();
    if (!snap.exists || !mounted) return;
    final data = snap.data() == null
        ? null
        : Map<String, dynamic>.from(snap.data() as Map);
    final companyId = (data?['idCompany'] ?? '').toString().trim();
    final profile = await _loadCompanyProfile(companyId);
    final companyCurrency = companyCurrencyFromProfileData(profile);
    final raw = data?['opening_balance_date'] ?? data?['openingBalanceDate'];
    final currency = normalizeCurrencyCode(
      (data?['account_currency'] ??
              data?['accountCurrency'] ??
              data?['currency'])
          ?.toString(),
      fallback: companyCurrency,
    );
    final value = raw is Timestamp
        ? raw.toDate()
        : raw is DateTime
            ? raw
            : raw is String
                ? DateTime.tryParse(raw)
                : null;
    setState(() {
      _companyId = companyId;
      _companyCountryCode = countryProfileFromData(profile).countryCode;
      _companyCurrencyCode = companyCurrency;
      _accountCurrencyCode = currency;
      _openingBalanceDate = value;
      _accountCurrencySymbol = moneySymbolForCurrency(_accountCurrencyCode);
    });
  }

  Future<Map<String, dynamic>?> _loadCompanyProfile(String companyId) async {
    if (companyId.isEmpty) return null;
    final direct = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    if (direct.data() != null) return direct.data();
    final byField = await FirebaseFirestore.instance
        .collection('company_profile')
        .where('idCompany', isEqualTo: companyId)
        .limit(1)
        .get(const GetOptions(source: Source.serverAndCache));
    if (byField.docs.isNotEmpty) return byField.docs.first.data();
    return null;
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  Widget _currencyDropdown() {
    return StreamBuilder<List<ValutaRecord>>(
      stream: queryValutaRecord(),
      builder: (context, snapshot) {
        final rawItems =
            (snapshot.data ?? const <ValutaRecord>[]).where((item) {
          final data = item.snapshotData;
          final explicit =
              (data['country_code'] ?? data['countryCode'] ?? item.countryCode)
                  .toString()
                  .trim();
          if (explicit.isEmpty && _companyCountryCode == 'KZ') {
            return true;
          }
          return countryProfileFromData(data).countryCode ==
              _companyCountryCode;
        }).toList();
        final byCode = <String, ValutaRecord>{};
        for (final item in rawItems) {
          final code = normalizeCurrencyCode(item.kod);
          if (code.isEmpty) continue;
          final idCompany =
              (item.snapshotData['idCompany'] ?? '').toString().trim();
          if (!byCode.containsKey(code) || idCompany == _companyId) {
            byCode[code] = item;
          }
        }
        final items = byCode.values.toList()
          ..sort((a, b) => normalizeCurrencyCode(a.kod)
              .compareTo(normalizeCurrencyCode(b.kod)));
        if (items.isEmpty) {
          return Text(
            'Валюта счета: $_accountCurrencyCode',
            style: FlutterFlowTheme.of(context).bodyMedium,
          );
        }
        final codes = items
            .map((item) => normalizeCurrencyCode(item.kod))
            .where((code) => code.trim().isNotEmpty)
            .toSet();
        final value = codes.contains(_accountCurrencyCode)
            ? _accountCurrencyCode
            : (_accountCurrencyCode.trim().isNotEmpty
                ? _accountCurrencyCode
                : normalizeCurrencyCode(items.first.kod,
                    fallback: _companyCurrencyCode));
        return DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Валюта счета',
            helperText: 'Баланс счета показывается в этой валюте.',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          items: [
            if (!codes.contains(value))
              DropdownMenuItem<String>(
                value: value,
                child: Text('$value ($value)'),
              ),
            for (final v in items)
              DropdownMenuItem<String>(
                value: normalizeCurrencyCode(v.kod),
                child: Text('${v.title} (${normalizeCurrencyCode(v.kod)})'),
              ),
          ],
          onChanged: (val) {
            if (val == null) return;
            final code =
                normalizeCurrencyCode(val, fallback: _companyCurrencyCode);
            setState(() {
              _accountCurrencyCode = code;
              _accountCurrencySymbol = moneySymbolForCurrency(code);
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!EditingHelper.canEditExisting()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Редактирование отключено.')),
        );
        Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }
    return Container(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24.0),
            bottomRight: Radius.circular(24.0),
            topLeft: Radius.circular(24.0),
            topRight: Radius.circular(24.0),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FFLocalizations.of(context).getText(
                    'ua7yq78h' /* Редактировать счет */,
                  ),
                  style: FlutterFlowTheme.of(context).headlineMedium.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).primaryText,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'sggqa047' /* Тип счета */,
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                        FlutterFlowDropDown<String>(
                          controller: _model.dropDownValueController ??=
                              FormFieldController<String>(
                            _model.dropDownValue ??= widget!.tip,
                          ),
                          options: List<String>.from(['nal', 'bank', 'my']),
                          optionLabels: [
                            FFLocalizations.of(context).getText(
                              'qlpvs4wf' /* Наличные */,
                            ),
                            FFLocalizations.of(context).getText(
                              'uuki7xgw' /* Банковский счет  */,
                            ),
                            FFLocalizations.of(context).getText(
                              'pmed91k0' /* Средства владельца */,
                            )
                          ],
                          onChanged: (val) =>
                              safeSetState(() => _model.dropDownValue = val),
                          width: MediaQuery.sizeOf(context).width * 1.0,
                          height: 40.0,
                          textStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                          hintText: FFLocalizations.of(context).getText(
                            'qfeipzj9' /* Выберите тип счета */,
                          ),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: FlutterFlowTheme.of(context).secondaryText,
                            size: 24.0,
                          ),
                          fillColor:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          elevation: 2.0,
                          borderColor: FlutterFlowTheme.of(context).alternate,
                          borderWidth: 1.0,
                          borderRadius: 8.0,
                          margin: EdgeInsetsDirectional.fromSTEB(
                              12.0, 0.0, 12.0, 0.0),
                          hidesUnderline: true,
                          isOverButton: false,
                          isSearchable: false,
                          isMultiSelect: false,
                        ),
                        FlutterFlowDropDown<String>(
                          controller: _model.dropDownValueUchetController ??=
                              FormFieldController<String>(
                            _model.dropDownValueUchet ??= 'Up1',
                          ),
                          options: List<String>.from(['Up1', 'Bu']),
                          optionLabels: [
                            'Управленческий (С)',
                            'Бухгалтерский',
                          ],
                          onChanged: (val) => safeSetState(
                              () => _model.dropDownValueUchet = val),
                          width: MediaQuery.sizeOf(context).width * 1.0,
                          height: 40.0,
                          textStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                          hintText: 'Тип учета',
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: FlutterFlowTheme.of(context).secondaryText,
                            size: 24.0,
                          ),
                          fillColor:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          elevation: 2.0,
                          borderColor: FlutterFlowTheme.of(context).alternate,
                          borderWidth: 1.0,
                          borderRadius: 8.0,
                          margin: EdgeInsetsDirectional.fromSTEB(
                              12.0, 0.0, 12.0, 0.0),
                          hidesUnderline: true,
                          isOverButton: false,
                          isSearchable: false,
                          isMultiSelect: false,
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _currencyDropdown(),
                        Text(
                          'Базовая валюта компании: $_companyCurrencyCode',
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                font: GoogleFonts.inter(),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Дата начального остатка',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                        FFButtonWidget(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _openingBalanceDate ?? DateTime.now(),
                              firstDate: DateTime(2010),
                              lastDate: DateTime(DateTime.now().year + 5),
                            );
                            if (picked == null) return;
                            setState(() => _openingBalanceDate = picked);
                          },
                          text: _openingBalanceDate == null
                              ? 'Дата не выбрана'
                              : dateTimeFormat(
                                  'd/M/y',
                                  _openingBalanceDate!,
                                  locale:
                                      FFLocalizations.of(context).languageCode,
                                ),
                          icon: const Icon(Icons.calendar_month_rounded),
                          options: FFButtonOptions(
                            height: 44.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            textStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                ),
                            elevation: 0.0,
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate,
                            ),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        if (_openingBalanceDate != null)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _openingBalanceDate = null),
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            label: const Text('Не ограничивать проводки датой'),
                          ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'jfksiy9w' /* Название */,
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _model.textController1,
                            focusNode: _model.textFieldFocusNode1,
                            autofocus: false,
                            obscureText: false,
                            decoration: InputDecoration(
                              hintText: FFLocalizations.of(context).getText(
                                'hfede2ri' /* Например: Главная касса */,
                              ),
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              contentPadding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 16.0, 16.0, 16.0),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                            validator: _model.textController1Validator
                                .asValidator(context),
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Баланс ($_accountCurrencySymbol)',
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _model.textController2,
                            focusNode: _model.textFieldFocusNode2,
                            autofocus: false,
                            obscureText: false,
                            decoration: InputDecoration(
                              hintText: FFLocalizations.of(context).getText(
                                '52pfogfa' /* 0 */,
                              ),
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              contentPadding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 16.0, 16.0, 16.0),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                            keyboardType: TextInputType.number,
                            validator: _model.textController2Validator
                                .asValidator(context),
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            '7qedvveo' /* Заметки */,
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                        ),
                        Container(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _model.textController3,
                            focusNode: _model.textFieldFocusNode3,
                            autofocus: false,
                            obscureText: false,
                            decoration: InputDecoration(
                              hintText: FFLocalizations.of(context).getText(
                                'utq58n6m' /* Дополнительная информация... */,
                              ),
                              hintStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0x00000000),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              filled: true,
                              fillColor: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              contentPadding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 16.0, 16.0, 16.0),
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                            maxLines: 6,
                            minLines: 4,
                            validator: _model.textController3Validator
                                .asValidator(context),
                          ),
                        ),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                  ].divide(SizedBox(height: 16.0)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          Navigator.pop(context);
                        },
                        text: FFLocalizations.of(context).getText(
                          '1jo0ut2d' /* Отменить */,
                        ),
                        options: FFButtonOptions(
                          height: 48.0,
                          padding: EdgeInsets.all(8.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          textStyle: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                              ),
                          elevation: 0.0,
                          borderSide: BorderSide(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: () async {
                          final oldTip = widget!.tip;
                          final oldSumma = widget!.summa ?? 0.0;
                          final newTip = _model.dropDownValue;
                          final newSumma = double.tryParse(_model
                                  .textController2.text
                                  .replaceAll(' ', '')
                                  .replaceAll(',', '.')) ??
                              0.0;
                          final accountCurrency = normalizeCurrencyCode(
                            _accountCurrencyCode,
                            fallback: _companyCurrencyCode,
                          );
                          final before = {
                            'title': widget!.title,
                            'tip': oldTip,
                            'coment': widget!.coment,
                            'summa': oldSumma,
                            'account_currency': _accountCurrencyCode,
                          };
                          final after = {
                            ...createShetaRecordData(
                              title: _model.textController1.text,
                              tip: newTip,
                              coment: _model.textController3.text,
                              summa: newSumma,
                              currency: accountCurrency,
                              accountCurrency: accountCurrency,
                              companyCurrency: _companyCurrencyCode,
                              openingBalance: newSumma,
                              openingBalanceDate: _openingBalanceDate,
                            ),
                            ...mapToFirestore(
                              {
                                'currency': accountCurrency,
                                'account_currency': accountCurrency,
                                'accountCurrency': accountCurrency,
                                'company_currency': _companyCurrencyCode,
                                'companyCurrency': _companyCurrencyCode,
                                'dateCreate': FieldValue.serverTimestamp(),
                                'user_id': currentUserUid,
                                'user_name': currentUserDisplayName,
                                'updated_by': currentUserUid,
                                'updated_by_name': currentUserDisplayName,
                              },
                            ),
                            if (_openingBalanceDate == null)
                              'opening_balance_date': FieldValue.delete(),
                            if (_openingBalanceDate == null)
                              'openingBalanceDate': FieldValue.delete(),
                          };

                          await widget!.id!.update(after);
                          await AuditLogService.logAction(
                            companyId: '',
                            action: 'update',
                            entity: 'account',
                            entityId: widget!.id!.id,
                            entityTitle: _model.textController1.text,
                            before: before,
                            after: after,
                            details: const {'message': 'Изменен счет'},
                          );

                          String? fieldForTip(String? tip) {
                            if (tip == 'nal') return 'nal';
                            if (tip == 'bank') return 'bank';
                            if (tip == 'my') return 'myMoney';
                            return null;
                          }

                          final updates = <String, double>{};
                          void addDelta(String field, double delta) {
                            if (delta == 0) return;
                            updates[field] = (updates[field] ?? 0) + delta;
                          }

                          final oldField = fieldForTip(oldTip);
                          final newField = fieldForTip(newTip);
                          if (oldField != null) {
                            addDelta(oldField, -oldSumma);
                          }
                          if (newField != null) {
                            addDelta(newField, newSumma);
                          }

                          if (updates.isNotEmpty) {
                            final userScheta = await querySchetaRecordOnce(
                              parent: currentUserReference,
                              singleRecord: true,
                            ).then((s) => s.firstOrNull);
                            if (userScheta != null) {
                              final inc = <String, dynamic>{};
                              updates.forEach((key, delta) {
                                inc[key] = FieldValue.increment(delta);
                              });
                              await userScheta.reference.update({
                                ...mapToFirestore(inc),
                              });
                            }
                          }

                          await showDialog(
                            context: context,
                            builder: (alertDialogContext) {
                              return AlertDialog(
                                content: Text('Счет изменен'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(alertDialogContext),
                                    child: Text('Ok'),
                                  ),
                                ],
                              );
                            },
                          );
                          Navigator.pop(context);
                        },
                        text: FFLocalizations.of(context).getText(
                          'p2vfid4v' /* Сохранить */,
                        ),
                        options: FFButtonOptions(
                          height: 48.0,
                          padding: EdgeInsets.all(8.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color: Color(0xFFB8956A),
                          textStyle:
                              FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                          elevation: 0.0,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ].divide(SizedBox(width: 16.0)),
                ),
              ].divide(SizedBox(height: 24.0)),
            ),
          ),
        ),
      ),
    );
  }
}
