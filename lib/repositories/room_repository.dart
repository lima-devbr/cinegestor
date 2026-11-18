import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/room.dart';

class RoomRepository {
  static const List<String> _defaultUciRooms = [
    'assets/cinemas/uci_park_campo_grande/sala_1.json',
    'assets/cinemas/uci_park_campo_grande/sala_2.json',
    'assets/cinemas/uci_park_campo_grande/sala_3.json',
    'assets/cinemas/uci_park_campo_grande/sala_4.json',
    'assets/cinemas/uci_park_campo_grande/sala_5.json',
    'assets/cinemas/uci_park_campo_grande/sala_6.json',
    'assets/cinemas/uci_park_campo_grande/sala_7.json',
    'assets/cinemas/uci_new_york_city_center/sala_1.json',
  ];

  static Future<List<Room>> loadRoomsFromJson() async {
    final Map<String, Room> roomsById = {};

    try {
      // 1. Descobre automaticamente todos os JSONs dentro de assets/cinemas/
      List<String> cinemaAssets = [];
      try {
        final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        cinemaAssets = assetManifest
            .listAssets()
            .where((path) => path.startsWith('assets/cinemas/') && path.endsWith('.json'))
            .toList()
          ..sort();
      } catch (_) {}

      if (cinemaAssets.isEmpty) {
        cinemaAssets = _defaultUciRooms;
      } else {
        for (final path in _defaultUciRooms) {
          if (!cinemaAssets.contains(path)) {
            cinemaAssets.add(path);
          }
        }
      }

      for (final assetPath in cinemaAssets) {
        try {
          final roomJsonStr = await rootBundle.loadString(assetPath);
          final Map<String, dynamic> roomMap = json.decode(roomJsonStr);
          final room = Room.fromJson(roomMap);
          roomsById['${room.theaterId ?? ""}_${room.id}'] = room;
        } catch (_) {}
      }

      final rooms = roomsById.values.toList();
      rooms.sort((a, b) {
        final aNum = int.tryParse(a.id) ?? 999;
        final bNum = int.tryParse(b.id) ?? 999;
        return aNum.compareTo(bNum);
      });
      return rooms;
    } catch (e) {
      throw Exception('Erro ao carregar salas: $e');
    }
  }
}
