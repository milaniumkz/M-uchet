import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../backend/rest/api_client.dart';
import 'commercial_repository.dart';

Future<Uint8List> purchaseReturnPdf(
  Map<String, dynamic> export,
  String currency,
) async {
  final row = jsonObject(export['item']),
      source = jsonObject(export['source']),
      data = jsonObject(row['data']),
      parent = jsonObject(source['data']),
      issuer = jsonObject(parent['issuer']),
      supplier = jsonObject(parent['counterparty']);
  final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
      ),
      bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
      );
  final pdf = pw.Document(
    title: 'Возврат поставщику ${row['number']}',
    author: issuer['legal_name'] as String,
    creator: 'М-учёт',
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(35),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Возврат товаров поставщику № ${row['number']}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Дата: ${row['business_date']} · ${documentStatuses[row['status']]}',
          ),
          pw.SizedBox(height: 16),
        ],
      ),
      footer: (c) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(),
          pw.Text(
            'Внутренняя учётная форма. Не является ЭСФ или фискальным чеком. Подписи не проставлены.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            '${c.pageNumber} / ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (_) => [
        pw.Text('Возвращает покупатель: ${issuer['legal_name']}'),
        pw.Text('БИН / ИИН: ${issuer['identifier'] ?? ''}'),
        pw.Text('Принимает поставщик: ${supplier['name']}'),
        pw.Text(
          'БИН / ИИН: ${supplier['identifier'] ?? supplier['bin'] ?? ''}',
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Основание: поступление ${source['number']} от ${source['business_date']}',
        ),
        pw.Text('Причина: ${row['reason']}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: [
            'Товар / склад',
            'Кол-во',
            'Стоимость запаса',
            'НДС',
            'Уменьшение поставки',
          ],
          data: (data['lines'] as List).map((raw) {
            final l = jsonObject(raw);
            return [
              '${l['productName']}\n${l['warehouseName']}',
              l['quantity'].toString(),
              moneyText(l['cost'] as num, currency),
              moneyText((l['vat'] as num?) ?? 0, currency),
              moneyText((l['total'] as num?) ?? l['cost'] as num, currency),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellPadding: const pw.EdgeInsets.all(4),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Уменьшение стоимости поставки: ${moneyText(data['total'] as num, currency)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Стоимость списанного запаса: ${moneyText(data['cost'] as num, currency)}',
        ),
        pw.Text(
          data['vatTreatment'] == 'PENDING'
              ? 'НДС уменьшает сумму к проверке права на зачёт.'
              : 'НДС входит в стоимость запаса.',
        ),
        pw.Text(
          'Стоимость списания определяется выбранными партиями поступления. Возврат денег оформляется отдельно.',
        ),
        pw.SizedBox(height: 24),
        pw.Text('Передал: __________________    Принял: __________________'),
      ],
    ),
  );
  return pdf.save();
}
