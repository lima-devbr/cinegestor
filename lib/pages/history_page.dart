import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/maintenance_issue.dart';
import '../models/cinema_sector.dart';
import '../models/app_user.dart';
import '../widgets/apple_surfaces.dart';
import '../widgets/photo_evidence_widgets.dart';
import '../widgets/assign_responsible_dialog.dart';
import '../services/pdf_report_service.dart';

class HistoryPage extends StatefulWidget {
  final String? initialRoomId;
  final String? initialSeatId;

  const HistoryPage({
    super.key,
    this.initialRoomId,
    this.initialSeatId,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late String _selectedRoomFilter;
  String _selectedStatusFilter = 'all';
  String _selectedUrgencyFilter = 'all';
  late final TextEditingController _seatFilterController;
  String _seatFilter = '';

  @override
  void initState() {
    super.initState();
    _selectedRoomFilter = widget.initialRoomId ?? 'all';
    _seatFilter = (widget.initialSeatId ?? '').trim().toUpperCase();
    _seatFilterController = TextEditingController(text: _seatFilter);

    // Passo 4: Carrega sob demanda a primeira página de histórico (limit 25)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomController =
          Provider.of<RoomController>(context, listen: false);
      if (roomController.historicalIssues.isEmpty &&
          roomController.hasMoreHistory) {
        roomController.loadHistoricalIssues();
      }
    });
  }

  @override
  void dispose() {
    _seatFilterController.dispose();
    super.dispose();
  }

