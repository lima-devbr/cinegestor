import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/app_user.dart';
import '../models/cinema_sector.dart';
import '../widgets/apple_surfaces.dart';
import '../widgets/photo_evidence_widgets.dart';

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
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppleColors.systemAmber.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.rule_folder_outlined,
                      size: 34,
                      color: AppleColors.systemAmber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma solicitação na fila de triagem',
                    style: TextStyle(
                      color: AppleColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'As solicitações enviadas pela equipe de operação aparecerão aqui.',
                    style: TextStyle(
                      color: AppleColors.textSecondary,
                      fontSize: 13,
                    ),
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
                String itemTitle;
                IconData itemIcon;

                if (issue.isCommonSector) {
                  final sector = CinemaSector.findById(issue.roomId);
                  final sectorName = sector?.name ?? 'Área Comum';
                  itemTitle = '$sectorName • ${issue.targetDisplayLabel}';
                  itemIcon = sector?.icon ?? Icons.storefront_rounded;
                } else {
                  final room = roomController.getRoomById(issue.roomId);
                  final roomName = room?.displayName ?? 'Sala ${issue.roomId}';
                  if (issue.isGeneralIssue) {
                    itemTitle = '$roomName • Infraestrutura (${issue.targetDisplayLabel})';
                    itemIcon = Icons.build_circle_outlined;
                  } else if (issue.isLightingIssue) {
                    itemTitle = '$roomName • Iluminação (${issue.seatId})';
                    itemIcon = Icons.lightbulb_outline_rounded;
                  } else {
                    itemTitle = '$roomName • Poltrona ${issue.seatId}';
                    itemIcon = Icons.chair_rounded;
                  }
                }

                return AppleGlassCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  borderRadius: 18,
                  borderColor: AppleColors.systemAmber.withValues(alpha: 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppleColors.systemAmber.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    itemIcon,
                                    color: AppleColors.systemAmber,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    itemTitle,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppleStatusPill(
                            label: 'Aguardando Aprovação',
                            color: AppleColors.systemAmber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Defeito relatado: ${issue.problemType}',
                        style: TextStyle(
                          color: AppleColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (issue.notes != null && issue.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Observações: ${issue.notes}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppleColors.textSecondary,
                          ),
                        ),
                      ],
                      if (issue.beforePhotoBase64 != null &&
                          issue.beforePhotoBase64!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        PhotoEvidenceThumb(
                          photoBase64: issue.beforePhotoBase64!,
                          tagLabel: 'Evidência',
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Reportado por ${issue.reportedBy ?? "Operação"} (${issue.reportedRole ?? "Operação"})',
                            style: TextStyle(
                              color: AppleColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm')
                                .format(issue.dateTime),
                            style: TextStyle(
                              color: AppleColors.textTertiary,
                              fontSize: 12,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (currentUser?.role.canApproveStaging ?? false)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ApplePressable(
                              pressedScale: 0.96,
                              onPressed: () {
                                roomController.rejectStagingIssue(
                                  issue.id,
                                  reason: 'Recusado na triagem',
                                );
                                showTopNotice(
                                  context,
                                  'Solicitação recusada e arquivada.',
                                  isWarning: true,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppleColors.systemRed.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppleColors.systemRed.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: AppleColors.systemRed,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Recusar',
                                      style: TextStyle(
                                        color: AppleColors.systemRed,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ApplePressable(
                              pressedScale: 0.96,
                              onPressed: () {
                                roomController.approveStagingIssue(
                                  issue.id,
                                  approvedBy: currentUser?.name,
                                );
                                showTopNotice(
                                  context,
                                  'Demanda aprovada! A poltrona ${issue.seatId} agora está em manutenção.',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppleColors.accentBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Aprovar Demanda',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Apenas Encarregados ou Gerentes podem aprovar solicitações.',
                          style: TextStyle(
                            color: AppleColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
