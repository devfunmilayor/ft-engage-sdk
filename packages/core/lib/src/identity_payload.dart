import 'exceptions.dart';

enum MarketingChannel { email, whatsapp, sms }

final _userId = RegExp(r'^[A-Za-z0-9_.:@+-]{1,128}$');
final _email = RegExp(r'^[^@\s]{1,64}@[^@\s]{1,255}$');
final _hash = RegExp(r'^[a-f0-9]{64}$');
final _phone = RegExp(r'^\+[1-9][0-9]{6,14}$');
final _trait = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
final _sensitive = RegExp(
  r'(^|_)(amount|amounts|fee|fees|rate|rates|price|prices|balance|balances|revenue|volume|usd|total|cost|salary|password|passcode|pin|token|secret|card|cvv|ssn|bvn|nin|account_number)($|_)',
);

const maxTraits = 30;

void validateIdentity({
  required String userId,
  String? userHash,
  String? email,
  String? phone,
  Map<String, Object?> traits = const {},
}) {
  if (userHash != null && !_hash.hasMatch(userHash)) {
    throw const InvalidIdentityException(
      'userHash must be 64 lowercase hex characters made by your server.',
    );
  }
  if (!_userId.hasMatch(userId)) {
    throw const InvalidIdentityException(
      'userId must be 1 to 128 characters: letters, digits and _ . : @ + -',
    );
  }
  if (email != null && (email.length > 320 || !_email.hasMatch(email))) {
    throw const InvalidIdentityException('email is not a valid address.');
  }
  if (phone != null && !_phone.hasMatch(phone)) {
    throw const InvalidIdentityException(
      'phone must be in international format, for example +2348012345678.',
    );
  }
  if (traits.length > maxTraits) {
    throw const InvalidIdentityException(
      'At most $maxTraits traits can be set in one call.',
    );
  }
  for (final entry in traits.entries) {
    final name = entry.key;
    if (!_trait.hasMatch(name)) {
      throw InvalidIdentityException(
        'Trait name "$name" must be lowercase snake_case.',
      );
    }
    if (_sensitive.hasMatch(name)) {
      throw InvalidIdentityException(
        'Trait name "$name" looks like a secret or a money value. FT.Engage does not store those.',
      );
    }
    final value = entry.value;
    final scalar =
        value == null || value is bool || value is num || value is String;
    if (!scalar) {
      throw InvalidIdentityException(
        'Trait "$name" must be a string, number, boolean or null.',
      );
    }
    if (value is String && value.length > 200) {
      throw InvalidIdentityException(
        'Trait "$name" is longer than 200 characters.',
      );
    }
    if (value is double && !value.isFinite) {
      throw InvalidIdentityException('Trait "$name" must be a finite number.');
    }
  }
}

Map<String, Object?> buildIdentify({
  required String installId,
  required String userId,
  String? userHash,
  String? email,
  String? phone,
  Map<String, Object?> traits = const {},
  Map<MarketingChannel, bool> marketingConsent = const {},
  Map<String, Object?>? pending,
}) {
  final same = pending != null && pending['userId'] == userId;
  final oldTraits = same
      ? Map<String, Object?>.from(pending['traits'] as Map? ?? {})
      : <String, Object?>{};
  final oldConsent = same
      ? Map<String, Object?>.from(pending['consent'] as Map? ?? {})
      : <String, Object?>{};
  final mergedTraits = {...oldTraits, ...traits};
  final mergedConsent = {
    ...oldConsent,
    for (final entry in marketingConsent.entries)
      entry.key.name: entry.value ? 'granted' : 'denied',
  };
  final oldEmail = same ? pending['email'] : null;
  final oldPhone = same ? pending['phone'] : null;
  final oldHash = same ? pending['userHash'] : null;
  return {
    'installId': installId,
    'userId': userId,
    'userHash': ?(userHash ?? oldHash),
    'email': ?(email ?? oldEmail),
    'phone': ?(phone ?? oldPhone),
    if (mergedTraits.isNotEmpty) 'traits': mergedTraits,
    if (mergedConsent.isNotEmpty) 'consent': mergedConsent,
  };
}
