import 'exceptions.dart';

final _name = RegExp(r'^[a-z][a-z0-9_.]{0,63}$');
final _key = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
final _financial = RegExp(
  r'(^|_)(amount|amounts|fee|fees|rate|rates|price|prices|balance|balances|revenue|volume|usd|total|cost|salary)($|_)',
);

void validateEventName(String name) {
  if (!_name.hasMatch(name)) {
    throw InvalidEventException(
      'Event name "$name" must be lowercase letters, digits, dots and underscores, starting with a letter.',
    );
  }
}

void validateProps(Map<String, Object?> props) {
  if (props.length > 40) {
    throw const InvalidEventException(
      'An event can have at most 40 properties.',
    );
  }
  for (final entry in props.entries) {
    final key = entry.key;
    if (!_key.hasMatch(key)) {
      throw InvalidEventException(
        'Property key "$key" must be lowercase snake_case.',
      );
    }
    if (_financial.hasMatch(key)) {
      throw InvalidEventException(
        'Property key "$key" looks like a financial value. FT.Engage does not accept money data.',
      );
    }
    final value = entry.value;
    final scalar =
        value == null || value is bool || value is num || value is String;
    if (!scalar) {
      throw InvalidEventException(
        'Property "$key" must be a string, number, boolean or null.',
      );
    }
    if (value is String && value.length > 256) {
      throw InvalidEventException(
        'Property "$key" is longer than 256 characters.',
      );
    }
    if (value is double && !value.isFinite) {
      throw InvalidEventException('Property "$key" must be a finite number.');
    }
  }
}
