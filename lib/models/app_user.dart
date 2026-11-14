enum UserRole {
  operacao,
  assistente,
  encarregado,
  gerente,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.operacao:
        return 'Operação (Limpeza/Portaria)';
      case UserRole.assistente:
        return 'Assistente de Manutenção';
      case UserRole.encarregado:
        return 'Encarregado';
      case UserRole.gerente:
        return 'Gerente Geral';
    }
  }

  String get shortName {
    switch (this) {
      case UserRole.operacao:
        return 'Operação';
      case UserRole.assistente:
        return 'Assistente';
      case UserRole.encarregado:
        return 'Encarregado';
      case UserRole.gerente:
        return 'Gerente';
    }
  }

  // Permissões
  bool get canApproveStaging => this == UserRole.encarregado || this == UserRole.gerente;
  bool get canResolveIssue => this == UserRole.encarregado || this == UserRole.gerente;
  bool get canReopenIssue => this == UserRole.gerente;
  bool get canDeleteIssue => this == UserRole.gerente;
  bool get canExportReports => this != UserRole.operacao;
  bool get createsAsStaging => this == UserRole.operacao;
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String cinemaId; // Ex: "2159"
  final String cinemaName; // Ex: "UCI Park Campo Grande"

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.cinemaId,
    required this.cinemaName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'cinemaId': cinemaId,
      'cinemaName': cinemaName,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      password: '',
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.operacao,
      ),
      cinemaId: json['cinemaId'] ?? '2159',
      cinemaName: json['cinemaName'] ?? 'UCI Park Campo Grande',
    );
  }
}
