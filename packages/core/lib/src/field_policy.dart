final _labelDeny = RegExp(
  r'(pin|passcode|password|passwd|pwd|security|cvv|cvc|csc|card|account|acct|iban|swift|routing|sort\s*code|ssn|social|bvn|nin\b|tax|otp|one[\s-]*time|verification|token|secret|balance|amount|salary|income|answer|mother|maiden|passport|licen[cs]e|mnemonic|seed|private|key|code)',
  caseSensitive: false,
);

final _hintDeny = RegExp(
  r'(password|newPassword|oneTimeCode|creditCard|telephoneNumber|birthday|postalCode|streetAddress|fullStreetAddress|addressLine|pin|code|account|iban|bank)',
  caseSensitive: false,
);

const _blockedKeyboards = {
  'number',
  'phone',
  'datetime',
  'visiblePassword',
  'numberWithOptions',
  'none',
};

class FieldFacts {
  const FieldFacts({
    required this.text,
    this.label = '',
    this.obscure = false,
    this.keyboard,
    this.hints = const [],
    this.autocorrect = true,
    this.suggestions = true,
  });

  final String text;
  final String label;
  final bool obscure;
  final String? keyboard;
  final List<String> hints;
  final bool autocorrect;
  final bool suggestions;
}

class FieldPolicy {
  const FieldPolicy._();

  static const maxLength = 80;

  static bool sensitive(FieldFacts f) =>
      f.obscure ||
      (!f.autocorrect && !f.suggestions) ||
      (f.keyboard != null && _blockedKeyboards.contains(f.keyboard)) ||
      f.hints.any(_hintDeny.hasMatch) ||
      _labelDeny.hasMatch(f.label);

  static bool luhn(String digits) {
    if (digits.length < 13 || digits.length > 19) return false;
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = digits.codeUnitAt(i) - 48;
      if (n < 0 || n > 9) return false;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  static String? scrub(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final compact = trimmed.replaceAll(RegExp(r'[\s-]'), '');
    if (RegExp(r'^\d+$').hasMatch(compact) && luhn(compact)) return null;
    final masked = trimmed.replaceAllMapped(
      RegExp(r'\d{5,}'),
      (m) => '•' * m.group(0)!.length,
    );
    return masked.length > maxLength ? masked.substring(0, maxLength) : masked;
  }

  static String? readable(FieldFacts f) => sensitive(f) ? null : scrub(f.text);

  static String slug(String label, {String fallback = 'field'}) {
    final lower = label.trim().toLowerCase();
    final words = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (words.isEmpty) return fallback;
    final named = RegExp(r'^[a-z]').hasMatch(words) ? words : 'f_$words';
    return named.length > 40 ? named.substring(0, 40) : named;
  }

  static String lengthBucket(int length) => length == 0
      ? '0'
      : length <= 4
      ? '1-4'
      : length <= 12
      ? '5-12'
      : '13+';
}
