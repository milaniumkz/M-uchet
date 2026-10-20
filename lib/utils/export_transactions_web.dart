import 'dart:convert';
import 'dart:html' as html;

String _escapeCsv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _toCsv(List<List<String>> rows) {
  return rows
      .map((row) => row.map((cell) => _escapeCsv(cell)).join(';'))
      .join('\n');
}

Future<void> exportTransactionsCsvImpl({
  required String filename,
  required List<List<String>> rows,
}) async {
  final csv = _toCsv(rows);
  final bytes = utf8.encode('\uFEFF$csv');
  final blob = html.Blob(
    [bytes],
    'text/csv;charset=utf-8',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}
