import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roomController = Provider.of<RoomController>(context);
    final issues = roomController.issues;

    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Manutenção'),
      ),
      body: issues.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum registro de manutenção encontrado',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: issues.length,
              itemBuilder: (context, index) {
                final issue = issues[index];
                final room = roomController.rooms.firstWhere(
                  (room) => room.id == issue.roomId,
                  orElse: () => throw Exception('Sala não encontrada'),
                );

                return Card(
                  margin: EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning,
                              color: _getUrgencyColor(issue.urgency),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sala ${room.id} - Assento ${issue.seatId}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Problema: ${issue.problemType}',
                          style: TextStyle(fontSize: 14),
                        ),
                        if (issue.notes != null && issue.notes!.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            'Observações: ${issue.notes}',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                        SizedBox(height: 8),
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
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(issue.dateTime),
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
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
