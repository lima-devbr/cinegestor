import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';

class AuthController extends ChangeNotifier {
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Lista padrão de usuários locais com os 4 perfis para teste
  static const List<AppUser> mockUsers = [
    AppUser(
      id: 'u1',
      name: 'Carlos Portaria',
      email: 'operacao@cinegestor.com',
      password: '123',
      role: UserRole.operacao,
      cinemaId: '2159',
      cinemaName: 'UCI Park Campo Grande',
    ),
    AppUser(
      id: 'u2',
      name: 'Roberto Manutenção',
      email: 'assistente@cinegestor.com',
      password: '123',
      role: UserRole.assistente,
      cinemaId: '2159',
      cinemaName: 'UCI Park Campo Grande',
    ),
    AppUser(
      id: 'u3',
      name: 'Marcos Encarregado',
      email: 'encarregado@cinegestor.com',
      password: '123',
      role: UserRole.encarregado,
      cinemaId: '2159',
      cinemaName: 'UCI Park Campo Grande',
    ),
    AppUser(
      id: 'u4',
      name: 'Alessandra Gerente',
      email: 'gerente@cinegestor.com',
      password: '123',
      role: UserRole.gerente,
      cinemaId: '2159',
      cinemaName: 'UCI Park Campo Grande',
    ),
    // Gerente padrão legado mantido
    AppUser(
      id: 'admin',
      name: 'Administrador',
      email: 'admin',
      password: '123',
      role: UserRole.gerente,
      cinemaId: '2159',
      cinemaName: 'UCI Park Campo Grande',
    ),
  ];

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user_session');
    if (userJson != null) {
      try {
        _currentUser = AppUser.fromJson(json.decode(userJson));
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPass = password.trim();

    final user = mockUsers.firstWhere(
      (u) =>
          (u.email.toLowerCase() == normalizedEmail ||
              (u.id == 'admin' && normalizedEmail == 'admin@cinegestor.com')) &&
          (u.password == normalizedPass ||
              (normalizedPass == 'admin123' && u.id == 'admin')),
      orElse:
          () => const AppUser(
            id: '',
            name: '',
            email: '',
            password: '',
            role: UserRole.operacao,
            cinemaId: '',
            cinemaName: '',
          ),
    );

    if (user.id.isNotEmpty) {
      _currentUser = user;
      _errorMessage = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_session', json.encode(user.toJson()));

      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Credenciais inválidas. Verifique o e-mail e senha.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout(BuildContext context) async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_session');
    notifyListeners();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }
}
