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
  IssueStatus status;
  DateTime? resolvedAt;
  String? resolvedBy;
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
    this.status = IssueStatus.active,
    this.resolvedAt,
    this.resolvedBy,
    this.rejectionReason,
  })  : id = id ?? '${cinemaId}_${roomId}_${seatId}_${(dateTime ?? DateTime.now()).microsecondsSinceEpoch}',
        dateTime = dateTime ?? DateTime.now();

  bool get resolved => status == IssueStatus.resolved;
  bool get isStaging => status == IssueStatus.staging;
  bool get isActive => status == IssueStatus.active;
  bool get isRejected => status == IssueStatus.rejected;

  /// True quando a demanda ativa interdita o assento (Encosto Solto / Assento Solto)
  bool get isBlockingSeat => isBlockingProblem(problemType);

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
      'status': status.name,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolvedBy': resolvedBy,
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
      status: parsedStatus,
      resolvedAt: json['resolvedAt'] != null ? DateTime.tryParse(json['resolvedAt']) : null,
      resolvedBy: json['resolvedBy'],
      rejectionReason: json['rejectionReason'],
    );
  }
}
