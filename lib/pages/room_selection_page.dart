import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/room.dart';
import '../models/app_user.dart';
import '../utils/responsive_utils.dart';
import '../widgets/apple_surfaces.dart';
import 'defect_summary_page.dart';

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

  Widget _buildSummaryDashboard(
    List<Room> rooms,
    RoomController roomController,
  ) {
    final totalSeats = rooms.fold<int>(0, (sum, r) => sum + r.totalSeats);
    final activeIssues =
        roomController.issues.where((i) => i.isActive).toList();
    final stagingCount = roomController.getStagingIssues().length;

    final defectiveSeatsCount =
        activeIssues.map((i) => '${i.roomId}_${i.seatId}').toSet().length;
    final operationalSeats =
        (totalSeats - defectiveSeatsCount).clamp(0, totalSeats);
    final operationalPercent = totalSeats > 0
        ? ((operationalSeats / totalSeats) * 100).toStringAsFixed(1)
        : '100.0';

    final Map<String, int> defectCounts = {
      'Capa Rasgada': 0,
      'Bracinho Solto': 0,
      'Poltrona sem Número': 0,
    };
    for (final issue in activeIssues) {
      final type = DefectSummaryPage.normalizeProblemType(issue.problemType);
      defectCounts[type] = (defectCounts[type] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(
                icon: Icons.theaters_rounded,
                label: 'SALAS MONITORADAS',
                value: '${rooms.length} salas',
                subtitle: '$totalSeats poltronas no total',
                color: AppleColors.accentIndigo,
              ),
              _buildStatCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'OPERACIONAIS',
                value: '$operationalPercent%',
                subtitle: '$operationalSeats de $totalSeats livres',
                color: AppleColors.systemGreen,
              ),
              _buildStatCard(
                icon: Icons.build_circle_outlined,
                label: 'MANUTENÇÃO ATIVA',
                value: '${activeIssues.length} demandas',
                subtitle: '$defectiveSeatsCount poltronas afetadas',
                color: activeIssues.isNotEmpty
                    ? AppleColors.systemRed
                    : AppleColors.textTertiary,
                onTap: () => Navigator.pushNamed(context, '/defects'),
              ),
              if (stagingCount > 0)
                _buildStatCard(
                  icon: Icons.pending_actions_rounded,
                  label: 'FILA DE TRIAGEM',
                  value: '$stagingCount pendentes',
                  subtitle: 'Toque para avaliar',
                  color: AppleColors.systemAmber,
                  onTap: () => Navigator.pushNamed(context, '/staging'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de Tarefas por Defeito estilo Apple Pill Bar
          AppleGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderRadius: 14,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.handyman_rounded,
                      size: 15,
                      color: AppleColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'TAREFAS POR DEFEITO:',
                      style: TextStyle(
                        color: AppleColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                ...defectCounts.entries.map((entry) {
                  final hasItems = entry.value > 0;
                  final pillColor = hasItems
                      ? AppleColors.systemOrange
                      : AppleColors.textTertiary;

                  return ApplePressable(
                    pressedScale: 0.95,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/defects',
                      arguments: entry.key,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: hasItems
                            ? AppleColors.systemOrange.withValues(alpha: 0.14)
                            : AppleColors.surfaceElevated.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: hasItems
                              ? AppleColors.systemOrange.withValues(alpha: 0.45)
                              : AppleColors.glassBorder,
                        ),
                      ),
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
                              color: pillColor.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: pillColor,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                ApplePressable(
                  pressedScale: 0.95,
                  onPressed: () => Navigator.pushNamed(context, '/defects'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppleColors.accentBlue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppleColors.accentBlue.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.checklist_rtl_rounded,
                          size: 15,
                          color: AppleColors.accentBlue,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Abrir Roteiro por Sala',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return AppleGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      borderColor: color.withValues(alpha: 0.28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppleColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppleColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppleColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIssueBadge(int activeIssuesCount, int stagingCount) {
    if (activeIssuesCount > 0) {
      return AppleStatusPill(
        label: '$activeIssuesCount em manutenção',
        color: AppleColors.systemRed,
      );
    }

    if (stagingCount > 0) {
      return AppleStatusPill(
        label: '$stagingCount em triagem',
        color: AppleColors.systemAmber,
      );
    }

    return const AppleStatusPill(
      label: '100% operacional',
      color: AppleColors.systemGreen,
    );
  }

  Widget _buildRoomGrid(List<Room> rooms, RoomController roomController) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveValue(
          mobile: 1,
          tablet: 2,
          desktop: 3,
        ).getValue(context),
        childAspectRatio: 1.55,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final activeIssuesCount =
            roomController.getIssuesByRoom(room.id, onlyActive: true).length;
        final stagingCount = roomController.issues
            .where((i) => i.roomId == room.id && i.isStaging)
            .length;
        return _buildRoomCard(room, activeIssuesCount, stagingCount);
      },
    );
  }

  Widget _buildRoomCard(Room room, int activeIssuesCount, int stagingCount) {
    final total = room.totalSeats > 0 ? room.totalSeats : 1;
    final healthRatio =
        ((total - activeIssuesCount) / total).clamp(0.0, 1.0);
    final statusColor = activeIssuesCount > 0
        ? AppleColors.systemRed
        : stagingCount > 0
            ? AppleColors.systemAmber
            : AppleColors.systemGreen;

    return AppleGlassCard(
      onTap: () => _onRoomTap(room),
      borderRadius: 18,
      padding: const EdgeInsets.all(18),
      borderColor: activeIssuesCount > 0
          ? AppleColors.systemRed.withValues(alpha: 0.32)
          : AppleColors.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  room.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildIssueBadge(activeIssuesCount, stagingCount),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${room.totalSeats} lugares • ${room.rows.length} fileiras',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          // Barra sutil de integridade operacional da sala
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: healthRatio,
              minHeight: 5,
              backgroundColor: AppleColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(healthRatio * 100).toStringAsFixed(0)}% disponível',
                style: const TextStyle(
                  color: AppleColors.textTertiary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Inspecionar mapa',
                    style: TextStyle(
                      color: AppleColors.accentBlue,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: AppleColors.accentBlue,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(AppUser? user, int stagingCount) {
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppleColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppleColors.glassBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppleColors.accentBlue, AppleColors.accentIndigo],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              user.name.isNotEmpty ? user.name[0] : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: AppleColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${user.role.displayName} • ${user.cinemaName}',
                  style: const TextStyle(
                    color: AppleColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (stagingCount > 0)
            ApplePressable(
              pressedScale: 0.95,
              onPressed: () => Navigator.pushNamed(context, '/staging'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppleColors.systemAmber.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppleColors.systemAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pending_actions_rounded,
                      size: 15,
                      color: AppleColors.systemAmber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Triagem ($stagingCount)',
                      style: const TextStyle(
                        color: AppleColors.systemAmber,
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
        title: const Text('Visão Geral das Salas'),
        actions: [
          if (currentUser?.role.canApproveStaging ?? false)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.rule_folder_outlined),
                  tooltip: 'Área de Triagem (Staging)',
                  onPressed: () => Navigator.pushNamed(context, '/staging'),
                ),
                if (stagingCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
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
            icon: const Icon(Icons.checklist_rtl_rounded),
            tooltip: 'Tarefas por Tipo de Defeito',
            onPressed: () => Navigator.pushNamed(context, '/defects'),
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUserHeader(currentUser, stagingCount),
          _buildSummaryDashboard(rooms, roomController),
          Expanded(
            child: ResponsiveBuilder(
              mobile: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final room = rooms[index];
                  final activeIssuesCount = roomController
                      .getIssuesByRoom(room.id, onlyActive: true)
                      .length;
                  final roomStagingCount = roomController.issues
                      .where((i) => i.roomId == room.id && i.isStaging)
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SizedBox(
                      height: 155,
                      child: _buildRoomCard(
                        room,
                        activeIssuesCount,
                        roomStagingCount,
                      ),
                    ),
                  );
                },
              ),
              tablet: _buildRoomGrid(rooms, roomController),
              desktop: _buildRoomGrid(rooms, roomController),
            ),
          ),
        ],
      ),
    );
  }
}
