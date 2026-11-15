import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../main.dart' show isFirebaseInitialized;
import '../firebase_options.dart';
import '../models/app_user.dart';

class AuthController extends ChangeNotifier {
  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<AppUser> _teamMembers = [];
  List<AppUser> get teamMembers => _teamMembers;

  bool _isLoadingTeam = false;
  bool get isLoadingTeam => _isLoadingTeam;

  // Conta mestre inicial de Administração (sincronizada direto com o Firebase)
  static const AppUser bootstrapAdmin = AppUser(
    id: 'admin',
    name: 'Administrador',
    username: 'admin',
    email: 'admin@cinegestor.com',
    password: '',
    role: UserRole.admin,
    cinemaId: '2159',
    cinemaName: 'UCI Park Campo Grande',
  );

  /// Converte um nome de usuário curto (ex: "joao" ou "admin") em e-mail válido
  /// caso não possua "@".
  static String normalizeToEmail(String input) {
    final cleaned = input.trim().toLowerCase();
    if (cleaned.isEmpty) return '';
    if (cleaned.contains('@')) return cleaned;
    return '$cleaned@cinegestor.com';
  }

  /// Ajusta senhas curtas (ex: "123") para o mínimo de 6 caracteres exigido pelo Firebase Auth
  static String toFirebasePassword(String rawPassword) {
    final cleaned = rawPassword.trim();
    if (cleaned.length < 6) {
      return 'cine$cleaned';
    }
    return cleaned;
  }

  Future<List<AppUser>> _loadLocalUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('managed_users_cache');
    final Map<String, AppUser> byEmail = {};

