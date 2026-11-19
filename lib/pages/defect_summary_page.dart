import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/maintenance_issue.dart';
import '../models/cinema_sector.dart';
import '../models/room.dart';
import '../models/app_user.dart';
import '../widgets/apple_surfaces.dart';
import '../widgets/assign_responsible_dialog.dart';
import '../services/pdf_report_service.dart';

class DefectSummaryPage extends StatefulWidget {
  final String? initialProblemType;

  const DefectSummaryPage({super.key, this.initialProblemType});

  /// Padroniza nomes antigos para agrupar junto com as novas nomenclaturas
  static String normalizeProblemType(String raw) =>
      MaintenanceIssue.normalizeProblemType(raw);

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
    if (normalized.contains('ar-condicionado') || normalized.contains('climatização')) {
      return Icons.ac_unit_rounded;
    }
    if (normalized.contains('iluminação') || normalized.contains('lâmpada')) {
      return Icons.lightbulb_outline_rounded;
    }
    if (normalized.contains('limpeza')) return Icons.cleaning_services_rounded;
    if (normalized.contains('porta') || normalized.contains('saída')) {
      return Icons.meeting_room_rounded;
    }
    if (normalized.contains('som') || normalized.contains('imagem') || normalized.contains('tela')) {
      return Icons.volume_up_rounded;
    }
    if (normalized.contains('segurança') || normalized.contains('extintor')) {
      return Icons.health_and_safety_rounded;
    }
    if (normalized.contains('capa')) return Icons.texture_rounded;
    if (normalized.contains('pc-e') ||
        normalized.contains('pc-d') ||
        normalized.contains('arremate')) {
      return Icons.airline_seat_recline_normal_rounded;
    }
    if (normalized.contains('número') || normalized.contains('numero')) {
      return Icons.pin_outlined;
    }
    if (normalized.contains('mola')) {
      return Icons.settings_suggest_rounded;
    }
    if (normalized.contains('encosto') || normalized.contains('assento solto')) {
      return Icons.warning_amber_rounded;
    }
    return Icons.build_circle_outlined;
  }

  Color _getColorForProblem(String problemType) {
    if (MaintenanceIssue.isBlockingProblem(problemType)) {
      return AppleColors.systemRed;
    }
    final normalized = normalizeProblemType(problemType).toLowerCase();
    if (normalized.contains('ar-condicionado')) return AppleColors.systemCyan;
    if (normalized.contains('iluminação')) return const Color(0xFFFFD60A);
    if (normalized.contains('limpeza')) return AppleColors.systemGreen;
    if (normalized.contains('porta')) return AppleColors.systemRed;
    if (normalized.contains('som') || normalized.contains('tela')) {
      return AppleColors.accentIndigo;
    }
    if (normalized.contains('capa')) return AppleColors.systemOrange;
    if (normalized.contains('pc-e') || normalized.contains('pc-d')) {
      return AppleColors.systemCyan;
    }
    if (normalized.contains('número') || normalized.contains('numero')) {
      return AppleColors.systemAmber;
    }
    if (normalized.contains('mola') || normalized.contains('arremate')) {
      return AppleColors.systemPurple;
    }
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
      for (final type in MaintenanceIssue.standardProblemTypes) type: 0,
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

    for (final sector in CinemaSector.commonSectors) {
      final sectorIssues = targetIssues.where((i) {
        if (i.roomId != sector.id) return false;
        if (_selectedProblemType != 'all' &&
            normalizeProblemType(i.problemType) != _selectedProblemType) {
          return false;
        }
        return true;
      }).toList();

      if (sectorIssues.isEmpty) continue;

      buffer.writeln(
        '\n🏢 ${sector.name.toUpperCase()} (${sectorIssues.length} item(ns)):',
      );
      for (final issue in sectorIssues) {
        final openedAt = DateFormat('dd/MM HH:mm').format(issue.dateTime);
        buffer.writeln('  🔧 ${issue.problemType} (Aberto em: $openedAt)');
        if (issue.notes != null && issue.notes!.isNotEmpty) {
          buffer.writeln('     Obs: ${issue.notes}');
        }
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
                showTopNotice(
                  context,
                  'Roteiro copiado para enviar à equipe de manutenção!',
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
    List<MaintenanceIssue> targetIssues,
    Map<String, int> countsByType,
  ) {
    final totalCount = targetIssues.length;
    final criticalCount = targetIssues
        .where((i) => i.isActive && i.urgency == 'Alta')
        .length;
    final inProgressCount = targetIssues.where((i) => i.isInProgress).length;
    final stagingCount = targetIssues.where((i) => i.isStaging).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppleColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppleColors.glassBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de KPIs Operacionais (Modo 2 - Checklist)
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildKpiCard(
                        label: 'Total Ativas',
                        count: targetIssues.where((i) => i.isActive).length,
                        color: AppleColors.accentBlue,
                        icon: Icons.checklist_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiCard(
                        label: 'Críticas',
                        count: criticalCount,
                        color: AppleColors.systemRed,
                        icon: Icons.error_outline_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildKpiCard(
                        label: 'Em Andamento',
                        count: inProgressCount,
                        color: AppleColors.accentIndigo,
                        icon: Icons.engineering_rounded,
                      ),
                      if (stagingCount > 0 || _includeStaging) ...[
                        const SizedBox(width: 8),
                        _buildKpiCard(
                          label: 'Triagem',
                          count: stagingCount,
                          color: AppleColors.systemAmber,
                          icon: Icons.hourglass_top_rounded,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text(
                  'Triagem',
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
          // Filtro Horizontal de Tipos de Defeito
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildTypeFilterChip(
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
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildTypeFilterChip(
                      label: type,
                      count: count,
                      icon: _getIconForProblem(type),
                      color: _getColorForProblem(type),
                      isSelected: _selectedProblemType == type,
                      onTap: () => setState(() {
                        _selectedProblemType =
                            _selectedProblemType == type ? 'all' : type;
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChip({
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.22)
              : AppleColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppleColors.glassBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppleColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                  fontSize: 11,
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

    final activeIssues = roomIssues.where((i) => i.isActive).toList();
    final activeIds = activeIssues.map((i) => i.id).toList();

    final sortedIssues = List<MaintenanceIssue>.from(roomIssues)
      ..sort((a, b) {
        if (a.urgency == 'Alta' && b.urgency != 'Alta') return -1;
        if (a.urgency != 'Alta' && b.urgency == 'Alta') return 1;
        return a.seatId.compareTo(b.seatId);
      });

    return AppleGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da Sala com Ações Rápidas
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
                      child: Icon(
                        Icons.meeting_room_rounded,
                        color: AppleColors.accentBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        room.displayName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppleStatusPill(
                      label: '${roomIssues.length} pendência(s)',
                      color: AppleColors.accentBlue,
                      showDot: false,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppleColors.accentBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppleColors.accentBlue.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 14,
                            color: AppleColors.accentBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Abrir Mapa',
                            style: TextStyle(
                              color: AppleColors.accentBlue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (canResolve && activeIds.length > 1) ...[
                    const SizedBox(width: 8),
                    ApplePressable(
                      pressedScale: 0.95,
                      onPressed: () async {
                        await roomController.resolveIssuesBatch(
                          activeIds,
                          resolvedBy: currentUser?.name,
                        );
                        if (mounted) {
                          showTopNotice(
                            context,
                            '${activeIds.length} pendências concluídas na ${room.nome}!',
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppleColors.systemGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.done_all_rounded,
                              size: 14,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Concluir Todas (${activeIds.length})',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          // Lista em Formato Checklist Operacional
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedIssues.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 14, thickness: 0.5),
            itemBuilder: (context, idx) {
              final issue = sortedIssues[idx];
              return _buildChecklistItem(
                issue: issue,
                locationLabel: room.nome,
                canResolve: canResolve,
                canApprove: canApprove,
                roomController: roomController,
                currentUser: currentUser,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectorTaskCard({
    required CinemaSector sector,
    required List<MaintenanceIssue> sectorIssues,
    required RoomController roomController,
    required AppUser? currentUser,
  }) {
    final canResolve = currentUser?.role.canResolveIssue ?? false;
    final canApprove = currentUser?.role.canApproveStaging ?? false;
    final activeIssues = sectorIssues.where((i) => i.isActive).toList();
    final activeIds = activeIssues.map((i) => i.id).toList();

    return AppleGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
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
                        color: AppleColors.systemOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        sector.icon,
                        color: AppleColors.systemOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🏢 ${sector.name}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppleStatusPill(
                      label: '${sectorIssues.length} pendente(s)',
                      color: AppleColors.systemOrange,
                      showDot: false,
                    ),
                  ],
                ),
              ),
              if (canResolve && activeIds.isNotEmpty) ...[
                const SizedBox(width: 8),
                ApplePressable(
                  pressedScale: 0.95,
                  onPressed: () async {
                    await roomController.resolveIssuesBatch(
                      activeIds,
                      resolvedBy: currentUser?.name,
                    );
                    if (mounted) {
                      showTopNotice(
                        context,
                        '${activeIds.length} chamado(s) concluído(s) em ${sector.name}!',
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppleColors.systemGreen,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Colors.black,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Concluir Tudo (${activeIds.length})',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sectorIssues.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 14, thickness: 0.5),
            itemBuilder: (context, idx) {
              final issue = sectorIssues[idx];
              return _buildChecklistItem(
                issue: issue,
                locationLabel: sector.name,
                canResolve: canResolve,
                canApprove: canApprove,
                roomController: roomController,
                currentUser: currentUser,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required MaintenanceIssue issue,
    required String locationLabel,
    required bool canResolve,
    required bool canApprove,
    required RoomController roomController,
    required AppUser? currentUser,
  }) {
    final color = _getColorForProblem(issue.problemType);
    final icon = _getIconForProblem(issue.problemType);

    final String displaySeat = issue.seatId.startsWith('GERAL-')
        ? (issue.targetDisplayLabel.contains('•')
            ? issue.targetDisplayLabel.split('•').last.trim()
            : 'Geral')
        : issue.seatId;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Botão de Checklist rápido [✓]
        if (canResolve && issue.isActive)
          ApplePressable(
            onPressed: () async {
              await roomController.resolveIssue(
                issue.id,
                resolvedBy: currentUser?.name,
              );
              if (mounted) {
                showTopNotice(
                  context,
                  'Assento ${issue.seatId} ($locationLabel) marcado como concluído!',
                );
              }
            },
            child: Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppleColors.systemGreen.withValues(alpha: 0.6),
                  width: 1.8,
                ),
                color: AppleColors.systemGreen.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: AppleColors.systemGreen,
              ),
            ),
          )
        else if (issue.isStaging)
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppleColors.systemAmber.withValues(alpha: 0.15),
              border: Border.all(
                color: AppleColors.systemAmber.withValues(alpha: 0.5),
              ),
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              size: 15,
              color: AppleColors.systemAmber,
            ),
          )
        else
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10),
            child: Icon(
              Icons.done_all_rounded,
              size: 18,
              color: AppleColors.systemGreen,
            ),
          ),

        // Badge do Assento / Local
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppleColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppleColors.glassBorder),
          ),
          child: Text(
            displaySeat,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Descrição do Problema e Observação
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      normalizeProblemType(issue.problemType),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppleColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (issue.urgency == 'Alta') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppleColors.systemRed.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Alta',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppleColors.systemRed,
                        ),
                      ),
                    ),
                  ],
                  if (issue.isInProgress) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppleColors.accentIndigo.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Em Andamento',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppleColors.accentIndigo,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (issue.notes != null && issue.notes!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  issue.notes!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppleColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Responsável e Ações de Aprovação / Atribuição
        if (issue.isStaging) ...[
          if (canApprove)
            ApplePressable(
              onPressed: () => roomController.approveStagingIssue(
                issue.id,
                approvedBy: currentUser?.name,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppleColors.systemAmber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppleColors.systemAmber),
                ),
                child: Text(
                  'Aprovar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppleColors.systemAmber,
                  ),
                ),
              ),
            ),
        ] else if (canResolve) ...[
          if (issue.assignedTo != null && issue.assignedTo!.isNotEmpty)
            ApplePressable(
              onPressed: () => AssignResponsibleDialog.show(
                context: context,
                issue: issue,
                roomController: roomController,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppleColors.accentIndigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppleColors.accentIndigo.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.engineering_rounded,
                      size: 12,
                      color: AppleColors.accentIndigo,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      issue.assignedTo!,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppleColors.accentIndigo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ApplePressable(
              onPressed: () => AssignResponsibleDialog.show(
                context: context,
                issue: issue,
                roomController: roomController,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppleColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppleColors.glassBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 12,
                      color: AppleColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Atribuir',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppleColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
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

    final sectorsWithIssues = CinemaSector.commonSectors.where((sector) {
      return filteredIssues.any((i) => i.roomId == sector.id);
    }).toList();

    final totalSections = roomsWithIssues.length + sectorsWithIssues.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roteiro por Tipo de Defeito'),
        actions: [
          if (filteredIssues.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Exportar Roteiro em PDF',
              onPressed: () {
                final cinemaName = currentUser?.cinemaName ?? 'CineGestor';
                final cinemaId = currentUser?.cinemaId ?? '2159';
                final filterTitle = _selectedProblemType == 'all'
                    ? 'Roteiro Completo de Manutenções Pendentes'
                    : 'Roteiro de Defeito: $_selectedProblemType';
                PdfReportService.generateAndPrintReport(
                  cinemaName: cinemaName,
                  cinemaId: cinemaId,
                  issues: filteredIssues,
                  rooms: roomController.rooms,
                  currentUser: currentUser,
                  subtitleFilter: filterTitle,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Copiar Roteiro de Serviço por Sala e Setor',
              onPressed: () =>
                  _exportTaskChecklist(context, targetIssues, roomController),
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDefectCounterBar(targetIssues, countsByType),
          Expanded(
            child: totalSections == 0
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: AppleColors.systemGreen,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedProblemType == 'all'
                              ? 'Nenhuma manutenção pendente nas salas ou áreas!'
                              : 'Nenhuma ocorrência pendente com "$_selectedProblemType".',
                          style: TextStyle(
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
                    itemCount: totalSections,
                    itemBuilder: (context, index) {
                      if (index < roomsWithIssues.length) {
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
                      } else {
                        final sectorIndex = index - roomsWithIssues.length;
                        final sector = sectorsWithIssues[sectorIndex];
                        final sectorIssues = filteredIssues
                            .where((i) => i.roomId == sector.id)
                            .toList();
                        return _buildSectorTaskCard(
                          sector: sector,
                          sectorIssues: sectorIssues,
                          roomController: roomController,
                          currentUser: currentUser,
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
