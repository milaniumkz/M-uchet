import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/workspace/money_transaction_dialog.dart';
void main(){
 testWidgets('money entry keeps original date, amount and retry key while an outcome is unknown',(tester)async{
  final requests=<http.Request>[];bool? saved;
  final api=BackendClient(origin:Uri.parse('https://api.example.test'),transport:MockClient((request)async{requests.add(request);return http.Response(requests.length==1?'{"error":"temporary"}':'{"id":"saved"}',requests.length==1?503:200,headers:{'content-type':'application/json'});}));api.acceptSession('a'*43);addTearDown(api.close);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()async{saved=await showDialog<bool>(context:context,barrierDismissible:false,builder:(_)=>MoneyTransactionDialog(api:api,companyId:'one',currency:'KZT',wallets:const[{'id':'bank','name':'SYNTHETIC BANK'}],projects:const[],today:'2026-10-20'));},child:const Text('Открыть'))))));
  await tester.tap(find.text('Открыть'));await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField,'Сумма, KZT'),'123.45');await tester.enterText(find.widgetWithText(TextField,'Основание операции'),'SYNTHETIC RETRY');await tester.enterText(find.widgetWithText(TextField,'Дата операции YYYY-MM-DD'),'2026-01-10');await tester.tap(find.text('Сохранить'));await tester.pumpAndSettle();
  expect(find.text('Повторить сохранение'),findsOneWidget);expect(tester.widget<TextField>(find.widgetWithText(TextField,'Сумма, KZT')).enabled,isFalse);
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);await tester.pumpAndSettle();expect(find.text('Денежная операция'),findsOneWidget);
  await tester.tap(find.text('Повторить сохранение'));await tester.pumpAndSettle();expect(saved,isTrue);expect(requests.length,2);expect(requests[0].headers['Idempotency-Key'],requests[1].headers['Idempotency-Key']);expect(requests[0].body,requests[1].body);expect(jsonDecode(requests[1].body)['amount'],12345);expect(jsonDecode(requests[1].body)['businessDate'],'2026-01-10');expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
 });
}
