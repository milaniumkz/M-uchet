import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/auth/firebase_auth/auth_util.dart';

enum EditSection { budget, goods, transactions, other }

class EditingHelper {
  static String? _stepKeyBySection(EditSection section) {
    switch (section) {
      case EditSection.budget:
        return 'budgets';
      case EditSection.goods:
        return 'products';
      case EditSection.transactions:
        return 'accounts';
      case EditSection.other:
        return null;
    }
  }

  static String? _stepKeyByContext(BuildContext context) {
    final path = GoRouterState.of(context).uri.path.toLowerCase();
    if (path.contains('/companysetup')) return 'companies';
    if (path.contains('/roli')) return 'roles';
    if (path.contains('/orgstructura')) return 'org';
    if (path.contains('/hrcontrols')) return 'employees';
    if (path.contains('/scheta')) return 'accounts';
    if (path.contains('/sclad')) return 'warehouses';
    if (path.contains('/shop')) return 'shops';
    if (path.contains('/tovar')) return 'products';
    if (path.contains('/statras')) return 'budgets';
    return null;
  }

  static Map<String, bool> _lockedSteps() {
    final raw = currentUserDocument?.snapshotData['onboarding_locked_steps'];
    if (raw is Map) {
      return raw.map(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    }
    return {};
  }

  static bool _temporaryEditingOpen() {
    final data = currentUserDocument?.snapshotData ?? const {};
    final enabled = data['temporary_editing_enabled'] == true ||
        data['temporaryEditingEnabled'] == true;
    if (!enabled) return false;
    final rawUntil =
        data['temporary_editing_until'] ?? data['temporaryEditingUntil'];
    DateTime? until;
    if (rawUntil is DateTime) {
      until = rawUntil;
    } else {
      try {
        final dynamic value = rawUntil;
        until = value?.toDate() as DateTime?;
      } catch (_) {
        until = DateTime.tryParse(rawUntil?.toString() ?? '');
      }
    }
    return until != null && until.isAfter(DateTime.now());
  }

  static bool isLocked({
    EditSection section = EditSection.other,
    BuildContext? context,
  }) {
    if (_temporaryEditingOpen()) return false;
    final step = _stepKeyBySection(section) ??
        (context != null ? _stepKeyByContext(context) : null);
    final bySteps = _lockedSteps();
    if (step != null && bySteps.isNotEmpty) {
      return bySteps[step] == true;
    }
    final legacyLocked =
        currentUserDocument?.snapshotData['data_locked'] == true ||
            currentUserDocument?.snapshotData['onboarding_complete'] == true;
    if (bySteps.isEmpty) return legacyLocked;
    return false;
  }

  static bool canEdit({EditSection section = EditSection.other}) =>
      !isLocked(section: section);

  static bool canEditExisting({EditSection section = EditSection.other}) {
    if (isLocked(section: section)) return false;
    return true;
  }

  static bool guard(BuildContext context,
      {EditSection section = EditSection.other}) {
    return true;
  }

  static bool guardEdit(BuildContext context,
      {EditSection section = EditSection.other}) {
    if (isLocked(section: section, context: context)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Этот блок зафиксирован после завершения первичного ввода.'),
        ),
      );
      return false;
    }
    return true;
  }
}
