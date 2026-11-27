import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

FieldFacts field(
  String text, {
  String label = '',
  bool obscure = false,
  String? keyboard,
  List<String> hints = const [],
  bool autocorrect = true,
  bool suggestions = true,
}) => FieldFacts(
  text: text,
  label: label,
  obscure: obscure,
  keyboard: keyboard,
  hints: hints,
  autocorrect: autocorrect,
  suggestions: suggestions,
);

void main() {
  test('plain email and name fields are readable', () {
    expect(
      FieldPolicy.readable(
        field('star@yopmail.com', label: 'Email', keyboard: 'emailAddress'),
      ),
      'star@yopmail.com',
    );
    expect(
      FieldPolicy.readable(field('Ada Lovelace', label: 'Full name')),
      'Ada Lovelace',
    );
    expect(FieldPolicy.readable(field('   ', label: 'Email')), isNull);
  });

  test(
    'password, PIN, code, card, account, balance and amount fields are never readable',
    () {
      for (final label in [
        'Password',
        'Confirm password',
        'Transaction PIN',
        'Enter your pin',
        'Security code',
        'Card number',
        'CVV',
        'Account number',
        'IBAN',
        'Routing number',
        'Sort code',
        'Wallet balance',
        'Amount to send',
        'One time password',
        'OTP',
        'Verification code',
        'BVN',
        'NIN',
        'SSN',
        'Mother maiden name',
        'Secret answer',
        'Recovery key',
        'Passport number',
      ]) {
        expect(
          FieldPolicy.readable(field('hunter2', label: label)),
          isNull,
          reason: label,
        );
      }
    },
  );

  test(
    'obscured boxes, number and phone keyboards and secret autofill hints are never readable',
    () {
      expect(FieldPolicy.readable(field('x', obscure: true)), isNull);
      for (final keyboard in [
        'number',
        'phone',
        'datetime',
        'visiblePassword',
        'numberWithOptions',
      ]) {
        expect(
          FieldPolicy.readable(field('1', keyboard: keyboard)),
          isNull,
          reason: keyboard,
        );
      }
      for (final hint in [
        'password',
        'newPassword',
        'oneTimeCode',
        'creditCardNumber',
        'creditCardSecurityCode',
        'telephoneNumber',
        'postalCode',
      ]) {
        expect(
          FieldPolicy.readable(field('x', hints: [hint])),
          isNull,
          reason: hint,
        );
      }
      expect(
        FieldPolicy.readable(
          field('x', autocorrect: false, suggestions: false),
        ),
        isNull,
      );
      expect(FieldPolicy.readable(field('x', hints: ['email'])), 'x');
    },
  );

  test(
    'card numbers are dropped and long digit runs are masked even in an allowed box',
    () {
      expect(FieldPolicy.readable(field('4111 1111 1111 1111')), isNull);
      expect(FieldPolicy.readable(field('4111111111111111')), isNull);
      expect(
        FieldPolicy.readable(field('call 08012345678 now')),
        'call ••••••••••• now',
      );
      expect(FieldPolicy.readable(field('order 1234')), 'order 1234');
      expect(
        FieldPolicy.readable(field('x' * 200))!.length,
        FieldPolicy.maxLength,
      );
    },
  );

  test('luhn, slug and length buckets', () {
    expect(FieldPolicy.luhn('4111111111111111'), isTrue);
    expect(FieldPolicy.luhn('4111111111111112'), isFalse);
    expect(FieldPolicy.luhn('123'), isFalse);
    expect(FieldPolicy.slug('Email address'), 'email_address');
    expect(FieldPolicy.slug('  '), 'field');
    expect(FieldPolicy.slug('9 lives'), 'f_9_lives');
    expect(FieldPolicy.slug('x' * 80).length, 40);
    expect([0, 3, 8, 30].map(FieldPolicy.lengthBucket).toList(), [
      '0',
      '1-4',
      '5-12',
      '13+',
    ]);
  });
}
