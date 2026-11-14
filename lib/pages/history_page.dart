import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/maintenance_issue.dart';
import '../models/app_user.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedRoomFilter = 'all';
  String _selectedStatusFilter = 'all'; // 'all', 'staging', 'active', 'resolved'
  String _selectedUrgencyFilter = 'all'; // 'all', 'Alta', 'Média', 'Baixa'

  List<MaintenanceIssue> _filterIssues(List<MaintenanceIssue> issues) {
    final filtered = issues.where((issue) {
      if (_selectedRoomFilter != 'all' && issue.roomId != _selectedRoomFilter) {
        return false;
      }
      if (_selectedStatusFilter == 'staging' && !issue.isStaging) {
        return false;
      }
      if (_selectedStatusFilter == 'active' && !issue.isActive) {
        return false;
      }
      if (_selectedStatusFilter == 'resolved' && !issue.resolved) {
        return false;
      }
      if (_selectedUrgencyFilter != 'all' &&
          issue.urgency.toLowerCase() != _selectedUrgencyFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return filtered;
  }

  Widget _buildFilterBar(RoomController roomController) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: Colors.black26,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              key: ValueKey('room_$_selectedRoomFilter'),
              initialValue: _selectedRoomFilter,
              decoration: const InputDecoration(
                labelText: 'Sala',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('Todas as Salas')),
                ...roomController.rooms.map(
                  (r) => DropdownMenuItem(value: r.id, child: Text(r.nome)),
                ),
              ],
              onChanged: (val) => setState(() => _selectedRoomFilter = val ?? 'all'),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              key: ValueKey('status_$_selectedStatusFilter'),
              initialValue: _selectedStatusFilter,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos')),
                DropdownMenuItem(value: 'staging', child: Text('Em Triagem')),
                DropdownMenuItem(value: 'active', child: Text('Em Manutenção')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolvidos')),
              ],
              onChanged: (val) => setState(() => _selectedStatusFilter = val ?? 'all'),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              key: ValueKey('urgency_$_selectedUrgencyFilter'),
              initialValue: _selectedUrgencyFilter,
              decoration: const InputDecoration(
                labelText: 'Urgência',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todas')),
                DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                DropdownMenuItem(value: 'Média', child: Text('Média')),
                DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
              ],
              onChanged: (val) => setState(() => _selectedUrgencyFilter = val ?? 'all'),
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(
    BuildContext context,
    List<MaintenanceIssue> filteredIssues,
    RoomController roomController,
  ) {
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final buffer = StringBuffer();
    buffer.writeln('=== RELATÓRIO DE MANUTENÇÃO - CINEGESTOR ===');
    buffer.writeln('Gerado em: $now');
    buffer.writeln('Total de registros listados: ${filteredIssues.length}');
    buffer.writeln('--------------------------------------------');

    for (final issue in filteredIssues) {
      final roomName = roomController.getRoomById(issue.roomId)?.displayName ?? 'Sala ${issue.roomId}';
      final status = issue.resolved ? 'RESOLVIDO' : 'PENDENTE';
      final openedAt = DateFormat('dd/MM/yyyy HH:mm').format(issue.dateTime);
      buffer.writeln('[$status] $roomName - Assento ${issue.seatId}');
      buffer.writeln('  Problema: ${issue.problemType} | Urgência: ${issue.urgency}');
      if (issue.notes != null && issue.notes!.isNotEmpty) {
        buffer.writeln('  Obs: ${issue.notes}');
      }
      buffer.writeln('  Aberto em: $openedAt');
      if (issue.resolved && issue.resolvedAt != null) {
        buffer.writeln('  Concluído em: ${DateFormat('dd/MM/yyyy HH:mm').format(issue.resolvedAt!)}');
      }
      buffer.writeln('');
    }

    final reportText = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar Relatório'),
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
                    content: Text('Relatório copiado para a área de transferência!'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar Relatório'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomController = Provider.of<RoomController>(context);
    final filteredIssues = _filterIssues(roomController.issues);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Manutenção'),
        actions: [
          if (filteredIssues.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Exportar / Copiar Relatório',
              onPressed: () => _showExportDialog(context, filteredIssues, roomController),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(roomController),
          Expanded(
            child: filteredIssues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Nenhum registro de manutenção encontrado',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        if (_selectedRoomFilter != 'all' ||
                            _selectedStatusFilter != 'all' ||
                            _selectedUrgencyFilter != 'all')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedRoomFilter = 'all';
                                  _selectedStatusFilter = 'all';
                                  _selectedUrgencyFilter = 'all';
                                });
                              },
                              child: const Text('Limpar filtros'),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredIssues.length,
                    itemBuilder: (context, index) {
                      final issue = filteredIssues[index];
                      final room = roomController.getRoomById(issue.roomId);
                      final roomName = room?.displayName ?? 'Sala ${issue.roomId}';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        issue.resolved
                                            ? Icons.check_circle
                                            : issue.isStaging
                                                ? Icons.pending_actions
                                                : Icons.warning,
                                        color: issue.resolved
                                            ? Colors.greenAccent
                                            : issue.isStaging
                                                ? Colors.amberAccent
                                                : _getUrgencyColor(issue.urgency),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$roomName - Assento ${issue.seatId}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: (issue.resolved
                                              ? Colors.greenAccent
                                              : issue.isStaging
                                                  ? Colors.amberAccent
                                                  : Colors.redAccent)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      issue.status.displayName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: issue.resolved
                                            ? Colors.greenAccent
                                            : issue.isStaging
                                                ? Colors.amberAccent
                                                : Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Problema: ${issue.problemType}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (issue.notes != null && issue.notes!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Observações: ${issue.notes}',
                                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Urgência: ${issue.urgency}',
                                    style: TextStyle(
                                      color: _getUrgencyColor(issue.urgency),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Aberto: ${DateFormat('dd/MM/yyyy HH:mm').format(issue.dateTime)}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (issue.resolved && issue.resolvedAt != null)
                                        Text(
                                          'Concluído: ${DateFormat('dd/MM/yyyy HH:mm').format(issue.resolvedAt!)}',
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: Colors.white12),
                              Consumer<AuthController>(
                                builder: (context, auth, _) {
                                  final user = auth.currentUser;
                                  final canResolve = user?.role.canResolveIssue ?? false;
                                  final canReopen = user?.role.canReopenIssue ?? false;
                                  final canDelete = user?.role.canDeleteIssue ?? false;
                                  final canApprove = user?.role.canApproveStaging ?? false;

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (canDelete)
                                        TextButton.icon(
                                          onPressed: () {
                                            roomController.deleteIssue(issue.id);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Registro removido do histórico.'),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.redAccent,
                                          ),
                                          label: const Text(
                                            'Excluir',
                                            style: TextStyle(color: Colors.redAccent),
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      if (issue.isStaging && canApprove)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            roomController.approveStagingIssue(
                                              issue.id,
                                              approvedBy: user?.name,
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Solicitação do assento ${issue.seatId} aprovada!',
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber.shade800,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                          ),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Aprovar'),
                                        )
                                      else if (issue.isActive && canResolve)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            roomController.resolveIssue(
                                              issue.id,
                                              resolvedBy: user?.name,
                                            );
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Manutenção do assento ${issue.seatId} concluída!',
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green.shade700,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                          ),
                                          icon: const Icon(Icons.check, size: 18),
                                          label: const Text('Marcar Resolvido'),
                                        )
                                      else if (issue.resolved && canReopen)
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            roomController.reopenIssue(issue.id);
                                          },
                                          icon: const Icon(Icons.replay, size: 18),
                                          label: const Text('Reabrir'),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'alta':
        return Colors.red;
      case 'média':
        return Colors.orange;
      case 'baixa':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }
}
