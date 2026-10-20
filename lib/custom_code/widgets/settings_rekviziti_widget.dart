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
import 'package:firebase_auth/firebase_auth.dart';
import '/custom_code/widgets/company_reload_mixin.dart';
import '/utils/effective_company_support.dart';
import '/utils/onboarding_progress.dart';

class SettingsRekvizitiWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SettingsRekvizitiWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<SettingsRekvizitiWidget> createState() =>
      _SettingsRekvizitiWidgetState();
}

class _SettingsRekvizitiWidgetState extends State<SettingsRekvizitiWidget>
    with CompanyReloadMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;
  bool _saving = false;
  Map<String, dynamic>? _data;
  final _company = TextEditingController();
  final _bin = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  String _companyDisplayName(Map<String, dynamic> data) {
    const fields = [
      'name',
      'nameCompany',
      'name_Company',
      'company_name',
      'title',
      'companyTitle',
    ];
    for (final field in fields) {
      final value = (data[field] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'компания') {
        return value;
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _company.dispose();
    _bin.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _data = null);
        return;
      }
      final effectiveCompanyId = resolveEffectiveCompanyId(
        userData: currentUserDocument?.snapshotData,
        fallbackUserId: user.uid,
      );

      final snap = await _firestore
          .collection('company_profile')
          .where('idCompany', isEqualTo: effectiveCompanyId)
          .limit(1)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        _data = {'id': snap.docs.first.id, ...data};
        _company.text = _companyDisplayName(data);
        _bin.text = (data['bin'] ?? '').toString();
        _address.text = (data['address'] ?? '').toString();
        _phone.text = (data['phone'] ?? '').toString();
        _email.text = (data['email'] ?? '').toString();
      } else {
        final companySnap = await _firestore
            .collection('companies')
            .doc(effectiveCompanyId)
            .get(
              const GetOptions(source: Source.serverAndCache),
            );
        final companyData = companySnap.data() ?? const <String, dynamic>{};
        _data = null;
        _company.text = _companyDisplayName(companyData);
        _bin.text = (companyData['bin'] ?? '').toString();
        _address.text = (companyData['address'] ?? '').toString();
        _phone.text = (companyData['phone'] ?? '').toString();
        _email.text = (companyData['email'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('Error loading rekviziti: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final user = _auth.currentUser;
    if (user == null) return;
    final effectiveCompanyId = resolveEffectiveCompanyId(
      userData: currentUserDocument?.snapshotData,
      fallbackUserId: user.uid,
    );
    if (effectiveCompanyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Компания не выбрана')),
      );
      return;
    }

    setState(() => _saving = true);

    final data = {
      'name': _company.text.trim(),
      'bin': _bin.text.trim(),
      'address': _address.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'idCompany': effectiveCompanyId,
      'user_id': user.uid,
      'updated_at': FieldValue.serverTimestamp(),
    };

    try {
      final profileDocId = (_data?['id'] ?? effectiveCompanyId).toString();
      await _firestore.collection('company_profile').doc(profileDocId).set({
        ...data,
        if (_data == null) 'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('companies').doc(effectiveCompanyId).set({
        'name': data['name'],
        'bin': data['bin'],
        'address': data['address'],
        'phone': data['phone'],
        'email': data['email'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await currentUserReference?.update({
        'name_Company': data['name'],
        'idCompany': effectiveCompanyId,
        'activeCompanyId': effectiveCompanyId,
        'companyIds': FieldValue.arrayUnion([effectiveCompanyId]),
        'onboarding_steps.companies': true,
      });

      FirestoreQueryCache.instance
          .invalidateCompanyCollection('company_profile', effectiveCompanyId);
      OnboardingProgress.invalidate(authUid: user.uid);
      await _loadData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Реквизиты сохранены')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить реквизиты: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    scheduleReloadOnCompanyChange(_loadData);
    if (!PermissionsHelper.has('settings.rekviziti')) {
      return PermissionsHelper.noAccess();
    }
    return ResponsiveFrame(
      backgroundColor: const Color(0xFFF7F8FA),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
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
                      'Реквизиты компании',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _field(_company, 'Наименование'),
                    _field(_bin, 'БИН/ИНН'),
                    _field(_address, 'Адрес'),
                    _field(_phone, 'Телефон'),
                    _field(_email, 'Email'),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Сохранение...' : 'Сохранить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
