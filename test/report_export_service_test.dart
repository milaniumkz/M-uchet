import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/report_export_service.dart';

void main() {
  test('builds service export rows', () {
    final rows = buildServiceReportExportRows(
      title: 'Service report',
      bodyRows: const [
        ['A', '1'],
      ],
    );
    expect(rows.first.first, 'Service report');
    expect(rows.last, ['A', '1']);
  });

  test('builds expense export rows', () {
    final rows = buildExpenseReportExportRows(
      title: 'Expense report',
      bodyRows: const [
        ['B', '2'],
      ],
    );
    expect(rows.first.first, 'Expense report');
    expect(rows.last, ['B', '2']);
  });
}
