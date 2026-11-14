import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cinegestor/controllers/room_controller.dart';
import 'package:cinegestor/controllers/auth_controller.dart';
import 'package:cinegestor/models/seat.dart';
import 'package:cinegestor/models/maintenance_issue.dart';
import 'package:cinegestor/models/app_user.dart';
import 'package:cinegestor/widgets/seat_widget.dart';
import 'package:cinegestor/widgets/apple_surfaces.dart';
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
  String selectedUrgency = 'Média';
  Seat? selectedSeat;
  final TextEditingController _notesController = TextEditingController();
  final TransformationController _transformationController =
      TransformationController();
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
    final RenderBox? renderBox =
        _seatLayoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size roomSize = renderBox.size;
    final Size viewSize = MediaQuery.of(context).size;

    final double scaleX = (viewSize.width * 0.9) / roomSize.width;
    final double scaleY = (viewSize.height * 0.48) / roomSize.height;
    final double scale =
        (scaleX < scaleY ? scaleX : scaleY).clamp(_minZoom, _maxZoom);

    final double xOffset = (viewSize.width - (roomSize.width * scale)) / 2;
    const double yOffset = 16.0;

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
    if (selectedSeat == null || selectedIssueType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toque em uma poltrona no mapa e escolha o tipo de defeito.'),
        ),
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
      urgency: selectedUrgency,
      notes: _notesController.text.trim(),
      dateTime: DateTime.now(),
      reportedBy: currentUser?.name ?? 'Usuário',
      reportedRole: currentUser?.role.shortName ?? 'Operação',
      status: isOperacao ? IssueStatus.staging : IssueStatus.active,
    );

    roomController.registerIssue(issue);

    setState(() {
      selectedIssueType = null;
      selectedUrgency = 'Média';
      _notesController.clear();
    });

    final msg = isOperacao
        ? 'Solicitação enviada para a fila de Triagem com sucesso!'
        : 'Demanda registrada em manutenção com sucesso.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppleColors.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        color: AppleColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppleColors.glassBorder, width: 1),
        ),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem(const Color(0xFF248A3D), 'Operacional'),
          _buildLegendItem(AppleColors.systemCyan, 'Cadeirante'),
          _buildLegendItem(AppleColors.systemOrange, 'Acompanhante'),
          _buildLegendItem(AppleColors.systemPurple, 'Obeso'),
          _buildLegendItem(AppleColors.systemAmber, 'Em Triagem'),
          _buildLegendItem(AppleColors.systemRed, 'Com Defeito'),
          _buildLegendItem(AppleColors.accentBlue, 'Selecionado'),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 14,
      bottom: 14,
      child: AppleGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        borderRadius: 14,
        blurSigma: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 19),
              onPressed: () => _updateZoom(_currentZoom + 0.15),
              tooltip: 'Aumentar zoom',
              visualDensity: VisualDensity.compact,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${(_currentZoom * 100).round()}%',
                style: const TextStyle(
                  color: AppleColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 19),
              onPressed: () => _updateZoom(_currentZoom - 0.15),
              tooltip: 'Diminuir zoom',
              visualDensity: VisualDensity.compact,
            ),
            const Divider(height: 8),
            IconButton(
              icon: const Icon(Icons.center_focus_strong_rounded, size: 17),
              onPressed: _resetZoom,
              tooltip: 'Centralizar mapa',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCinemaScreenBanner(double width) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Column(
        children: [
          Container(
            width: width,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  Colors.transparent,
                  AppleColors.accentBlue,
                  Colors.white,
                  AppleColors.accentBlue,
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppleColors.accentBlue.withValues(alpha: 0.55),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'T E L A   D E   P R O J E Ç Ã O',
            style: TextStyle(
              color: AppleColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 3.5,
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxLine, (lineIdx) {
          final lineNum = lineIdx + 1;

          if (lineNum == stageLine) {
            return _buildCinemaScreenBanner((maxCol - 2) * 38.0);
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
                      style: const TextStyle(
                        color: AppleColors.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }

              final seat = seatByCoord[coordKey];
              if (seat != null) {
                final exception = room.excecoes[seat.id];
                return ApplePressable(
                  pressedScale: 0.90,
                  onPressed: () {
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
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: room.rows.map((rowLabel) {
                  final extraSpacing =
                      (room.spacingBetweenRows[rowLabel] ?? 8).toDouble();
                  return Padding(
                    padding: EdgeInsets.only(bottom: extraSpacing),
                    child: SizedBox(
                      height: 38,
                      width: 30,
                      child: Center(
                        child: Text(
                          rowLabel,
                          style: const TextStyle(
                            color: AppleColors.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Column(
                children: room.rows.map((rowLabel) {
                  final numCols = room.colsByRow[rowLabel] ?? room.colsDefault;
                  final aisles = room.aislesByRow[rowLabel] ?? [];
                  final extraSpacing =
                      (room.spacingBetweenRows[rowLabel] ?? 8).toDouble();

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
                        final seat =
                            widget.roomController.getSeat(rowLabel, colNumber);
                        if (seat == null) {
                          return const SizedBox(width: 30);
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ApplePressable(
                            pressedScale: 0.90,
                            onPressed: () {
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
          const SizedBox(height: 36),
          _buildCinemaScreenBanner(360),
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
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppleColors.systemRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppleColors.systemRed.withValues(alpha: 0.38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.build_circle_rounded,
                color: AppleColors.systemRed,
                size: 19,
              ),
              const SizedBox(width: 8),
              Text(
                'Demandas na poltrona $seatId (${activeIssues.length})',
                style: const TextStyle(
                  color: AppleColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
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
                            Flexible(
                              child: Text(
                                '${issue.problemType} • Urgência ${issue.urgency}',
                                style: const TextStyle(
                                  color: AppleColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (issue.isStaging)
                              const AppleStatusPill(
                                label: 'Triagem',
                                color: AppleColors.systemAmber,
                              ),
                          ],
                        ),
                        if (issue.notes != null && issue.notes!.isNotEmpty)
                          Text(
                            issue.notes!,
                            style: const TextStyle(
                              color: AppleColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          'Por ${issue.reportedBy ?? "Operação"} • ${DateFormat('dd/MM HH:mm').format(issue.dateTime)}',
                          style: const TextStyle(
                            color: AppleColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (issue.isStaging &&
                      (currentUser?.role.canApproveStaging ?? false))
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
                              content: Text(
                                'Demanda do assento $seatId aprovada para manutenção!',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.check_rounded,
                        color: AppleColors.systemAmber,
                        size: 18,
                      ),
                      label: const Text(
                        'Aprovar',
                        style: TextStyle(
                          color: AppleColors.systemAmber,
                          fontWeight: FontWeight.w600,
                        ),
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
                              content: Text(
                                'Manutenção do assento $seatId concluída!',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppleColors.systemGreen,
                        size: 18,
                      ),
                      label: const Text(
                        'Concluir',
                        style: TextStyle(
                          color: AppleColors.systemGreen,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildMaintenanceSheet(Room room) {
    final exceptionLabel =
        selectedSeat != null ? room.excecoes[selectedSeat!.id] : null;
    final isOperacao = Provider.of<AuthController>(context, listen: false)
            .currentUser
            ?.role
            .createsAsStaging ??
        false;

    return AppleGlassCard(
      elevated: true,
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grabber handle estilo iOS Sheet
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          _buildActiveIssuesForSeat(room),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registrar Ocorrência',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (selectedSeat != null)
                AppleStatusPill(
                  label:
                      'Poltrona ${selectedSeat!.id}${exceptionLabel != null ? ' • $exceptionLabel' : ''}',
                  color: AppleColors.accentBlue,
                  icon: Icons.event_seat_rounded,
                )
              else
                const AppleStatusPill(
                  label: 'Toque em um assento no mapa',
                  color: AppleColors.systemAmber,
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'TIPO DE DEFEITO (TOQUE PARA SELECIONAR)',
            style: TextStyle(
              color: AppleColors.textTertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: issueTypes.map((type) {
              final isSelected = selectedIssueType == type;
              return ApplePressable(
                pressedScale: 0.95,
                onPressed: () => setState(() => selectedIssueType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppleColors.accentBlue.withValues(alpha: 0.24)
                        : AppleColors.surfaceElevated.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppleColors.accentBlue
                          : AppleColors.glassBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppleColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'URGÊNCIA:',
                style: TextStyle(
                  color: AppleColors.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: urgencyLevels.map((level) {
                    final isSelected = selectedUrgency == level;
                    final color = level == 'Alta'
                        ? AppleColors.systemRed
                        : level == 'Média'
                            ? AppleColors.systemOrange
                            : AppleColors.systemGreen;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ApplePressable(
                          pressedScale: 0.96,
                          onPressed: () =>
                              setState(() => selectedUrgency = level),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withValues(alpha: 0.2)
                                  : AppleColors.surfaceElevated.withValues(
                                      alpha: 0.6,
                                    ),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : AppleColors.glassBorder,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              level,
                              style: TextStyle(
                                color: isSelected
                                    ? color
                                    : AppleColors.textSecondary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            maxLines: 1,
            style: const TextStyle(
              color: AppleColors.textPrimary,
              fontSize: 13.5,
            ),
            decoration: const InputDecoration(
              labelText: 'Observações adicionais (opcional)',
              prefixIcon: Icon(
                Icons.notes_rounded,
                size: 18,
                color: AppleColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ApplePressable(
            onPressed: registerIssue,
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: isOperacao
                      ? [AppleColors.systemOrange, AppleColors.systemAmber]
                      : [const Color(0xFF1E90FF), AppleColors.accentBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isOperacao
                            ? AppleColors.systemOrange
                            : AppleColors.accentBlue)
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOperacao ? Icons.send_rounded : Icons.add_task_rounded,
                    color: isOperacao ? Colors.black : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOperacao
                        ? 'Enviar Solicitação para Triagem'
                        : 'Confirmar Demanda de Manutenção',
                    style: TextStyle(
                      color: isOperacao ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: -0.2,
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
    final selectRoom = widget.roomController.selectRoom ?? widget.room;

    return Scaffold(
      backgroundColor: AppleColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(selectRoom.nome),
            if (selectRoom.theaterName != null)
              Text(
                selectRoom.theaterName!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppleColors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rtl_rounded),
            onPressed: () => Navigator.pushNamed(context, '/defects'),
            tooltip: 'Tarefas por Defeito',
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'Histórico de manutenção',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded),
            onPressed: _resetZoom,
            tooltip: 'Resetar visualização',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildLegend(),
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transformationController,
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(120),
                    minScale: _minZoom,
                    maxScale: _maxZoom,
                    onInteractionEnd: (_) {
                      setState(() {
                        _currentZoom =
                            _transformationController.value.getMaxScaleOnAxis();
                      });
                    },
                    child: _buildSeatLayout(selectRoom),
                  ),
                  _buildZoomControls(),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _buildMaintenanceSheet(selectRoom),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
