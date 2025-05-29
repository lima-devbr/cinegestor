import 'dart:convert';
import 'package:cinegestor/widgets/chair_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    // Initialize zoom and offset for InteractiveViewer
    const zoom = 0.8; // Adjusted for better visibility
    final offsetX = 20.0;
    final offsetY = 20.0;
    _transformationController.value =
        Matrix4.identity()
          ..translate(offsetX, offsetY)
          ..scale(zoom);
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
          sala = null; // Trigger error UI
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    if (sala == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.nomeSala, style: theme.appBarTheme.titleTextStyle),
        ),
        body: Center(
          child:
              sala == null
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
      body: Container(
        color: theme.colorScheme.surface, // Use theme background
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(8),
            width: screenWidth * 0.95,
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 2,
              ),
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(100),
              constrained:false,
              minScale: 0.5,
              maxScale: 2.0,
              child: Column(
                children: [
                  // Seating layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Row labels (left)
                      Column(
                        children:
                            rows.map((row) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      (spacingBetweenRows[row] ?? 8).toDouble(),
                                ),
                                child: SizedBox(
                                  height: 38,
                                  width: 30,
                                  child: Center(
                                    child: Text(
                                      row,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      // Seats
                      Column(
                        children:
                            rows.map((row) {
                              final cols = colsByRow[row] ?? colsDefault;
                              final aisleCols =
                                  aislesByRow[row]?.cast<int>() ?? [];
                              int currentCol = 1;
                              final List<Widget> seatWidgets = [];

                              while (currentCol <= cols) {
                                if (aisleCols.contains(currentCol)) {
                                  seatWidgets.add(
                                    const SizedBox(width: 30),
                                  ); // Aisle
                                  currentCol++;
                                  continue;
                                }
                                final seatLabel = '$row$currentCol';
                                final seatType = excecoes[seatLabel];
                                final isObeso = seatType == 'cadeiraObeso';
                                seatWidgets.add(
                                  SizedBox(
                                    width:
                                        isObeso
                                            ? 60
                                            : 30, // Double width for obese
                                    child: ChairWidget(
                                      label: seatLabel,
                                      tipo: seatType,
                                    ),
                                  ),
                                );
                                currentCol +=
                                    isObeso ? 2 : 1; // Skip 2 columns for obese
                              }

                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      (spacingBetweenRows[row] ?? 8).toDouble(),
                                ),
                                child: Row(children: seatWidgets),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Screen indicator
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    child: Center(
                      child: Text(
                        'TELA',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppTheme {
  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: Colors.deepPurple,
      secondary: Colors.deepPurpleAccent,
      surface: Color(0xFF1E1E1E),
      error: Colors.redAccent,
    ),
    scaffoldBackgroundColor: Color(0xFF121212),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.deepPurpleAccent),
      ),
      labelStyle: TextStyle(color: Colors.white70),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    cardTheme: CardTheme(
      color: Color(0xFF2D2D2D),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

