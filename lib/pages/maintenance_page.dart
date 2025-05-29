import 'package:flutter/material.dart';
import 'package:cinegestor/controllers/room_controller.dart';
import 'package:cinegestor/models/seat.dart';
import 'package:cinegestor/models/maintenance_issue.dart';
import 'package:cinegestor/widgets/seat_widget.dart';
import 'package:cinegestor/models/room.dart';

class MaintenancePage extends StatefulWidget {
  final String roomId;
  final RoomController roomController;
  final Room room;

  const MaintenancePage( {
    super.key, 
    required this.roomId,
    required this.room, 
    required this.roomController,
    });

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  String? selectedIssueType;
  String? selectedUrgency;
  String notes = '';
  Seat? selectedSeat;

  final List<String> issueTypes = [
    'Encosto Solto',
    'Rasgo',
    'Não Reclina',
    'Barulho',
    'Outro',
  ];

  final List<String> urgencyLevels = ['Baixa', 'Média', 'Alta'];

  @override
  void initState() {
    super.initState();
    widget.roomController.selectRoomById(widget.roomId);
  }

  void registerIssue() {
    if (selectedSeat == null || selectedIssueType == null || selectedUrgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos para registrar o problema.')),
      );
      return;
    }

    final roomController = widget.roomController;
    final issue = MaintenanceIssue(
      roomId: roomController.selectRoom!.id,
      seatId: '${selectedSeat!.row}${selectedSeat!.number}',
      problemType: selectedIssueType!,
      urgency: selectedUrgency!,
      notes: notes,
      dateTime: DateTime.now(),
    );

    roomController.registerIssue(issue);

    setState(() {
      selectedIssueType = null;
      selectedUrgency = null;
      notes = '';
      selectedSeat = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Problema registrado com sucesso.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectRoom = widget.roomController.selectRoom;

    if (selectRoom == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D3748), Color(0xFF4A5568)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Título
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  selectRoom.nome,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              // Layout dos assentos com zoom
              Expanded(
                flex: 3,
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 2.0,
                  child: Column(
                    children: selectRoom.rows.map((rowLabel) {
                      final numCols = selectRoom.colsByRow[rowLabel] ?? selectRoom.colsDefault;
                      final aisles = selectRoom.aislesByRow[rowLabel] ?? [];

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(numCols, (index) {
                          final colNumber = index + 1;
                          final seatId = '$rowLabel$colNumber';

                          if (aisles.contains(colNumber)) {
                            return const SizedBox(
                              width: 20,
                              height: 40,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: Colors.grey),
                              ),
                            );
                          }

                          final exception = selectRoom.excecoes[seatId];
                          final seat = widget.roomController.getSeat(rowLabel, colNumber);
                            if (seat == null){
                              return const SizedBox.shrink();
                            }
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedSeat = seat;
                                widget.roomController.toggleSeatDefect(rowLabel, colNumber);
                              });
                            },
                            child: SeatWidget(
                              seat: seat,
                              exceptionType: exception,
                              isSelected: selectedSeat == seat,
                            ),
                          );
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Formulário de problema
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Registrar Problema no Assento', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        value: selectedIssueType,
                        decoration: const InputDecoration(labelText: 'Tipo de Problema'),
                        items: issueTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => selectedIssueType = val),
                      ),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        value: selectedUrgency,
                        decoration: const InputDecoration(labelText: 'Urgência'),
                        items: urgencyLevels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setState(() => selectedUrgency = val),
                      ),
                      const SizedBox(height: 10),

                      TextFormField(
                        initialValue: notes,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Observações'),
                        onChanged: (val) => notes = val,
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: registerIssue,
                        icon: const Icon(Icons.report),
                        label: const Text('Registrar Problema'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
