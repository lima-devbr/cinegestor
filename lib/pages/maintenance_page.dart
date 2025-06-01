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

  const MaintenancePage({
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
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _seatLayoutKey = GlobalKey();

  final List<String> issueTypes = [
    'Encosto Solto',
    'Trocar Capa Encosto',
    'Trocar Capa Assento',
    'Trocar Mola',
    'Sem número',
    'Sem Bracinho',
    'Barulho',
    'Não Reclina',
    'Outro',
  ];

  final List<String> urgencyLevels = ['Baixa', 'Média', 'Alta'];

  @override
  void initState() {
    super.initState();
    widget.roomController.selectRoomById(widget.roomId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetZoom());
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    final RenderBox? renderBox = _seatLayoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size roomSize = renderBox.size;
    final Size viewSize = MediaQuery.of(context).size;

    // Calcula o zoom necessário para caber a sala na tela
    final double scaleX = (viewSize.width * 0.9) / roomSize.width;
    final double scaleY = (viewSize.height * 0.6) / roomSize.height; // Mantém 60% da altura para acomodar o formulário
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calcula a posição para centralizar horizontalmente e alinhar próximo ao topo
    final double xOffset = (viewSize.width - (roomSize.width * scale)) / 2;
    final double yOffset = viewSize.height * 0.09; // 5% da altura da tela como margem superior

    final matrix = Matrix4.identity()
      ..translate(xOffset, yOffset)
      ..scale(scale);

    setState(() {
      _transformationController.value = matrix;
    });
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

  Widget _buildSeatLayout(Room room) {
    return Container(
      key: _seatLayoutKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
         
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rótulo da fileira
              Column(
                children: room.rows.map((rowLabel) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: SizedBox(
                      width: 30,
                      child: Text(
                        rowLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Assentos
              Column(
                children: room.rows.map((rowLabel) {
                  final numCols = room.colsByRow[rowLabel] ?? room.colsDefault;
                  final aisles = room.aislesByRow[rowLabel] ?? [];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(numCols, (index) {
                        final colNumber = index + 1;
                        final seatId = '$rowLabel$colNumber';

                        if (aisles.contains(colNumber)) {
                          return const SizedBox(width: 20);
                        }

                        final exception = room.excecoes[seatId];
                        final seat = widget.roomController.getSeat(rowLabel, colNumber);
                        if (seat == null) {
                          return const SizedBox(width: 30);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: GestureDetector(
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
                          ),
                        );
                      }),
                    ),
                  );
                }).toList(),
              ),
              
            ],
          ),
          const SizedBox(height: 48), // Semapra tela dos assentos
           // Tela no final da coluna
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 200,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'TELA',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Registrar Problema no Assento',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          if (selectedSeat != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Assento selecionado: ${selectedSeat!.row}${selectedSeat!.number}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          DropdownButtonFormField<String>(
            value: selectedIssueType,
            decoration: const InputDecoration(
              labelText: 'Tipo de Problema',
              filled: true,
              fillColor: Colors.black12,
            ),
            items: issueTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => selectedIssueType = val),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: selectedUrgency,
            decoration: const InputDecoration(
              labelText: 'Urgência',
              filled: true,
              fillColor: Colors.black12,
            ),
            items: urgencyLevels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => selectedUrgency = val),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observações',
              filled: true,
              fillColor: Colors.black12,
            ),
            onChanged: (val) => notes = val,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: registerIssue,
              child: const Text('Registrar Problema'),
            ),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: Text(selectRoom.nome),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetZoom,
            tooltip: 'Resetar visualização',
          ),
        ],
      ),
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
              Expanded(
                flex: 3,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(100),
                  minScale: 0.5,
                  maxScale: 2.0,
                  child: _buildSeatLayout(selectRoom),
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildMaintenanceForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
