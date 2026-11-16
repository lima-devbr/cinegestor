import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MaintenancePageState extends State<MaintenancePage>
    with SingleTickerProviderStateMixin {
  String? selectedIssueType;
  String selectedUrgency = 'Média';
  Seat? selectedSeat;
  final TextEditingController _notesController = TextEditingController();
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _seatLayoutKey = GlobalKey();

  // Usa ValueNotifier para atualizar apenas o indicador de % sem reconstruir as 350 poltronas
  final ValueNotifier<double> _zoomNotifier = ValueNotifier<double>(0.8);
  Size _viewportSize = Size.zero;

  late final AnimationController _matrixAnimController;
  Animation<Matrix4>? _matrixAnimation;

  static const double _minZoom = 0.25;
  static const double _maxZoom = 2.8;

  final List<String> issueTypes = MaintenanceIssue.standardProblemTypes;

  final List<String> urgencyLevels = ['Baixa', 'Média', 'Alta'];

  @override
  void initState() {
    super.initState();
    widget.roomController.selectRoomById(widget.roomId);

    _matrixAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_matrixAnimation != null) {
          _transformationController.value = _matrixAnimation!.value;
          _zoomNotifier.value =
              _transformationController.value.getMaxScaleOnAxis();
        }
      });

    _transformationController.addListener(_onTransformChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetZoom(animate: false));
  }

  void _onTransformChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _zoomNotifier.value).abs() > 0.01) {
      _zoomNotifier.value = scale;
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformChanged);
    _matrixAnimController.dispose();
    _zoomNotifier.dispose();
    _notesController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _animateMatrixTo(Matrix4 targetMatrix) {
    _matrixAnimation = Matrix4Tween(
      begin: _transformationController.value.clone(),
      end: targetMatrix,
    ).animate(
      CurvedAnimation(
        parent: _matrixAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _matrixAnimController.forward(from: 0);
  }

  void _resetZoom({bool animate = true}) {
    final RenderBox? renderBox =
        _seatLayoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size roomSize = renderBox.size;
    final Size viewSize = _viewportSize != Size.zero
        ? _viewportSize
        : MediaQuery.of(context).size;

    if (roomSize.width <= 0 || roomSize.height <= 0) return;

    final double scaleX = (viewSize.width * 0.94) / roomSize.width;
    final double scaleY = (viewSize.height * 0.80) / roomSize.height;
    final double scale =
        (scaleX < scaleY ? scaleX : scaleY).clamp(_minZoom, _maxZoom);

    final double xOffset = (viewSize.width - (roomSize.width * scale)) / 2;
    final double yOffset =
        ((viewSize.height * 0.86) - (roomSize.height * scale)) / 2;

    final targetMatrix = Matrix4.identity()
      ..translateByDouble(xOffset, yOffset.clamp(8.0, 120.0), 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    if (animate) {
      _animateMatrixTo(targetMatrix);
    } else {
      _transformationController.value = targetMatrix;
      _zoomNotifier.value = scale;
    }
  }

  /// Faz zoom mantendo o centro da tela (ou ponto tocado) fixo no lugar
  void _zoomAroundPoint(double targetZoom, {Offset? focalPoint}) {
    final currentMatrix = _transformationController.value.clone();
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    if (currentScale <= 0) return;

    final clampedZoom = targetZoom.clamp(_minZoom, _maxZoom);
    final scaleFactor = clampedZoom / currentScale;

    final center = focalPoint ??
        Offset(_viewportSize.width / 2, (_viewportSize.height * 0.8) / 2);

    // Translada para o ponto focal, aplica escala e volta
    final nextMatrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0.0, 1.0)
      ..scaleByDouble(scaleFactor, scaleFactor, 1.0, 1.0)
      ..translateByDouble(-center.dx, -center.dy, 0.0, 1.0)
      ..multiply(currentMatrix);

    _animateMatrixTo(nextMatrix);
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    HapticFeedback.selectionClick();
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale < 1.15) {
      _zoomAroundPoint(1.55, focalPoint: details.localPosition);
    } else {
      _resetZoom(animate: true);
    }
  }

  void _selectSeat(Seat seat) {
    HapticFeedback.selectionClick();
    setState(() {
      if (selectedSeat?.id == seat.id) {
        selectedSeat = null;
      } else {
        selectedSeat = seat;
      }
    });
  }

  void registerIssue() {
    if (selectedSeat == null || selectedIssueType == null) {
      showTopNotice(
        context,
        'Toque em uma poltrona no mapa e escolha o tipo de defeito.',
        isWarning: true,
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
      // Fecha o sheet após registrar para devolver a visão livre do mapa
      selectedSeat = null;
    });

    final msg = isOperacao
        ? 'Solicitação enviada para a fila de Triagem com sucesso!'
        : 'Demanda registrada em manutenção com sucesso.';

    showTopNotice(context, msg, isWarning: isOperacao);
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: AppleColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppleColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppleColors.glassBorder, width: 1),
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          _buildLegendItem(const Color(0xFF248A3D), 'Operacional'),
          _buildLegendItem(AppleColors.systemCyan, 'Cadeirante'),
          _buildLegendItem(AppleColors.accentIndigo, 'Acompanhante'),
          _buildLegendItem(AppleColors.systemPurple, 'Obeso'),
          _buildLegendItem(AppleColors.systemAmber, 'Em Triagem'),
          _buildLegendItem(AppleColors.systemOrange, 'Atenção (Usual)'),
          _buildLegendItem(AppleColors.systemRed, 'Interditada'),
          _buildLegendItem(AppleColors.accentBlue, 'Selecionado'),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 12,
      top: 12,
      child: AppleGlassCard(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        borderRadius: 14,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () => _zoomAroundPoint(_zoomNotifier.value + 0.25),
              tooltip: 'Aproximar (+)',
              visualDensity: VisualDensity.compact,
            ),
            ValueListenableBuilder<double>(
              valueListenable: _zoomNotifier,
              builder: (context, zoom, _) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${(zoom * 100).round()}%',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 20),
              onPressed: () => _zoomAroundPoint(_zoomNotifier.value - 0.25),
              tooltip: 'Afastar (-)',
              visualDensity: VisualDensity.compact,
            ),
            const Divider(height: 6),
            IconButton(
              icon: const Icon(Icons.fit_screen_rounded, size: 18),
              onPressed: () => _resetZoom(animate: true),
              tooltip: 'Ajustar sala inteira na tela',
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
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppleColors.accentBlue,
                  Colors.white,
                  AppleColors.accentBlue,
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
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

    // RepaintBoundary isola a textura das 350 poltronas na GPU durante o pan/zoom
    return RepaintBoundary(
      child: Container(
        key: _seatLayoutKey,
        padding: const EdgeInsets.all(24),
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
                        style: TextStyle(
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
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectSeat(seat),
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
      ),
    );
  }

  Widget _buildSeatLayout(Room room) {
    if (room.isGridLayout) {
      return _buildGridSeatLayout(room);
    }

    return RepaintBoundary(
      child: Container(
        key: _seatLayoutKey,
        padding: const EdgeInsets.all(24),
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
                            style: TextStyle(
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
                    final numCols =
                        room.colsByRow[rowLabel] ?? room.colsDefault;
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
                          final seat = widget.roomController
                              .getSeat(rowLabel, colNumber);
                          if (seat == null) {
                            return const SizedBox(width: 30);
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectSeat(seat),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppleColors.systemRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppleColors.systemRed.withValues(alpha: 0.38),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_circle_rounded,
                color: AppleColors.systemRed,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Demandas na poltrona $seatId (${activeIssues.length})',
                style: TextStyle(
                  color: AppleColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...activeIssues.map((issue) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
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
                                '${issue.problemType} • ${issue.urgency}',
                                style: TextStyle(
                                  color: AppleColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (issue.isStaging)
                              AppleStatusPill(
                                label: 'Triagem',
                                color: AppleColors.systemAmber,
                              ),
                          ],
                        ),
                        if (issue.notes != null && issue.notes!.isNotEmpty)
                          Text(
                            issue.notes!,
                            style: TextStyle(
                              color: AppleColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        Text(
                          'Por ${issue.reportedBy ?? "Operação"} • ${DateFormat('dd/MM HH:mm').format(issue.dateTime)}',
                          style: TextStyle(
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
                          showTopNotice(
                            context,
                            'Demanda do assento $seatId aprovada!',
                          );
                        }
                      },
                      icon: Icon(
                        Icons.check_rounded,
                        color: AppleColors.systemAmber,
                        size: 16,
                      ),
                      label: Text(
                        'Aprovar',
                        style: TextStyle(
                          color: AppleColors.systemAmber,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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
                          showTopNotice(
                            context,
                            'Manutenção do assento $seatId concluída!',
                          );
                        }
                      },
                      icon: Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppleColors.systemGreen,
                        size: 16,
                      ),
                      label: Text(
                        'Concluir',
                        style: TextStyle(
                          color: AppleColors.systemGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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

  /// Painel flutuante recolhível estilo Apple Maps:
  /// - Quando nenhuma poltrona está selecionada, ocupa apenas uma pílula discreta.
  /// - Quando uma poltrona é tocada, abre o formulário compacto com opção de fechar.
  Widget _buildBottomOverlay(Room room) {
    if (selectedSeat == null) {
      return Positioned(
        left: 16,
        right: 16,
        bottom: 14,
        child: Center(
          child: AppleGlassCard(
            enableBlur: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            borderRadius: 999,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: AppleColors.accentBlue,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Toque em uma poltrona para inspecionar • 2 toques para zoom',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final exceptionLabel = room.excecoes[selectedSeat!.id];
    final isOperacao = Provider.of<AuthController>(context, listen: false)
            .currentUser
            ?.role
            .createsAsStaging ??
        false;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 10,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.48,
        ),
        child: SingleChildScrollView(
          child: AppleGlassCard(
            elevated: true,
            enableBlur: true,
            borderRadius: 22,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 34,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        AppleStatusPill(
                          label:
                              'Poltrona ${selectedSeat!.id}${exceptionLabel != null ? ' • $exceptionLabel' : ''}',
                          color: AppleColors.accentBlue,
                          icon: Icons.event_seat_rounded,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Fechar painel e ver mapa inteiro',
                      onPressed: () => setState(() => selectedSeat = null),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildActiveIssuesForSeat(room),
                Text(
                  'SELECIONE O DEFEITO:',
                  style: TextStyle(
                    color: AppleColors.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: issueTypes.map((type) {
                    final isSelected = selectedIssueType == type;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => selectedIssueType = type);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppleColors.accentBlue.withValues(alpha: 0.26)
                              : AppleColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(9),
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
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'URGÊNCIA:',
                      style: TextStyle(
                        color: AppleColors.textTertiary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => selectedUrgency = level);
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? color.withValues(alpha: 0.22)
                                        : AppleColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(8),
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
                                      fontSize: 11.5,
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextFormField(
                          controller: _notesController,
                          style: TextStyle(
                            color: AppleColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Observação (opcional)',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ApplePressable(
                      onPressed: registerIssue,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: LinearGradient(
                            colors: isOperacao
                                ? [
                                    AppleColors.systemOrange,
                                    AppleColors.systemAmber,
                                  ]
                                : [
                                    const Color(0xFF1E90FF),
                                    AppleColors.accentBlue,
                                  ],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOperacao
                                  ? Icons.send_rounded
                                  : Icons.check_rounded,
                              color: isOperacao ? Colors.black : Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOperacao ? 'Enviar Triagem' : 'Registrar',
                              style: TextStyle(
                                color: isOperacao ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                style: TextStyle(
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
            icon: const Icon(Icons.fit_screen_rounded),
            onPressed: () => _resetZoom(animate: true),
            tooltip: 'Ajustar sala inteira na tela',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildLegend(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportSize =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onDoubleTapDown: _handleDoubleTapDown,
                        onDoubleTap: () {},
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          constrained: false,
                          boundaryMargin: const EdgeInsets.symmetric(
                            horizontal: 240,
                            vertical: 260,
                          ),
                          minScale: _minZoom,
                          maxScale: _maxZoom,
                          child: _buildSeatLayout(selectRoom),
                        ),
                      ),
                      _buildZoomControls(),
                      _buildBottomOverlay(selectRoom),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
