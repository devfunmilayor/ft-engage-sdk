import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsStore implements KeyValueStore {
  PrefsStore(this._prefs);

  final SharedPreferencesAsync _prefs;

  static PrefsStore create() => PrefsStore(SharedPreferencesAsync());

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> delete(String key) => _prefs.remove(key);
}
