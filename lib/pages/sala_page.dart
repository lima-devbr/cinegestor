import 'dart:convert';
import 'package:cinegestor/widgets/chair_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/room_controller.dart';

class SalaPage extends StatefulWidget {
  final String nomeSala;

  const SalaPage({super.key, required this.nomeSala});

  @override
  State<SalaPage> createState() => _SalaPageState();
}

class _SalaPageState extends State<SalaPage> {
  Map<String, dynamic>? sala;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    const zoom = 0.3;
    final offsetX = 20.0;
    final offsetY = 20.0;
    _transformationController.value = Matrix4.identity()..translate(offsetX, offsetY)..scale(zoom);
    carregarSala();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> carregarSala() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/salas.json');
      final jsonData = json.decode(jsonStr);
      final listaSalas = jsonData['salas'] as List<dynamic>;

      final salaSelecionada = listaSalas.firstWhere(
        (s) => s['nome'] == widget.nomeSala,
        orElse: () => null,
      );

      if (mounted && salaSelecionada != null) {
        setState(() {
          sala = salaSelecionada;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          sala = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sala == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.nomeSala, style: theme.appBarTheme.titleTextStyle),
        ),
        body: Center(
          child: sala == null
              ? const CircularProgressIndicator()
              : Text(
                  'Error loading room data',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
        ),
      );
    }

    final rows = List<String>.from(sala!['rows']);
    final colsDefault = sala!['colsDefault'] as int;
    final colsByRow = Map<String, dynamic>.from(sala!['colsByRow']);
    final excecoes = Map<String, dynamic>.from(sala!['excecoes']);
    final spacingBetweenRows = Map<String, dynamic>.from(
      sala!['spacingBetweenRows'],
    );
    final aislesByRow = Map<String, dynamic>.from(sala!['aislesByRow']);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.nomeSala} - Seating')),
      body: Consumer<RoomController>(
        builder: (context, roomController, child) {
          return Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100.0),
              minScale: 0.1,
              maxScale: 3.0,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: rows.map((row) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: (spacingBetweenRows[row] ?? 8).toDouble(),
                              ),
                              child: SizedBox(
                                height: 38,
                                width: 30,
                                child: Center(
                                  child: Text(
                                    row,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        Column(
                          children: rows.map((row) {
                            final cols = colsByRow[row] ?? colsDefault;
                            final aisleCols = aislesByRow[row]?.cast<int>() ?? [];
                            int currentCol = 1;
                            final List<Widget> seatWidgets = [];

                            while (currentCol <= cols) {
                              if (aisleCols.contains(currentCol)) {
                                seatWidgets.add(
                                  const SizedBox(width: 30),
                                );
                                currentCol++;
                                continue;
                              }
                              final seatLabel = '$row$currentCol';
                              final seatType = excecoes[seatLabel];
                              final isObeso = seatType == 'cadeiraObeso';
                              seatWidgets.add(
                                SizedBox(
                                  width: isObeso ? 60 : 30,
                                  child: ChairWidget(
                                    label: seatLabel,
                                    tipo: seatType,
                                  ),
                                ),
                              );
                              currentCol += isObeso ? 2 : 1;
                            }

                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: (spacingBetweenRows[row] ?? 8).toDouble(),
                              ),
                              child: Row(children: seatWidgets),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 64,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'TELA',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 