    if (raw != null) {
      try {
        final List<dynamic> decoded = json.decode(raw);
        for (final item in decoded) {
          final user = AppUser.fromJson(Map<String, dynamic>.from(item));
          if (user.email.isNotEmpty) {
            byEmail[user.email.toLowerCase()] = user;
          }
        }
      } catch (_) {}
    }
    return byEmail.values.toList();
  }

  Future<void> _saveLocalUsers(List<AppUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final list = users
        .map((u) => {
              ...u.toJson(),
              'password': u.password,
            })
        .toList();
    await prefs.setString('managed_users_cache', json.encode(list));
  }

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user_session');
    if (userJson != null) {
      try {
        final saved = AppUser.fromJson(json.decode(userJson));
        if (saved.active) {
          _currentUser = saved;
          notifyListeners();
        }
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
            final cloudUser = AppUser.fromJson(doc.data()!);
            if (!cloudUser.active) {
              await FirebaseAuth.instance.signOut();
              _currentUser = null;
              await prefs.remove('current_user_session');
            } else {
              _currentUser = cloudUser;
              await prefs.setString(
                'current_user_session',
                json.encode(_currentUser!.toJson()),
              );
            }
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Aviso ao sincronizar sessão Firebase: $e');
      }
    }
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    final normalizedEmail = normalizeToEmail(usernameOrEmail);
    final normalizedPass = password.trim();

    if (normalizedEmail.isEmpty || normalizedPass.isEmpty) {
      _errorMessage = 'Informe seu usuário e senha.';
      notifyListeners();
      return false;
    }

    final localUsers = await _loadLocalUsers();
    final isBootstrapAdminLogin =
        normalizedEmail == bootstrapAdmin.email && normalizedPass == 'admin123';

    final matchedLocal = localUsers.firstWhere(
      (u) =>
          u.email.toLowerCase() == normalizedEmail &&
          u.password.isNotEmpty &&
          u.password == normalizedPass,
      orElse: () => isBootstrapAdminLogin
          ? bootstrapAdmin
          : const AppUser(
              id: '',
              name: '',
              email: '',
              password: '',
              role: UserRole.operacao,
              cinemaId: '',
              cinemaName: '',
            ),
    );

    if (matchedLocal.id.isNotEmpty && !matchedLocal.active) {
      _errorMessage = 'Este acesso foi desativado pela gerência.';
      notifyListeners();
      return false;
    }

    if (isFirebaseInitialized) {
      try {
        final firebasePass = toFirebasePassword(normalizedPass);

        UserCredential credential;
        try {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: firebasePass,
          );
        } on FirebaseAuthException catch (e) {
          final isAuthNotFoundOrInvalid = e.code == 'user-not-found' ||
              e.code == 'invalid-credential' ||
              e.code == 'invalid-login-credentials' ||
              e.code == 'wrong-password';

          if (isBootstrapAdminLogin && isAuthNotFoundOrInvalid) {
            try {
              // Se ainda não existir no Firebase Auth, cria com admin123
              credential =
                  await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: normalizedEmail,
                password: firebasePass,
              );
            } on FirebaseAuthException catch (createErr) {
              if (createErr.code == 'email-already-in-use') {
                // Migra automaticamente caso tenha sido criado antes com a senha antiga '123' ('cine123')
                credential =
                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: normalizedEmail,
                  password: 'cine123',
                );
                await credential.user?.updatePassword(firebasePass);
              } else {
                rethrow;
              }
            }
          } else if (matchedLocal.id.isNotEmpty && isAuthNotFoundOrInvalid) {
            credential =
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
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
          // Garante que o login admin sempre tenha o papel admin atualizado
          if (normalizedEmail == bootstrapAdmin.email &&
              resolvedUser.role != UserRole.admin) {
            resolvedUser = resolvedUser.copyWith(role: UserRole.admin);
            await userDocRef.set(resolvedUser.toJson());
          }
        } else {
          final isAdminEmail = normalizedEmail == bootstrapAdmin.email;
          resolvedUser = AppUser(
            id: uid,
            name: isAdminEmail
                ? bootstrapAdmin.name
                : (matchedLocal.id.isNotEmpty
                    ? matchedLocal.name
                    : normalizedEmail.split('@').first),
            username: normalizedEmail.split('@').first,
            email: normalizedEmail,
            password: '',
            role: isAdminEmail
                ? UserRole.admin
                : (matchedLocal.id.isNotEmpty
                    ? matchedLocal.role
                    : UserRole.operacao),
            cinemaId: matchedLocal.id.isNotEmpty &&
                    matchedLocal.cinemaId.isNotEmpty
                ? matchedLocal.cinemaId
                : bootstrapAdmin.cinemaId,
            cinemaName: matchedLocal.id.isNotEmpty &&
                    matchedLocal.cinemaName.isNotEmpty
                ? matchedLocal.cinemaName
                : bootstrapAdmin.cinemaName,
            active: true,
            mustChangePassword: matchedLocal.mustChangePassword,
          );
          await userDocRef.set(resolvedUser.toJson());
        }

        if (!resolvedUser.active) {
          await FirebaseAuth.instance.signOut();
          _errorMessage = 'Este acesso foi desativado pela gerência.';
          notifyListeners();
          return false;
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

    if (matchedLocal.id.isNotEmpty) {
      if (!matchedLocal.active) {
        _errorMessage = 'Este acesso foi desativado pela gerência.';
        notifyListeners();
        return false;
      }
      _currentUser = matchedLocal;
      _errorMessage = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'current_user_session',
        json.encode(matchedLocal.toJson()),
      );

      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Usuário ou senha inválidos.';
      notifyListeners();
      return false;
    }
  }

  /// Altera a senha do próprio usuário logado (e desativa a flag mustChangePassword)
  Future<String?> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return 'Nenhum usuário autenticado.';
    if (newPassword.trim().length < 3) {
      return 'A nova senha deve ter pelo menos 3 caracteres.';
    }

    if (isFirebaseInitialized && FirebaseAuth.instance.currentUser != null) {
      try {
        final fbUser = FirebaseAuth.instance.currentUser!;
        final email = fbUser.email ?? _currentUser!.email;
        final cred = EmailAuthProvider.credential(
          email: email,
          password: toFirebasePassword(currentPassword),
        );
        await fbUser.reauthenticateWithCredential(cred);
        await fbUser.updatePassword(toFirebasePassword(newPassword));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password' ||
            e.code == 'invalid-credential' ||
            e.code == 'invalid-login-credentials') {
          return 'A senha atual informada está incorreta.';
        }
        return 'Erro ao atualizar senha no servidor: ${e.message}';
      } catch (_) {}
    }

    final updated = _currentUser!.copyWith(
      password: newPassword.trim(),
      mustChangePassword: false,
    );
    _currentUser = updated;

    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updated.id)
            .set(updated.toJson());
      } catch (_) {}
    }

    final localUsers = await _loadLocalUsers();
    final idx = localUsers.indexWhere(
      (u) => u.email.toLowerCase() == updated.email.toLowerCase(),
    );
    if (idx != -1) {
      localUsers[idx] = updated;
    } else {
      localUsers.add(updated);
    }
    await _saveLocalUsers(localUsers);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'current_user_session',
      json.encode(updated.toJson()),
    );
    notifyListeners();
    return null;
  }

  /// Permite ao Supervisor Regional ou Admin alternar a unidade ativa
  Future<void> switchActiveCinema(String cinemaId, String cinemaName) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      cinemaId: cinemaId,
      cinemaName: cinemaName,
    );

    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.id)
            .set(_currentUser!.toJson());
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'current_user_session',
      json.encode(_currentUser!.toJson()),
    );
    notifyListeners();
  }

  /// Carrega a lista de colaboradores para a tela de Gestão de Equipe
  Future<void> loadTeamMembers() async {
    _isLoadingTeam = true;
    notifyListeners();

    final Map<String, AppUser> byEmail = {};
    final localList = await _loadLocalUsers();
    for (final u in localList) {
      byEmail[u.email.toLowerCase()] = u;
    }

    if (isFirebaseInitialized) {
      try {
        final canSeeAll = _currentUser?.role.canSwitchCinema ?? false;
        final query = canSeeAll
            ? FirebaseFirestore.instance.collection('users')
            : FirebaseFirestore.instance
                .collection('users')
                .where('cinemaId', isEqualTo: _currentUser?.cinemaId ?? '2159');

        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] ??= doc.id;
          final cloudUser = AppUser.fromJson(data);
          if (cloudUser.email.isNotEmpty) {
            final existingLocal = byEmail[cloudUser.email.toLowerCase()];
            byEmail[cloudUser.email.toLowerCase()] = cloudUser.copyWith(
              password: existingLocal?.password ?? '123',
            );
          }
        }
      } catch (e) {
        debugPrint('Aviso ao buscar equipe no Firestore: $e');
      }
    }

    final canSeeAll = _currentUser?.role.canSwitchCinema ?? false;
    final activeCinemaId = _currentUser?.cinemaId ?? '2159';

    _teamMembers = byEmail.values.where((u) {
      if (canSeeAll) return true;
      return u.cinemaId == activeCinemaId;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    await _saveLocalUsers(byEmail.values.toList());
    _isLoadingTeam = false;
    notifyListeners();
  }

  /// Cria um novo funcionário usando uma instância secundária do FirebaseApp
  /// para não deslogar o Gerente/Supervisor/Admin atual!
  Future<String?> createEmployee({
    required String name,
    required String usernameOrEmail,
    required String initialPassword,
    required UserRole role,
    required String cinemaId,
    required String cinemaName,
    required bool mustChangePassword,
  }) async {
    final normalizedEmail = normalizeToEmail(usernameOrEmail);
    final shortUser = normalizedEmail.split('@').first;
    final cleanPass = initialPassword.trim();

    if (name.trim().isEmpty || normalizedEmail.isEmpty || cleanPass.isEmpty) {
      return 'Preencha nome, usuário e senha inicial.';
    }

    String newUserId = 'usr_${DateTime.now().millisecondsSinceEpoch}';

    if (isFirebaseInitialized) {
      FirebaseApp? secondaryApp;
      try {
        try {
          secondaryApp = Firebase.app('SecondaryUserCreator');
        } catch (_) {
          secondaryApp = await Firebase.initializeApp(
            name: 'SecondaryUserCreator',
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }

        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        final cred = await secondaryAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: toFirebasePassword(cleanPass),
        );
        newUserId = cred.user!.uid;
        await secondaryAuth.signOut();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return 'Este usuário ($shortUser) já está cadastrado.';
        }
        debugPrint('Aviso criação secundária Firebase Auth: $e');
      } catch (e) {
        debugPrint('Erro ao criar em app secundário: $e');
      }
    }

    final newUser = AppUser(
      id: newUserId,
      name: name.trim(),
      username: shortUser,
      email: normalizedEmail,
      password: cleanPass,
      role: role,
      cinemaId: cinemaId,
      cinemaName: cinemaName,
      active: true,
      mustChangePassword: mustChangePassword,
    );

    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(newUserId)
            .set(newUser.toJson());
      } catch (e) {
        debugPrint('Erro ao gravar novo usuário no Firestore: $e');
      }
    }

    final allLocal = await _loadLocalUsers();
    allLocal.removeWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    allLocal.add(newUser);
    await _saveLocalUsers(allLocal);

    await loadTeamMembers();
    return null;
  }

  /// Atualiza cargo, unidade, status ativo ou exigência de troca de senha de um colaborador
  Future<void> updateEmployee(
    AppUser updatedUser, {
    String? newResetPassword,
  }) async {
    final finalUser = newResetPassword != null && newResetPassword.isNotEmpty
        ? updatedUser.copyWith(password: newResetPassword.trim())
        : updatedUser;

    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(finalUser.id)
            .set(finalUser.toJson());
      } catch (e) {
        debugPrint('Erro ao atualizar colaborador no Firestore: $e');
      }
    }

    final allLocal = await _loadLocalUsers();
    final idx = allLocal.indexWhere(
      (u) =>
          u.id == finalUser.id ||
          u.email.toLowerCase() == finalUser.email.toLowerCase(),
    );
    if (idx != -1) {
      allLocal[idx] = finalUser;
    } else {
      allLocal.add(finalUser);
    }
    await _saveLocalUsers(allLocal);

    if (_currentUser?.id == finalUser.id) {
      _currentUser = finalUser;
    }

    await loadTeamMembers();
  }

  /// Exclui um colaborador da equipe
  Future<void> deleteEmployee(AppUser targetUser) async {
    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUser.id)
            .delete();
      } catch (e) {
        debugPrint('Erro ao remover colaborador no Firestore: $e');
      }
    }

    final allLocal = await _loadLocalUsers();
    allLocal.removeWhere(
      (u) =>
          u.id == targetUser.id ||
          u.email.toLowerCase() == targetUser.email.toLowerCase(),
    );
    await _saveLocalUsers(allLocal);
    await loadTeamMembers();
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
