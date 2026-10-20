import 'export_transactions_stub.dart'
    if (dart.library.html) 'export_transactions_web.dart';

Future<void> exportTransactionsCsv({
  required String filename,
  required List<List<String>> rows,
}) {
  return exportTransactionsCsvImpl(filename: filename, rows: rows);
}
