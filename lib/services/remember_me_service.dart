import 'package:shared_preferences/shared_preferences.dart';

class SavedLoginInfo {
  final bool rememberMe;
  final String phone;
  final String password;

  const SavedLoginInfo({
    required this.rememberMe,
    required this.phone,
    required this.password,
  });
}

class RememberMeService {
  static const _rememberMeKey = 'remember_me';
  static const _savedPhoneKey = 'saved_phone';
  static const _savedPasswordKey = 'saved_password';

  static String _key(String base, String scope) =>
      scope.isEmpty ? base : '${base}_$scope';

  static Future<SavedLoginInfo> load({String scope = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_key(_rememberMeKey, scope)) ?? false;
    return SavedLoginInfo(
      rememberMe: rememberMe,
      phone: rememberMe
          ? (prefs.getString(_key(_savedPhoneKey, scope)) ?? '')
          : '',
      password: rememberMe
          ? (prefs.getString(_key(_savedPasswordKey, scope)) ?? '')
          : '',
    );
  }

  static Future<void> save({
    required bool rememberMe,
    required String phone,
    required String password,
    String scope = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setBool(_key(_rememberMeKey, scope), true);
      await prefs.setString(_key(_savedPhoneKey, scope), phone);
      await prefs.setString(_key(_savedPasswordKey, scope), password);
    } else {
      await prefs.setBool(_key(_rememberMeKey, scope), false);
      await prefs.remove(_key(_savedPhoneKey, scope));
      await prefs.remove(_key(_savedPasswordKey, scope));
    }
  }
}
