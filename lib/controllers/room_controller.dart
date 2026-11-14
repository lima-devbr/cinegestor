import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinegestor/models/seat.dart';
import '../models/room.dart';
import '../models/maintenance_issue.dart';
import '../repositories/room_repository.dart';

class RoomController extends ChangeNotifier {
  List<Room> _rooms = [];
  List<MaintenanceIssue> _issues = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Room> get rooms => _rooms;
  List<MaintenanceIssue> get issues => _issues;

  Room? _selectRoom;
  Room? get selectRoom => _selectRoom;

  Future<void> loadRooms({String? cinemaId}) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final allRooms = await RoomRepository.loadRoomsFromJson();

      // Se um cinemaId for passado (ex.: funcionário de uma unidade específica),
      // filtra apenas as salas pertencentes àquele cinema
      final filteredRooms = (cinemaId != null && cinemaId.isNotEmpty)
          ? allRooms.where((r) => r.theaterId == null || r.theaterId == cinemaId).toList()
          : allRooms;

      for (var room in filteredRooms) {
        if (room.isGridLayout && room.seats.isNotEmpty) {
          continue;
        }
        for (var row in room.rows) {
          final cols = room.colsByRow[row] ?? room.colsDefault;
          final aisles = room.aislesByRow[row] ?? [];
          for (var col = 1; col <= cols; col++) {
            if (aisles.contains(col)) continue;
            final seatId = '$row$col';
            room.seats[seatId] = Seat(row: row, number: col);
          }
        }
      }

      _rooms = filteredRooms;
      await loadIssues();
      _syncSeatsWithIssues();

      if (_selectRoom != null) {
        try {
          _selectRoom = _rooms.firstWhere((r) => r.id == _selectRoom!.id);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Erro ao carregar salas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _syncSeatsWithIssues() {
    for (final room in _rooms) {
      // Assentos com manutenção confirmada (ativa)
      final activeSeatIds = _issues
          .where((issue) => issue.roomId == room.id && issue.isActive)
          .map((issue) => issue.seatId)
          .toSet();

      // Assentos com solicitações pendentes de triagem (staging)
      final stagingSeatIds = _issues
          .where((issue) => issue.roomId == room.id && issue.isStaging)
          .map((issue) => issue.seatId)
          .toSet();

      for (final entry in room.seats.entries) {
        entry.value.hasDefect = activeSeatIds.contains(entry.key);
        entry.value.hasStaging = stagingSeatIds.contains(entry.key);
      }
    }
  }

  Room? getRoomByName(String nomeSala) {
    try {
      return _rooms.firstWhere((room) => room.nome == nomeSala);
    } catch (e) {
      debugPrint('Erro ao buscar sala: $e');
      return null;
    }
  }

  Room? getRoomById(String roomId) {
    try {
      return _rooms.firstWhere((room) => room.id == roomId);
    } catch (_) {
      return null;
    }
  }

  void selectRoomById(String roomId) {
    if (_selectRoom?.id == roomId) return;

    try {
      final room = _rooms.firstWhere(
        (room) => room.id == roomId,
        orElse: () => throw Exception('Room not found'),
      );

      _selectRoom = room;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Erro ao selecionar sala: $e');
    }
  }

  Future<void> registerIssue(MaintenanceIssue issue) async {
    _issues.insert(0, issue);
    _syncSeatsWithIssues();
    notifyListeners();
    await saveIssues();
  }

  // Triagem: Aprovar demanda (vai para ativa/manutenção)
  Future<void> approveStagingIssue(String issueId, {String? approvedBy}) async {
    final index = _issues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      _issues[index].status = IssueStatus.active;
      _syncSeatsWithIssues();
      notifyListeners();
      await saveIssues();
    }
  }

  // Triagem: Rejeitar demanda (recusada)
  Future<void> rejectStagingIssue(String issueId, {String? reason}) async {
    final index = _issues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      _issues[index].status = IssueStatus.rejected;
      _issues[index].rejectionReason = reason;
      _syncSeatsWithIssues();
      notifyListeners();
      await saveIssues();
    }
  }

  // Finalizar manutenção
  Future<void> resolveIssue(String issueId, {String? resolvedBy}) async {
    final index = _issues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      _issues[index].status = IssueStatus.resolved;
      _issues[index].resolvedAt = DateTime.now();
      _issues[index].resolvedBy = resolvedBy;
      _syncSeatsWithIssues();
      notifyListeners();
      await saveIssues();
    }
  }

  // Reabrir manutenção
  Future<void> reopenIssue(String issueId) async {
    final index = _issues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      _issues[index].status = IssueStatus.active;
      _issues[index].resolvedAt = null;
      _issues[index].resolvedBy = null;
      _syncSeatsWithIssues();
      notifyListeners();
      await saveIssues();
    }
  }

  // Excluir registro
  Future<void> deleteIssue(String issueId) async {
    _issues.removeWhere((i) => i.id == issueId);
    _syncSeatsWithIssues();
    notifyListeners();
    await saveIssues();
  }

  Future<void> saveIssues() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _issues.map((i) => i.toJson()).toList();
    await prefs.setString('maintenance_issues', json.encode(jsonList));
  }

  Future<void> loadIssues() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('maintenance_issues');

    if (jsonString != null) {
      try {
        final List<dynamic> decoded = json.decode(jsonString);
        _issues = decoded.map((issue) => MaintenanceIssue.fromJson(issue)).toList();
      } catch (e) {
        debugPrint('Erro ao carregar histórico de manutenção: $e');
      }
    }
  }

  List<MaintenanceIssue> getIssuesByRoom(String roomId, {bool onlyActive = false}) {
    return _issues
        .where((i) => i.roomId == roomId && (!onlyActive || i.isActive))
        .toList();
  }

  List<MaintenanceIssue> getStagingIssues() {
    return _issues.where((i) => i.isStaging).toList();
  }

  List<MaintenanceIssue> getIssuesBySeat(String roomId, String seatId, {bool onlyActive = true}) {
    return _issues
        .where((i) =>
            i.roomId == roomId &&
            i.seatId == seatId &&
            (!onlyActive || i.isActive || i.isStaging))
        .toList();
  }

  Seat? getSeat(String row, int number) {
    if (selectRoom == null) return null;
    return selectRoom!.getSeat(row, number);
  }
}
