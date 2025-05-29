class MaintenanceIssue {
  final String roomId;
  final String seatId;
  final String problemType;
  final String urgency;
  final String? notes;
  final DateTime dateTime;

  MaintenanceIssue({
    required this.roomId,
    required this.seatId,
    required this.problemType,
    required this.urgency,
    this.notes,
    DateTime? dateTime,
  }) : dateTime = dateTime ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'seatId': seatId,
      'problemType': problemType,
      'urgency': urgency,
      'notes': notes,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  factory MaintenanceIssue.fromJson(Map<String, dynamic> json) {
    return MaintenanceIssue(
      roomId: json['roomId'],
      seatId: json['seatId'],
      problemType: json['problemType'],
      urgency: json['urgency'],
      notes: json['notes'],
      dateTime: DateTime.parse(json['dateTime']),
    );
  }
}
