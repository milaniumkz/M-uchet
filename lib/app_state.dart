import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/api_requests/api_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    final p = await SharedPreferences.getInstance();
    prefs = p;
    _safeInit(() {
      _role = p.getString('ff_role') ?? _role;
    });
    _safeInit(() {
      _valutaSimvol = p.getString('ff_valutaSimvol') ?? _valutaSimvol;
    });
    _safeInit(() {
      _accountingMode = p.getString('ff_accountingMode') ?? _accountingMode;
    });
    _safeInit(() {
      _userSidebarCollapsed =
          p.getBool('ff_userSidebarCollapsed') ?? _userSidebarCollapsed;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  SharedPreferences? prefs;

  String _role = '';
  String get role => _role;
  set role(String value) {
    _role = value;
    prefs?.setString('ff_role', value);
  }

  String _valutaSimvol = '';
  String get valutaSimvol => _valutaSimvol;
  set valutaSimvol(String value) {
    _valutaSimvol = value;
    prefs?.setString('ff_valutaSimvol', value);
  }

  String _accountingMode = 'Bu';
  String get accountingMode => _accountingMode;
  set accountingMode(String value) {
    _accountingMode = value;
    prefs?.setString('ff_accountingMode', value);
  }

  bool _userSidebarCollapsed = false;
  bool get userSidebarCollapsed => _userSidebarCollapsed;
  set userSidebarCollapsed(bool value) {
    _userSidebarCollapsed = value;
    prefs?.setBool('ff_userSidebarCollapsed', value);
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
