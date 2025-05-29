import 'package:flutter/material.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/room.dart';
import 'package:provider/provider.dart';

class RoomSelectionPage extends StatefulWidget {
  final RoomController roomController;

  const RoomSelectionPage({super.key, required this.roomController});

  @override
  State<RoomSelectionPage> createState() => _RoomSelectionPageState();
}

class _RoomSelectionPageState extends State<RoomSelectionPage> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      await widget.roomController.loadRooms();
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar salas: $e';
      });
    }
  }

  void _onRoomTap(Room room) {
    Navigator.pushNamed(
      context, 
      '/maintenance',
      arguments: {
        'roomId': room.id,
        'room': room,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController = Provider.of<AuthController>(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Seleção de Sala')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Seleção de Sala')),
        body: Center(child: Text(_error!)),
      );
    }

    final rooms = widget.roomController.rooms;

    return Scaffold(
      appBar: AppBar(
        title: Text('Seleção de Sala'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'history':
                  Navigator.pushNamed(context, '/history');
                  break;
                case 'logout':
                  authController.logout(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Histórico'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sair'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return Card(
            margin: EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Icon(Icons.meeting_room, color: Theme.of(context).colorScheme.primary),
              title: Text(
                'Sala ${room.id}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${room.rows.length} fileiras'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _onRoomTap(room),
            ),
          );
        },
      ),
    );
  }
}




