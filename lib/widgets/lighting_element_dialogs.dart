import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/room.dart';
import '../models/maintenance_issue.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import 'apple_surfaces.dart';
import 'photo_evidence_widgets.dart';

class LightingElementDialogs {
  static void showInspectionSheet({
    required BuildContext context,
    required RoomLightingItem item,
    required Room room,
    required RoomController roomController,
    required AuthController authController,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LightingInspectionContent(
        item: item,
        room: room,
        roomController: roomController,
        authController: authController,
      ),
    );
  }
}

class _LightingInspectionContent extends StatefulWidget {
  final RoomLightingItem item;
  final Room room;
  final RoomController roomController;
  final AuthController authController;

  const _LightingInspectionContent({
    required this.item,
    required this.room,
    required this.roomController,
    required this.authController,
  });

  @override
  State<_LightingInspectionContent> createState() =>
      _LightingInspectionContentState();
}

class _LightingInspectionContentState
    extends State<_LightingInspectionContent> {
  bool _isCreatingIssue = false;
  String? _selectedProblemType;
  String _selectedUrgency = 'Média';
  final TextEditingController _notesController = TextEditingController();
  String? _photoBase64;
  String? _afterPhotoBase64;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  List<String> get _problemOptions {
    if (widget.item.isStepLed) {
      return [
        'Fita LED Apagada',
        'Trecho com Falha / Piscando',
        'Perfil de Degrau Solto',
        'Fonte Queimada',
        'Fiação Exposta',
      ];
    }
    if (widget.item.isWallSconce) {
      return [
        'Lâmpada Queimada',
        'Flickering / Oscilando no Dimer',
        'Arandela Quebrada / Frouxa',
        'Não Dimeriza (Sempre no Máximo)',
      ];
    }
    return [
      'Refletor Queimado',
      'Reator com Falha',
      'Foco Desalinhado / Apontando Errado',
    ];
  }

  MaintenanceIssue? get _currentActiveIssue {
    final list = widget.roomController.issues.where(
      (i) => i.roomId == widget.room.id && i.seatId == widget.item.id,
    ).toList();

    try {
      return list.firstWhere((i) => i.isActive || i.isStaging);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitNewIssue() async {
    if (_selectedProblemType == null) {
      showTopNotice(context, 'Selecione o tipo de defeito na iluminação.',
          isError: true);
      return;
    }

    final user = widget.authController.currentUser;
    final createsAsStaging = user?.role.createsAsStaging ?? false;

    final newIssue = MaintenanceIssue(
      cinemaId: widget.room.theaterId ?? '2160',
      roomId: widget.room.id,
      seatId: widget.item.id,
      problemType: _selectedProblemType!,
      urgency: _selectedUrgency,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      reportedBy: user?.name ?? user?.email ?? 'Equipe',
      reportedRole: user?.role.name,
      beforePhotoBase64: _photoBase64,
      status: createsAsStaging ? IssueStatus.staging : IssueStatus.active,
    );

    await widget.roomController.registerIssue(newIssue);

    if (mounted) {
      Navigator.pop(context);
      showTopNotice(
        context,
        createsAsStaging
            ? 'Solicitação para "${widget.item.name}" enviada para Triagem!'
            : 'Demanda de iluminação criada para "${widget.item.name}"!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.currentUser;
    final activeIssue = _currentActiveIssue;

    final Color categoryColor = widget.item.isStepLed
        ? const Color(0xFFFFD60A)
        : widget.item.isWallSconce
            ? AppleColors.systemOrange
            : AppleColors.accentBlue;

    final IconData categoryIcon = widget.item.isStepLed
        ? Icons.stairs_rounded
        : widget.item.isWallSconce
            ? Icons.lightbulb_rounded
            : Icons.highlight_rounded;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppleColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de arraste
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppleColors.textTertiary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),

            // Cabeçalho do Elemento de Luz
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: categoryColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Icon(categoryIcon, color: categoryColor, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: TextStyle(
                          color: AppleColors.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.room.nome} • Circuito: ${widget.item.circuit ?? "Padrão"}',
                        style: TextStyle(
                          color: AppleColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeIssue != null)
                  AppleStatusPill(
                    label: activeIssue.status.displayName,
                    color: activeIssue.isActive
                        ? AppleColors.systemRed
                        : AppleColors.systemAmber,
                  )
                else
                  AppleStatusPill(
                    label: 'Operacional',
                    color: AppleColors.systemGreen,
                  ),
              ],
            ),

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 18),

            // Se JÁ POSSUI defeito aberto
            if (activeIssue != null) ...[
              Text(
                'Problema Reportado',
                style: TextStyle(
                  color: AppleColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppleColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppleColors.systemRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          activeIssue.problemType,
                          style: TextStyle(
                            color: AppleColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Urgência ${activeIssue.urgency}',
                          style: TextStyle(
                            color: activeIssue.urgency == 'Alta'
                                ? AppleColors.systemRed
                                : AppleColors.systemOrange,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Por ${activeIssue.reportedBy ?? "Equipe"} • ${DateFormat("dd/MM/yyyy HH:mm").format(activeIssue.dateTime)}',
                      style: TextStyle(
                        color: AppleColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    if (activeIssue.notes != null &&
                        activeIssue.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Obs: ${activeIssue.notes}',
                        style: TextStyle(
                          color: AppleColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (activeIssue.beforePhotoBase64 != null &&
                        activeIssue.beforePhotoBase64!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      PhotoEvidenceThumb(
                        photoBase64: activeIssue.beforePhotoBase64!,
                        tagLabel: 'Foto do defeito',
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Ações sobre o chamado ativo
              if (activeIssue.isStaging &&
                  (user?.role.canApproveStaging ?? false)) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await widget.roomController.rejectStagingIssue(
                            activeIssue.id,
                            reason: 'Recusado na inspeção de iluminação',
                          );
                        },
                        icon: Icon(Icons.close_rounded,
                            color: AppleColors.systemRed),
                        label: Text('Recusar',
                            style: TextStyle(color: AppleColors.systemRed)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await widget.roomController.approveStagingIssue(
                            activeIssue.id,
                            approvedBy: user?.name,
                          );
                          if (context.mounted) {
                            showTopNotice(context, 'Solicitação aprovada!');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppleColors.systemGreen,
                          foregroundColor: Colors.black,
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Aprovar'),
                      ),
                    ),
                  ],
                ),
              ] else if (activeIssue.isActive &&
                  (user?.role.canResolveIssue ?? false)) ...[
                PhotoEvidencePickerTile(
                  photoBase64: _afterPhotoBase64,
                  label: 'Foto do reparo concluído (opcional)',
                  onChanged: (val) => setState(() => _afterPhotoBase64 = val),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await widget.roomController.resolveIssue(
                        activeIssue.id,
                        resolvedBy: user?.name,
                        afterPhotoBase64: _afterPhotoBase64,
                      );
                      if (context.mounted) {
                        showTopNotice(context,
                            'Reparo de "${widget.item.name}" concluído com sucesso!');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppleColors.systemGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Concluir Manutenção / Reparo',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ] else if (!_isCreatingIssue) ...[
              // Elemento está operacional
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppleColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppleColors.systemGreen.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: AppleColors.systemGreen, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Iluminação em funcionamento',
                            style: TextStyle(
                              color: AppleColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            widget.item.isStepLed
                                ? 'Fita LED e balizador operando normalmente'
                                : widget.item.isWallSconce
                                    ? 'Arandela dimerizável respondendo normalmente'
                                    : 'Refletor de limpeza ativo',
                            style: TextStyle(
                              color: AppleColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _isCreatingIssue = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppleColors.systemRed.withValues(alpha: 0.15),
                    foregroundColor: AppleColors.systemRed,
                    elevation: 0,
                    side: BorderSide(color: AppleColors.systemRed, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.report_problem_rounded),
                  label: const Text(
                    'Reportar Falha / Queimado',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else ...[
              // Formulário de Abertura de Falha de Iluminação
              Text(
                'Selecione a Falha Identificada:',
                style: TextStyle(
                  color: AppleColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _problemOptions.map((opt) {
                  final isSelected = _selectedProblemType == opt;
                  return ChoiceChip(
                    label: Text(opt),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedProblemType = val ? opt : null;
                      });
                    },
                    selectedColor: AppleColors.accentBlue,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppleColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Urgência: ',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...['Baixa', 'Média', 'Alta'].map((u) {
                    final isSel = _selectedUrgency == u;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(u),
                        selected: isSel,
                        onSelected: (_) => setState(() => _selectedUrgency = u),
                        selectedColor: u == 'Alta'
                            ? AppleColors.systemRed
                            : u == 'Média'
                                ? AppleColors.systemOrange
                                : AppleColors.systemGreen,
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppleColors.textPrimary,
                          fontSize: 11.5,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 14),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Observações adicionais (ex: piscando rápido)',
                  filled: true,
                  fillColor: AppleColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 14),
              PhotoEvidencePickerTile(
                photoBase64: _photoBase64,
                label: 'Foto da falha (opcional)',
                onChanged: (val) => setState(() => _photoBase64 = val),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _isCreatingIssue = false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _submitNewIssue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppleColors.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text(
                        'Confirmar Abertura',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
