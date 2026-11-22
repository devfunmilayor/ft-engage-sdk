import 'dart:math';

abstract interface class IdGenerator {
  String install();
  String event();
}

class RandomIdGenerator implements IdGenerator {
  RandomIdGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  String _hex(int bytes) => List.generate(
    bytes,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  @override
  String install() => 'inst_${_hex(12)}';

  @override
  String event() => 'evt_${_hex(12)}';
}
