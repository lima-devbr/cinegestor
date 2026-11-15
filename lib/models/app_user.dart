enum UserRole {
  operacao,
  assistente,
  encarregado,
  gerente,
  supervisor,
  admin,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.operacao:
        return 'Operações';
      case UserRole.assistente:
        return 'Assistente/Supervisor';
      case UserRole.encarregado:
        return 'Encarregado';
      case UserRole.gerente:
        return 'Gerente';
      case UserRole.supervisor:
        return 'Supervisor Regional';
      case UserRole.admin:
        return 'Administrador';
    }
  }

  String get shortName {
    switch (this) {
      case UserRole.operacao:
        return 'Operações';
      case UserRole.assistente:
        return 'Assistente/Supervisor';
      case UserRole.encarregado:
        return 'Encarregado';
      case UserRole.gerente:
        return 'Gerente';
      case UserRole.supervisor:
        return 'Supervisor Regional';
      case UserRole.admin:
        return 'Admin';
    }
  }

  // Permissões de Negócio
  bool get createsAsStaging => this == UserRole.operacao;

  bool get canApproveStaging =>
      this == UserRole.encarregado ||
      this == UserRole.gerente ||
      this == UserRole.supervisor ||
      this == UserRole.admin;

  bool get canResolveIssue =>
      this == UserRole.encarregado ||
      this == UserRole.gerente ||
      this == UserRole.supervisor ||
      this == UserRole.admin;

  bool get canReopenIssue =>
      this == UserRole.gerente ||
      this == UserRole.supervisor ||
      this == UserRole.admin;

  bool get canDeleteIssue =>
      this == UserRole.gerente ||
      this == UserRole.supervisor ||
      this == UserRole.admin;

  bool get canExportReports => this != UserRole.operacao;

  /// Pode acessar o painel de Gestão de Equipe (criar/editar/bloquear logins)
  bool get canManageUsers =>
      this == UserRole.gerente ||
      this == UserRole.supervisor ||
      this == UserRole.admin;

  /// Pode alternar entre diferentes unidades/cinemas da rede e transferir funcionários
  bool get canSwitchCinema =>
      this == UserRole.supervisor || this == UserRole.admin;
}

class CinemaUnit {
  final String id;
  final String name;

  const CinemaUnit({required this.id, required this.name});

  static const List<CinemaUnit> availableCinemas = [
    CinemaUnit(id: '2159', name: 'UCI Park Campo Grande'),
    CinemaUnit(id: '2160', name: 'UCI New York City Center'),
    CinemaUnit(id: '2161', name: 'UCI Kinoplex NorteShopping'),
  ];

  static String nameForId(String id) {
    for (final c in availableCinemas) {
      if (c.id == id) return c.name;
    }
    return 'Unidade $id';
  }
}

class AppUser {
  final String id;
  final String name;
  final String username;
  final String email;
  final String password;
  final UserRole role;
  final String cinemaId;
  final String cinemaName;
  final bool active;
  final bool mustChangePassword;

  const AppUser({
    required this.id,
    required this.name,
    String? username,
    required this.email,
    required this.password,
    required this.role,
    required this.cinemaId,
    required this.cinemaName,
    this.active = true,
    this.mustChangePassword = false,
  }) : username = username ?? '';

  String get displayUsername {
    if (username.isNotEmpty) return username;
    if (email.contains('@')) return email.split('@').first;
    return email;
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? password,
    UserRole? role,
    String? cinemaId,
    String? cinemaName,
    bool? active,
    bool? mustChangePassword,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      cinemaId: cinemaId ?? this.cinemaId,
      cinemaName: cinemaName ?? this.cinemaName,
      active: active ?? this.active,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': displayUsername,
      'email': email,
      'role': role.name,
      'cinemaId': cinemaId,
      'cinemaName': cinemaName,
      'active': active,
      'mustChangePassword': mustChangePassword,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawEmail = (json['email'] ?? '').toString();
    final rawUsername = (json['username'] ?? '').toString();
    return AppUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      username: rawUsername.isNotEmpty
          ? rawUsername
          : (rawEmail.contains('@') ? rawEmail.split('@').first : rawEmail),
      email: rawEmail,
      password: (json['password'] ?? '').toString(),
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.operacao,
      ),
      cinemaId: (json['cinemaId'] ?? '2159').toString(),
      cinemaName: (json['cinemaName'] ?? 'UCI Park Campo Grande').toString(),
      active: json['active'] is bool ? json['active'] as bool : true,
      mustChangePassword: json['mustChangePassword'] is bool
          ? json['mustChangePassword'] as bool
          : false,
    );
  }
}
