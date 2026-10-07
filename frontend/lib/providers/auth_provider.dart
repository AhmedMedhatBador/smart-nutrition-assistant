import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';

  bool get isLoggedIn => _isLoggedIn;
  String get userName => _userName;
  String get userEmail => _userEmail;

  Future<bool> login(String email, String password) async {
    try {
      final response = await _api.login(email, password);
      await _api.saveToken(response.data['token']);
      _userName = response.data['name'];
      _userEmail = email;
      _isLoggedIn = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      await _api.register(name, email, password);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    _isLoggedIn = false;
    _userName = '';
    _userEmail = '';
    notifyListeners();
  }

  Future<void> checkLoginStatus() async {
    final token = await _api.getToken();
    _isLoggedIn = token != null;
    notifyListeners();
  }
}