import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../backend/rest/api_client.dart';
import 'commercial_repository.dart';
import 'debts_repository.dart';

Future<Uint8List> debtPdf(Map<String, dynamic> record, String currency) async {
  final data = jsonObject(record['data']),
      party = jsonObject(data['counterparty'] ?? {});
  final font = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
      ),
      bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
      );
  final pdf = pw.Document(title: 'Начальные взаиморасчёты', creator: 'М-учёт');
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(base: font, bold: bold),
      footer: (context) => pw.Text(
        'Внутренний регистр. Не является первичным документом или платёжным поручением. Подписи не проставлены. ${context.pageNumber}/${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8),
      ),
      build: (_) => [
        pw.Text(
          'Начальные взаиморасчёты',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Фирма: ${record['companyName'] ?? record['company_id']}'),
        pw.Text('Контрагент: ${party['name'] ?? record['counterparty_id']}'),
        if (party['identifier'] != null)
          pw.Text('БИН / ИИН: ${party['identifier']}'),
        pw.Text('${debtTypes[record['type']]} · ${record['business_date']}'),
        pw.Text(
          '${debtStatuses[record['status']]} · Версия ${record['version']}',
        ),
        pw.Text('Снимок данных: ${record['snapshotAt'] ?? ''}'),
        pw.SizedBox(height: 12),
        pw.Text(
          'Начальный остаток: ${moneyText(record['total'] as num, currency)}',
        ),
        pw.Text(
          'Текущая задолженность: ${moneyText(record['remaining'] as num, currency)}',
        ),
        pw.Text('Аванс: ${moneyText(record['advance'] as num, currency)}'),
        pw.Text(
          'Фактически получено: ${moneyText(record['received'] as num, currency)}',
        ),
        pw.Text(
          'Фактически выплачено: ${moneyText(record['paidOut'] as num, currency)}',
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Дата', 'Движение', 'Сумма', 'Состояние'],
          data: [
            for (final p in (record['payments'] as List).map(jsonObject))
              [
                p['business_date'],
                p['direction'] == 'IN' ? 'Поступление' : 'Списание',
                moneyText(p['amount'] as num, currency),
                p['voided'] == true ? 'Отменено' : 'Учтено',
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if ((data['notes'] as String? ?? '').isNotEmpty)
          pw.Text('Примечание: ${data['notes']}'),
      ],
    ),
  );
  return pdf.save();
}
