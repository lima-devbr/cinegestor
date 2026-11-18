import 'cinema_sector.dart';

enum IssueStatus {
  staging, // Pendente de aprovação pela operação
  rejected, // Rejeitada na triagem
  active, // Aprovada / em manutenção
  resolved, // Finalizada
}

extension IssueStatusExtension on IssueStatus {
  String get displayName {
    switch (this) {
      case IssueStatus.staging:
        return 'Em Triagem';
      case IssueStatus.rejected:
        return 'Rejeitada';
      case IssueStatus.active:
        return 'Em Aberto';
      case IssueStatus.resolved:
        return 'Resolvida';
    }
  }
}

class MaintenanceIssue {
  static const List<String> standardProblemTypes = [
    'Capa Assento Rasg.',
    'Capa Encosto Rasg.',
    'Arremate Solto',
    'PC-E',
    'PC-D',
    'Poltrona s/ Número',
    'Encosto Solto',
    'Assento Solto',
    'S/Mola',
    'Outros',
  ];

  /// Padroniza nomes antigos e atuais para a lista oficial de defeitos
  static String normalizeProblemType(String raw) {
    if (raw.contains(':')) {
      final prefix = raw.split(':').first.trim();
      if (prefix.isNotEmpty && prefix.length <= 40) {
        return prefix;
      }
    }
    final lower = raw.trim().toLowerCase();
    if (lower == 'trocar capa assento' ||
        lower == 'capa assento rasg.' ||
        lower == 'capa rasgada') {
      return 'Capa Assento Rasg.';
    }
    if (lower == 'trocar capa encosto' || lower == 'capa encosto rasg.') {
      return 'Capa Encosto Rasg.';
    }
    if (lower == 'sem número' ||
        lower == 'sem numero' ||
        lower == 'poltrona sem número' ||
        lower == 'poltrona s/ número' ||
        lower == 'poltrona s/ numero') {
      return 'Poltrona s/ Número';
    }
    if (lower == 'trocar mola' || lower == 's/mola' || lower == 'sem mola') {
      return 'S/Mola';
    }
    if (lower == 'encosto solto') {
      return 'Encosto Solto';
    }
    if (lower == 'assento solto') {
      return 'Assento Solto';
    }
    if (lower == 'arremate solto') {
      return 'Arremate Solto';
    }
    if (lower == 'pc-e') {
      return 'PC-E';
    }
    if (lower == 'pc-d') {
      return 'PC-D';
    }
    if (lower == 'outro' || lower == 'outros') {
      return 'Outros';
    }
    return raw.trim();
  }

  /// Retorna true apenas se o defeito inviabiliza/interdita a poltrona para o cliente
  /// (Encosto Solto ou Assento Solto). Capas, números, PC-E/D, mola e arremate
  /// mantêm a poltrona usual/operacional, mas em atenção.
  static bool isBlockingProblem(String raw) {
    final normalized = normalizeProblemType(raw);
    return normalized == 'Encosto Solto' || normalized == 'Assento Solto';
  }

  final String id;
  final String cinemaId;
  final String roomId;
  final String seatId;
  final String problemType;
  final String urgency;
  final String? notes;
  final DateTime dateTime;
  final String? reportedBy; // Nome ou email de quem criou
  final String? reportedRole; // Papel de quem criou
  final String? beforePhotoBase64; // Foto de evidência na abertura
  IssueStatus status;
  DateTime? resolvedAt;
  String? resolvedBy;
  String? afterPhotoBase64; // Foto de evidência na conclusão
  String? rejectionReason;

  MaintenanceIssue({
    String? id,
    this.cinemaId = '2159',
    required this.roomId,
    required this.seatId,
    required this.problemType,
    required this.urgency,
    this.notes,
    DateTime? dateTime,
    this.reportedBy,
    this.reportedRole,
    this.beforePhotoBase64,
    this.status = IssueStatus.active,
    this.resolvedAt,
    this.resolvedBy,
    this.afterPhotoBase64,
    this.rejectionReason,
  })  : id = id ?? '${cinemaId}_${roomId}_${seatId}_${(dateTime ?? DateTime.now()).microsecondsSinceEpoch}',
        dateTime = dateTime ?? DateTime.now();

