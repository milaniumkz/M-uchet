import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/utils/audit_log_service.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_wallet_support.dart';
import '/utils/accounting_accounts.dart';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'add_schet_model.dart';
export 'add_schet_model.dart';

class _CompanyOption {
  final String id;
  final String name;

  const _CompanyOption({
    required this.id,
    required this.name,
  });
}

class AddSchetWidget extends StatefulWidget {
  const AddSchetWidget({super.key});

  @override
  State<AddSchetWidget> createState() => _AddSchetWidgetState();
}

class _AddSchetWidgetState extends State<AddSchetWidget> {
  late AddSchetModel _model;
  String? _selectedCompanyId;
  String? _ownerKind;
  String? _currencyValue;
  DateTime? _openingBalanceDate;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddSchetModel());

    _model.textController1 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();

    _model.textController2 ??= TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();

    _model.textController3 ??= TextEditingController();
    _model.textFieldFocusNode3 ??= FocusNode();

    _selectedCompanyId = _effectiveCompanyId();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  String _effectiveCompanyId() {
    final raw = (currentUserDocument?.idCompany ?? '').trim();
    final active = (currentUserDocument?.activeCompanyId ?? '').trim();
    final companyIds = (currentUserDocument?.companyIds ?? const <String>[])
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (raw == '__all__') {
      if (active.isNotEmpty) return active;
      if (companyIds.isNotEmpty) return companyIds.first;
      return currentUserUid;
    }
    if (raw.isNotEmpty) return raw;
    if (active.isNotEmpty) return active;
    if (companyIds.isNotEmpty) return companyIds.first;
    return currentUserUid;
  }

  String _companyNameFromData(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString().trim();
    return name.isEmpty ? 'Компания' : name;
  }

  Future<List<_CompanyOption>> _loadMissingCompanies(Set<String> ids) async {
    if (ids.isEmpty) {
      return const <_CompanyOption>[];
    }
    final options = <_CompanyOption>[];
    for (final chunk in splitCompanyIdsForWhereIn(ids.toList()..sort())) {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .where(FieldPath.documentId, whereIn: chunk)
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in snap.docs) {
        final data = doc.data();
        options.add(
          _CompanyOption(
            id: doc.id,
            name: _companyNameFromData(data),
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
          .get(const GetOptions(source: Source.serverAndCache));
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = (data['idCompany'] ?? doc.id).toString().trim();
        final name = (data['name'] ?? '').toString().trim();
        if (id.isNotEmpty && name.isNotEmpty) {
          options.add(_CompanyOption(id: id, name: name));
        }
      }
    }
    return options;
  }

  Future<String> _companyBaseCurrency(String companyId) async {
    if (companyId.trim().isEmpty) return 'KZT';
    final snap = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    var data = snap.data();
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
    data ??= const <String, dynamic>{};
    final profile = countryProfileFromData(data);
    return normalizeCurrencyCode(
      (data['base_currency'] ?? data['company_currency'] ?? data['valuta'])
          ?.toString(),
      fallback: profile.baseCurrency,
    );
  }

  Future<String> _companyCountryCode(String companyId) async {
    if (companyId.trim().isEmpty) return 'KZ';
    final snap = await FirebaseFirestore.instance
        .collection('company_profile')
        .doc(companyId)
        .get(const GetOptions(source: Source.serverAndCache));
    var data = snap.data();
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
    data ??= const <String, dynamic>{};
    return countryProfileFromData(data).countryCode;
  }

  double _parseRate(String raw) {
    return double.tryParse(
          raw
              .replaceAll('\u00A0', ' ')
              .replaceAll(' ', '')
              .replaceAll(',', '.'),
        ) ??
        0;
  }

  Future<void> _openQuickAddCurrencyDialog({
    required String companyId,
    required String countryCode,
  }) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final symbolController = TextEditingController();
    final rateController = TextEditingController(text: '1');
    String? dialogError;

    try {
      final savedCode = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Добавить валюту'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Код валюты',
                        hintText: 'Например USD',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Например Доллар США',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: symbolController,
                      decoration: const InputDecoration(
                        labelText: 'Символ',
                        hintText: r'Например $',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Курс к основной валюте компании',
                        hintText: 'Например 450',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError!,
                        style: TextStyle(
                          color: FlutterFlowTheme.of(context).error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () async {
                    final code = normalizeCurrencyCode(
                      codeController.text,
                      fallback: '',
                    );
                    final name = nameController.text.trim();
                    final rawSymbol = symbolController.text.trim();
                    final symbol =
                        normalizeCurrencyCode(rawSymbol, fallback: '') == code
                            ? currencySymbolForCode(code)
                            : rawSymbol;
                    final rate = _parseRate(rateController.text);

                    if (code.isEmpty ||
                        name.isEmpty ||
                        symbol.isEmpty ||
                        rate <= 0) {
                      setDialogState(() {
                        dialogError =
                            'Заполните код, название, символ и курс больше нуля.';
                      });
                      return;
                    }

                    try {
                      final existing = await FirebaseFirestore.instance
                          .collection('valuta')
                          .where('idCompany', isEqualTo: companyId)
                          .where('kod', isEqualTo: code)
                          .limit(1)
                          .get(const GetOptions(
                              source: Source.serverAndCache));
                      final baseCurrency =
                          await _companyBaseCurrency(companyId);
                      final payload = {
                        'kod': code,
                        'code': code,
                        'title': name,
                        'name': name,
                        'simvol': symbol,
                        'symbol': symbol,
                        'country_code': countryCode,
                        'countryCode': countryCode,
                        'idCompany': companyId,
                        'user_id': currentUserUid,
                        'base_currency': baseCurrency,
                        'exchange_rate_to_company': rate,
                        'exchangeRateToCompany': rate,
                        'exchange_rate_date': FieldValue.serverTimestamp(),
                        'exchange_rate_source': 'manual_account_form',
                        'updated_at': FieldValue.serverTimestamp(),
                      };
                      if (existing.docs.isNotEmpty) {
                        await existing.docs.first.reference
                            .set(payload, SetOptions(merge: true));
                      } else {
                        await FirebaseFirestore.instance
                            .collection('valuta')
                            .add({
                          ...payload,
                          'created_at': FieldValue.serverTimestamp(),
                        });
                      }
                      FirestoreQueryCache.instance
                          .invalidateCollection('valuta');
                      FirestoreQueryCache.instance
                          .invalidateCompanyCollection('valuta', companyId);
                      Navigator.pop(dialogContext, code);
                    } catch (e) {
                      setDialogState(() {
                        dialogError = 'Не удалось сохранить валюту: $e';
                      });
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        ),
      );
      if (savedCode == null || !mounted) return;
      setState(() => _currencyValue = savedCode);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Валюта добавлена')),
      );
    } finally {
      codeController.dispose();
      nameController.dispose();
      symbolController.dispose();
      rateController.dispose();
    }
  }

  Widget _companyDropdown() {
    if (currentUserUid.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .where('members', arrayContains: currentUserUid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final seedIds = <String>{
          valueOrDefault<String>(currentUserDocument?.idCompany, '').trim(),
          valueOrDefault<String>(currentUserDocument?.activeCompanyId, '')
              .trim(),
          ...((currentUserDocument?.companyIds ?? const <String>[])
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)),
        }..removeWhere((id) => id.isEmpty || id == '__all__');

        final streamedOptions = docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map);
          return _CompanyOption(
            id: doc.id,
            name: _companyNameFromData(data),
          );
        }).toList();

        final streamedIds = streamedOptions.map((item) => item.id).toSet();
        final missingIds = seedIds.difference(streamedIds);

        Widget buildSelector(List<_CompanyOption> options) {
          if (options.isEmpty) {
            return const SizedBox.shrink();
          }
          final defaultId = _effectiveCompanyId();
          final selected = (_selectedCompanyId?.trim().isNotEmpty ?? false)
              ? _selectedCompanyId!
              : defaultId;
          final normalizedSelected = options.any((o) => o.id == selected)
              ? selected
              : options.first.id;
          if ((_selectedCompanyId ?? '').trim() != normalizedSelected) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _selectedCompanyId = normalizedSelected);
            });
          }
          final selectedName = options
                  .firstWhereOrNull((item) => item.id == normalizedSelected)
                  ?.name ??
              'Компания';
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: normalizedSelected,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Компания, куда добавляется счет',
                    helperText: 'Счет будет сохранен в выбранную компанию.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  items: options
                      .map(
                        (o) => DropdownMenuItem<String>(
                          value: o.id,
                          child: Text(
                            o.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedCompanyId = val;
                      _currencyValue = null;
                    });
                  },
                ),
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(4.0, 8.0, 4.0, 0.0),
                  child: Text(
                    'Новый счет будет добавлен в компанию: $selectedName',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodySmall
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                  ),
                ),
              ],
            ),
          );
        }

        if (seedIds.isEmpty && streamedOptions.isEmpty) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<List<List<_CompanyOption>>>(
          future: Future.wait([
            _loadMissingCompanies(missingIds),
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
            final orderedIds = {
              ...streamedOptions.map((item) => item.id),
              ...seedIds,
              ...missingCompanies.map((item) => item.id),
              ...profileNames.map((item) => item.id),
            }.toList();
            final options = orderedIds
                .map((id) => merged[id])
                .whereType<_CompanyOption>()
                .toList();
            return buildSelector(options);
          },
        );
      },
    );
  }

  Widget _ownerKindDropdown() {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
      child: DropdownButtonFormField<String>(
        value: _ownerKind,
        decoration: InputDecoration(
          labelText: 'Тип средств владельца',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: 'card',
            child: Text('Карточный'),
          ),
          DropdownMenuItem(
            value: 'cash',
            child: Text('Наличный'),
          ),
        ],
        onChanged: (val) {
          setState(() => _ownerKind = val);
        },
      ),
    );
  }

  Widget _currencyDropdown() {
    final companyId = (_selectedCompanyId ?? _effectiveCompanyId()).trim();
    return FutureBuilder<String>(
      future: _companyCountryCode(companyId),
      builder: (context, countrySnapshot) {
        final companyCountryCode = countrySnapshot.data ?? 'KZ';
        Widget addButton() {
          return SizedBox(
            height: 48,
            width: 48,
            child: IconButton.filled(
              tooltip: 'Добавить валюту',
              onPressed: companyId.isEmpty
                  ? null
                  : () => _openQuickAddCurrencyDialog(
                        companyId: companyId,
                        countryCode: companyCountryCode,
                      ),
              icon: const Icon(Icons.add_rounded),
            ),
          );
        }

        return StreamBuilder<List<ValutaRecord>>(
          stream: queryValutaRecord(),
          builder: (context, snapshot) {
            final rawItems =
                (snapshot.data ?? const <ValutaRecord>[]).where((item) {
              final data = item.snapshotData;
              final explicit = (data['country_code'] ??
                      data['countryCode'] ??
                      item.countryCode)
                  .toString()
                  .trim();
              if (explicit.isEmpty && companyCountryCode == 'KZ') {
                return true;
              }
              return countryProfileFromData(data).countryCode ==
                  companyCountryCode;
            }).toList();
            final byCode = <String, ValutaRecord>{};
            for (final item in rawItems) {
              final code = normalizeCurrencyCode(item.kod);
              if (code.isEmpty) continue;
              final idCompany =
                  (item.snapshotData['idCompany'] ?? '').toString().trim();
              if (!byCode.containsKey(code) || idCompany == companyId) {
                byCode[code] = item;
              }
            }
            final items = byCode.values.toList()
              ..sort((a, b) => normalizeCurrencyCode(a.kod)
                  .compareTo(normalizeCurrencyCode(b.kod)));
            if (items.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Валюта счета',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          'Нет валют. Добавьте валюту.',
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    addButton(),
                  ],
                ),
              );
            }
            final codes = items
                .map((item) => normalizeCurrencyCode(item.kod))
                .where((code) => code.trim().isNotEmpty)
                .toSet();
            final value = codes.contains(_currencyValue)
                ? _currencyValue!
                : normalizeCurrencyCode(items.first.kod);
            if ((_currencyValue ?? '').isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _currencyValue = value);
              });
            }
            return Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: value,
                      decoration: InputDecoration(
                        labelText: 'Валюта счета',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      items: items
                          .map(
                            (v) => DropdownMenuItem<String>(
                              value: normalizeCurrencyCode(v.kod),
                              child: Text(
                                  '${v.title} (${normalizeCurrencyCode(v.kod)})'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _currencyValue = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  addButton(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    'qavjdeil' /* Добавить счет */,
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
                    _companyDropdown(),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'cl8n8xrn' /* Тип счета */,
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
                            _model.dropDownValue ??= 'nal',
                          ),
                          options: List<String>.from(['nal', 'bank', 'my']),
                          optionLabels: [
                            FFLocalizations.of(context).getText(
                              'z7x305g0' /* Наличные */,
                            ),
                            FFLocalizations.of(context).getText(
                              'v96f53v3' /* Банковский счет  */,
                            ),
                            FFLocalizations.of(context).getText(
                              'yhcdqd4m' /* Средства владельца */,
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
                            '2jrsefte' /* Выберите тип счета */,
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
                        if (_model.dropDownValue == 'my') _ownerKindDropdown(),
                        _currencyDropdown(),
                      ].divide(SizedBox(height: 8.0)),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'scskm4mi' /* Название */,
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
                                '2r7mnp19' /* Например: Главная касса */,
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
                        Text(
                          'Если дата выбрана, операции раньше нее не будут менять текущий остаток счета.',
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
                          'Всего (${currencySymbolForCode(_currencyValue ?? FFAppState().valutaSimvol)})',
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
                                '57s982ob' /* 0 */,
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
                            '3m8k7l0g' /* Заметки */,
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
                                'jfvtu0wl' /* Дополнительная информация... */,
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
                          '1uwd4lba' /* Отменить */,
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
                          final companyId =
                              (_selectedCompanyId ?? _effectiveCompanyId())
                                  .trim();
                          if (companyId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Выберите компанию.'),
                              ),
                            );
                            return;
                          }
                          if (currentUserReference != null &&
                              (currentUserDocument?.idCompany ?? '').trim() !=
                                  companyId) {
                            await currentUserReference!.update({
                              'idCompany': companyId,
                              'activeCompanyId': companyId,
                              'companyScope': 'single',
                            });
                          }
                          if ((_currencyValue ?? '').isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Выберите валюту счета.'),
                              ),
                            );
                            return;
                          }
                          if (_model.dropDownValue == 'my') {
                            if ((_ownerKind ?? '').isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Выберите тип средств владельца.'),
                                ),
                              );
                              return;
                            }
                          }
                          final amount = double.tryParse(_model
                                  .textController2.text
                                  .replaceAll(' ', '')
                                  .replaceAll(',', '.')) ??
                              0.0;
                          try {
                            final companyCurrency =
                                await _companyBaseCurrency(companyId);
                            final accountCurrency = normalizeCurrencyCode(
                              _currencyValue,
                              fallback: companyCurrency,
                            );
                            final newSchetRef = ShetaRecord.collection.doc();
                            final newSchetData = {
                              ...createShetaRecordData(
                                title: _model.textController1.text,
                                tip: _model.dropDownValue,
                                coment: _model.textController3.text,
                                summa: amount,
                                currency: accountCurrency,
                                accountCurrency: accountCurrency,
                                companyCurrency: companyCurrency,
                                openingBalance: amount,
                                openingBalanceDate: _openingBalanceDate,
                                accountType: accountNatureStorageValue(
                                  accountNatureFromValue(
                                    null,
                                    tip: _model.dropDownValue,
                                  ),
                                ),
                                idCompany: companyId,
                                typeUchet: _model.dropDownValueUchet ?? 'Up1',
                                ledgerScope: ledgerScopeFromLegacyValue(
                                  _model.dropDownValueUchet ?? 'Up1',
                                ).storageValue,
                              ),
                              ...mapToFirestore({
                                if (_model.dropDownValue == 'my')
                                  'ownerKind': _ownerKind,
                                'currency': accountCurrency,
                                'account_currency': accountCurrency,
                                'accountCurrency': accountCurrency,
                                'company_currency': companyCurrency,
                                'companyCurrency': companyCurrency,
                              }),
                              ...mapToFirestore(
                                {
                                  'dateCreate': FieldValue.serverTimestamp(),
                                  'isActive': true,
                                  'user_id': currentUserUid,
                                  'user_name': currentUserDisplayName,
                                  'created_by': currentUserUid,
                                  'created_by_name': currentUserDisplayName,
                                },
                              ),
                            };
                            await newSchetRef.set(newSchetData);
                            await AuditLogService.logAction(
                              companyId: companyId,
                              action: 'create',
                              entity: 'account',
                              entityId: newSchetRef.id,
                              entityTitle: _model.textController1.text,
                              after: {
                                ...newSchetData,
                                'opening_balance_entered': amount,
                                'opening_balance_date': _openingBalanceDate,
                              },
                              details: {
                                'message': 'Создан счет',
                                'account_type': _model.dropDownValue,
                                'accounting_mode':
                                    _model.dropDownValueUchet ?? 'Up1',
                              },
                            );
                            final createdAccount =
                                await ShetaRecord.getDocumentOnce(newSchetRef);
                            await ensureWalletForAccountRecord(
                              firestore: FirebaseFirestore.instance,
                              account: createdAccount,
                              fallbackTitle: _model.textController1.text,
                            );

                            _model.userSheta = await querySchetaRecordOnce(
                              parent: currentUserReference,
                              singleRecord: true,
                            ).then((s) => s.firstOrNull);
                            if (_model.userSheta == null &&
                                currentUserReference != null) {
                              final doc =
                                  SchetaRecord.createDoc(currentUserReference!);
                              await doc.set(createSchetaRecordData(
                                nal: 0.0,
                                bank: 0.0,
                                myMoney: 0.0,
                              ));
                              _model.userSheta =
                                  await SchetaRecord.getDocumentOnce(doc);
                            }

                            if (_model.userSheta != null) {
                              if (_model.dropDownValue == 'nal') {
                                await _model.userSheta!.reference.update({
                                  ...mapToFirestore(
                                    {
                                      'nal': FieldValue.increment(amount),
                                    },
                                  ),
                                });
                              } else {
                                if (_model.dropDownValue == 'bank') {
                                  await _model.userSheta!.reference.update({
                                    ...mapToFirestore(
                                      {
                                        'bank': FieldValue.increment(amount),
                                      },
                                    ),
                                  });
                                } else {
                                  await _model.userSheta!.reference.update({
                                    ...mapToFirestore(
                                      {
                                        'myMoney': FieldValue.increment(amount),
                                      },
                                    ),
                                  });
                                }
                              }
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Не удалось создать счет: $e'),
                              ),
                            );
                            return;
                          }

                          await showDialog(
                            context: context,
                            builder: (alertDialogContext) {
                              return AlertDialog(
                                content: Text('Счет создан'),
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

                          safeSetState(() {});
                        },
                        text: FFLocalizations.of(context).getText(
                          'j4omfp7e' /* Добавить */,
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
