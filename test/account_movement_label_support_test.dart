import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/account_movement_label_support.dart';

void main() {
  test('shows income label instead of generic posting text', () {
    expect(
      accountMovementDescription(
        description: 'Проводка',
        memo: '',
        isPositive: true,
      ),
      'Приход',
    );
  });

  test('shows expense label instead of generic posting text', () {
    expect(
      accountMovementDescription(
        description: 'Проводка',
        memo: '',
        isPositive: false,
      ),
      'Расход',
    );
  });

  test('normalizes plural posting text too', () {
    expect(
      accountMovementDescription(
        description: 'Проводки',
        memo: '',
        isPositive: true,
      ),
      'Приход',
    );
  });

  test('prefers counterparty/account title for card title', () {
    expect(
      accountMovementTitle(
        counterTitle: 'Forte Bank',
        description: 'Проводка',
        memo: '',
        isPositive: true,
      ),
      'Forte Bank',
    );
  });
}
