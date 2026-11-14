import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/maintenance_issue.dart';
import '../models/room.dart';
import '../models/app_user.dart';
import '../widgets/apple_surfaces.dart';

class DefectSummaryPage extends StatefulWidget {
  final String? initialProblemType;

  const DefectSummaryPage({super.key, this.initialProblemType});

  /// Padroniza nomes antigos para agrupar junto com as novas nomenclaturas
  static String normalizeProblemType(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'sem número' ||
        lower == 'sem numero' ||
        lower == 'poltrona sem número') {
      return 'Poltrona sem Número';
    }
    if (lower == 'sem bracinho' || lower == 'bracinho solto') {
      return 'Bracinho Solto';
    }
    if (lower == 'capa rasgada') {
      return 'Capa Rasgada';
    }
    return raw.trim();
  }

  @override
  State<DefectSummaryPage> createState() => _DefectSummaryPageState();
}

class _DefectSummaryPageState extends State<DefectSummaryPage> {
  String _selectedProblemType = 'all';
  bool _includeStaging = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProblemType != null &&
        widget.initialProblemType!.isNotEmpty) {
      _selectedProblemType = widget.initialProblemType!;
    }
  }

  static String normalizeProblemType(String raw) =>
      DefectSummaryPage.normalizeProblemType(raw);

  IconData _getIconForProblem(String problemType) {
    final normalized = normalizeProblemType(problemType).toLowerCase();
    if (normalized.contains('capa')) return Icons.texture_rounded;
    if (normalized.contains('bracinho') || normalized.contains('braço')) {
      return Icons.airline_seat_recline_normal_rounded;
    }
    if (normalized.contains('número') || normalized.contains('numero')) {
      return Icons.pin_outlined;
    }
    if (normalized.contains('mola') || normalized.contains('reclina')) {
      return Icons.settings_suggest_rounded;
    }
    if (normalized.contains('encosto')) return Icons.event_seat_rounded;
    if (normalized.contains('barulho')) return Icons.volume_up_outlined;
    return Icons.build_circle_outlined;
  }

  Color _getColorForProblem(String problemType) {
    final normalized = normalizeProblemType(problemType).toLowerCase();
    if (normalized.contains('capa')) return AppleColors.systemOrange;
    if (normalized.contains('bracinho')) return AppleColors.systemCyan;
    if (normalized.contains('número') || normalized.contains('numero')) {
      return AppleColors.systemAmber;
    }
    if (normalized.contains('mola') || normalized.contains('reclina')) {
      return AppleColors.systemRed;
    }
    if (normalized.contains('encosto')) return AppleColors.systemPurple;
    return AppleColors.accentBlue;
  }

  List<MaintenanceIssue> _getTargetIssues(RoomController roomController) {
    return roomController.issues.where((issue) {
      if (_includeStaging) {
        return issue.isActive || issue.isStaging;
      }
      return issue.isActive;
    }).toList();
  }

  Map<String, int> _getCountsByProblemType(
    List<MaintenanceIssue> targetIssues,
  ) {
    final Map<String, int> counts = {
      'Capa Rasgada': 0,
      'Bracinho Solto': 0,
      'Poltrona sem Número': 0,
    };

    for (final issue in targetIssues) {
      final type = normalizeProblemType(issue.problemType);
      counts[type] = (counts[type] ?? 0) + 1;
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return a.key.compareTo(b.key);
      });

    return Map.fromEntries(sortedEntries);
  }

  void _exportTaskChecklist(
    BuildContext context,
    List<MaintenanceIssue> targetIssues,
    RoomController roomController,
  ) {
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final buffer = StringBuffer();
    buffer.writeln('=== ROTEIRO DE MANUTENÇÃO POR TAREFA ===');
    buffer.writeln('Gerado em: $now');
    if (_selectedProblemType != 'all') {
      buffer.writeln('Filtro de Tarefa: $_selectedProblemType');
    }
    buffer.writeln('----------------------------------------');

    final counts = _getCountsByProblemType(targetIssues);
    buffer.writeln('RESUMO GERAL DE ITENS PENDENTES:');
    for (final entry in counts.entries) {
      if (entry.value > 0) {
        buffer.writeln('• ${entry.key}: ${entry.value} poltrona(s)');
      }
    }
    buffer.writeln('----------------------------------------');

    for (final room in roomController.rooms) {
      final roomIssues = targetIssues.where((i) {
        if (i.roomId != room.id) return false;
        if (_selectedProblemType != 'all' &&
            normalizeProblemType(i.problemType) != _selectedProblemType) {
          return false;
        }
        return true;
      }).toList();

      if (roomIssues.isEmpty) continue;

      buffer.writeln(
        '\n📍 ${room.displayName.toUpperCase()} (${roomIssues.length} item(ns)):',
      );
      final Map<String, List<MaintenanceIssue>> byType = {};
      for (final issue in roomIssues) {
        final type = normalizeProblemType(issue.problemType);
        byType.putIfAbsent(type, () => []).add(issue);
      }

      for (final entry in byType.entries) {
        final seats = entry.value.map((i) => i.seatId).toList()..sort();
        buffer.writeln(
          '  🔧 ${entry.key} (${entry.value.length}x): Assentos [ ${seats.join(', ')} ]',
        );
      }
    }

    final reportText = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copiar Roteiro de Manutenção'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: SelectableText(
              reportText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reportText));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Roteiro copiado para enviar à equipe de manutenção!',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('Copiar Roteiro'),
          ),
        ],
      ),
    );
  }

  Widget _buildDefectCounterBar(
    Map<String, int> countsByType,
    int totalCount,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: AppleColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppleColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'RESUMO DE MATERIAIS E TAREFAS (TOQUE PARA FILTRAR)',
                  style: TextStyle(
                    color: AppleColors.textTertiary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              FilterChip(
                label: const Text(
                  'Incluir Triagem',
                  style: TextStyle(fontSize: 11.5),
                ),
                selected: _includeStaging,
                selectedColor: AppleColors.systemAmber.withValues(alpha: 0.25),
                checkmarkColor: AppleColors.systemAmber,
                onSelected: (val) => setState(() => _includeStaging = val),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildTypeFilterCard(
                label: 'Todos os Defeitos',
                count: totalCount,
                icon: Icons.assignment_outlined,
                color: AppleColors.accentBlue,
                isSelected: _selectedProblemType == 'all',
                onTap: () => setState(() => _selectedProblemType = 'all'),
              ),
              ...countsByType.entries.map((entry) {
                final type = entry.key;
                final count = entry.value;
                return _buildTypeFilterCard(
                  label: type,
                  count: count,
                  icon: _getIconForProblem(type),
                  color: _getColorForProblem(type),
                  isSelected: _selectedProblemType == type,
                  onTap: () => setState(() {
                    _selectedProblemType =
                        _selectedProblemType == type ? 'all' : type;
                  }),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ApplePressable(
      pressedScale: 0.96,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.22)
              : AppleColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppleColors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: AppleColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0
                    ? color.withValues(alpha: 0.22)
                    : AppleColors.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: count > 0 ? color : AppleColors.textTertiary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTaskCard({
    required Room room,
    required List<MaintenanceIssue> roomIssues,
    required RoomController roomController,
    required AppUser? currentUser,
  }) {
    final canResolve = currentUser?.role.canResolveIssue ?? false;
    final canApprove = currentUser?.role.canApproveStaging ?? false;

    final Map<String, List<MaintenanceIssue>> issuesByProblem = {};
    for (final issue in roomIssues) {
      final type = normalizeProblemType(issue.problemType);
      issuesByProblem.putIfAbsent(type, () => []).add(issue);
    }

    return AppleGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppleColors.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.meeting_room_rounded,
                        color: AppleColors.accentBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        room.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              ApplePressable(
                pressedScale: 0.96,
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/maintenance',
                    arguments: {
                      'roomId': room.id,
                      'room': room,
                    },
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppleColors.accentBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppleColors.accentBlue.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 15,
                        color: AppleColors.accentBlue,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Abrir Mapa',
                        style: TextStyle(
                          color: AppleColors.accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          ...issuesByProblem.entries.map((entry) {
            final problemType = entry.key;
            final groupIssues = entry.value
              ..sort((a, b) => a.seatId.compareTo(b.seatId));
            final color = _getColorForProblem(problemType);
            final activeIds = groupIssues
                .where((i) => i.isActive)
                .map((i) => i.id)
                .toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppleColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              _getIconForProblem(problemType),
                              color: color,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                problemType,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppleStatusPill(
                              label: '${groupIssues.length} poltrona(s)',
                              color: color,
                              showDot: false,
                            ),
                          ],
                        ),
                      ),
                      if (canResolve && activeIds.isNotEmpty)
                        ApplePressable(
                          pressedScale: 0.95,
                          onPressed: () async {
                            await roomController.resolveIssuesBatch(
                              activeIds,
                              resolvedBy: currentUser?.name,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${activeIds.length} poltrona(s) de "$problemType" concluída(s) na ${room.nome}!',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppleColors.systemGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.done_all_rounded,
                                  size: 15,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  activeIds.length > 1
                                      ? 'Concluir todos (${activeIds.length})'
                                      : 'Concluir',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: groupIssues.map((issue) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppleColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: issue.isStaging
                                ? AppleColors.systemAmber.withValues(alpha: 0.6)
                                : AppleColors.glassBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_seat_rounded,
                              size: 14,
                              color: AppleColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              issue.seatId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppleColors.textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (issue.notes != null &&
                                issue.notes!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: issue.notes!,
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  size: 15,
                                  color: AppleColors.textSecondary,
                                ),
                              ),
                            ],
                            if (issue.isStaging) ...[
                              const SizedBox(width: 6),
                              const Text(
                                'Triagem',
                                style: TextStyle(
                                  color: AppleColors.systemAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (canApprove) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () =>
                                      roomController.approveStagingIssue(
                                    issue.id,
                                    approvedBy: currentUser?.name,
                                  ),
                                  child: const Tooltip(
                                    message: 'Aprovar solicitação',
                                    child: Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 17,
                                      color: AppleColors.systemAmber,
                                    ),
                                  ),
                                ),
                              ],
                            ] else if (canResolve) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  await roomController.resolveIssue(
                                    issue.id,
                                    resolvedBy: currentUser?.name,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Assento ${issue.seatId} (${room.nome}) marcado como resolvido!',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: const Tooltip(
                                  message: 'Marcar assento como resolvido',
                                  child: Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                    color: AppleColors.systemGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomController = Provider.of<RoomController>(context);
    final authController = Provider.of<AuthController>(context);
    final currentUser = authController.currentUser;

    final targetIssues = _getTargetIssues(roomController);
    final countsByType = _getCountsByProblemType(targetIssues);

    final filteredIssues = _selectedProblemType == 'all'
        ? targetIssues
        : targetIssues
            .where(
              (i) =>
                  normalizeProblemType(i.problemType) == _selectedProblemType,
            )
            .toList();

    final roomsWithIssues = roomController.rooms.where((room) {
      return filteredIssues.any((i) => i.roomId == room.id);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roteiro por Tipo de Defeito'),
        actions: [
          if (filteredIssues.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Copiar Roteiro de Serviço por Sala',
              onPressed: () =>
                  _exportTaskChecklist(context, targetIssues, roomController),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDefectCounterBar(countsByType, targetIssues.length),
          Expanded(
            child: roomsWithIssues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppleColors.systemGreen,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedProblemType == 'all'
                              ? 'Nenhuma manutenção pendente nas salas!'
                              : 'Nenhuma poltrona pendente com "$_selectedProblemType".',
                          style: const TextStyle(
                            color: AppleColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        if (_selectedProblemType != 'all')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedProblemType = 'all'),
                              icon: const Icon(Icons.filter_alt_off_rounded),
                              label: const Text(
                                'Mostrar todos os tipos de defeito',
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: roomsWithIssues.length,
                    itemBuilder: (context, index) {
                      final room = roomsWithIssues[index];
                      final roomIssues = filteredIssues
                          .where((i) => i.roomId == room.id)
                          .toList();
                      return _buildRoomTaskCard(
                        room: room,
                        roomIssues: roomIssues,
                        roomController: roomController,
                        currentUser: currentUser,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
