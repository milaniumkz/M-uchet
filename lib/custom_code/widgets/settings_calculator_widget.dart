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

class SettingsCalculatorWidget extends StatefulWidget {
  final double? width;
  final double? height;

  const SettingsCalculatorWidget({
    Key? key,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<SettingsCalculatorWidget> createState() =>
      _SettingsCalculatorWidgetState();
}

class _SettingsCalculatorWidgetState extends State<SettingsCalculatorWidget> {
  String _display = '0';
  double _acc = 0;
  String _op = '';
  bool _resetNext = false;

  void _press(String v) {
    setState(() {
      if ('0123456789'.contains(v)) {
        if (_resetNext || _display == '0') {
          _display = v;
          _resetNext = false;
        } else {
          _display += v;
        }
      } else if (v == '.') {
        if (!_display.contains('.')) _display += '.';
      } else if (v == 'C') {
        _display = '0';
        _acc = 0;
        _op = '';
        _resetNext = false;
      } else if (v == '+/-') {
        if (_display.startsWith('-')) {
          _display = _display.substring(1);
        } else if (_display != '0') {
          _display = '-$_display';
        }
      } else if (v == '%') {
        final val = double.tryParse(_display) ?? 0;
        _display = (val / 100).toString();
      } else if (['+', '-', '×', '÷'].contains(v)) {
        _compute();
        _op = v;
        _resetNext = true;
      } else if (v == '=') {
        _compute();
        _op = '';
        _resetNext = true;
      }
    });
  }

  void _compute() {
    final val = double.tryParse(_display) ?? 0;
    if (_op.isEmpty) {
      _acc = val;
      return;
    }
    switch (_op) {
      case '+':
        _acc = _acc + val;
        break;
      case '-':
        _acc = _acc - val;
        break;
      case '×':
        _acc = _acc * val;
        break;
      case '÷':
        _acc = val == 0 ? 0 : _acc / val;
        break;
    }
    _display = _acc.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionsHelper.has('settings.calculator')) {
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
                  child: const Icon(Icons.calculate, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Калькулятор',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: FlutterFlowTheme.of(context).primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Быстрые расчеты',
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
          Expanded(
            child: Center(
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: FlutterFlowTheme.of(context).alternate),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      alignment: Alignment.centerRight,
                      child: Text(
                        _display,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(),
                    _row(['C', '+/-', '%', '÷']),
                    _row(['7', '8', '9', '×']),
                    _row(['4', '5', '6', '-']),
                    _row(['1', '2', '3', '+']),
                    _row(['0', '.', '=', '']),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> keys) {
    return Row(
      children: keys.map((k) {
        if (k.isEmpty) {
          return Expanded(child: Container());
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ElevatedButton(
              onPressed: () => _press(k),
              child: Text(k),
            ),
          ),
        );
      }).toList(),
    );
  }
}
