import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uchet_s_d/utils/device_management_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('resolveCurrentDeviceId persists generated id', () async {
    final first = await resolveCurrentDeviceId();
    final second = await resolveCurrentDeviceId();

    expect(first, isNotEmpty);
    expect(second, first);
  });

  test('lock command blocks device and requires logout', () async {
    final result = await executeDeviceCommand(
      command: {'command_type': 'LOCK_APP', 'reason': 'admin'},
    );
    final prefs = await SharedPreferences.getInstance();

    expect(result.status, DeviceCommandStatus.executed);
    expect(result.requiresLogout, isTrue);
    expect(prefs.getString('ff_device_status'), DeviceStatus.blocked.storageValue);
  });

  test('wipe command clears persisted state', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ff_role', 'admin');
    await prefs.setString('ff_device_id', 'device-1');

    final result = await executeDeviceCommand(
      command: {'command_type': 'WIPE_DATA'},
      prefs: prefs,
    );

    expect(result.wasWiped, isTrue);
    expect(prefs.getString('ff_role'), isNull);
  });
}
