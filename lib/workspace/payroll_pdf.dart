import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../backend/rest/api_client.dart';
import 'commercial_repository.dart';
import 'payroll_repository.dart';

Future<Uint8List> payrollPdf(
  Map<String, dynamic> record,
  String currency,
) async {
  final d = jsonObject(record['data']),
      i = jsonObject(d['input']),
      person = jsonObject(i['employee']),
      c = jsonObject(d['calculation']);
  final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
      ),
      bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
      );
  final pdf = pw.Document(
    title: 'Расчётный листок ${record['month']}',
    creator: 'М-учёт',
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Text(
        'Внутренний расчётный листок. Не является платёжным поручением или налоговой декларацией. Подписи не проставлены. ${context.pageNumber}/${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8),
      ),
      build: (_) => [
        pw.Text(
          'Расчётный листок · ${record['month']}',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Работодатель: ${jsonObject(i['company'])['legalName'] ?? ''} · БИН/ИИН ${jsonObject(i['company'])['identifier'] ?? ''}',
        ),
        pw.Text(person['name'] as String),
        pw.Text('ИИН: ${person['identifier'] ?? 'Не указан'}'),
        pw.Text(
          'Статус: ${payrollStatuses[record['status']]} · дата начисления ${d['businessDate']}',
        ),
        pw.SizedBox(height: 16),
        pw.Text('Начислено: ${moneyText(c['gross'] as num, currency)}'),
        pw.Text(
          'Удержания: ${moneyText(c['employeeWithholdings'] as num, currency)}',
        ),
        pw.Text(
          'К выплате: ${moneyText(c['net'] as num, currency)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Фактически выплачено: ${moneyText(record['paid'] as num, currency)}',
        ),
        pw.Text(
          'Остаток: ${moneyText(record['outstanding'] as num, currency)}',
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Платёж', 'Расчётная база', 'Сумма'],
          data: (c['breakdown'] as List)
              .map(jsonObject)
              .map(
                (row) => [
                  payrollChargeLabels[row['code']] ?? row['code'],
                  moneyText(row['base'] as num, currency),
                  moneyText(row['amount'] as num, currency),
                ],
              )
              .toList(),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Расходы работодателя сверх начисления: ${moneyText(c['employerContributions'] as num, currency)}',
        ),
        pw.Text(
          'Общий расход фирмы: ${moneyText(c['totalCost'] as num, currency)}',
        ),
        pw.Text('Правила: ${c['ruleVersion']}'),
        pw.Text(
          'Социальные отчисления округлены вверх до тенге; ОСМС — по правилу 50 тиын. Прочие суммы — с учётной точностью 0,01 тенге.',
        ),
        pw.Text(d['note'] as String? ?? ''),
      ],
    ),
  );
  return pdf.save();
}
