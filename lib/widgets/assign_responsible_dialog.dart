import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/room_controller.dart';
import '../models/maintenance_issue.dart';
import '../models/app_user.dart';
import 'apple_surfaces.dart';

class AssignResponsibleDialog extends StatefulWidget {
  final MaintenanceIssue issue;
  final RoomController roomController;

  const AssignResponsibleDialog({
    super.key,
    required this.issue,
    required this.roomController,
  });

  static Future<void> show({
    required BuildContext context,
    required MaintenanceIssue issue,
    required RoomController roomController,
  }) async {
    final auth = Provider.of<AuthController>(context, listen: false);
    if (auth.teamMembers.isEmpty && !auth.isLoadingTeam) {
      await auth.loadTeamMembers();
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AssignResponsibleDialog(
        issue: issue,
        roomController: roomController,
      ),
    );
  }

  @override
  State<AssignResponsibleDialog> createState() =>
      _AssignResponsibleDialogState();
}

class _AssignResponsibleDialogState extends State<AssignResponsibleDialog> {
  late final TextEditingController _customResponsibleController;
  String? _selectedMemberName;
  bool _isCustomContractor = false;
  bool _markInProgress = true;

  static const List<String> _quickSuggestions = [
    'Tapeçaria / Poltronas',
    'Técnico de Ar-Condicionado',
    'Eletricista Predial',
    'Áudio & Projeção',
    'Limpeza / Higienização',
    'Encarregado Local',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.issue.assignedTo ?? '';
    _customResponsibleController = TextEditingController(text: existing);

    final auth = Provider.of<AuthController>(context, listen: false);
    final isTeamMember =
        auth.teamMembers.any((m) => m.name == existing || m.displayUsername == existing);

    if (existing.isNotEmpty && isTeamMember) {
      _selectedMemberName = existing;
      _isCustomContractor = false;
    } else if (existing.isNotEmpty) {
      _isCustomContractor = true;
    } else if (auth.teamMembers.isNotEmpty) {
      _selectedMemberName = auth.teamMembers.first.name;
    }

    _markInProgress = widget.issue.status != IssueStatus.inProgress;
  }

  @override
  void dispose() {
    _customResponsibleController.dispose();
    super.dispose();
  }

  String _getFinalResponsibleName() {
    if (_isCustomContractor) {
      return _customResponsibleController.text.trim();
    }
    return (_selectedMemberName ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final members = auth.teamMembers.where((u) => u.active).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppleColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppleColors.accentIndigo.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_ind_rounded,
                      color: AppleColors.accentIndigo,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atribuir Responsável',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: AppleColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.issue.targetDisplayLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppleColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card do problema
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppleColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppleColors.glassBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.issue.problemType,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppleColors.textPrimary,
                      ),
                    ),
                    if (widget.issue.notes != null &&
                        widget.issue.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Obs: ${widget.issue.notes}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppleColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Alternador: Membro da equipe vs Terceirizada
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Equipe Interna'),
                      selected: !_isCustomContractor,
                      onSelected: (val) {
                        setState(() {
                          _isCustomContractor = !val;
                          if (members.isNotEmpty &&
                              _selectedMemberName == null) {
                            _selectedMemberName = members.first.name;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Terceirizada / Outro'),
                      selected: _isCustomContractor,
                      onSelected: (val) {
                        setState(() => _isCustomContractor = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (!_isCustomContractor) ...[
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhum colaborador carregado. Use a opção Terceirizada/Outro.',
                      style: TextStyle(
                        color: AppleColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: members.any((m) => m.name == _selectedMemberName)
                        ? _selectedMemberName
                        : members.first.name,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Colaborador Responsável',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: members.map((u) {
                      return DropdownMenuItem(
                        value: u.name,
                        child: Text(
                          '${u.name} (${u.role.displayName})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMemberName = val);
                      }
                    },
                  ),
              ] else ...[
                TextField(
                  controller: _customResponsibleController,
                  decoration: InputDecoration(
                    labelText: 'Nome do Técnico ou Empresa',
                    hintText: 'Ex: Tapeçaria Santos, ArFrio Climatização',
                    prefixIcon: const Icon(Icons.engineering_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickSuggestions.map((sug) {
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _customResponsibleController.text = sug;
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppleColors.accentIndigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '+ $sug',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppleColors.accentIndigo,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),

              // Switch para marcar como "Em Andamento"
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Atualizar status para "Em Andamento"',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Indica que o serviço de manutenção já foi iniciado',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppleColors.textSecondary,
                  ),
                ),
                value: _markInProgress,
                activeTrackColor: AppleColors.accentIndigo,
                onChanged: (val) => setState(() => _markInProgress = val),
              ),
              const SizedBox(height: 12),

              // Botões de Ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppleColors.accentIndigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final name = _getFinalResponsibleName();
                      if (name.isEmpty) {
                        showTopNotice(
                          context,
                          'Informe o responsável ou empresa executante.',
                          isError: true,
                        );
                        return;
                      }

                      await widget.roomController.assignIssue(
                        widget.issue.id,
                        assignedTo: name,
                        markInProgress: _markInProgress,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        showTopNotice(
                          context,
                          'OS atribuída a $name com sucesso!',
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
