import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../models/app_user.dart';
import '../widgets/apple_surfaces.dart';

/// Modal reutilizável para o próprio colaborador alterar sua senha
/// (ou quando mustChangePassword == true no primeiro acesso)
Future<void> showChangeOwnPasswordDialog(
  BuildContext context, {
  bool isMandatoryFirstAccess = false,
}) async {
  final currentPassCtrl = TextEditingController(
    text: isMandatoryFirstAccess ? '123' : '',
  );
  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  String? localError;
  bool isSaving = false;

  await showDialog(
    context: context,
    barrierDismissible: !isMandatoryFirstAccess,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Text(
              isMandatoryFirstAccess
                  ? 'Crie sua Senha Pessoal'
                  : 'Alterar Minha Senha',
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMandatoryFirstAccess)
                    Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Text(
                        'Este é o seu primeiro acesso (ou sua senha foi redefinida). Escolha uma nova senha pessoal para continuar.',
                        style: TextStyle(
                          color: AppleColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  TextField(
                    controller: currentPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Senha Atual',
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nova Senha',
                      prefixIcon: Icon(Icons.key_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar Nova Senha',
                      prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      localError!,
                      style: TextStyle(
                        color: AppleColors.systemRed,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (!isMandatoryFirstAccess)
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (newPassCtrl.text.trim().isEmpty) {
                          setModalState(
                            () => localError = 'Digite a nova senha.',
                          );
                          return;
                        }
                        if (newPassCtrl.text.trim() !=
                            confirmPassCtrl.text.trim()) {
                          setModalState(
                            () => localError = 'As senhas não coincidem.',
                          );
                          return;
                        }
                        setModalState(() {
                          isSaving = true;
                          localError = null;
                        });
                        final auth = Provider.of<AuthController>(
                          context,
                          listen: false,
                        );
                        final err = await auth.changeOwnPassword(
                          currentPassword: currentPassCtrl.text.trim(),
                          newPassword: newPassCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        if (err != null) {
                          setModalState(() {
                            isSaving = false;
                            localError = err;
                          });
                        } else {
                          Navigator.pop(ctx);
                          showTopNotice(
                            context,
                            'Senha atualizada com sucesso!',
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Salvar Senha'),
              ),
            ],
          );
        },
      );
    },
  );
}

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  String _selectedRoleFilter = 'all';
  String _selectedCinemaFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthController>(context, listen: false).loadTeamMembers();
    });
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.operacao:
        return AppleColors.systemAmber;
      case UserRole.assistente:
        return AppleColors.systemCyan;
      case UserRole.encarregado:
        return AppleColors.systemGreen;
      case UserRole.gerente:
        return AppleColors.accentBlue;
      case UserRole.supervisor:
        return AppleColors.systemPurple;
      case UserRole.admin:
        return AppleColors.systemRed;
    }
  }

  List<UserRole> _allowedRolesToAssign(AppUser? caller) {
    if (caller?.role == UserRole.admin) {
      return UserRole.values;
    }
    if (caller?.role == UserRole.supervisor) {
      return [
        UserRole.operacao,
        UserRole.assistente,
        UserRole.encarregado,
        UserRole.gerente,
        UserRole.supervisor,
      ];
    }
    // Gerente da unidade pode criar/editar até Gerente da própria unidade
    return [
      UserRole.operacao,
      UserRole.assistente,
      UserRole.encarregado,
      UserRole.gerente,
    ];
  }

  Future<void> _showCreateEmployeeModal(
    BuildContext context,
    AuthController authController,
  ) async {
    final caller = authController.currentUser;
    final canSwitchCinema = caller?.role.canSwitchCinema ?? false;
    final allowedRoles = _allowedRolesToAssign(caller);

    final nameCtrl = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: '123456');
    UserRole selectedRole = UserRole.operacao;
    String selectedCinemaId = caller?.cinemaId ?? '2159';
    bool mustChangePassword = true;
    String? localError;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: const Text('Novo Colaborador'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome Completo',
                          hintText: 'Ex: João Silva',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usernameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Usuário de Login (sem @)',
                          hintText: 'Ex: joao.silva',
                          prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Senha Inicial',
                          prefixIcon: Icon(Icons.key_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<UserRole>(
                        key: ValueKey('create_role_$selectedRole'),
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Cargo',
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        ),
                        items: allowedRoles
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedRole = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (canSwitchCinema)
                        DropdownButtonFormField<String>(
                          key: ValueKey('create_cinema_$selectedCinemaId'),
                          initialValue: selectedCinemaId,
                          decoration: const InputDecoration(
                            labelText: 'Unidade / Cinema',
                            prefixIcon: Icon(Icons.theaters_rounded, size: 18),
                          ),
                          items: CinemaUnit.availableCinemas
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedCinemaId = val);
                            }
                          },
                        ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Exigir troca de senha no 1º acesso',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          'Pede para o colaborador criar uma senha pessoal ao entrar',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppleColors.textTertiary,
                          ),
                        ),
                        value: mustChangePassword,
                        activeTrackColor: AppleColors.accentBlue,
                        onChanged: (val) =>
                            setModalState(() => mustChangePassword = val),
                      ),
                      if (localError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          localError!,
                          style: TextStyle(
                            color: AppleColors.systemRed,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() {
                            isSaving = true;
                            localError = null;
                          });
                          final cinemaName =
                              CinemaUnit.nameForId(selectedCinemaId);
                          final err = await authController.createEmployee(
                            name: nameCtrl.text,
                            usernameOrEmail: usernameCtrl.text,
                            initialPassword: passwordCtrl.text,
                            role: selectedRole,
                            cinemaId: selectedCinemaId,
                            cinemaName: cinemaName,
                            mustChangePassword: mustChangePassword,
                          );
                          if (!ctx.mounted) return;
                          if (err != null) {
                            setModalState(() {
                              isSaving = false;
                              localError = err;
                            });
                          } else {
                            Navigator.pop(ctx);
                            showTopNotice(
                              context,
                              'Acesso criado para ${nameCtrl.text.trim()} (usuário: ${usernameCtrl.text.trim()})!',
                            );
                          }
                        },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                  label: const Text('Criar Acesso'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditEmployeeModal(
    BuildContext context,
    AuthController authController,
    AppUser targetUser,
  ) async {
    final caller = authController.currentUser;
    final canSwitchCinema = caller?.role.canSwitchCinema ?? false;
    final allowedRoles = _allowedRolesToAssign(caller);

    final nameCtrl = TextEditingController(text: targetUser.name);
    final resetPassCtrl = TextEditingController();
    UserRole selectedRole = allowedRoles.contains(targetUser.role)
        ? targetUser.role
        : allowedRoles.first;
    String selectedCinemaId = targetUser.cinemaId;
    bool isActive = targetUser.active;
    bool requirePassChange = targetUser.mustChangePassword;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: Text('Editar • ${targetUser.displayUsername}'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<UserRole>(
                        key: ValueKey('edit_role_$selectedRole'),
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Cargo / Permissão',
                          prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        ),
                        items: allowedRoles
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedRole = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (canSwitchCinema)
                        DropdownButtonFormField<String>(
                          key: ValueKey('edit_cinema_$selectedCinemaId'),
                          initialValue: selectedCinemaId,
                          decoration: const InputDecoration(
                            labelText: 'Transferir de Cinema',
                            prefixIcon: Icon(Icons.theaters_rounded, size: 18),
                          ),
                          items: CinemaUnit.availableCinemas
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => selectedCinemaId = val);
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: resetPassCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Redefinir Senha (deixe vazio para manter)',
                          hintText: 'Ex: 123456',
                          prefixIcon: Icon(Icons.lock_reset_rounded, size: 18),
                        ),
                        onChanged: (val) {
                          if (val.trim().isNotEmpty && !requirePassChange) {
                            setModalState(() => requirePassChange = true);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Conta Ativa',
                          style: TextStyle(fontSize: 13.5),
                        ),
                        subtitle: Text(
                          isActive
                              ? 'Colaborador pode acessar o sistema'
                              : 'Acesso bloqueado imediatamente',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isActive
                                ? AppleColors.systemGreen
                                : AppleColors.systemRed,
                          ),
                        ),
                        value: isActive,
                        activeTrackColor: AppleColors.systemGreen,
                        onChanged: (val) => setModalState(() => isActive = val),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Solicitar nova senha no próximo login',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: requirePassChange,
                        activeTrackColor: AppleColors.accentBlue,
                        onChanged: (val) =>
                            setModalState(() => requirePassChange = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final updated = targetUser.copyWith(
                      name: nameCtrl.text.trim(),
                      role: selectedRole,
                      cinemaId: selectedCinemaId,
                      cinemaName: CinemaUnit.nameForId(selectedCinemaId),
                      active: isActive,
                      mustChangePassword: requirePassChange,
                    );
                    await authController.updateEmployee(
                      updated,
                      newResetPassword: resetPassCtrl.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    showTopNotice(
                      context,
                      'Dados de ${updated.name} atualizados!',
                    );
                  },
                  child: const Text('Salvar Alterações'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);
    final currentUser = authController.currentUser;
    final canSwitchCinema = currentUser?.role.canSwitchCinema ?? false;

    final filteredMembers = authController.teamMembers.where((u) {
      if (_selectedRoleFilter != 'all' && u.role.name != _selectedRoleFilter) {
        return false;
      }
      if (_selectedCinemaFilter != 'all' &&
          u.cinemaId != _selectedCinemaFilter) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Equipe & Acessos'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ApplePressable(
              pressedScale: 0.95,
              onPressed: () =>
                  _showCreateEmployeeModal(context, authController),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppleColors.accentBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Novo Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de filtros por Cargo e Cinema
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: AppleColors.backgroundSecondary,
                  border: Border(
                    bottom: BorderSide(color: AppleColors.glassBorder),
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 210,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('role_filter_$_selectedRoleFilter'),
                        initialValue: _selectedRoleFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Cargo',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Todos os Cargos'),
                          ),
                          ...UserRole.values.map(
                            (r) => DropdownMenuItem(
                              value: r.name,
                              child: Text(r.displayName),
                            ),
                          ),
                        ],
                        onChanged: (val) => setState(
                          () => _selectedRoleFilter = val ?? 'all',
                        ),
                      ),
                    ),
                    if (canSwitchCinema)
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('cinema_filter_$_selectedCinemaFilter'),
                          initialValue: _selectedCinemaFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filtrar por Cinema',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('Todas as Unidades'),
                            ),
                            ...CinemaUnit.availableCinemas.map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(
                            () => _selectedCinemaFilter = val ?? 'all',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: authController.isLoadingTeam
                    ? const Center(child: CircularProgressIndicator())
                    : filteredMembers.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhum colaborador encontrado para este filtro.',
                              style: TextStyle(color: AppleColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredMembers.length,
                            itemBuilder: (context, index) {
                              final member = filteredMembers[index];
                              final roleColor = _getRoleColor(member.role);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: AppleGlassCard(
                                  onTap: () => _showEditEmployeeModal(
                                    context,
                                    authController,
                                    member,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  borderRadius: 15,
                                  borderColor: !member.active
                                      ? AppleColors.systemRed.withValues(
                                          alpha: 0.4,
                                        )
                                      : AppleColors.glassBorder,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: roleColor.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(11),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          member.name.isNotEmpty
                                              ? member.name[0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            color: roleColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    member.name,
                                                    style: TextStyle(
                                                      color: member.active
                                                          ? AppleColors
                                                              .textPrimary
                                                          : AppleColors
                                                              .textTertiary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                      decoration: member.active
                                                          ? null
                                                          : TextDecoration
                                                              .lineThrough,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (!member.active)
                                                  AppleStatusPill(
                                                    label: 'Bloqueado',
                                                    color: AppleColors.systemRed,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Usuário: ${member.displayUsername} • ${member.cinemaName}',
                                              style: TextStyle(
                                                color:
                                                    AppleColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AppleStatusPill(
                                        label: member.role.displayName,
                                        color: roleColor,
                                      ),
                                      const SizedBox(width: 6),
                                      if (member.id != currentUser?.id &&
                                          member.role != UserRole.admin)
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppleColors.systemRed,
                                            size: 19,
                                          ),
                                          tooltip: 'Excluir acesso',
                                          onPressed: () async {
                                            await authController
                                                .deleteEmployee(member);
                                            if (context.mounted) {
                                              showTopNotice(
                                                context,
                                                'Acesso de ${member.name} removido.',
                                                isWarning: true,
                                              );
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
