import 'dart:convert';
import 'dart:html' as html;

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

String _tableHtml(String title, List<List<String>> rows) {
  final tableRows = rows
      .map(
        (row) => '<tr>${row.map((cell) => '<td>${_escapeHtml(cell)}</td>').join()}</tr>',
      )
      .join();
  return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>${_escapeHtml(title)}</title>
    <style>
      body { font-family: Arial, sans-serif; padding: 24px; }
      h1 { font-size: 20px; margin-bottom: 16px; }
      table { border-collapse: collapse; width: 100%; }
      td { border: 1px solid #d0d7de; padding: 6px 8px; font-size: 12px; }
    </style>
  </head>
  <body>
    <h1>${_escapeHtml(title)}</h1>
    <table>$tableRows</table>
  </body>
</html>
''';
}

Future<void> exportReportExcelImpl({
  required String filename,
  required String title,
  required List<List<String>> rows,
}) async {
  final htmlContent = _tableHtml(title, rows);
  final bytes = utf8.encode(htmlContent);
  final blob = html.Blob([bytes], 'application/vnd.ms-excel;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
}

Future<void> exportReportPdfImpl({
  required String filename,
  required String title,
  required List<List<String>> rows,
}) async {
  final htmlContent = _tableHtml(title, rows);
  final newWindow = html.window.open('', '_blank');
  final popup = newWindow as dynamic;
  popup.document.write(htmlContent);
  popup.document.close();
  popup.focus();
  popup.print();
}
