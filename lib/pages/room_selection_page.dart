import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/room.dart';
import '../models/app_user.dart';
import '../models/maintenance_issue.dart';
import '../widgets/apple_surfaces.dart';

class RoomSelectionPage extends StatefulWidget {
  final RoomController roomController;

  const RoomSelectionPage({super.key, required this.roomController});

  @override
  State<RoomSelectionPage> createState() => _RoomSelectionPageState();
}

class _RoomSelectionPageState extends State<RoomSelectionPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final authController =
          Provider.of<AuthController>(context, listen: false);
      final userCinemaId = authController.currentUser?.cinemaId;
      await widget.roomController.loadRooms(cinemaId: userCinemaId);

      if (mounted) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Erro ao carregar salas: $e';
        });
      }
    }
  }

  void _onRoomTap(Room room) {
    Navigator.pushNamed(
      context,
      '/maintenance',
      arguments: {
        'roomId': room.id,
        'room': room,
      },
    );
  }

  /// Faixa única e compacta de métricas no topo (3 colunas lado a lado)
  /// Poltronas com defeitos usuais (Capas, s/ Número, PC-E/D, S/Mola, Arremate)
  /// continuam Operacionais; apenas Encosto Solto e Assento Solto interditam a cadeira.
  Widget _buildCompactMetricsStrip(
    List<Room> rooms,
    RoomController roomController,
  ) {
    final totalSeats = rooms.fold<int>(0, (sum, r) => sum + r.totalSeats);
    final activeIssues =
        roomController.issues.where((i) => i.isActive).toList();
    final stagingCount = roomController.getStagingIssues().length;

    final blockingSeatsCount = activeIssues
        .where((i) => i.isBlockingSeat)
        .map((i) => '${i.roomId}_${i.seatId}')
        .toSet()
        .length;
    final affectedSeatsCount =
        activeIssues.map((i) => '${i.roomId}_${i.seatId}').toSet().length;

    final operationalSeats =
        (totalSeats - blockingSeatsCount).clamp(0, totalSeats);
    final operationalPercent = totalSeats > 0
        ? ((operationalSeats / totalSeats) * 100).toStringAsFixed(1)
        : '100.0';

    return AppleGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: _buildCompactMetricItem(
              label: 'OPERACIONAL',
              value: '$operationalPercent%',
              sub: blockingSeatsCount > 0
                  ? '$blockingSeatsCount interditada(s)'
                  : '$operationalSeats/$totalSeats lug.',
              color: blockingSeatsCount > 0
                  ? AppleColors.systemOrange
                  : AppleColors.systemGreen,
            ),
          ),
          Container(width: 1, height: 34, color: AppleColors.glassBorder),
          Expanded(
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/defects'),
              borderRadius: BorderRadius.circular(8),
              child: _buildCompactMetricItem(
                label: 'PENDÊNCIAS',
                value: '${activeIssues.length}',
                sub: '$affectedSeatsCount poltrona(s)',
                color: activeIssues.isNotEmpty
                    ? (blockingSeatsCount > 0
                        ? AppleColors.systemRed
                        : AppleColors.systemOrange)
                    : AppleColors.textSecondary,
              ),
            ),
          ),
          Container(width: 1, height: 34, color: AppleColors.glassBorder),
          Expanded(
            child: InkWell(
              onTap: () => Navigator.pushNamed(context, '/staging'),
              borderRadius: BorderRadius.circular(8),
              child: _buildCompactMetricItem(
                label: 'TRIAGEM',
                value: '$stagingCount',
                sub: stagingCount > 0 ? 'Avaliar agora' : 'Fila limpa',
                color: stagingCount > 0
                    ? AppleColors.systemAmber
                    : AppleColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetricItem({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppleColors.textTertiary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          sub,
          style: const TextStyle(
            color: AppleColors.textSecondary,
            fontSize: 10.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Barra horizontal deslizável de 1 linha para os 10 tipos de defeito
  Widget _buildHorizontalDefectBar(RoomController roomController) {
    final activeIssues =
        roomController.issues.where((i) => i.isActive).toList();

    final Map<String, int> defectCounts = {
      for (final type in MaintenanceIssue.standardProblemTypes) type: 0,
    };
    for (final issue in activeIssues) {
      final type = MaintenanceIssue.normalizeProblemType(issue.problemType);
      defectCounts[type] = (defectCounts[type] ?? 0) + 1;
    }

    // Ordena deixando os defeitos com mais ocorrências na frente
    final sortedEntries = defectCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ApplePressable(
            pressedScale: 0.95,
            onPressed: () => Navigator.pushNamed(context, '/defects'),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppleColors.accentBlue.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppleColors.accentBlue.withValues(alpha: 0.5),
                ),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.checklist_rtl_rounded,
                    size: 15,
                    color: AppleColors.accentBlue,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Roteiro por Sala',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppleColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ...sortedEntries.map((entry) {
            final hasItems = entry.value > 0;
            final isBlocking = MaintenanceIssue.isBlockingProblem(entry.key);
            final pillColor = !hasItems
                ? AppleColors.textTertiary
                : (isBlocking
                    ? AppleColors.systemRed
                    : AppleColors.systemOrange);

            return ApplePressable(
              pressedScale: 0.95,
              onPressed: () => Navigator.pushNamed(
                context,
                '/defects',
                arguments: entry.key,
              ),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: hasItems
                      ? pillColor.withValues(alpha: 0.14)
                      : AppleColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasItems
                        ? pillColor.withValues(alpha: 0.45)
                        : AppleColors.glassBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            hasItems ? FontWeight.w600 : FontWeight.w500,
                        color: hasItems
                            ? AppleColors.textPrimary
                            : AppleColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: pillColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: pillColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Item compacto de Sala com Termômetro baseado em % da sala:
  /// - 0% a 5% usuais: Verde
  /// - 5.1% a 12% usuais: Amarelo
  /// - 12.1% a 20% usuais (ou 1-2 interditadas): Laranja
  /// - > 20% usuais (ou 3+ interditadas): Vermelho
  Widget _buildCompactRoomTile({
    required Room room,
    required int usualDefectSeats,
    required int blockingSeats,
    required int stagingCount,
  }) {
    final total = room.totalSeats > 0 ? room.totalSeats : 1;
    final totalAttentionSeats = usualDefectSeats + blockingSeats;
    final attentionPct = (totalAttentionSeats / total) * 100.0;

    final heat = AppleThermometerBar.calculateHeat(
      usualDefectSeats: usualDefectSeats,
      blockingSeats: blockingSeats,
      stagingCount: stagingCount,
      totalSeats: total,
    );
    final thermoColor = AppleThermometerBar.colorForHeat(heat);

    String statusText;
    if (blockingSeats > 0) {
      statusText =
          '$blockingSeats interd. • ${attentionPct.toStringAsFixed(1)}%';
    } else if (usualDefectSeats > 0) {
      statusText =
          '${attentionPct.toStringAsFixed(1)}% atenção ($usualDefectSeats)';
    } else if (stagingCount > 0) {
      statusText = '$stagingCount em triagem';
    } else {
      statusText = '100% OK';
    }

    final operationalInRoom = (total - blockingSeats).clamp(0, total);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppleGlassCard(
        onTap: () => _onRoomTap(room),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 15,
        borderColor: totalAttentionSeats > 0
            ? thermoColor.withValues(alpha: 0.35)
            : AppleColors.glassBorder,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: thermoColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: thermoColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                room.id,
                style: TextStyle(
                  color: thermoColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        room.nome,
                        style: const TextStyle(
                          color: AppleColors.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.25,
                        ),
                      ),
                      AppleStatusPill(
                        label: statusText,
                        color: thermoColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    blockingSeats > 0
                        ? '$operationalInRoom/${room.totalSeats} operacionais • $blockingSeats interditada(s)'
                        : '${room.totalSeats} poltronas (100% operacionais) • ${room.rows.length} fileiras',
                    style: const TextStyle(
                      color: AppleColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppleThermometerBar(
                    usualDefectSeats: usualDefectSeats,
                    blockingSeats: blockingSeats,
                    stagingCount: stagingCount,
                    totalSeats: room.totalSeats,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppleColors.textTertiary,
              size: 20,
            ),
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
    final stagingCount = roomController.getStagingIssues().length;

    if (_loading || roomController.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Salas de Cinema')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Salas de Cinema')),
        body: Center(child: Text(_error!)),
      );
    }

    final rooms = roomController.rooms;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentUser?.cinemaName ?? 'Salas de Cinema',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (currentUser != null)
              Text(
                '${currentUser.name} • ${currentUser.role.displayName}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppleColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if ((currentUser?.role.canApproveStaging ?? false) && stagingCount > 0)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.rule_folder_outlined),
                  tooltip: 'Triagem de Solicitações',
                  onPressed: () => Navigator.pushNamed(context, '/staging'),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppleColors.systemAmber,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$stagingCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Histórico de Manutenções',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (value) {
              switch (value) {
                case 'defects':
                  Navigator.pushNamed(context, '/defects');
                  break;
                case 'staging':
                  Navigator.pushNamed(context, '/staging');
                  break;
                case 'history':
                  Navigator.pushNamed(context, '/history');
                  break;
                case 'logout':
                  authController.logout(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'defects',
                child: ListTile(
                  leading: Icon(
                    Icons.checklist_rtl_rounded,
                    color: AppleColors.systemOrange,
                  ),
                  title: Text('Tarefas por Defeito'),
                ),
              ),
              if (currentUser?.role.canApproveStaging ?? false)
                PopupMenuItem(
                  value: 'staging',
                  child: ListTile(
                    leading: const Icon(
                      Icons.pending_actions_rounded,
                      color: AppleColors.systemAmber,
                    ),
                    title: Text('Triagem ($stagingCount)'),
                  ),
                ),
              const PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('Histórico'),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(
                    Icons.logout_rounded,
                    color: AppleColors.systemRed,
                  ),
                  title: Text('Encerrar Sessão'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _buildCompactMetricsStrip(rooms, roomController),
              const SizedBox(height: 12),
              _buildHorizontalDefectBar(roomController),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'SALAS DA UNIDADE • TERMÔMETRO DE MANUTENÇÃO',
                  style: TextStyle(
                    color: AppleColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              ...rooms.map((room) {
                final roomActiveIssues =
                    roomController.getIssuesByRoom(room.id, onlyActive: true);
                final blockingSeatIds = roomActiveIssues
                    .where((i) => i.isBlockingSeat)
                    .map((i) => i.seatId)
                    .toSet();
                final usualSeatIds = roomActiveIssues
                    .where((i) => !i.isBlockingSeat)
                    .map((i) => i.seatId)
                    .where((seatId) => !blockingSeatIds.contains(seatId))
                    .toSet();
                final roomStagingCount = roomController.issues
                    .where((i) => i.roomId == room.id && i.isStaging)
                    .length;

                return _buildCompactRoomTile(
                  room: room,
                  usualDefectSeats: usualSeatIds.length,
                  blockingSeats: blockingSeatIds.length,
                  stagingCount: roomStagingCount,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