  bool get resolved => status == IssueStatus.resolved;
  bool get isStaging => status == IssueStatus.staging;
  bool get isActive => status == IssueStatus.active;
  bool get isRejected => status == IssueStatus.rejected;

  /// True quando a demanda ativa interdita o assento (Encosto Solto / Assento Solto)
  bool get isBlockingSeat => isBlockingProblem(problemType);

  /// True se o chamado for aberto para uma área comum do cinema (fora das salas)
  bool get isCommonSector => roomId.startsWith('setor_');

  bool get isLightingIssue =>
      seatId.startsWith('LED-') ||
      seatId.startsWith('ARAN-') ||
      seatId.startsWith('REF-');

  bool get isGeneralIssue =>
      seatId.startsWith('GERAL-') ||
      seatId == 'SALA' ||
      seatId.startsWith('INFRA-');

  bool get isSeatIssue => !isLightingIssue && !isGeneralIssue && !isCommonSector;

  String get targetCategoryLabel {
    if (isCommonSector) {
      final sector = CinemaSector.findById(roomId);
      return sector?.name ?? 'Área Comum / Geral';
    }
    if (isGeneralIssue) return 'Infraestrutura da Sala';
    if (isLightingIssue) return 'Iluminação Técnica';
    return 'Poltrona';
  }

  String get targetDisplayLabel {
    if (isCommonSector) {
      final sector = CinemaSector.findById(roomId);
      final sectorName = sector?.name ?? roomId.replaceFirst('setor_', '').toUpperCase();
      if (isGeneralIssue) {
        final clean = seatId.replaceFirst('GERAL-', '').replaceAll('_', ' ');
        return '$sectorName • $clean';
      }
      return sectorName;
    }
    if (isGeneralIssue) {
      final clean = seatId.replaceFirst('GERAL-', '').replaceAll('_', ' ');
      return clean.isNotEmpty ? clean : 'Geral da Sala';
    }
    if (isLightingIssue) {
      return seatId;
    }
    return 'Poltrona $seatId';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cinemaId': cinemaId,
      'roomId': roomId,
      'seatId': seatId,
      'problemType': problemType,
      'urgency': urgency,
      'notes': notes,
      'dateTime': dateTime.toIso8601String(),
      'reportedBy': reportedBy,
      'reportedRole': reportedRole,
      'beforePhotoBase64': beforePhotoBase64,
      'status': status.name,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
      'afterPhotoBase64': afterPhotoBase64,
      'rejectionReason': rejectionReason,
    };
  }

  factory MaintenanceIssue.fromJson(Map<String, dynamic> json) {
    final parsedDate = DateTime.parse(json['dateTime']);
    
    // Compatibilidade com registros legados (que usavam bool resolved)
    IssueStatus parsedStatus;
    if (json.containsKey('status')) {
      parsedStatus = IssueStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => IssueStatus.active,
      );
    } else {
      final wasResolved = json['resolved'] == true;
      parsedStatus = wasResolved ? IssueStatus.resolved : IssueStatus.active;
    }

    return MaintenanceIssue(
      id: json['id'] ?? '${json['cinemaId'] ?? "2159"}_${json['roomId']}_${json['seatId']}_${parsedDate.microsecondsSinceEpoch}',
      cinemaId: json['cinemaId'] ?? '2159',
      roomId: json['roomId'],
      seatId: json['seatId'],
      problemType: json['problemType'],
      urgency: json['urgency'],
      notes: json['notes'],
      dateTime: parsedDate,
      reportedBy: json['reportedBy'],
      reportedRole: json['reportedRole'],
      beforePhotoBase64: json['beforePhotoBase64'],
      status: parsedStatus,
      resolvedAt: json['resolvedAt'] != null ? DateTime.tryParse(json['resolvedAt']) : null,
      resolvedBy: json['resolvedBy'],
      afterPhotoBase64: json['afterPhotoBase64'],
      rejectionReason: json['rejectionReason'],
    );
  }
}
