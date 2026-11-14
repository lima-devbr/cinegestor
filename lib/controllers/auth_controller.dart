import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart' show isFirebaseInitialized;
import '../models/app_user.dart';

class AuthController extends ChangeNotifier {
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Lista padrão de usuários com os 4 perfis
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
    AppUser(
      id: 'admin',
      name: 'Administrador',
      email: 'admin@cinegestor.com',
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

    if (isFirebaseInitialized) {
      try {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(fbUser.uid)
              .get();
          if (doc.exists && doc.data() != null) {
            _currentUser = AppUser.fromJson(doc.data()!);
            await prefs.setString(
              'current_user_session',
              json.encode(_currentUser!.toJson()),
            );
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Aviso ao sincronizar sessão Firebase: $e');
      }
    }
  }

  Future<bool> login(String email, String password) async {
    final normalizedInput = email.trim().toLowerCase();
    final normalizedEmail = normalizedInput == 'admin'
        ? 'admin@cinegestor.com'
        : normalizedInput;
    final normalizedPass = password.trim();

    final matchedMock = mockUsers.firstWhere(
      (u) =>
          u.email.toLowerCase() == normalizedEmail &&
          (u.password == normalizedPass ||
              (normalizedPass == 'admin123' && u.id == 'admin') ||
              normalizedPass == 'cine123'),
      orElse: () => const AppUser(
        id: '',
        name: '',
        email: '',
        password: '',
        role: UserRole.operacao,
        cinemaId: '',
        cinemaName: '',
      ),
    );

    if (isFirebaseInitialized) {
      try {
        // Firebase Auth exige senha de no mínimo 6 caracteres
        final firebasePass = normalizedPass.length < 6
            ? 'cine$normalizedPass'
            : normalizedPass;

        UserCredential credential;
        try {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: firebasePass,
          );
        } on FirebaseAuthException catch (e) {
          // Se for uma das 5 contas padrão ainda não provisionada no Firebase Auth, cria automaticamente
          if (matchedMock.id.isNotEmpty &&
              (e.code == 'user-not-found' ||
                  e.code == 'invalid-credential' ||
                  e.code == 'invalid-login-credentials')) {
            credential = await FirebaseAuth.instance
                .createUserWithEmailAndPassword(
              email: normalizedEmail,
              password: firebasePass,
            );
          } else {
            rethrow;
          }
        }

        final uid = credential.user!.uid;
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(uid);
        final userSnapshot = await userDocRef.get();

        AppUser resolvedUser;
        if (userSnapshot.exists && userSnapshot.data() != null) {
          resolvedUser = AppUser.fromJson(userSnapshot.data()!);
        } else {
          resolvedUser = AppUser(
            id: uid,
            name: matchedMock.id.isNotEmpty
                ? matchedMock.name
                : normalizedEmail.split('@').first,
            email: normalizedEmail,
            password: '',
            role: matchedMock.id.isNotEmpty
                ? matchedMock.role
                : UserRole.operacao,
            cinemaId: matchedMock.id.isNotEmpty
                ? matchedMock.cinemaId
                : '2159',
            cinemaName: matchedMock.id.isNotEmpty
                ? matchedMock.cinemaName
                : 'UCI Park Campo Grande',
          );
          await userDocRef.set(resolvedUser.toJson());
        }

        _currentUser = resolvedUser;
        _errorMessage = null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'current_user_session',
          json.encode(resolvedUser.toJson()),
        );

        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Fallback login local após erro Firebase Auth: $e');
      }
    }

    // Fallback local (caso esteja rodando em Linux desktop sem plugin nativo C++ ou offline)
    if (matchedMock.id.isNotEmpty) {
      _currentUser = matchedMock;
      _errorMessage = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'current_user_session',
        json.encode(matchedMock.toJson()),
      );

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
    if (isFirebaseInitialized) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_session');
    notifyListeners();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }
}
