import 'package:shared_preferences/shared_preferences.dart';

import '/app_state.dart';
import '/backend/firestore_cache.dart';

const Set<String> _cryptoWipePrefKeys = {
  'ff_role',
  'ff_valutaSimvol',
  'ff_accountingMode',
  'ff_userSidebarCollapsed',
  'ff_device_id',
  'ff_device_status',
  'ff_device_last_command_sync',
  'ff_device_lock_reason',
};

Future<void> performCryptoWipe({
  SharedPreferences? prefs,
  Future<void> Function()? onBeforeReset,
  Future<void> Function()? onAfterReset,
}) async {
  final resolvedPrefs = prefs ?? await SharedPreferences.getInstance();
  if (onBeforeReset != null) {
    await onBeforeReset();
  }
  for (final key in _cryptoWipePrefKeys) {
    await resolvedPrefs.remove(key);
  }
  await resolvedPrefs.clear();
  FirestoreQueryCache.instance.clear();
  FFAppState.reset();
  if (onAfterReset != null) {
    await onAfterReset();
  }
}

