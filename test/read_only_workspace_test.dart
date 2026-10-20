import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/main_server.dart';
void main(){
 testWidgets('a reader sees authorized sections and cannot open financial mutation dialogs',(tester)async{
  tester.view.physicalSize=const Size(1440,960);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final api=BackendClient(origin:Uri.parse('https://api.example.test'),transport:MockClient((request)async{
   Object value;
   switch('${request.method} ${request.url.path}'){
    case 'POST /v1/auth/login':value={'token':'a'*43,'user':{'id':'reader','name':'SYNTHETIC READER','canCreateCompanies':false}};
    case 'GET /v1/companies':value=[{'id':'one','name':'SYNTHETIC FIRM','currency':'KZT','role':'member','permissions':['projects.read','reports.read','accounting.read']}];
    case 'GET /v1/companies/one/projects':value={'items':[]};
    case 'GET /v1/companies/one/reports/projects':value={'items':[],'total':{'revenue':0,'expenses':0,'cogs':0,'netProfit':0}};
    case 'GET /v1/companies/one/periods':value={'items':[]};
    default:throw StateError('Reader attempted an unauthorized request: ${request.method} ${request.url.path}');
   }
   return http.Response(jsonEncode(value),200,headers:{'content-type':'application/json'});
  }));
  await tester.pumpWidget(AccountingWorkspace(client:api));await tester.enterText(find.byType(TextField).at(0),'synthetic@example.test');await tester.enterText(find.byType(TextField).at(1),'SYNTHETIC PASSWORD');await tester.tap(find.text('Войти'));await tester.pumpAndSettle();
  expect(find.text('Бизнес под контролем'),findsOneWidget);expect(find.byTooltip('Создать проект'),findsNothing);expect(find.text('Сотрудники'),findsNothing);expect(find.text('Доступ'),findsNothing);expect(find.text('Добавить фирму'),findsNothing);
  await tester.tap(find.text('Доход / расход'));await tester.pumpAndSettle();expect(find.text('Денежная операция'),findsNothing);
  await tester.tap(find.text('Закрытие месяца'));await tester.pumpAndSettle();await tester.tap(find.text('Изменить состояние месяца'));await tester.pumpAndSettle();expect(find.text('Состояние месяца'),findsNothing);expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());
 });
}
