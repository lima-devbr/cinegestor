import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cinema_sector.dart';
import '../models/maintenance_issue.dart';
import '../models/app_user.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import 'apple_surfaces.dart';
import 'photo_evidence_widgets.dart';
import 'quick_issue_dialog.dart';

class CommonSectorsSheet extends StatefulWidget {
  final RoomController roomController;

  const CommonSectorsSheet({super.key, required this.roomController});

  static Future<void> show(BuildContext context, RoomController roomController) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommonSectorsSheet(roomController: roomController),
    );
  }

  @override
  State<CommonSectorsSheet> createState() => _CommonSectorsSheetState();
}

class _CommonSectorsSheetState extends State<CommonSectorsSheet> {
  String? _expandedSectorId;

  void _showResolveDialog(MaintenanceIssue issue, AppUser? user) {
    String? afterPhoto;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Concluir: ${issue.targetDisplayLabel}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Confirma a finalização deste chamado?',
                style: TextStyle(color: AppleColors.textSecondary),
              ),
              const SizedBox(height: 14),
              PhotoEvidencePickerTile(
                photoBase64: afterPhoto,
                label: 'Foto do Reparo Concluído (opcional)',
                onChanged: (val) => setDialogState(() => afterPhoto = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.roomController.resolveIssue(
                  issue.id,
                  resolvedBy: user?.name ?? user?.email ?? 'Manutenção',
                  afterPhotoBase64: afterPhoto,
                );
                Navigator.pop(ctx);
                showTopNotice(context, 'Chamado concluído com sucesso!');
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppleColors.systemGreen,
                foregroundColor: Colors.black,
              ),
              child: const Text('Confirmar Conclusão'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueItem(MaintenanceIssue issue, AppUser? user) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppleColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: issue.urgency == 'Alta'
              ? AppleColors.systemRed.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: (issue.urgency == 'Alta'
                          ? AppleColors.systemRed
                          : issue.urgency == 'Média'
                              ? AppleColors.systemOrange
                              : AppleColors.systemGreen)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  issue.urgency,
                  style: TextStyle(
                    color: issue.urgency == 'Alta'
                        ? AppleColors.systemRed
                        : issue.urgency == 'Média'
                            ? AppleColors.systemOrange
                            : AppleColors.systemGreen,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (issue.isStaging)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppleColors.systemAmber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Triagem',
                    style: TextStyle(
                      color: AppleColors.systemAmber,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                DateFormat('dd/MM HH:mm').format(issue.dateTime),
                style: TextStyle(
                  color: AppleColors.textTertiary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            issue.problemType,
            style: TextStyle(
              color: AppleColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (issue.notes != null && issue.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              issue.notes!,
              style: TextStyle(
                color: AppleColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (issue.beforePhotoBase64 != null) ...[
            const SizedBox(height: 8),
            PhotoEvidenceThumb(
              photoBase64: issue.beforePhotoBase64!,
              tagLabel: 'Evidência',
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Por ${issue.reportedBy ?? "Equipe"}',
            style: TextStyle(
              color: AppleColors.textTertiary,
              fontSize: 11,
            ),
          ),
          if ((issue.isStaging && (user?.role.canApproveStaging ?? false)) ||
              (issue.isActive && (user?.role.canResolveIssue ?? false))) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (issue.isStaging &&
                    (user?.role.canApproveStaging ?? false)) ...[
                  TextButton(
                    onPressed: () {
                      widget.roomController.rejectStagingIssue(
                        issue.id,
                        reason: 'Descartado em Áreas Comuns',
                      );
                      setState(() {});
                    },
                    child: Text(
                      'Recusar',
                      style: TextStyle(color: AppleColors.systemRed),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.roomController.approveStagingIssue(
                        issue.id,
                        approvedBy: user?.name,
                      );
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppleColors.systemGreen,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Aprovar'),
                  ),
                ] else if (issue.isActive &&
                    (user?.role.canResolveIssue ?? false)) ...[
                  ElevatedButton.icon(
                    onPressed: () => _showResolveDialog(issue, user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppleColors.systemGreen,
                      foregroundColor: Colors.black,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Concluir Reparo'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthController>(context);
    final user = auth.currentUser;
    final issues = widget.roomController.activeIssues;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: BoxDecoration(
        color: AppleColors.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppleColors.textTertiary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppleColors.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    color: AppleColors.accentBlue,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Áreas Comuns do Cinema',
                      style: TextStyle(
                        color: AppleColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Bomboniere, Foyer, Banheiros e Instalações',
                      style: TextStyle(
                        color: AppleColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Sectors List
          Expanded(
            child: ListView.separated(
              itemCount: CinemaSector.commonSectors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final sector = CinemaSector.commonSectors[index];
                final sectorIssues =
                    issues.where((i) => i.roomId == sector.id).toList();
                final isExpanded = _expandedSectorId == sector.id;

                return AppleGlassCard(
                  elevated: true,
                  borderRadius: 14,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedSectorId =
                                isExpanded ? null : sector.id;
                          });
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (sectorIssues.isNotEmpty
                                        ? AppleColors.systemOrange
                                        : AppleColors.accentBlue)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  sector.icon,
                                  color: sectorIssues.isNotEmpty
                                      ? AppleColors.systemOrange
                                      : AppleColors.accentBlue,
                                  size: 19,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sector.name,
                                    style: TextStyle(
                                      color: AppleColors.textPrimary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    sector.description,
                                    style: TextStyle(
                                      color: AppleColors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (sectorIssues.isNotEmpty
                                        ? AppleColors.systemOrange
                                        : AppleColors.systemGreen)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sectorIssues.isNotEmpty
                                    ? '${sectorIssues.length} pendente${sectorIssues.length > 1 ? "s" : ""}'
                                    : 'OK',
                                style: TextStyle(
                                  color: sectorIssues.isNotEmpty
                                      ? AppleColors.systemOrange
                                      : AppleColors.systemGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.add_rounded, size: 20),
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Novo Chamado em ${sector.name}',
                              onPressed: () {
                                QuickIssueDialog.show(
                                  context: context,
                                  roomController: widget.roomController,
                                  preSelectedSector: sector,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        if (sectorIssues.isEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                'Nenhuma ocorrência neste setor!',
                                style: TextStyle(
                                  color: AppleColors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          ...sectorIssues.map((issue) =>
                              _buildIssueItem(issue, user)),
                        ],
                      ],
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
}
