final _named = RegExp(r'^[A-Za-z]+(?:/[A-Za-z0-9_+\-]+)+$');

/// The time zone to report for a device, as an IANA name the server can use
/// to time messages to the person's local hour.
///
/// A [configured] name wins. Otherwise [deviceName] is used when it is
/// already an IANA name such as `Africa/Lagos`. Abbreviations such as `WAT`
/// are ambiguous, so the zone is then derived from [offset] as `UTC` or an
/// `Etc/GMT` zone. Offsets that are not whole hours give `null`, and the
/// server falls back to the campaign's own time zone.
String? resolveTimezone({
  String? configured,
  String? deviceName,
  required Duration offset,
}) {
  final chosen = configured?.trim();
  if (chosen != null && chosen.isNotEmpty) return chosen;
  final name = deviceName?.trim() ?? '';
  if (name == 'UTC' || _named.hasMatch(name)) return name;
  return timezoneFromOffset(offset);
}

/// `UTC` for no offset, `Etc/GMT-1` for one hour ahead of UTC and
/// `Etc/GMT+5` for five hours behind. The IANA `Etc` zones use the opposite
/// sign on purpose. Returns `null` for offsets that are not whole hours or
/// are outside the range the `Etc` zones cover.
String? timezoneFromOffset(Duration offset) {
  if (offset.inMinutes % 60 != 0) return null;
  final hours = offset.inHours;
  if (hours == 0) return 'UTC';
  if (hours < -12 || hours > 14) return null;
  return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
}
