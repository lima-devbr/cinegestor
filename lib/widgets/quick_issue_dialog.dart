import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/room.dart';
import '../models/maintenance_issue.dart';
import '../models/app_user.dart';
import '../models/cinema_sector.dart';
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
          key: 'GERAL-ILUMINACAO',
          label: 'Iluminação Geral / Lâmpada',
          icon: Icons.lightbulb_outline_rounded,
          color: const Color(0xFFFFD60A),
        ),
        QuickIssueCategory(
          key: 'GERAL-CARPETE',
          label: 'Piso / Carpete / Passarela',
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
          label: 'Som / Imagem / Telas',
          icon: Icons.volume_up_rounded,
          color: AppleColors.accentIndigo,
        ),
        QuickIssueCategory(
          key: 'GERAL-LIMPEZA',
          label: 'Limpeza Pesada / Derramamento',
          icon: Icons.cleaning_services_rounded,
          color: AppleColors.systemGreen,
        ),
        QuickIssueCategory(
          key: 'GERAL-SEGURANCA',
          label: 'Segurança / Extintor / Sinalização',
          icon: Icons.health_and_safety_rounded,
          color: AppleColors.systemRed,
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
    CinemaSector? preSelectedSector,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickIssueSheet(
        roomController: roomController,
        initialRoom: preSelectedRoom,
        initialSector: preSelectedSector,
      ),
    );
  }
}

class _QuickIssueSheet extends StatefulWidget {
  final RoomController roomController;
  final Room? initialRoom;
  final CinemaSector? initialSector;

  const _QuickIssueSheet({
    required this.roomController,
    this.initialRoom,
    this.initialSector,
  });

  @override
  State<_QuickIssueSheet> createState() => _QuickIssueSheetState();
}

class _QuickIssueSheetState extends State<_QuickIssueSheet> {
  late String _locationType; // 'room' ou 'common'
  Room? _selectedRoom;
  CinemaSector _selectedSector = CinemaSector.commonSectors.first;
  QuickIssueCategory _selectedCategory = QuickIssueCategory.categories.first;
  String _selectedUrgency = 'Média';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _photoBase64;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSector != null) {
      _locationType = 'common';
      _selectedSector = widget.initialSector!;
      _selectedRoom = widget.roomController.rooms.isNotEmpty
          ? widget.roomController.rooms.first
          : null;
    } else if (widget.initialRoom != null) {
      _locationType = 'room';
      _selectedRoom = widget.initialRoom;
    } else if (widget.roomController.rooms.isNotEmpty) {
      _locationType = 'room';
      _selectedRoom = widget.roomController.rooms.first;
    } else {
      _locationType = 'common';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _currentLocationName {
    if (_locationType == 'room') {
      return _selectedRoom?.nome ?? 'Sala não selecionada';
    }
    return _selectedSector.name;
  }

  String get _placeholderText {
    if (_locationType == 'common') {
      switch (_selectedSector.id) {
        case 'setor_bomboniere':
          return 'Ex: Pipocqueira com resistência falhando, estufa fria';
        case 'setor_bilheteria':
          return 'Ex: Toten 2 travado na impressão, monitor apagado';
        case 'setor_banheiro_f':
        case 'setor_banheiro_m':
          return 'Ex: Torneira com vazamento, trinco quebrado, descarga fraca';
        case 'setor_foyer':
          return 'Ex: Lâmpada do corredor piscando, display apagado';
        case 'setor_gerencia':
          return 'Ex: Ar-condicionado não gela, tomada sem energia';
        case 'setor_area_funcionarios':
          return 'Ex: Torneira do tanque com vazamento no DML, micro-ondas falhando';
        default:
          return 'Ex: Descreva o problema encontrado no setor';
      }
    }
    return 'Ex: Dreno do ar pingando próximo à saída de emergência';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showTopNotice(
        context,
        'Informe o que está acontecendo.',
        isError: true,
      );
      return;
    }

    if (_locationType == 'room' && _selectedRoom == null) {
      showTopNotice(context, 'Selecione a sala da ocorrência.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthController>(context, listen: false);
      final user = auth.currentUser;
      final createsAsStaging = user?.role.createsAsStaging ?? false;

      final isRoom = _locationType == 'room';
      final roomId = isRoom ? _selectedRoom!.id : _selectedSector.id;
      final cinemaId = isRoom
          ? (_selectedRoom!.theaterId ?? user?.cinemaId ?? '2159')
          : (user?.cinemaId ?? '2159');
      final locationName = isRoom ? _selectedRoom!.nome : _selectedSector.name;

      final issue = MaintenanceIssue(
        cinemaId: cinemaId,
        roomId: roomId,
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
              ? 'Ocorrência enviada para Triagem em $locationName!'
              : 'Chamado aberto com sucesso em $locationName!',
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
                        'Novo Chamado',
                        style: TextStyle(
                          color: AppleColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Defina o Setor e a Categoria do problema',
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
            const SizedBox(height: 14),

            // SELEÇÃO DE SETOR / LOCAL
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1. Setor / Local',
                  style: TextStyle(
                    color: AppleColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppleColors.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '📍 $_currentLocationName',
                    style: TextStyle(
                      color: AppleColors.accentBlue,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Alternância entre Áreas Comuns e Salas
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppleColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _locationType = 'room'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _locationType == 'room'
                              ? AppleColors.accentBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.theaters_rounded,
                                size: 14,
                                color: _locationType == 'room'
                                    ? Colors.white
                                    : AppleColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Salas de Cinema (${rooms.length})',
                                style: TextStyle(
                                  color: _locationType == 'room'
                                      ? Colors.white
                                      : AppleColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _locationType = 'common'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: _locationType == 'common'
                              ? AppleColors.accentBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 14,
                                color: _locationType == 'common'
                                    ? Colors.white
                                    : AppleColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Áreas Comuns (${CinemaSector.commonSectors.length})',
                                style: TextStyle(
                                  color: _locationType == 'common'
                                      ? Colors.white
                                      : AppleColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Chips das Salas ou Setores
            if (_locationType == 'room') ...[
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
                          fontWeight:
                              isSel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ] else ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: CinemaSector.commonSectors.map((sector) {
                    final isSel = _selectedSector.id == sector.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          sector.icon,
                          size: 15,
                          color: isSel ? Colors.white : AppleColors.accentBlue,
                        ),
                        label: Text(sector.name),
                        selected: isSel,
                        selectedColor: AppleColors.accentBlue,
                        onSelected: (_) =>
                            setState(() => _selectedSector = sector),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppleColors.textPrimary,
                          fontWeight:
                              isSel ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // SELEÇÃO DE CATEGORIA
            Text(
              '2. Categoria do Defeito',
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
                  avatar: Icon(cat.icon,
                      size: 16, color: isSel ? Colors.white : cat.color),
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

            // O QUE ESTÁ ACONTECENDO?
            Text(
              '3. O que está acontecendo?',
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
                hintText: _placeholderText,
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
                hintText:
                    'Observações adicionais ou detalhes específicos do local (opcional)',
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

            // NÍVEL DE URGÊNCIA
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

            // FOTO DA OCORRÊNCIA
            PhotoEvidencePickerTile(
              photoBase64: _photoBase64,
              label: 'Foto da Ocorrência (Recomendado)',
              onChanged: (val) => setState(() => _photoBase64 = val),
            ),

            const SizedBox(height: 20),

            // BOTÃO DE ENVIO
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
