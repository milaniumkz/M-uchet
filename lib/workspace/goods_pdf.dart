import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../backend/rest/api_client.dart';
import 'commercial_repository.dart';
import 'goods_repository.dart';

Future<Uint8List> goodsPdf(Map<String, dynamic> order, String currency) async {
  final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
      ),
      bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
      );
  final d = jsonObject(order['data']),
      issuer = d['issuer'] == null
          ? <String, dynamic>{}
          : jsonObject(d['issuer']),
      party = d['counterparty'] == null
          ? <String, dynamic>{}
          : jsonObject(d['counterparty']);
  final pdf = pw.Document(
    title: 'Товарная продажа ${order['id']}',
    creator: 'М-учёт',
  );
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Text(
        'Внутренняя товарная накладная. Не является утверждённой формой З-2, ЭСФ или фискальным чеком. Подписи не проставлены. ${context.pageNumber}/${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8),
      ),
      build: (_) => [
        pw.Text(
          'Товарная накладная ${d['number'] ?? ''}',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Внутренний идентификатор: ${order['id']}'),
        pw.Text('${d['businessDate']} · ${goodsStatuses[order['status']]}'),
        pw.SizedBox(height: 16),
        pw.Text(
          'Поставщик: ${issuer['legal_name'] ?? ''} · БИН/ИИН ${issuer['identifier'] ?? ''}',
        ),
        pw.Text(
          'Покупатель: ${party['name'] ?? 'Не указан'} · БИН/ИИН ${party['identifier'] ?? ''}',
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Товар / склад', 'Кол-во', 'Цена без НДС', 'НДС', 'Итого'],
          data: (d['items'] as List)
              .map(jsonObject)
              .map(
                (l) => [
                  '${l['productName'] ?? l['productId']}\n${l['warehouseName'] ?? l['warehouseId']}',
                  l['quantity'].toString(),
                  moneyText(l['unitPrice'] as num, currency),
                  moneyText(l['vat'] as num? ?? 0, currency),
                  moneyText(
                    l['total'] as num? ??
                        (l['quantity'] as num) * (l['unitPrice'] as num),
                    currency,
                  ),
                ],
              )
              .toList(),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Без НДС: ${moneyText(d['net'] as num? ?? d['total'] as num, currency)} · НДС: ${moneyText(d['vat'] as num? ?? 0, currency)}',
        ),
        pw.Text(
          'Итого: ${moneyText(d['total'] as num, currency)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(d['vatReason'] as String? ?? ''),
        pw.Text(d['note'] as String? ?? ''),
        pw.SizedBox(height: 24),
        pw.Text(
          'Отпустил: ____________________  Получил: ____________________',
        ),
      ],
    ),
  );
  return pdf.save();
}
