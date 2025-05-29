import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/room.dart';

class RoomRepository {
  static Future<List<Room>> loadRoomsFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/salas.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final List<dynamic> roomsJson = jsonMap['salas'];

      return roomsJson.map((e) => Room.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Erro ao carregar salas.json: $e');
    }
  }
}
