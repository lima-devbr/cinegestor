import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/room.dart';
import '../models/app_user.dart';
import '../utils/responsive_utils.dart';
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
      final authController = Provider.of<AuthController>(context, listen: false);
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

  Widget _buildSummaryDashboard(List<Room> rooms, RoomController roomController) {
    final totalSeats = rooms.fold<int>(0, (sum, r) => sum + r.totalSeats);
    final activeIssues = roomController.issues.where((i) => i.isActive).toList();
    final stagingCount = roomController.getStagingIssues().length;

    final defectiveSeatsCount = activeIssues
        .map((i) => '${i.roomId}_${i.seatId}')
        .toSet()
        .length;
    final operationalSeats = (totalSeats - defectiveSeatsCount).clamp(0, totalSeats);
    final operationalPercent = totalSeats > 0
        ? ((operationalSeats / totalSeats) * 100).toStringAsFixed(1)
        : '100.0';

    // Contabiliza os problemas ativos por tipo padronizado
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildStatCard(
                icon: Icons.theaters,
                label: 'Salas',
                value: '${rooms.length}',
                color: Colors.deepPurpleAccent,
              ),
              _buildStatCard(
                icon: Icons.event_seat,
                label: 'Operacionais',
                value: '$operationalSeats/$totalSeats ($operationalPercent%)',
                color: Colors.greenAccent.shade700,
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/defects'),
                borderRadius: BorderRadius.circular(12),
                child: _buildStatCard(
                  icon: Icons.build_circle_outlined,
                  label: 'Manutenção Ativa (ver tarefas)',
                  value: '${activeIssues.length} ($defectiveSeatsCount assentos)',
                  color: activeIssues.isNotEmpty ? Colors.redAccent : Colors.grey,
                ),
              ),
              if (stagingCount > 0)
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/staging'),
                  borderRadius: BorderRadius.circular(12),
                  child: _buildStatCard(
                    icon: Icons.pending_actions,
                    label: 'Em Triagem',
                    value: '$stagingCount solicitações',
                    color: Colors.amberAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.handyman_outlined, size: 15, color: Colors.white70),
                    SizedBox(width: 6),
                    Text(
                      'Por Defeito:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ...defectCounts.entries.map((entry) {
                  final hasItems = entry.value > 0;
                  return InkWell(
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/defects',
                      arguments: entry.key,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasItems
                            ? Colors.orangeAccent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasItems
                              ? Colors.orangeAccent.withValues(alpha: 0.5)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: hasItems ? FontWeight.bold : FontWeight.normal,
                          color: hasItems ? Colors.orangeAccent : Colors.white54,
                        ),
                      ),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/defects'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.checklist_rtl, size: 16),
                  label: const Text(
                    'Roteiro por Sala',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text(
              '$activeIssuesCount em manutenção',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (stagingCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amberAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pending_actions, size: 14, color: Colors.amberAccent),
            const SizedBox(width: 4),
            Text(
              '$stagingCount em triagem',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent.shade700.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.shade700.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 14, color: Colors.greenAccent.shade700),
          const SizedBox(width: 4),
          Text(
            '100% operacional',
            style: TextStyle(
              color: Colors.greenAccent.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        final activeIssuesCount = roomController.getIssuesByRoom(room.id, onlyActive: true).length;
        final stagingCount = roomController.issues
            .where((i) => i.roomId == room.id && i.isStaging)
            .length;
        return _buildRoomCard(room, activeIssuesCount, stagingCount);
      },
    );
  }

  Widget _buildRoomCard(Room room, int activeIssuesCount, int stagingCount) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _onRoomTap(room),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      room.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIssueBadge(activeIssuesCount, stagingCount),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Capacidade: ${room.totalSeats} lugares • ${room.rows.length} fileiras',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _onRoomTap(room),
                    icon: const Icon(Icons.event_seat, size: 18),
                    label: const Text('Acessar Sala'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(AppUser? user, int stagingCount) {
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.black26,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.deepPurple,
            child: Text(
              user.name.isNotEmpty ? user.name[0] : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${user.role.displayName} • ${user.cinemaName}',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          if (stagingCount > 0)
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/staging'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.pending_actions, size: 16),
              label: Text(
                'Triagem ($stagingCount)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
        appBar: AppBar(title: const Text('Seleção de Sala')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seleção de Sala')),
        body: Center(child: Text(_error!)),
      );
    }

    final rooms = roomController.rooms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas de Cinema'),
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
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$stagingCount',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.checklist_rtl),
            tooltip: 'Tarefas por Tipo de Defeito',
            onPressed: () => Navigator.pushNamed(context, '/defects'),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Histórico de Manutenções',
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
                  leading: Icon(Icons.checklist_rtl, color: Colors.orangeAccent),
                  title: Text('Tarefas por Defeito'),
                ),
              ),
              if (currentUser?.role.canApproveStaging ?? false)
                PopupMenuItem(
                  value: 'staging',
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions, color: Colors.amberAccent),
                    title: Text('Triagem ($stagingCount)'),
                  ),
                ),
              const PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Histórico'),
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
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
                  final activeIssuesCount =
                      roomController.getIssuesByRoom(room.id, onlyActive: true).length;
                  final roomStagingCount = roomController.issues
                      .where((i) => i.roomId == room.id && i.isStaging)
                      .length;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Icon(
                        Icons.meeting_room,
                        color: activeIssuesCount > 0
                            ? Colors.redAccent
                            : roomStagingCount > 0
                                ? Colors.amberAccent
                                : Theme.of(context).colorScheme.primary,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              room.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildIssueBadge(activeIssuesCount, roomStagingCount),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${room.totalSeats} assentos • ${room.rows.length} fileiras'),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _onRoomTap(room),
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
