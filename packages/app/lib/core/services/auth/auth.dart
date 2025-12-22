import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService with ChangeNotifier {
  late SharedPreferences _prefs;
  static const _tokenKey = 'auth_token';

  String? _token;

  String? get token => _token;

  bool get isLoggedIn => _token != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _token = _prefs.getString(_tokenKey);
  }

  void setToken(String token) {
    _token = token;
    _prefs.setString(_tokenKey, token);
    notifyListeners();
  }

  void logout() {
    _token = null;
    _prefs.remove(_tokenKey);
    notifyListeners();
  }
}
