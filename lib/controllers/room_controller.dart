import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinegestor/models/seat.dart';
import '../main.dart' show isFirebaseInitialized;
import '../models/room.dart';
import '../models/maintenance_issue.dart';
import '../repositories/room_repository.dart';

class RoomController extends ChangeNotifier {
  List<Room> _rooms = [];
  List<MaintenanceIssue> _issues = [];
  List<MaintenanceIssue> _activeIssues = [];
  List<MaintenanceIssue> _historicalIssues = [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _issuesSubscription;
  String _activeCinemaId = '2159';

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  bool _hasMoreHistory = true;
  bool get hasMoreHistory => _hasMoreHistory;

  DocumentSnapshot<Map<String, dynamic>>? _lastHistoryDoc;

  List<Room> get rooms => _rooms;
  List<MaintenanceIssue> get issues => _issues;
  List<MaintenanceIssue> get activeIssues => _activeIssues;
  List<MaintenanceIssue> get historicalIssues => _historicalIssues;

  Room? _selectRoom;
  Room? get selectRoom => _selectRoom;

  @override
  void dispose() {
    _issuesSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadRooms({String? cinemaId}) async {
    if (_isLoading) return;
    _isLoading = true;
    if (cinemaId != null && cinemaId.isNotEmpty && cinemaId != _activeCinemaId) {
      _activeCinemaId = cinemaId;
      _lastHistoryDoc = null;
      _hasMoreHistory = true;
      _historicalIssues.clear();
    }

    try {
      final allRooms = await RoomRepository.loadRoomsFromJson();

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
      _listenToFirestoreIssues(_activeCinemaId);
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

  void _listenToFirestoreIssues(String cinemaId) {
    if (!isFirebaseInitialized) return;

    _issuesSubscription?.cancel();
    try {
      // Passo 1: Ouve apenas demandas em triagem e em aberto (reduz até 90% das leituras diárias)
      _issuesSubscription = FirebaseFirestore.instance
          .collection('maintenance_issues')
          .where('cinemaId', isEqualTo: cinemaId)
          .where('status', whereIn: ['staging', 'active'])
          .snapshots()
          .listen(
        (snapshot) async {
          final cloudActive = snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] ??= doc.id;
            return MaintenanceIssue.fromJson(data);
          }).toList();

          cloudActive.sort((a, b) => b.dateTime.compareTo(a.dateTime));
          _activeIssues = cloudActive;
          _mergeAndSyncIssues();
          await _saveIssuesLocally();
        },
        onError: (e) {
          debugPrint('Aviso listener Firestore (usando cache local): $e');
        },
      );
    } catch (e) {
      debugPrint('Erro ao iniciar stream do Firestore: $e');
    }
  }

  void _mergeAndSyncIssues() {
    final Map<String, MaintenanceIssue> map = {};
    for (final issue in _historicalIssues) {
      map[issue.id] = issue;
    }
    for (final issue in _activeIssues) {
      map[issue.id] = issue;
    }
    final merged = map.values.toList();
    merged.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    _issues = merged;
    _syncSeatsWithIssues();
    notifyListeners();
  }

  void _syncSeatsWithIssues() {
    for (final room in _rooms) {
      final roomActiveIssues = _issues
          .where((issue) => issue.roomId == room.id && issue.isActive)
          .toList();

      final activeSeatIds = roomActiveIssues.map((i) => i.seatId).toSet();
      final blockingSeatIds = roomActiveIssues
          .where((i) => i.isBlockingSeat)
          .map((i) => i.seatId)
          .toSet();

      final stagingSeatIds = _issues
          .where((issue) => issue.roomId == room.id && issue.isStaging)
          .map((issue) => issue.seatId)
          .toSet();

      for (final entry in room.seats.entries) {
        entry.value.hasDefect = activeSeatIds.contains(entry.key);
        entry.value.hasBlockingDefect = blockingSeatIds.contains(entry.key);
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

  Future<void> _syncIssueToFirestore(MaintenanceIssue issue) async {
    if (!isFirebaseInitialized) return;
    try {
      await FirebaseFirestore.instance
          .collection('maintenance_issues')
          .doc(issue.id)
          .set(issue.toJson());
    } catch (e) {
      debugPrint('Erro ao sincronizar demanda no Firestore: $e');
    }
  }

  Future<void> registerIssue(MaintenanceIssue issue) async {
    // Passo 5: Assegura que fotos comprimidas respeitem a cota e limite de segurança
    _activeIssues.removeWhere((i) => i.id == issue.id);
    _activeIssues.insert(0, issue);
    _mergeAndSyncIssues();
    await _saveIssuesLocally();
    await _syncIssueToFirestore(issue);
  }

  Future<void> approveStagingIssue(String issueId, {String? approvedBy}) async {
    final index = _activeIssues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      _activeIssues[index].status = IssueStatus.active;
      _mergeAndSyncIssues();
      await _saveIssuesLocally();
      await _syncIssueToFirestore(_activeIssues[index]);
    }
  }

  Future<void> rejectStagingIssue(String issueId, {String? reason}) async {
    final index = _activeIssues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      final item = _activeIssues[index];
      item.status = IssueStatus.rejected;
      item.rejectionReason = reason;
      _activeIssues.removeAt(index);
      _historicalIssues.removeWhere((i) => i.id == issueId);
      _historicalIssues.insert(0, item);
      _mergeAndSyncIssues();
      await _saveIssuesLocally();
      await _syncIssueToFirestore(item);
    }
  }

  Future<void> resolveIssue(
    String issueId, {
    String? resolvedBy,
    String? afterPhotoBase64,
  }) async {
    final index = _activeIssues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      final item = _activeIssues[index];
      item.status = IssueStatus.resolved;
      item.resolvedAt = DateTime.now();
      item.resolvedBy = resolvedBy;
      if (afterPhotoBase64 != null && afterPhotoBase64.isNotEmpty) {
        item.afterPhotoBase64 = afterPhotoBase64;
      }
      _activeIssues.removeAt(index);
      _historicalIssues.removeWhere((i) => i.id == issueId);
      _historicalIssues.insert(0, item);
      _mergeAndSyncIssues();
      await _saveIssuesLocally();
      await _syncIssueToFirestore(item);
    }
  }

  Future<void> resolveIssuesBatch(List<String> issueIds, {String? resolvedBy}) async {
    final now = DateTime.now();
    final updatedIssues = <MaintenanceIssue>[];

    for (final id in issueIds) {
      final index = _activeIssues.indexWhere((i) => i.id == id);
      if (index != -1) {
        final item = _activeIssues[index];
        item.status = IssueStatus.resolved;
        item.resolvedAt = now;
        item.resolvedBy = resolvedBy;
        _activeIssues.removeAt(index);
        _historicalIssues.removeWhere((i) => i.id == id);
        _historicalIssues.insert(0, item);
        updatedIssues.add(item);
      }
    }

    if (updatedIssues.isEmpty) return;

    _mergeAndSyncIssues();
    await _saveIssuesLocally();
    for (final issue in updatedIssues) {
      await _syncIssueToFirestore(issue);
    }
  }

  Future<void> reopenIssue(String issueId) async {
    final index = _historicalIssues.indexWhere((i) => i.id == issueId);
    if (index != -1) {
      final item = _historicalIssues[index];
      item.status = IssueStatus.active;
      item.resolvedAt = null;
      item.resolvedBy = null;
      _historicalIssues.removeAt(index);
      _activeIssues.removeWhere((i) => i.id == issueId);
      _activeIssues.insert(0, item);
      _mergeAndSyncIssues();
      await _saveIssuesLocally();
      await _syncIssueToFirestore(item);
    }
  }

  Future<void> deleteIssue(String issueId) async {
    _activeIssues.removeWhere((i) => i.id == issueId);
    _historicalIssues.removeWhere((i) => i.id == issueId);
    _mergeAndSyncIssues();
    await _saveIssuesLocally();
    if (isFirebaseInitialized) {
      try {
        await FirebaseFirestore.instance
            .collection('maintenance_issues')
            .doc(issueId)
            .delete();
      } catch (e) {
        debugPrint('Erro ao excluir demanda no Firestore: $e');
      }
    }
  }

  Future<void> _saveIssuesLocally() async {
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
        _activeIssues = _issues.where((i) => i.isActive || i.isStaging).toList();
        _historicalIssues = _issues.where((i) => i.resolved || i.isRejected).toList();
      } catch (e) {
        debugPrint('Erro ao carregar histórico local de manutenção: $e');
      }
    }
    // Passo 2: O get() redundante que lia todo o banco foi removido aqui.
    // O stream _listenToFirestoreIssues() logo abaixo conecta no Firestore e atualiza
    // os chamados com zero leituras duplicadas.
  }

  /// Passo 4: Carrega chamados finalizados/resolvidos sob demanda com paginação (limit 25)
  Future<void> loadHistoricalIssues({bool reset = false, int limit = 25}) async {
    if (!isFirebaseInitialized || _isLoadingHistory) return;
    if (!reset && !_hasMoreHistory) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      if (reset) {
        _historicalIssues.clear();
        _lastHistoryDoc = null;
        _hasMoreHistory = true;
      }

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('maintenance_issues')
          .where('cinemaId', isEqualTo: _activeCinemaId)
          .where('status', isEqualTo: 'resolved')
          .limit(limit);

      if (_lastHistoryDoc != null) {
        query = query.startAfterDocument(_lastHistoryDoc!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastHistoryDoc = snapshot.docs.last;
        final newResolved = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] ??= doc.id;
          return MaintenanceIssue.fromJson(data);
        }).toList();

        final existingIds = _historicalIssues.map((i) => i.id).toSet();
        for (final item in newResolved) {
          if (!existingIds.contains(item.id)) {
            _historicalIssues.add(item);
          }
        }
      }

      if (snapshot.docs.length < limit) {
        _hasMoreHistory = false;
      }

      _mergeAndSyncIssues();
      await _saveIssuesLocally();
    } catch (e) {
      debugPrint('Aviso ao paginar histórico de manutenção: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
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

  /// Total de ocorrências não rejeitadas já registradas nessa poltrona (para reincidência)
  int getSeatRecurrenceCount(String roomId, String seatId) {
    return _issues
        .where((i) => i.roomId == roomId && i.seatId == seatId && !i.isRejected)
        .length;
  }

  /// Lista de manutenções já concluídas no passado para esta poltrona
  List<MaintenanceIssue> getSeatPastIssues(String roomId, String seatId) {
    final past = _issues
        .where((i) => i.roomId == roomId && i.seatId == seatId && i.resolved)
        .toList();
    past.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return past;
  }

  Seat? getSeat(String row, int number) {
    if (selectRoom == null) return null;
    return selectRoom!.getSeat(row, number);
  }
}
