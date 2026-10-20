// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/auth/firebase_auth/auth_util.dart';
import '/utils/country_profile.dart';
import '/utils/effective_company_support.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class SettingsValutaWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SettingsValutaWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<SettingsValutaWidget> createState() => _SettingsValutaWidgetState();
}

class _SettingsValutaWidgetState extends State<SettingsValutaWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  bool _saving = false;
  List<Map<String, dynamic>> _currencies = [];
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _symbol = TextEditingController();
  String _countryCode = 'KZ';
  String _companyCurrency = 'KZT';
  List<Map<String, dynamic>> _availableCurrencies = [];

  String _effectiveCompanyId(String fallbackUserId) {
    return resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: fallbackUserId,
    );
  }

  bool _matchesCurrentCountry(Map<String, dynamic> data) {
    final explicit =
        (data['country_code'] ?? data['countryCode'] ?? '').toString().trim();
    final profile = countryProfileFromData(data);
    if (explicit.isEmpty && _countryCode == 'KZ') return true;
    return profile.countryCode == _countryCode;
  }

  bool _isGlobalOrCurrentCompany(
    Map<String, dynamic> data,
    String companyId,
    String uid,
  ) {
    final idCompany = (data['idCompany'] ?? '').toString().trim();
    final userId = (data['user_id'] ?? data['userId'] ?? '').toString().trim();
    return idCompany.isEmpty || idCompany == companyId || userId == uid;
  }

  List<Map<String, dynamic>> _dedupeCurrencies(
    Iterable<Map<String, dynamic>> items, {
    String? preferCompanyId,
  }) {
    final byCode = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final code = normalizeCurrencyCode(
        (item['code'] ?? item['kod'] ?? '').toString(),
        fallback: '',
      );
      if (code.isEmpty || code == _companyCurrency) continue;
      final rawSymbol =
          (item['symbol'] ?? item['simvol'] ?? currencySymbolForCode(code))
              .toString()
              .trim();
      final symbol = normalizeCurrencyCode(rawSymbol, fallback: '') == code
          ? currencySymbolForCode(code)
          : rawSymbol;
      final normalized = {
        ...item,
        'code': code,
        'kod': code,
        'name': (item['name'] ?? item['title'] ?? code).toString(),
        'title': (item['title'] ?? item['name'] ?? code).toString(),
        'symbol': symbol,
        'simvol': symbol,
      };
      final current = byCode[code];
      if (current == null) {
        byCode[code] = normalized;
        continue;
      }
      final itemCompany = (normalized['idCompany'] ?? '').toString().trim();
      final currentCompany = (current['idCompany'] ?? '').toString().trim();
      if (preferCompanyId != null &&
          itemCompany == preferCompanyId &&
          currentCompany != preferCompanyId) {
        byCode[code] = normalized;
      }
    }
    final result = byCode.values.toList()
      ..sort((a, b) =>
          (a['code'] ?? '').toString().compareTo((b['code'] ?? '').toString()));
    return result;
  }

  List<Map<String, dynamic>> _fallbackCurrencyOptions() {
    const codes = ['KZT', 'TJS', 'USD', 'EUR', 'RUB', 'CNY'];
    return codes
        .where((code) => code != _companyCurrency)
        .map(
          (code) => {
            'code': code,
            'kod': code,
            'name': code,
            'title': code,
            'symbol': currencySymbolForCode(code),
            'simvol': currencySymbolForCode(code),
          },
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _symbol.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _currencies = []);
        return;
      }
      final effectiveCompanyId = _effectiveCompanyId(user.uid);
      final profileSnap = effectiveCompanyId.isEmpty
          ? null
          : await _firestore
              .collection('company_profile')
              .doc(effectiveCompanyId)
              .get(const GetOptions(source: Source.serverAndCache));
      final profileData = profileSnap?.data() ?? const <String, dynamic>{};
      final countryProfile = countryProfileFromData(profileData);
      _countryCode = countryProfile.countryCode;
      _companyCurrency = normalizeCurrencyCode(
        (profileData['base_currency'] ??
                profileData['company_currency'] ??
                profileData['valuta'])
            ?.toString(),
        fallback: countryProfile.baseCurrency,
      );

      final snap = await _firestore
          .collection('valuta')
          .get(const GetOptions(source: Source.serverAndCache));
      setState(() {
        final all = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .map((data) => {
                  ...data,
                  'code': (data['kod'] ?? data['code'] ?? '').toString(),
                  'name': (data['title'] ?? data['name'] ?? '').toString(),
                  'symbol': (data['simvol'] ?? data['symbol'] ?? '').toString(),
                })
            .toList();
        final available = _dedupeCurrencies(
          all.where((data) => _matchesCurrentCountry(data)).where(
              (data) => (data['idCompany'] ?? '').toString().trim().isEmpty),
        );
        _availableCurrencies =
            available.isNotEmpty ? available : _fallbackCurrencyOptions();
        _currencies = _dedupeCurrencies(
          all.where((data) => _matchesCurrentCountry(data)).where(
                (data) => _isGlobalOrCurrentCompany(
                    data, effectiveCompanyId, user.uid),
              ),
          preferCompanyId: effectiveCompanyId,
        );
      });
    } catch (e) {
      print('Error loading currencies: $e');
    } finally {
      setState(() => _loading = false);
    }
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

  Future<void> _openAddCurrencyDialog() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (_availableCurrencies.isEmpty) {
      await _loadData();
    }
    final options = _availableCurrencies.isNotEmpty
        ? List<Map<String, dynamic>>.from(_availableCurrencies)
        : _fallbackCurrencyOptions();
    String? selectedCode =
        options.isNotEmpty ? (options.first['code'] ?? '').toString() : null;
    final rateController = TextEditingController(text: '1');
    String? dialogError;
    bool? saved;
    try {
      saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final selected = options.firstWhere(
              (item) => (item['code'] ?? '').toString() == selectedCode,
              orElse: () => const <String, dynamic>{},
            );
            return AlertDialog(
              title: const Text('Добавить валюту'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedCode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Валюта',
                        border: OutlineInputBorder(),
                      ),
                      items: options
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: (item['code'] ?? '').toString(),
                              child: Text(
                                '${item['code'] ?? ''} — ${item['name'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        selectedCode = value;
                        dialogError = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rateController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Курс к $_companyCurrency',
                        helperText:
                            '1 ${selected['code'] ?? ''} = ... $_companyCurrency',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setDialogState(() {
                        dialogError = null;
                      }),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          final code = (selectedCode ?? '').trim();
                          final selectedCurrency = options.firstWhere(
                            (item) =>
                                (item['code'] ?? '').toString().trim() == code,
                            orElse: () => const <String, dynamic>{},
                          );
                          final name = (selectedCurrency['name'] ??
                                  selectedCurrency['title'] ??
                                  '')
                              .toString()
                              .trim();
                          final symbol = (selectedCurrency['symbol'] ??
                                  selectedCurrency['simvol'] ??
                                  '')
                              .toString()
                              .trim();
                          final rate = _parseRate(rateController.text);
                          if (code.isEmpty || name.isEmpty || symbol.isEmpty) {
                            setDialogState(() {
                              dialogError = 'Выберите валюту из списка';
                            });
                            return;
                          }
                          if (rate <= 0) {
                            setDialogState(() {
                              dialogError = 'Укажите курс больше нуля';
                            });
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        },
                  child: const Text('Добавить'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      rateController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть окно валюты: $e')),
        );
      }
      return;
    }
    if (saved != true || selectedCode == null) {
      rateController.dispose();
      return;
    }
    final rate = _parseRate(rateController.text);
    rateController.dispose();
    if (rate <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите курс больше нуля')),
        );
      }
      return;
    }
    final selected = options.firstWhere(
      (item) => (item['code'] ?? '').toString() == selectedCode,
      orElse: () => const <String, dynamic>{},
    );
    final code = (selected['code'] ?? '').toString().trim().toUpperCase();
    final name =
        (selected['name'] ?? selected['title'] ?? code).toString().trim();
    final rawSymbol =
        (selected['symbol'] ?? selected['simvol'] ?? code).toString().trim();
    final symbol = normalizeCurrencyCode(rawSymbol, fallback: '') == code
        ? currencySymbolForCode(code)
        : rawSymbol;
    if (code.isEmpty || name.isEmpty || symbol.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите валюту из списка')),
        );
      }
      return;
    }
    final effectiveCompanyId = _effectiveCompanyId(user.uid);
    setState(() => _saving = true);
    try {
      final existing = await _firestore
          .collection('valuta')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .where('kod', isEqualTo: code)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));
      final payload = {
        'kod': code,
        'title': name,
        'simvol': symbol,
        'code': code,
        'name': name,
        'symbol': symbol,
        'country_code': _countryCode,
        'countryCode': _countryCode,
        'idCompany': effectiveCompanyId,
        'user_id': user.uid,
        'base_currency': _companyCurrency,
        'exchange_rate_to_company': rate,
        'exchangeRateToCompany': rate,
        'exchange_rate_date': FieldValue.serverTimestamp(),
        'exchange_rate_source': 'manual_settings',
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference
            .set(payload, SetOptions(merge: true));
      } else {
        await _firestore.collection('valuta').add({
          ...payload,
          'created_at': FieldValue.serverTimestamp(),
        });
      }
      FirestoreQueryCache.instance.invalidateCollection('valuta');
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('valuta', effectiveCompanyId);
      _code.clear();
      _name.clear();
      _symbol.clear();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Валюта сохранена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить валюту: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('settings.currency')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).accent1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.currency_exchange_outlined,
                      color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Валюты',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Справочник валют',
                        style: TextStyle(
                          fontSize: 13,
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Базовая валюта компании: $_companyCurrency',
                    style: TextStyle(
                      fontSize: 13,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saving ? null : _openAddCurrencyDialog,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Добавить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Список валют',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _currencies.isEmpty
                              ? Center(
                                  child: Text(
                                    'Валюты не найдены',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _currencies.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_currencies[index]);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Row(
      children: const [
        _HeaderCell('Код', flex: 1),
        _HeaderCell('Название', flex: 3),
        _HeaderCell('Символ', flex: 1),
        _HeaderCell('Курс', flex: 1),
      ],
    );
  }

  Widget _tableRow(Map<String, dynamic> item) {
    final code = (item['code'] ?? '').toString();
    final name = (item['name'] ?? '').toString();
    final symbol = (item['symbol'] ?? '').toString();
    final rate = item['exchange_rate_to_company'] ??
        item['exchangeRateToCompany'] ??
        item['rate'];
    final rateText = rate == null || rate.toString().isEmpty
        ? (code == _companyCurrency ? '1' : '-')
        : rate.toString();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: FlutterFlowTheme.of(context)
                    .alternate
                    .withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          _Cell(code.isEmpty ? '-' : code, flex: 1, bold: true),
          _Cell(name.isEmpty ? '-' : name, flex: 3),
          _Cell(symbol.isEmpty ? '-' : symbol, flex: 1),
          _Cell(rateText, flex: 1),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell(this.text, {required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: FlutterFlowTheme.of(context).secondaryText)),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;

  const _Cell(this.text, {required this.flex, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          color: const Color(0xFF1F2A37),
        ),
      ),
    );
  }
}
