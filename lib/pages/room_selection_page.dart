import 'package:flutter/material.dart';
import '../controllers/room_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/room.dart';
import 'package:provider/provider.dart';
import '../utils/responsive_utils.dart';

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

  Widget _buildRoomGrid(List<Room> rooms) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveValue(
          mobile: 1,
          tablet: 2,
          desktop: 3,
        ).getValue(context),
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _buildRoomCard(room);
      },
    );
  }

  Widget _buildRoomCard(Room room) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => _onRoomTap(room),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.nome,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Capacidade: ${room.totalSeats} lugares',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _onRoomTap(room),
                    child: const Text('Gerenciar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seleção de Sala')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seleção de Sala')),
        body: Center(child: Text(_error!)),
      );
    }

    final rooms = widget.roomController.rooms;
    final authController = Provider.of<AuthController>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleção de Sala'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
              const PopupMenuItem(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Histórico'),
                ),
              ),
              const PopupMenuItem(
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
      body: ResponsiveBuilder(
        mobile: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                leading: Icon(Icons.meeting_room, color: Theme.of(context).colorScheme.primary),
                title: Text(
                  'Sala ${room.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${room.totalSeats} assentos'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _onRoomTap(room),
              ),
            );
          },
        ),
        tablet: _buildRoomGrid(rooms),
        desktop: _buildRoomGrid(rooms),
      ),
    );
  }
}




