import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

void main() {
  test('a configured zone wins over the device', () {
    expect(
      resolveTimezone(
        configured: 'Africa/Lagos',
        deviceName: 'WAT',
        offset: const Duration(hours: 1),
      ),
      'Africa/Lagos',
    );
  });

  test('an IANA name from the device is kept', () {
    expect(
      resolveTimezone(deviceName: 'Europe/London', offset: Duration.zero),
      'Europe/London',
    );
    expect(
      resolveTimezone(
        deviceName: 'America/Argentina/Buenos_Aires',
        offset: const Duration(hours: -3),
      ),
      'America/Argentina/Buenos_Aires',
    );
  });

  test('an abbreviation is replaced by a zone from the offset', () {
    expect(
      resolveTimezone(deviceName: 'WAT', offset: const Duration(hours: 1)),
      'Etc/GMT-1',
    );
    expect(
      resolveTimezone(deviceName: 'EST', offset: const Duration(hours: -5)),
      'Etc/GMT+5',
    );
    expect(resolveTimezone(deviceName: 'GMT', offset: Duration.zero), 'UTC');
    expect(resolveTimezone(deviceName: '', offset: Duration.zero), 'UTC');
  });

  test('offsets that no Etc zone covers give nothing', () {
    expect(
      resolveTimezone(
        deviceName: 'IST',
        offset: const Duration(hours: 5, minutes: 30),
      ),
      isNull,
    );
    expect(timezoneFromOffset(const Duration(hours: 15)), isNull);
    expect(timezoneFromOffset(const Duration(hours: 14)), 'Etc/GMT-14');
    expect(timezoneFromOffset(const Duration(hours: -12)), 'Etc/GMT+12');
  });
}
