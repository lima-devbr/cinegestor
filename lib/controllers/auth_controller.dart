import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String email, String password) async {
    // Simula uma pequena espera
    await Future.delayed(Duration(milliseconds: 500));

    if (email == 'admin@cinegestor.com' && password == 'admin123') {
      _isAuthenticated = true;
      _errorMessage = null;
      notifyListeners();
      return true;
    } else {
      _isAuthenticated = false;
      _errorMessage = 'Credenciais inválidas.';
      notifyListeners();
      return false;
    }
  }

  void logout(BuildContext context) {
    _isAuthenticated = false;
    notifyListeners();
    Navigator.pushReplacementNamed(context, '/');
  }
}
