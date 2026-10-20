import 'report_export_service_stub.dart'
    if (dart.library.html) 'report_export_service_web.dart';

List<List<String>> buildServiceReportExportRows({
  required String title,
  required List<List<String>> bodyRows,
}) {
  return <List<String>>[
    <String>[title],
    <String>[],
    ...bodyRows,
  ];
}

List<List<String>> buildExpenseReportExportRows({
  required String title,
  required List<List<String>> bodyRows,
}) {
  return <List<String>>[
    <String>[title],
    <String>[],
    ...bodyRows,
  ];
}

Future<void> exportReportExcel({
  required String filename,
  required String title,
  required List<List<String>> rows,
}) {
  return exportReportExcelImpl(filename: filename, title: title, rows: rows);
}

Future<void> exportReportPdf({
  required String filename,
  required String title,
  required List<List<String>> rows,
}) {
  return exportReportPdfImpl(filename: filename, title: title, rows: rows);
}
