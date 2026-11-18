import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../models/maintenance_issue.dart';
import '../models/app_user.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import 'apple_surfaces.dart';
import 'photo_evidence_widgets.dart';

class QuickIssueCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  const QuickIssueCategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  static List<QuickIssueCategory> get categories => [
        QuickIssueCategory(
          key: 'GERAL-AR-COND',
          label: 'Ar-Condicionado / Climatização',
          icon: Icons.ac_unit_rounded,
          color: AppleColors.systemCyan,
        ),
        QuickIssueCategory(
          key: 'GERAL-CARPETE',
          label: 'Carpete / Piso / Passarela',
          icon: Icons.layers_rounded,
          color: AppleColors.systemOrange,
        ),
        QuickIssueCategory(
          key: 'GERAL-PORTA',
          label: 'Porta / Saída de Emergência',
          icon: Icons.meeting_room_rounded,
          color: AppleColors.systemRed,
        ),
        QuickIssueCategory(
          key: 'GERAL-SOM-TELA',
          label: 'Som / Projeção / Tela',
          icon: Icons.volume_up_rounded,
          color: AppleColors.accentIndigo,
        ),
        QuickIssueCategory(
          key: 'GERAL-ILUMINACAO',
          label: 'Iluminação Geral / Teto',
          icon: Icons.lightbulb_outline_rounded,
          color: const Color(0xFFFFD60A),
        ),
        QuickIssueCategory(
          key: 'GERAL-SEGURANCA',
          label: 'Segurança / Extintor / Barra',
          icon: Icons.health_and_safety_rounded,
          color: AppleColors.systemRed,
        ),
        QuickIssueCategory(
          key: 'GERAL-LIMPEZA',
          label: 'Limpeza Pesada / Derramamento',
          icon: Icons.cleaning_services_rounded,
          color: AppleColors.systemGreen,
        ),
        QuickIssueCategory(
          key: 'GERAL-OUTROS',
          label: 'Outros / Predial Geral',
          icon: Icons.build_circle_rounded,
          color: AppleColors.textSecondary,
        ),
      ];
}

class QuickIssueDialog {
  static Future<void> show({
    required BuildContext context,
    required RoomController roomController,
    Room? preSelectedRoom,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickIssueSheet(
        roomController: roomController,
        initialRoom: preSelectedRoom,
      ),
    );
  }
}

class _QuickIssueSheet extends StatefulWidget {
  final RoomController roomController;
  final Room? initialRoom;

  const _QuickIssueSheet({
    required this.roomController,
    this.initialRoom,
  });

  @override
  State<_QuickIssueSheet> createState() => _QuickIssueSheetState();
}

class _QuickIssueSheetState extends State<_QuickIssueSheet> {
  Room? _selectedRoom;
  QuickIssueCategory _selectedCategory = QuickIssueCategory.categories.first;
  String _selectedUrgency = 'Média';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _photoBase64;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.initialRoom ??
        (widget.roomController.rooms.isNotEmpty
            ? widget.roomController.rooms.first
            : null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRoom == null) {
      showTopNotice(context, 'Selecione a sala da ocorrência.', isError: true);
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showTopNotice(
        context,
        'Informe o que está acontecendo (ex: dreno pingando).',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthController>(context, listen: false);
      final user = auth.currentUser;
      final createsAsStaging = user?.role.createsAsStaging ?? false;

      final issue = MaintenanceIssue(
        cinemaId: _selectedRoom!.theaterId ?? user?.cinemaId ?? '2159',
        roomId: _selectedRoom!.id,
        seatId: _selectedCategory.key,
        problemType: '${_selectedCategory.label}: $title',
        urgency: _selectedUrgency,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        reportedBy: user?.name ?? user?.email ?? 'Equipe',
        reportedRole: user?.role.name,
        beforePhotoBase64: _photoBase64,
        status: createsAsStaging ? IssueStatus.staging : IssueStatus.active,
      );

      await widget.roomController.registerIssue(issue);

      if (mounted) {
        Navigator.pop(context);
        showTopNotice(
          context,
          createsAsStaging
              ? 'Ocorrência enviada para Triagem na ${_selectedRoom!.nome}!'
              : 'Chamado aberto com sucesso na ${_selectedRoom!.nome}!',
        );
      }
    } catch (e) {
      if (mounted) {
        showTopNotice(context, 'Erro ao registrar chamado: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.roomController.rooms;

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

            // Título
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppleColors.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_task_rounded,
                      color: AppleColors.accentBlue,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Novo Chamado Rápido',
                        style: TextStyle(
                          color: AppleColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Ocorrências gerais, prediais e infraestrutura da sala',
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

            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Seleção de Sala (se não pré-selecionada)
            if (widget.initialRoom == null && rooms.isNotEmpty) ...[
              Text(
                'Sala da Ocorrência',
                style: TextStyle(
                  color: AppleColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: rooms.map((r) {
                    final isSel = _selectedRoom?.id == r.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(r.nome),
                        selected: isSel,
                        selectedColor: AppleColors.accentBlue,
                        onSelected: (_) => setState(() => _selectedRoom = r),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppleColors.textPrimary,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Categorias
            Text(
              'Setor / Categoria',
              style: TextStyle(
                color: AppleColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: QuickIssueCategory.categories.map((cat) {
                final isSel = _selectedCategory.key == cat.key;
                return ChoiceChip(
                  avatar: Icon(cat.icon, size: 16, color: isSel ? Colors.white : cat.color),
                  label: Text(cat.label),
                  selected: isSel,
                  selectedColor: AppleColors.accentBlue,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  labelStyle: TextStyle(
                    color: isSel ? Colors.white : AppleColors.textPrimary,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Descrição do problema
            Text(
              'O que está acontecendo?',
              style: TextStyle(
                color: AppleColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Ex: Dreno pingando água próximo à saída',
                filled: true,
                fillColor: AppleColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Observações adicionais ou localização detalhada',
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

            // Nível de Urgência
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

            // Foto da Ocorrência
            PhotoEvidencePickerTile(
              photoBase64: _photoBase64,
              label: 'Foto da Ocorrência (Recomendado)',
              onChanged: (val) => setState(() => _photoBase64 = val),
            ),

            const SizedBox(height: 20),

            // Botão de envio
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppleColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Registrando...' : 'Registrar Chamado',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
