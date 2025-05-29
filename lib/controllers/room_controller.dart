import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinegestor/models/seat.dart';
import '../models/room.dart';
import '../models/maintenance_issue.dart';

class RoomController extends ChangeNotifier {
  List<Room> _rooms = [];
  List<MaintenanceIssue> _issues = [];

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Room> get rooms => _rooms;
  List<MaintenanceIssue> get issues => _issues;

  Room? _selectRoom;
  Room? get selectRoom => _selectRoom;

  Future<void> loadRooms() async {
    _isLoading = true;
    notifyListeners();

    try {
      final jsonString = await rootBundle.loadString('assets/salas.json');
      final Map<String, dynamic> data = json.decode(jsonString);
      _rooms =
          (data['salas'] as List).map((sala) => Room.fromJson(sala)).toList();
      
      // Inicializa os assentos para cada sala
      for (var room in _rooms) {
        for (var row in room.rows) {
          final cols = room.colsByRow[row] ?? room.colsDefault;
          for (var col = 1; col <= cols; col++) {
            final seatId = '$row$col';
            if (!room.excecoes.containsKey(seatId)) {
              room.seats[seatId] = Seat(row: row, number: col);
            }
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar salas.json: $e');
    }

    await loadIssues();

    _isLoading = false;
    notifyListeners();
  }

  void selectRoomById(String roomId) {
    _selectRoom = _rooms.firstWhere(
      (room) => room.id == roomId,
      orElse: () => throw Exception('Room not found'),
    );
    notifyListeners();
  }

  Future<void> registerIssue(MaintenanceIssue issue) async {
    _issues.add(issue);
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
        _issues =
            decoded.map((issue) => MaintenanceIssue.fromJson(issue)).toList();
      } catch (e) {
        print('Erro ao carregar histórico de manutenção: $e');
      }
    }
  }

  List<MaintenanceIssue> getIssuesByRoom(String roomId) {
    return _issues.where((i) => i.roomId == roomId).toList();
  }

  Seat? getSeat(String row, int number) {
    if (selectRoom == null) return null;
    return selectRoom!.getSeat(row, number);
  }

  void toggleSeatDefect(String row, int number) {
    final seat = getSeat(row, number);
    if (seat != null) {
      seat.hasDefect = !seat.hasDefect;
      notifyListeners();
    }
  }
}
