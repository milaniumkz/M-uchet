import 'package:flutter/material.dart';

Future<void> exportTransactionsCsvImpl({
  required String filename,
  required List<List<String>> rows,
}) async {
  debugPrint(
    'Export is only supported on web. Requested: $filename (${rows.length} rows)',
  );
}
