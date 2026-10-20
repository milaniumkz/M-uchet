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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';

class SettingsNalogiWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SettingsNalogiWidget({
    super.key,
    this.width,
    this.height,
  });

  @override
  State<SettingsNalogiWidget> createState() => _SettingsNalogiWidgetState();
}

class _SettingsNalogiWidgetState extends State<SettingsNalogiWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  List<Map<String, dynamic>> _taxes = [];
  final _name = TextEditingController();
  final _rate = TextEditingController();
  final _ndsRate = TextEditingController();
  final _kpnRate = TextEditingController();
  String? _companyProfileId;
  String _vatLabel = 'НДС';
  String _profitTaxLabel = 'КПН';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _ndsRate.dispose();
    _kpnRate.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _taxes = []);
        return;
      }
      final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
      final effectiveCompanyId =
          rawCompanyId.isNotEmpty ? rawCompanyId : user.uid;

      final snap = await _firestore
          .collection('taxes')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .get(const GetOptions(source: Source.serverAndCache));

      final profileSnap = await _firestore
          .collection('company_profile')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .limit(1)
          .get();

      setState(() {
        _taxes = snap.docs.map((d) {
          final raw = d.data();
          final data = Map<String, dynamic>.from(raw);
          return {'id': d.id, ...data};
        }).toList();
        if (profileSnap.docs.isNotEmpty) {
          final profile = profileSnap.docs.first;
          _companyProfileId = profile.id;
          final data = profile.data();
          final countryProfile = countryProfileFromData(data);
          _vatLabel = countryProfile.vatLabel;
          _profitTaxLabel = countryProfile.profitTaxLabel;
          _ndsRate.text = (data['nds_rate'] ?? '').toString();
          _kpnRate.text = (data['kpn_rate'] ?? '').toString();
        } else {
          _vatLabel = 'НДС';
          _profitTaxLabel = 'КПН';
        }
      });
    } catch (e) {
      debugPrint('Error loading taxes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить налоги: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addTax() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название налога')),
      );
      return;
    }
    final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
    final effectiveCompanyId =
        rawCompanyId.isNotEmpty ? rawCompanyId : user.uid;
    final rate = double.tryParse(_rate.text.replaceAll(',', '.')) ?? 0;
    try {
      final existing = await _firestore
          .collection('taxes')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .where('name', isEqualTo: name)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.set({
          'name': name,
          'rate': rate,
          'idCompany': effectiveCompanyId,
          'user_id': user.uid,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await _firestore.collection('taxes').add({
          'name': name,
          'rate': rate,
          'idCompany': effectiveCompanyId,
          'user_id': user.uid,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      FirestoreQueryCache.instance
          .invalidateCompanyCollection('taxes', effectiveCompanyId);
      _name.clear();
      _rate.clear();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Налог сохранен')),
        );
      }
    } catch (e) {
      debugPrint('Error saving tax: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить налог: $e')),
        );
      }
    }
  }

  Future<void> _saveRates() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final rawCompanyId = (currentUserDocument?.idCompany ?? '').trim();
    final effectiveCompanyId =
        rawCompanyId.isNotEmpty ? rawCompanyId : user.uid;

    final nds = double.tryParse(_ndsRate.text.replaceAll(',', '.')) ?? 0;
    final kpn = double.tryParse(_kpnRate.text.replaceAll(',', '.')) ?? 0;

    final data = {
      'idCompany': effectiveCompanyId,
      'nds_rate': nds,
      'kpn_rate': kpn,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (_companyProfileId == null) {
      data['created_at'] = FieldValue.serverTimestamp();
      final docRef =
          _firestore.collection('company_profile').doc(effectiveCompanyId);
      await docRef.set(data, SetOptions(merge: true));
      _companyProfileId = docRef.id;
    } else {
      await _firestore
          .collection('company_profile')
          .doc(_companyProfileId)
          .update(data);
    }

    FirestoreQueryCache.instance
        .invalidateCompanyCollection('company_profile', effectiveCompanyId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ставки обновлены')),
    );
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('settings.taxes')) {
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
                    color: FlutterFlowTheme.of(context)
                        .warning
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.receipt_long, color: Color(0xFFF97316)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Налоги',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Справочник налогов и ставок',
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
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Название'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _rate,
                    decoration: const InputDecoration(labelText: 'Ставка, %'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTax,
                  child: Text('Добавить'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: FlutterFlowTheme.of(context).alternate),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ставки по умолчанию',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Укажите ставки в процентах (например, 16).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ndsRate,
                          decoration:
                              InputDecoration(labelText: '$_vatLabel, %'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _kpnRate,
                          decoration:
                              InputDecoration(labelText: '$_profitTaxLabel, %'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saveRates,
                        child: const Text('Сохранить'),
                      ),
                    ],
                  ),
                ],
              ),
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
                          'Список налогов',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _tableHeader(),
                        const Divider(height: 1),
                        Expanded(
                          child: _taxes.isEmpty
                              ? Center(
                                  child: Text(
                                    'Налоги не найдены',
                                    style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _taxes.length,
                                  itemBuilder: (context, index) {
                                    return _tableRow(_taxes[index]);
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
        _HeaderCell('Название', flex: 3),
        _HeaderCell('Ставка', flex: 1),
      ],
    );
  }

  Widget _tableRow(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString();
    final rate = (item['rate'] ?? 0).toString();
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
          _Cell(name.isEmpty ? '-' : name, flex: 3, bold: true),
          _Cell('$rate%', flex: 1),
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