  List<MaintenanceIssue> _filterIssues(List<MaintenanceIssue> issues) {
    final filtered = issues.where((issue) {
      if (_selectedRoomFilter != 'all' && issue.roomId != _selectedRoomFilter) {
        return false;
      }
      if (_seatFilter.isNotEmpty &&
          !issue.seatId.toUpperCase().contains(_seatFilter)) {
        return false;
      }
      if (_selectedStatusFilter == 'staging' && !issue.isStaging) {
        return false;
      }
      if (_selectedStatusFilter == 'active' && issue.status != IssueStatus.active) {
        return false;
      }
      if (_selectedStatusFilter == 'inProgress' && !issue.isInProgress) {
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppleColors.backgroundSecondary,
        border: Border(
          bottom: BorderSide(color: AppleColors.glassBorder, width: 1),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String>(
              key: ValueKey('room_$_selectedRoomFilter'),
              initialValue: _selectedRoomFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Local',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    'Todas as Salas / Áreas',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...roomController.rooms.map(
                  (r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.nome, overflow: TextOverflow.ellipsis),
                  ),
                ),
                ...CinemaSector.commonSectors.map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('🏢 ${s.name}', overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedRoomFilter = val ?? 'all'),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              key: ValueKey('status_$_selectedStatusFilter'),
              initialValue: _selectedStatusFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('Todos', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'staging',
                  child: Text('Em Triagem', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Em Aberto', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'inProgress',
                  child: Text('Em Andamento', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'resolved',
                  child: Text('Resolvidos', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedStatusFilter = val ?? 'all'),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String>(
              key: ValueKey('urgency_$_selectedUrgencyFilter'),
              initialValue: _selectedUrgencyFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Urgência',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('Todas', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'Alta',
                  child: Text('Alta', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'Média',
                  child: Text('Média', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'Baixa',
                  child: Text('Baixa', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedUrgencyFilter = val ?? 'all'),
            ),
          ),
          SizedBox(
            width: 150,
            child: TextField(
              controller: _seatFilterController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Poltrona (ex: G12)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                suffixIcon: _seatFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _seatFilterController.clear();
                          setState(() => _seatFilter = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) =>
                  setState(() => _seatFilter = val.trim().toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(
    BuildContext context,
    List<MaintenanceIssue> filteredIssues,
    RoomController roomController,
  ) async {
    final auth = Provider.of<AuthController>(context, listen: false);
    final currentUser = auth.currentUser;
    final cinemaName = currentUser?.cinemaName ?? 'CineGestor';
    final cinemaId = currentUser?.cinemaId ?? '2159';

    final List<String> activeFilters = [];
    if (_selectedRoomFilter != 'all') {
      final room = roomController.getRoomById(_selectedRoomFilter);
      activeFilters.add(room?.nome ?? _selectedRoomFilter);
    }
    if (_selectedStatusFilter != 'all') {
      activeFilters.add('Status: $_selectedStatusFilter');
    }
    if (_selectedUrgencyFilter != 'all') {
      activeFilters.add('Urgência: $_selectedUrgencyFilter');
    }
    final filterSubtitle = activeFilters.isNotEmpty
        ? activeFilters.join(' • ')
        : 'Todos os registros';

    await PdfReportService.generateAndPrintReport(
      cinemaName: cinemaName,
      cinemaId: cinemaId,
      issues: filteredIssues,
      rooms: roomController.rooms,
      currentUser: currentUser,
      subtitleFilter: filterSubtitle,
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
      String locationName;
      if (issue.isCommonSector) {
        final sector = CinemaSector.findById(issue.roomId);
        locationName = 'Área: ${sector?.name ?? issue.roomId}';
      } else {
        locationName = roomController.getRoomById(issue.roomId)?.displayName ??
            'Sala ${issue.roomId}';
      }
      final status = issue.resolved
          ? 'RESOLVIDO'
          : (issue.isInProgress ? 'EM ANDAMENTO' : 'PENDENTE');
      final openedAt = DateFormat('dd/MM/yyyy HH:mm').format(issue.dateTime);
      buffer.writeln('[$status] $locationName - ${issue.targetDisplayLabel}');
      buffer.writeln(
        '  Problema: ${issue.problemType} | Urgência: ${issue.urgency}',
      );
      if (issue.assignedTo != null && issue.assignedTo!.isNotEmpty) {
        buffer.writeln('  Responsável: ${issue.assignedTo}');
      }
      if (issue.notes != null && issue.notes!.isNotEmpty) {
        buffer.writeln('  Obs: ${issue.notes}');
      }
      buffer.writeln('  Aberto em: $openedAt');
      if (issue.resolved && issue.resolvedAt != null) {
        buffer.writeln(
          '  Concluído em: ${DateFormat('dd/MM/yyyy HH:mm').format(issue.resolvedAt!)}',
        );
      }
      buffer.writeln('');
    }

    final reportText = buffer.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar Relatório'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escolha se deseja gerar o documento oficial em PDF (com cabeçalho, métricas e espaço para assinaturas) ou copiar os dados em texto puro:',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppleColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppleColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppleColors.glassBorder),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    reportText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reportText));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                showTopNotice(
                  context,
                  'Relatório copiado para a área de transferência!',
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar Texto'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _generatePdf(context, filteredIssues, roomController);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppleColors.accentIndigo,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
            label: const Text('Gerar PDF'),
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
        title: const Text('Histórico de Manutenções'),
        actions: [
          if (filteredIssues.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Gerar Relatório em PDF',
              onPressed: () =>
                  _generatePdf(context, filteredIssues, roomController),
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: 'Exportar / Copiar Relatório',
              onPressed: () =>
                  _showExportDialog(context, filteredIssues, roomController),
            ),
          ],
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
                        Icon(
                          Icons.history_rounded,
                          size: 58,
                          color: AppleColors.textTertiary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Nenhum registro de manutenção encontrado',
                          style: TextStyle(
                            color: AppleColors.textSecondary,
                            fontSize: 15,
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
                        if (roomController.hasMoreHistory &&
                            (_selectedStatusFilter == 'all' ||
                                _selectedStatusFilter == 'resolved'))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ElevatedButton.icon(
                              onPressed: roomController.isLoadingHistory
                                  ? null
                                  : () => roomController.loadHistoricalIssues(),
                              icon: roomController.isLoadingHistory
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.history_rounded, size: 18),
                              label: const Text('Buscar no Histórico (+25)'),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredIssues.length +
                        ((roomController.hasMoreHistory &&
                                (_selectedStatusFilter == 'all' ||
                                    _selectedStatusFilter == 'resolved'))
                            ? 1
                            : 0),
                    itemBuilder: (context, index) {
                      if (index == filteredIssues.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: roomController.isLoadingHistory
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () =>
                                        roomController.loadHistoricalIssues(),
                                    icon: const Icon(Icons.download_rounded, size: 18),
                                    label: const Text('Carregar Mais do Histórico (+25)'),
                                  ),
                          ),
                        );
                      }
                      final issue = filteredIssues[index];
                      String itemTitle;

                      if (issue.isCommonSector) {
                        final sector = CinemaSector.findById(issue.roomId);
                        final sectorName = sector?.name ?? 'Área Comum';
                        itemTitle = '$sectorName • ${issue.targetDisplayLabel}';
                      } else {
                        final room = roomController.getRoomById(issue.roomId);
                        final roomName =
                            room?.displayName ?? 'Sala ${issue.roomId}';
                        if (issue.isGeneralIssue) {
                          itemTitle =
                              '$roomName • Infraestrutura (${issue.targetDisplayLabel})';
                        } else if (issue.isLightingIssue) {
                          itemTitle =
                              '$roomName • Iluminação (${issue.targetDisplayLabel})';
                        } else {
                          itemTitle = '$roomName • Poltrona ${issue.seatId}';
                        }
                      }

                      final statusColor = issue.resolved
                          ? AppleColors.systemGreen
                          : issue.isStaging
                              ? AppleColors.systemAmber
                              : issue.isInProgress
                                  ? AppleColors.accentIndigo
                                  : AppleColors.systemRed;

                      return AppleGlassCard(
                        margin: const EdgeInsets.only(bottom: 14),
                        borderRadius: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        issue.resolved
                                            ? Icons.check_circle_rounded
                                            : issue.isStaging
                                                ? Icons.pending_actions_rounded
                                                : issue.isInProgress
                                                    ? Icons.handyman_rounded
                                                    : Icons.warning_amber_rounded,
                                        color: statusColor,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          itemTitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppleStatusPill(
                                  label: issue.status.displayName,
                                  color: statusColor,
                                ),
                              ],
                            ),
                            if (roomController.getSeatRecurrenceCount(
                                  issue.roomId,
                                  issue.seatId,
                                ) >=
                                2) ...[
                              const SizedBox(height: 8),
                              AppleStatusPill(
                                icon: Icons.repeat_rounded,
                                label:
                                    'Reincidente (${roomController.getSeatRecurrenceCount(issue.roomId, issue.seatId)}x)',
                                color: AppleColors.systemAmber,
                              ),
                            ],
                            if (issue.assignedTo != null &&
                                issue.assignedTo!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              AppleStatusPill(
                                icon: Icons.engineering_rounded,
                                label: 'Responsável: ${issue.assignedTo}',
                                color: AppleColors.accentIndigo,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Text(
                              'Defeito: ${issue.problemType}',
                              style: TextStyle(
                                color: AppleColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (issue.notes != null &&
                                issue.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Observações: ${issue.notes}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppleColors.textSecondary,
                                ),
                              ),
                            ],
                            if ((issue.beforePhotoBase64 != null &&
                                    issue.beforePhotoBase64!.isNotEmpty) ||
                                (issue.afterPhotoBase64 != null &&
                                    issue.afterPhotoBase64!.isNotEmpty)) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  if (issue.beforePhotoBase64 != null &&
                                      issue.beforePhotoBase64!.isNotEmpty)
                                    PhotoEvidenceThumb(
                                      photoBase64: issue.beforePhotoBase64!,
                                      tagLabel: 'Antes',
                                    ),
                                  if (issue.afterPhotoBase64 != null &&
                                      issue.afterPhotoBase64!.isNotEmpty)
                                    PhotoEvidenceThumb(
                                      photoBase64: issue.afterPhotoBase64!,
                                      tagLabel: 'Depois',
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppleStatusPill(
                                  label: 'Urgência ${issue.urgency}',
                                  color: _getUrgencyColor(issue.urgency),
                                  showDot: false,
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Aberto: ${DateFormat('dd/MM/yyyy HH:mm').format(issue.dateTime)}',
                                      style: TextStyle(
                                        color: AppleColors.textTertiary,
                                        fontSize: 11.5,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    if (issue.resolved &&
                                        issue.resolvedAt != null)
                                      Text(
                                        'Concluído: ${DateFormat('dd/MM/yyyy HH:mm').format(issue.resolvedAt!)}',
                                        style: TextStyle(
                                          color: AppleColors.systemGreen,
                                          fontSize: 11.5,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 22),
                            Consumer<AuthController>(
                              builder: (context, auth, _) {
                                final user = auth.currentUser;
                                final canResolve =
                                    user?.role.canResolveIssue ?? false;
                                final canReopen =
                                    user?.role.canReopenIssue ?? false;
                                final canDelete =
                                    user?.role.canDeleteIssue ?? false;
                                final canApprove =
                                    user?.role.canApproveStaging ?? false;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (canDelete)
                                      TextButton.icon(
                                        onPressed: () {
                                          roomController.deleteIssue(issue.id);
                                          showTopNotice(
                                            context,
                                            'Registro removido do histórico.',
                                            isWarning: true,
                                          );
                                        },
                                        icon: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 17,
                                          color: AppleColors.systemRed,
                                        ),
                                        label: Text(
                                          'Excluir',
                                          style: TextStyle(
                                            color: AppleColors.systemRed,
                                          ),
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
                                          showTopNotice(
                                            context,
                                            'Solicitação do assento ${issue.seatId} aprovada!',
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppleColors.systemOrange,
                                          foregroundColor: Colors.black,
                                        ),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Aprovar'),
                                      )
                                    else if (issue.isActive && canResolve) ...[
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            AssignResponsibleDialog.show(
                                          context: context,
                                          issue: issue,
                                          roomController: roomController,
                                        ),
                                        icon: const Icon(
                                          Icons.assignment_ind_rounded,
                                          size: 16,
                                        ),
                                        label: Text(
                                          issue.assignedTo != null
                                              ? 'Reatribuir'
                                              : 'Atribuir',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          roomController.resolveIssue(
                                            issue.id,
                                            resolvedBy: user?.name,
                                          );
                                          showTopNotice(
                                            context,
                                            'Manutenção do assento ${issue.seatId} concluída!',
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppleColors.systemGreen,
                                          foregroundColor: Colors.black,
                                        ),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Concluir'),
                                      ),
                                    ] else if (issue.resolved && canReopen)
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          roomController.reopenIssue(issue.id);
                                        },
                                        icon: const Icon(
                                          Icons.replay_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Reabrir'),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
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
        return AppleColors.systemRed;
      case 'média':
        return AppleColors.systemOrange;
      case 'baixa':
        return AppleColors.systemGreen;
      default:
        return AppleColors.textSecondary;
    }
  }
}
