// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:cloud_firestore/cloud_firestore.dart';

Future<double> calculateTotalDecome(
  List<DocumentReference> transactionRefs,
) async {
  double totalIncome = 0;

  if (transactionRefs.isEmpty) {
    return 0;
  }

  for (final ref in transactionRefs) {
    try {
      final snapshot = await ref.get();

      if (!snapshot.exists) continue;

      final data = Map<String, dynamic>.from(snapshot.data() as Map);

      final type = data['type']?.toString().toLowerCase();
      final amount = _amountCompany(data);

      // Проверяем, что это расход
      if (type == 'decome' && amount != 0) {
        totalIncome += amount;
      }
    } catch (e) {
      print('Error loading transaction: $e');
    }
  }

  return totalIncome;
}

double _amountCompany(Map<String, dynamic> data) {
  final value =
      data['amount_company'] ?? data['amountCompany'] ?? data['summa'];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
}
