import 'dart:convert';
import 'package:cinegestor/widgets/chair_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive_utils.dart';

class SalaPage extends StatefulWidget {
  final String nomeSala;

  const SalaPage({super.key, required this.nomeSala});

  @override
  State<SalaPage> createState() => _SalaPageState();
}

class _SalaPageState extends State<SalaPage> {
  Map<String, dynamic>? sala;
  final TransformationController _transformationController = TransformationController();
  final GlobalKey _seatLayoutKey = GlobalKey();
  double _currentZoom = 0.3;
  static const double _minZoom = 0.1;
  static const double _maxZoom = 3.0;

  @override
  void initState() {
    super.initState();
    carregarSala();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetZoom());
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    final RenderBox? renderBox = _seatLayoutKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Size roomSize = renderBox.size;
    final Size viewSize = MediaQuery.of(context).size;

    // Calcula o zoom necessário para caber a sala na tela
    final double scaleX = (viewSize.width * 0.9) / roomSize.width;
    final double scaleY = (viewSize.height * 0.85) / roomSize.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calcula a posição para centralizar horizontalmente e alinhar próximo ao topo
    final double xOffset = (viewSize.width - (roomSize.width * scale)) / 2;
    final double yOffset = viewSize.height * 0.05; // 5% da altura da tela como margem superior

    setState(() {
      _currentZoom = scale;
      _transformationController.value = Matrix4.identity()
        ..translate(xOffset, yOffset)
        ..scale(scale);
    });
  }

  void _updateZoom(double zoom) {
    setState(() {
      _currentZoom = zoom.clamp(_minZoom, _maxZoom);
      final matrix = _transformationController.value.clone();
      final scale = _currentZoom / (matrix.getMaxScaleOnAxis());
      matrix.scale(scale);
      _transformationController.value = matrix;
    });
  }

  Widget _buildZoomControls() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _updateZoom(_currentZoom + 0.1),
                tooltip: 'Aumentar zoom',
              ),
              Text(
                '${(_currentZoom * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: () => _updateZoom(_currentZoom - 0.1),
                tooltip: 'Diminuir zoom',
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _resetZoom,
                tooltip: 'Resetar zoom',
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildSeatingLayout(BuildContext context, ThemeData theme) {
    if (sala == null) return const SizedBox.shrink();

    final rows = List<String>.from(sala!['rows']);
    final colsDefault = sala!['colsDefault'] as int;
    final colsByRow = Map<String, dynamic>.from(sala!['colsByRow']);
    final excecoes = Map<String, dynamic>.from(sala!['excecoes']);
    final spacingBetweenRows = Map<String, dynamic>.from(sala!['spacingBetweenRows']);
    final aislesByRow = Map<String, dynamic>.from(sala!['aislesByRow']);

    return Container(
      key: _seatLayoutKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Tela no topo
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 48,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
          const SizedBox(height: 48), // Espaço maior após a tela
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Letras das fileiras
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
              // Assentos
              Column(
                children: rows.map((row) {
                  final cols = colsByRow[row] ?? colsDefault;
                  final aisleCols = aislesByRow[row]?.cast<int>() ?? [];
                  int currentCol = 1;
                  final List<Widget> seatWidgets = [];

                  while (currentCol <= cols) {
                    if (aisleCols.contains(currentCol)) {
                      seatWidgets.add(const SizedBox(width: 30));
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
        ],
      ),
    );
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

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.nomeSala} - Seating'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetZoom,
            tooltip: 'Resetar visualização',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D3748), Color(0xFF4A5568)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: EdgeInsets.all(
                ResponsiveValue(
                  mobile: 50.0,
                  tablet: 100.0,
                  desktop: 200.0,
                ).getValue(context),
              ),
              minScale: _minZoom,
              maxScale: _maxZoom,
              onInteractionEnd: (details) {
                setState(() {
                  _currentZoom = _transformationController.value.getMaxScaleOnAxis();
                });
              },
              child: _buildSeatingLayout(context, theme),
            ),
            _buildZoomControls(),
          ],
        ),
      ),
    );
  }
} 