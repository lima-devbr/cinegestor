import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cinegestor/controllers/room_controller.dart';
import 'package:cinegestor/controllers/auth_controller.dart';
import 'package:cinegestor/models/seat.dart';
import 'package:cinegestor/models/maintenance_issue.dart';
import 'package:cinegestor/models/app_user.dart';
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
  Seat? selectedSeat;
  final TextEditingController _notesController = TextEditingController();
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _seatLayoutKey = GlobalKey();
  double _currentZoom = 0.8;
  static const double _minZoom = 0.3;
  static const double _maxZoom = 2.5;

  final List<String> issueTypes = [
    'Capa Rasgada',
    'Bracinho Solto',
    'Poltrona sem Número',
    'Trocar Capa Encosto',
    'Trocar Capa Assento',
    'Encosto Solto',
    'Trocar Mola',
    'Não Reclina',
    'Barulho',
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
    _notesController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    final RenderBox? renderBox = _seatLayoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size roomSize = renderBox.size;
    final Size viewSize = MediaQuery.of(context).size;

    final double scaleX = (viewSize.width * 0.9) / roomSize.width;
    final double scaleY = (viewSize.height * 0.5) / roomSize.height;
    final double scale = (scaleX < scaleY ? scaleX : scaleY).clamp(_minZoom, _maxZoom);

    final double xOffset = (viewSize.width - (roomSize.width * scale)) / 2;
    final double yOffset = 16.0;

    final matrix = Matrix4.identity()
      ..translateByDouble(xOffset, yOffset, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    setState(() {
      _currentZoom = scale;
      _transformationController.value = matrix;
    });
  }

  void _updateZoom(double zoom) {
    setState(() {
      _currentZoom = zoom.clamp(_minZoom, _maxZoom);
      final matrix = _transformationController.value.clone();
      final currentScale = matrix.getMaxScaleOnAxis();
      if (currentScale > 0) {
        final scale = _currentZoom / currentScale;
        matrix.scaleByDouble(scale, scale, 1.0, 1.0);
        _transformationController.value = matrix;
      }
    });
  }

  void registerIssue() {
    if (selectedSeat == null || selectedIssueType == null || selectedUrgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um assento, o tipo de problema e a urgência.')),
      );
      return;
    }

    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUser = authController.currentUser;
    final isOperacao = currentUser?.role.createsAsStaging ?? false;

    final roomController = widget.roomController;
    final issue = MaintenanceIssue(
      cinemaId: widget.room.theaterId ?? currentUser?.cinemaId ?? '2159',
      roomId: roomController.selectRoom!.id,
      seatId: '${selectedSeat!.row}${selectedSeat!.number}',
      problemType: selectedIssueType!,
      urgency: selectedUrgency!,
      notes: _notesController.text.trim(),
      dateTime: DateTime.now(),
      reportedBy: currentUser?.name ?? 'Usuário',
      reportedRole: currentUser?.role.shortName ?? 'Operação',
      status: isOperacao ? IssueStatus.staging : IssueStatus.active,
    );

    roomController.registerIssue(issue);

    setState(() {
      selectedIssueType = null;
      selectedUrgency = null;
      _notesController.clear();
    });

    final msg = isOperacao
        ? 'Solicitação enviada para a fila de Triagem com sucesso!'
        : 'Problema registrado em manutenção com sucesso.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black26),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black26,
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem(Colors.greenAccent.shade700, 'Normal'),
          _buildLegendItem(Colors.lightBlueAccent, 'Cadeirante'),
          _buildLegendItem(Colors.orangeAccent, 'Acompanhante'),
          _buildLegendItem(Colors.amber, 'Obeso'),
          _buildLegendItem(Colors.amberAccent.shade400, 'Em Triagem'),
          _buildLegendItem(Colors.redAccent, 'Com Defeito'),
          _buildLegendItem(Colors.deepPurpleAccent, 'Selecionado'),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 12,
      bottom: 12,
      child: Card(
        color: Colors.black54,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () => _updateZoom(_currentZoom + 0.15),
                tooltip: 'Aumentar zoom',
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '${(_currentZoom * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: () => _updateZoom(_currentZoom - 0.15),
                tooltip: 'Diminuir zoom',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridSeatLayout(Room room) {
    final Map<String, Seat> seatByCoord = {};
    for (final seat in room.seats.values) {
      if (seat.line != null && seat.column != null) {
        seatByCoord['${seat.line}_${seat.column}'] = seat;
      }
    }

    final Map<String, String> labelByCoord = {};
    for (final lbl in room.gridLabels) {
      labelByCoord['${lbl.line}_${lbl.column}'] = lbl.label;
    }

    final int maxLine = room.boundsLines;
    final int maxCol = room.boundsColumns;
    final int stageLine = room.stageLine ?? (maxLine - 1);

    return Container(
      key: _seatLayoutKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxLine, (lineIdx) {
          final lineNum = lineIdx + 1;

          if (lineNum == stageLine) {
            return Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Container(
                width: (maxCol - 2) * 38.0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'TELA',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                ),
              ),
            );
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(maxCol, (colIdx) {
              final colNum = colIdx + 1;
              final coordKey = '${lineNum}_$colNum';

              if (labelByCoord.containsKey(coordKey)) {
                return SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: Text(
                      labelByCoord[coordKey]!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }

              final seat = seatByCoord[coordKey];
              if (seat != null) {
                final exception = room.excecoes[seat.id];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedSeat = seat;
                    });
                  },
                  child: SeatWidget(
                    seat: seat,
                    exceptionType: exception,
                    isSelected: selectedSeat?.id == seat.id,
                  ),
                );
              }

              // Célula vazia do grid (corredor vertical/horizontal ou recuo lateral)
              return const SizedBox(width: 38, height: 38);
            }),
          );
        }),
      ),
    );
  }

  Widget _buildSeatLayout(Room room) {
    if (room.isGridLayout) {
      return _buildGridSeatLayout(room);
    }

    return Container(
      key: _seatLayoutKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rótulo da fileira
              Column(
                children: room.rows.map((rowLabel) {
                  final extraSpacing = (room.spacingBetweenRows[rowLabel] ?? 8).toDouble();
                  return Padding(
                    padding: EdgeInsets.only(bottom: extraSpacing),
                    child: SizedBox(
                      height: 38,
                      width: 30,
                      child: Center(
                        child: Text(
                          rowLabel,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
                  final extraSpacing = (room.spacingBetweenRows[rowLabel] ?? 8).toDouble();

                  return Padding(
                    padding: EdgeInsets.only(bottom: extraSpacing),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(numCols, (index) {
                        final colNumber = index + 1;
                        final seatId = '$rowLabel$colNumber';

                        if (aisles.contains(colNumber)) {
                          return const SizedBox(width: 24);
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
                              });
                            },
                            child: SeatWidget(
                              seat: seat,
                              exceptionType: exception,
                              isSelected: selectedSeat?.id == seat.id,
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
          const SizedBox(height: 48),
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

  Widget _buildActiveIssuesForSeat(Room room) {
    if (selectedSeat == null) return const SizedBox.shrink();

    final seatId = selectedSeat!.id;
    final activeIssues = widget.roomController.getIssuesBySeat(
      room.id,
      seatId,
      onlyActive: true,
    );

    if (activeIssues.isEmpty) return const SizedBox.shrink();

    final authController = Provider.of<AuthController>(context, listen: false);
    final currentUser = authController.currentUser;
    final canResolve = currentUser?.role.canResolveIssue ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Demandas no assento $seatId (${activeIssues.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...activeIssues.map((issue) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${issue.problemType} • Urgência ${issue.urgency}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (issue.isStaging)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Triagem',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (issue.notes != null && issue.notes!.isNotEmpty)
                          Text(
                            issue.notes!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        Text(
                          'Reportado por: ${issue.reportedBy ?? "Operação"} • ${DateFormat('dd/MM/yyyy HH:mm').format(issue.dateTime)}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (issue.isStaging && (currentUser?.role.canApproveStaging ?? false))
                    TextButton.icon(
                      onPressed: () async {
                        await widget.roomController.approveStagingIssue(
                          issue.id,
                          approvedBy: currentUser?.name,
                        );
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Demanda do assento $seatId aprovada para manutenção!'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check, color: Colors.amberAccent, size: 18),
                      label: const Text(
                        'Aprovar',
                        style: TextStyle(color: Colors.amberAccent),
                      ),
                    )
                  else if (issue.isActive && canResolve)
                    TextButton.icon(
                      onPressed: () async {
                        await widget.roomController.resolveIssue(
                          issue.id,
                          resolvedBy: currentUser?.name,
                        );
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Manutenção do assento $seatId marcada como resolvida!'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 18),
                      label: const Text(
                        'Resolver',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMaintenanceForm(Room room) {
    final exceptionLabel = selectedSeat != null ? room.excecoes[selectedSeat!.id] : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActiveIssuesForSeat(room),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registrar Problema no Assento',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (selectedSeat != null)
                Chip(
                  label: Text(
                    'Assento ${selectedSeat!.id}${exceptionLabel != null ? ' ($exceptionLabel)' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.deepPurple,
                ),
            ],
          ),
          if (selectedSeat == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Toque em um assento no mapa acima para selecioná-lo.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('issue_type_$selectedIssueType'),
            initialValue: selectedIssueType,
            decoration: const InputDecoration(
              labelText: 'Tipo de Problema',
              filled: true,
              fillColor: Colors.black12,
            ),
            items: issueTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => selectedIssueType = val),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey('urgency_$selectedUrgency'),
            initialValue: selectedUrgency,
            decoration: const InputDecoration(
              labelText: 'Urgência',
              filled: true,
              fillColor: Colors.black12,
            ),
            items: urgencyLevels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => selectedUrgency = val),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Observações',
              filled: true,
              fillColor: Colors.black12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: registerIssue,
              icon: Icon(
                Provider.of<AuthController>(context, listen: false)
                            .currentUser
                            ?.role
                            .createsAsStaging ??
                        false
                    ? Icons.send
                    : Icons.save_outlined,
              ),
              label: Text(
                Provider.of<AuthController>(context, listen: false)
                            .currentUser
                            ?.role
                            .createsAsStaging ??
                        false
                    ? 'Enviar para Triagem'
                    : 'Registrar Problema',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectRoom = widget.roomController.selectRoom ?? widget.room;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          children: [
            Text(selectRoom.nome),
            if (selectRoom.theaterName != null)
              Text(
                selectRoom.theaterName!,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'Histórico de manutenção',
          ),
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
              _buildLegend(),
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    InteractiveViewer(
                      transformationController: _transformationController,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(100),
                      minScale: _minZoom,
                      maxScale: _maxZoom,
                      onInteractionEnd: (_) {
                        setState(() {
                          _currentZoom = _transformationController.value.getMaxScaleOnAxis();
                        });
                      },
                      child: _buildSeatLayout(selectRoom),
                    ),
                    _buildZoomControls(),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildMaintenanceForm(selectRoom),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
