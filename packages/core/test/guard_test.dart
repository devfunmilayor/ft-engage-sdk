import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

void main() {
  test('financial looking keys are rejected', () {
    for (final token in [
      'amount',
      'fee',
      'rate',
      'price',
      'balance',
      'revenue',
      'volume',
      'usd',
      'total',
      'cost',
      'salary',
    ]) {
      for (final key in [
        token,
        'sent_$token',
        '${token}_value',
        'a_${token}_b',
      ]) {
        expect(
          () => validateProps({key: 1}),
          throwsA(isA<InvalidEventException>()),
          reason: key,
        );
      }
    }
  });

  test('keys that only contain a token inside a word are allowed', () {
    validateProps({
      'migrated': 1,
      'feedback': 'ok',
      'separate': true,
      'unit_name': 'x',
    });
  });

  test('keys must be lowercase snake_case and values scalar', () {
    expect(
      () => validateProps({'Plan': 'a'}),
      throwsA(isA<InvalidEventException>()),
    );
    expect(
      () => validateProps({
        'plan': {'a': 1},
      }),
      throwsA(isA<InvalidEventException>()),
    );
    expect(
      () => validateProps({'plan': List.filled(1, 'a')}),
      throwsA(isA<InvalidEventException>()),
    );
    expect(
      () => validateProps({'plan': 'x' * 257}),
      throwsA(isA<InvalidEventException>()),
    );
    expect(
      () => validateProps({'plan': double.nan}),
      throwsA(isA<InvalidEventException>()),
    );
    expect(
      () => validateProps({for (var i = 0; i < 41; i++) 'k$i': 1}),
      throwsA(isA<InvalidEventException>()),
    );
  });

  test('event names follow the naming rule', () {
    validateEventName('signup.completed');
    expect(
      () => validateEventName('SignUp'),
      throwsA(isA<InvalidEventException>()),
    );
    expect(
      () => validateEventName('1st'),
      throwsA(isA<InvalidEventException>()),
    );
  });
}
