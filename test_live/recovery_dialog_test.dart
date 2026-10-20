import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:uchet_s_d/backend/rest/api_client.dart';
import 'package:uchet_s_d/backend/rest/repositories.dart';
import 'package:uchet_s_d/workspace/recovery_dialog.dart';
class RealNetwork extends HttpOverrides {}
void main(){
 LiveTestWidgetsFlutterBinding.ensureInitialized();
 testWidgets('real recovery form consumes the issued code and permits login only with the new password',(tester)async{
  final fixture=jsonDecode(File(Platform.environment['MUCHET_TEST_FIXTURE']!).readAsStringSync()) as Map<String,dynamic>;
  final transport=HttpOverrides.runWithHttpOverrides(()=>IOClient(HttpClient()),RealNetwork());final api=BackendClient(origin:Uri.parse(fixture['origin'] as String),transport:transport);
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(context)=>TextButton(onPressed:()=>showDialog<void>(context:context,builder:(_)=>RecoveryDialog(api:api)),child:const Text('Открыть восстановление'))))));
  await tester.tap(find.text('Открыть восстановление'));await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField,'Код восстановления'),fixture['recoveryToken'] as String);
  await tester.enterText(find.widgetWithText(TextField,'Новый пароль'),fixture['recoveryNextPassword'] as String);
  await tester.enterText(find.widgetWithText(TextField,'Повторите новый пароль'),fixture['recoveryNextPassword'] as String);
  await tester.runAsync(()async{await tester.tap(find.text('Изменить пароль'));await Future<void>.delayed(const Duration(milliseconds:500));});await tester.pumpAndSettle();
  expect(find.textContaining('Пароль изменён.'),findsOneWidget);
  await tester.runAsync(()async{await IdentityRepository(api).login(fixture['recoveryLogin'] as String,fixture['recoveryNextPassword'] as String);});
  expect(api.authenticated,true);expect(tester.takeException(),isNull);await tester.pumpWidget(const SizedBox());api.close();
 });
}
