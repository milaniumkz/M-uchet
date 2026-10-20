import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/workspace/ledger_workspace.dart';
void main(){
 test('CSV export protects formula text, keeps signed numbers and escapes quotes',(){
  expect(csvCell('=SUM(A1:A9)'), '"\'=SUM(A1:A9)"');
  expect(csvCell('-not-a-number'), '"\'-not-a-number"');
  expect(csvCell(-12345), '"-12345"');
  expect(csvCell('Текст "в кавычках"; значение'), '"Текст ""в кавычках""; значение"');
 });
}
