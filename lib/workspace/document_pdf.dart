import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../backend/rest/api_client.dart';
import 'commercial_repository.dart';

Future<Uint8List> documentPdf(Map<String, dynamic> doc, String currency) async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  final data = jsonObject(doc['data']),
      issuer = jsonObject(data['issuer']),
      party = jsonObject(data['counterparty']);
  final purchase = isPurchaseKind(doc['kind']);
  final pdf = pw.Document(
      title: '${documentLabels[doc['kind']]} ${doc['number']}',
      author: issuer['legal_name'] as String,
      creator: 'М-учёт');
  pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(35),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (context) =>
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('${documentLabels[doc['kind']]} № ${doc['number']}',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(
                'от ${doc['business_date']} · ${documentStatuses[doc['status']]}'),
            pw.SizedBox(height: 18)
          ]),
      footer: (context) =>
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Divider(),
            pw.Text(
                'Внутренняя печатная форма. Не является ЭСФ или фискальным чеком. Подписи не проставлены.',
                style: const pw.TextStyle(fontSize: 8)),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8)))
          ]),
      build: (context) => [
            pw.Text(
                '${purchase ? 'Покупатель' : 'Исполнитель'}: ${issuer['legal_name']}'),
            pw.Text('БИН / ИИН: ${issuer['identifier'] ?? ''}'),
            if ((issuer['legal_address'] as String? ?? '').isNotEmpty)
              pw.Text('Адрес: ${issuer['legal_address']}'),
            if ((issuer['bank_iban'] as String? ?? '').isNotEmpty)
              pw.Text(
                  'IBAN: ${issuer['bank_iban']} · БИК: ${issuer['bank_bic'] ?? ''}'),
            pw.SizedBox(height: 10),
            pw.Text(
                '${purchase ? (doc['kind'] == 'PURCHASE_GOODS' ? 'Поставщик' : 'Исполнитель') : 'Заказчик'}: ${party['name']}'),
            pw.Text('БИН / ИИН: ${party['identifier'] ?? party['bin'] ?? ''}'),
            if (party['address'] is String)
              pw.Text('Адрес: ${party['address']}'),
            if (data['externalNumber'] != '')
              pw.Text('Документ контрагента: ${data['externalNumber']}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
                columnWidths: const {
                  0: pw.FixedColumnWidth(160),
                  1: pw.FixedColumnWidth(45),
                  2: pw.FixedColumnWidth(40),
                  3: pw.FixedColumnWidth(70),
                  4: pw.FixedColumnWidth(70),
                  5: pw.FixedColumnWidth(65),
                  6: pw.FixedColumnWidth(75)
                },
                headers: [
                  'Наименование',
                  'Ед.',
                  'Кол-во',
                  'Цена без НДС',
                  'Без НДС',
                  'НДС',
                  'Итого'
                ],
                data: (data['items'] as List).map((raw) {
                  final line = jsonObject(raw);
                  return [
                    '${line['description']}${line['warehouseName'] == null ? '' : '\nСклад: ${line['warehouseName']}'}',
                    line['unit'],
                    line['quantity'],
                    moneyText(line['unitPrice'] as num, currency),
                    moneyText(line['net'] as num, currency),
                    moneyText(line['vat'] as num, currency),
                    moneyText(line['total'] as num, currency)
                  ];
                }).toList(),
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                cellPadding: const pw.EdgeInsets.all(4)),
            pw.SizedBox(height: 18),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                          'Без НДС: ${moneyText(data['net'] as num, currency)}'),
                      pw.Text(
                          'НДС: ${moneyText(data['vat'] as num, currency)}'),
                      pw.SizedBox(height: 8),
                      pw.Text(
                          'Итого: ${moneyText(data['total'] as num, currency)}',
                          style: pw.TextStyle(
                              fontSize: 15, fontWeight: pw.FontWeight.bold))
                    ])),
            if (data['vatReason'] != '')
              pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 14),
                  child: pw.Text('Основание без НДС: ${data['vatReason']}')),
            if (data['note'] != '')
              pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 14),
                  child: pw.Text(data['note'] as String)),
            pw.SizedBox(height: 30),
            pw.Text(
                'Руководитель: ${issuer['director_name'] ?? ''} ____________________'),
            pw.SizedBox(height: 14),
            pw.Text(
                'Бухгалтер: ${issuer['accountant_name'] ?? ''} ____________________'),
            pw.SizedBox(height: 22),
            pw.Text('_______________________________________________')
          ]));
  return pdf.save();
}
