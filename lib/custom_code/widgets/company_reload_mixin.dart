import '/auth/firebase_auth/auth_util.dart';
import 'package:flutter/widgets.dart';
import '/utils/user_access_context.dart';

mixin CompanyReloadMixin<T extends StatefulWidget> on State<T> {
  String _lastCompanyKey = '';
  bool _reloadScheduled = false;
  bool _awaitingInitialCompanyContext = false;

  String _buildCompanyKey() {
    final context =
        UserAccessContext.fromData(currentUserDocument?.snapshotData);
    final idsKey = context.companyIds.toList()..sort();
    final allowedKey = context.allowedCompanyIds.toList()..sort();
    final parts = <String>[
      context.primaryCompanyId,
      context.activeCompanyId,
      context.companyScope,
      idsKey.join(','),
      allowedKey.join(','),
    ];
    if (!parts.any((p) => p.isNotEmpty)) return '';
    return parts.join('|');
  }

  void scheduleReloadOnCompanyChange(Future<void> Function() loadData) {
    final key = _buildCompanyKey();
    if (key.isEmpty) {
      _awaitingInitialCompanyContext = true;
      return;
    }
    if (_lastCompanyKey.isEmpty) {
      _lastCompanyKey = key;
      if (_awaitingInitialCompanyContext) {
        _awaitingInitialCompanyContext = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          loadData();
        });
      }
      return;
    }
    if (_reloadScheduled || key == _lastCompanyKey) return;
    _reloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadScheduled = false;
      if (!mounted) return;
      final latestKey = _buildCompanyKey();
      if (latestKey.isEmpty || latestKey == _lastCompanyKey) return;
      _lastCompanyKey = latestKey;
      loadData();
    });
  }

  void markCompanyReloadBaseline() {
    final key = _buildCompanyKey();
    if (key.isNotEmpty) {
      _lastCompanyKey = key;
      _awaitingInitialCompanyContext = false;
    }
  }
}
