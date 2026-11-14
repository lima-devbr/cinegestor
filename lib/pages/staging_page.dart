import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/app_user.dart';

class StagingPage extends StatelessWidget {
  const StagingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roomController = Provider.of<RoomController>(context);
    final authController = Provider.of<AuthController>(context);
    final currentUser = authController.currentUser;
    final stagingIssues = roomController.getStagingIssues();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Triagem de Solicitações'),
      ),
      body: stagingIssues.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rule_folder_outlined,
                    size: 64,
                    color: Colors.amberAccent.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma solicitação na fila de triagem.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'As solicitações enviadas pela equipe de operação aparecerão aqui.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stagingIssues.length,
              itemBuilder: (context, index) {
                final issue = stagingIssues[index];
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
                                const Icon(
                                  Icons.pending_actions,
                                  color: Colors.amberAccent,
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
                                color: Colors.amberAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amberAccent.withValues(alpha: 0.6),
                                ),
                              ),
                              child: const Text(
                                'Aguardando Aprovação',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Problema informado: ${issue.problemType}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (issue.notes != null && issue.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Observações: ${issue.notes}',
                            style: const TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reportado por: ${issue.reportedBy ?? "Operação"} (${issue.reportedRole ?? "Operação"})',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(issue.dateTime),
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: Colors.white12),
                        if (currentUser?.role.canApproveStaging ?? false)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  roomController.rejectStagingIssue(
                                    issue.id,
                                    reason: 'Recusado na triagem',
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Solicitação recusada e arquivada.'),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                label: const Text(
                                  'Recusar',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  roomController.approveStagingIssue(
                                    issue.id,
                                    approvedBy: currentUser?.name,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Demanda aprovada! O assento ${issue.seatId} agora está em manutenção.',
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Aprovar Demanda'),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Apenas Encarregados ou Gerentes podem aprovar solicitações.',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
