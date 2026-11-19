import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/maintenance_issue.dart';
import '../models/cinema_sector.dart';
import '../models/room.dart';
import '../models/app_user.dart';

class PdfReportService {
  /// Gera e abre o visualizador/impressão de PDF com a lista de ocorrências
  static Future<void> generateAndPrintReport({
    required String cinemaName,
    required String cinemaId,
    required List<MaintenanceIssue> issues,
    required List<Room> rooms,
    required AppUser? currentUser,
    String? subtitleFilter,
  }) async {
    final pdf = pw.Document();

    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final total = issues.length;
    final resolvedCount = issues.where((i) => i.resolved).length;
    final inProgressCount = issues.where((i) => i.isInProgress).length;
    final openCount = issues.where((i) => i.isOpen).length;
    final stagingCount = issues.where((i) => i.isStaging).length;

    // Constrói mapa de salas para lookup rápido
    final roomMap = {for (final r in rooms) r.id: r};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildHeader(
          cinemaName: cinemaName,
          cinemaId: cinemaId,
          nowStr: nowStr,
          issuerName: currentUser?.name ?? 'Administração',
          issuerRole: currentUser?.role.displayName ?? 'Gerência',
        ),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),
          if (subtitleFilter != null && subtitleFilter.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Filtro aplicado: $subtitleFilter',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
          ],

          // Cards de Métricas no topo
          pw.Row(
            children: [
              _buildMetricBox('TOTAL DE OS', '$total', PdfColors.blueGrey800),
              pw.SizedBox(width: 8),
              _buildMetricBox('RESOLVIDAS', '$resolvedCount', PdfColors.green700),
              pw.SizedBox(width: 8),
              _buildMetricBox('EM ANDAMENTO', '$inProgressCount', PdfColors.indigo700),
              pw.SizedBox(width: 8),
              _buildMetricBox('EM ABERTO', '$openCount', PdfColors.orange800),
              if (stagingCount > 0) ...[
                pw.SizedBox(width: 8),
                _buildMetricBox('TRIAGEM', '$stagingCount', PdfColors.amber800),
              ],
            ],
          ),
          pw.SizedBox(height: 16),

          pw.Text(
            'DETALHAMENTO DAS ORDENS DE SERVIÇO',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 8),

          // Tabela das Ordens de Serviço
          pw.TableHelper.fromTextArray(
            headers: [
              'Local / Setor',
              'Problema / Defeito',
              'Urgência',
              'Responsável (OS)',
              'Status',
              'Abertura',
              'Conclusão',
            ],
            data: issues.map((issue) {
              String location;
              if (issue.isCommonSector) {
                final sector = CinemaSector.findById(issue.roomId);
                location = sector?.name ?? issue.roomId;
              } else {
                final room = roomMap[issue.roomId];
                location = room?.nome ?? 'Sala ${issue.roomId}';
              }

              final openDate = DateFormat('dd/MM/yy HH:mm').format(issue.dateTime);
              final resolveDate = issue.resolved && issue.resolvedAt != null
                  ? DateFormat('dd/MM/yy HH:mm').format(issue.resolvedAt!)
                  : '-';

              String statusText = issue.status.displayName;
              if (issue.isInProgress) {
                statusText = 'Em Andamento';
              }

              final responsible = issue.assignedTo != null && issue.assignedTo!.isNotEmpty
                  ? issue.assignedTo!
                  : (issue.resolvedBy != null && issue.resolvedBy!.isNotEmpty
                      ? issue.resolvedBy!
                      : 'Não atribuído');

              return [
                '$location\n(${issue.targetDisplayLabel})',
                issue.notes != null && issue.notes!.isNotEmpty
                    ? '${issue.problemType}\nObs: ${issue.notes}'
                    : issue.problemType,
                issue.urgency,
                responsible,
                statusText,
                openDate,
                resolveDate,
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
          ),

          pw.SizedBox(height: 28),

          // Espaço de Assinaturas
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 200,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey700, width: 1),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Encarregado / Responsável Técnico',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 200,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: PdfColors.grey700, width: 1),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Gerência Geral / Validação Operacional',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // Abre o diálogo nativo do sistema / navegador de impressão/download PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Relatorio_OS_${cinemaId}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildHeader({
    required String cinemaName,
    required String cinemaId,
    required String nowStr,
    required String issuerName,
    required String issuerRole,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CINEGESTOR • RELATÓRIO DE ORDENS DE SERVIÇO',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '$cinemaName (Unidade $cinemaId)',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Emitido em: $nowStr',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                'Por: $issuerName ($issuerRole)',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'CineGestor - Sistema Inteligente de Manutenção de Salas',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: color, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
