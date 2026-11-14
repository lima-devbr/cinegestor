import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/maintenance_issue.dart';
import '../models/room.dart';
import '../models/app_user.dart';

class DefectSummaryPage extends StatefulWidget {
  final String? initialProblemType;

  const DefectSummaryPage({super.key, this.initialProblemType});

  /// Padroniza nomes antigos para agrupar junto com as novas nomenclaturas
  static String normalizeProblemType(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'sem número' || lower == 'sem numero' || lower == 'poltrona sem número') {
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
    if (widget.initialProblemType != null && widget.initialProblemType!.isNotEmpty) {
      _selectedProblemType = widget.initialProblemType!;
    }
  }

  static String normalizeProblemType(String raw) =>
      DefectSummaryPage.normalizeProblemType(raw);

  IconData _getIconForProblem(String problemType) {
    final normalized = normalizeProblemType(problemType).toLowerCase();
    if (normalized.contains('capa')) return Icons.texture;
    if (normalized.contains('bracinho') || normalized.contains('braço')) {
      return Icons.airline_seat_recline_normal;
    }
    if (normalized.contains('número') || normalized.contains('numero')) {
      return Icons.pin_outlined;
    }
    if (normalized.contains('mola') || normalized.contains('reclina')) {
      return Icons.settings_suggest;
    }
    if (normalized.contains('encosto')) return Icons.event_seat;
    if (normalized.contains('barulho')) return Icons.volume_up_outlined;
    return Icons.build_circle_outlined;
  }

  Color _getColorForProblem(String problemType) {
    final normalized = normalizeProblemType(problemType).toLowerCase();
    if (normalized.contains('capa')) return Colors.orangeAccent;
    if (normalized.contains('bracinho')) return Colors.lightBlueAccent;
    if (normalized.contains('número') || normalized.contains('numero')) {
      return Colors.amberAccent;
    }
    if (normalized.contains('mola') || normalized.contains('reclina')) {
      return Colors.redAccent;
    }
    if (normalized.contains('encosto')) return Colors.purpleAccent;
    return Colors.tealAccent;
  }

  List<MaintenanceIssue> _getTargetIssues(RoomController roomController) {
    return roomController.issues.where((issue) {
      if (_includeStaging) {
        return issue.isActive || issue.isStaging;
      }
      return issue.isActive;
    }).toList();
  }

  Map<String, int> _getCountsByProblemType(List<MaintenanceIssue> targetIssues) {
    final Map<String, int> counts = {};
    // Garante que os 3 principais apareçam mesmo quando zerados para rápida visualização
    counts['Capa Rasgada'] = 0;
    counts['Bracinho Solto'] = 0;
    counts['Poltrona sem Número'] = 0;

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

    // Resumo de peças/materiais necessários
    final counts = _getCountsByProblemType(targetIssues);
    buffer.writeln('RESUMO GERAL DE ITENS PENDENTES:');
    for (final entry in counts.entries) {
      if (entry.value > 0) {
        buffer.writeln('• ${entry.key}: ${entry.value} poltrona(s)');
      }
    }
    buffer.writeln('----------------------------------------');

    // Agrupado por Sala -> Tipo de Defeito
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

      buffer.writeln('\n📍 ${room.displayName.toUpperCase()} (${roomIssues.length} item(ns)):');
      final Map<String, List<MaintenanceIssue>> byType = {};
      for (final issue in roomIssues) {
        final type = normalizeProblemType(issue.problemType);
        byType.putIfAbsent(type, () => []).add(issue);
      }

      for (final entry in byType.entries) {
        final seats = entry.value.map((i) => i.seatId).toList()..sort();
        buffer.writeln('  🔧 ${entry.key} (${entry.value.length}x): Assentos [ ${seats.join(', ')} ]');
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
                    content: Text('Roteiro copiado para enviar à equipe de manutenção!'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: Colors.black26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Quantidade por Tipo de Defeito (toque para filtrar a tarefa):',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilterChip(
                label: const Text(
                  'Incluir Triagem',
                  style: TextStyle(fontSize: 11),
                ),
                selected: _includeStaging,
                selectedColor: Colors.amber.shade800,
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
                color: Colors.deepPurpleAccent,
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
                    _selectedProblemType = _selectedProblemType == type ? 'all' : type;
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.35),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: count > 0 ? color.withValues(alpha: 0.25) : Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: count > 0 ? color : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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

    // Agrupa os chamados desta sala por tipo de defeito padronizado
    final Map<String, List<MaintenanceIssue>> issuesByProblem = {};
    for (final issue in roomIssues) {
      final type = normalizeProblemType(issue.problemType);
      issuesByProblem.putIfAbsent(type, () => []).add(issue);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da Sala
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room, color: Colors.deepPurpleAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          room.displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
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
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver no Mapa'),
                ),
              ],
            ),
            const Divider(height: 20, color: Colors.white12),

            // Grupos de Tarefa por Tipo de Defeito dentro da Sala
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
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
                              Icon(_getIconForProblem(problemType), color: color, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  problemType,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${groupIssues.length} poltrona(s)',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canResolve && activeIds.isNotEmpty)
                          ElevatedButton.icon(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.done_all, size: 16),
                            label: Text(
                              activeIds.length > 1
                                  ? 'Concluir todos (${activeIds.length})'
                                  : 'Concluir',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: groupIssues.map((issue) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D2D2D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: issue.isStaging
                                  ? Colors.amberAccent.withValues(alpha: 0.6)
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_seat,
                                size: 15,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                issue.seatId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              if (issue.notes != null && issue.notes!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message: issue.notes!,
                                  child: const Icon(
                                    Icons.info_outline,
                                    size: 15,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                              if (issue.isStaging) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  '(Triagem)',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 11,
                                  ),
                                ),
                                if (canApprove) ...[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () => roomController.approveStagingIssue(
                                      issue.id,
                                      approvedBy: currentUser?.name,
                                    ),
                                    child: const Tooltip(
                                      message: 'Aprovar solicitação',
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        size: 17,
                                        color: Colors.amberAccent,
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
                                      Icons.check_circle_outline,
                                      size: 18,
                                      color: Colors.greenAccent,
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
            .where((i) => normalizeProblemType(i.problemType) == _selectedProblemType)
            .toList();

    final roomsWithIssues = roomController.rooms.where((room) {
      return filteredIssues.any((i) => i.roomId == room.id);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas por Tipo de Defeito'),
        actions: [
          if (filteredIssues.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.assignment_turned_in_outlined),
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
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedProblemType == 'all'
                              ? 'Nenhuma manutenção pendente nas salas!'
                              : 'Nenhuma poltrona pendente com "$_selectedProblemType".',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        if (_selectedProblemType != 'all')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedProblemType = 'all'),
                              icon: const Icon(Icons.filter_alt_off),
                              label: const Text('Mostrar todos os tipos de defeito'),
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
