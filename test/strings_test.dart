import 'package:dgzone_money/src/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime language selection returns Myanmar and English labels', () {
    expect(const AppStrings(AppLanguage.myanmar).get('income'), 'ဝင်ငွေ');
    expect(const AppStrings(AppLanguage.english).get('income'), 'Income');
  });
}
