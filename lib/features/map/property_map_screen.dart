import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/property_art.dart';
import '../../models/property.dart';
import '../search/property_detail_screen.dart';

class PropertyMapScreen extends StatefulWidget {
  const PropertyMapScreen({super.key});

  @override
  State<PropertyMapScreen> createState() => _PropertyMapScreenState();
}

class _PropertyMapScreenState extends State<PropertyMapScreen> {
  String? selectedPropertyId;
  String selectedAreaId = 'all';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final properties = state.properties
        .where(
          (property) =>
              selectedAreaId == 'all' || property.areaId == selectedAreaId,
        )
        .toList();
    final selected = selectedPropertyId == null
        ? (properties.isEmpty ? null : properties.first)
        : state.properties.firstWhere(
            (property) => property.id == selectedPropertyId,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map & nearby facilities'),
        actions: [
          IconButton(
            onPressed: () => _showMapInfo(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final map = _MapCanvas(
            properties: properties,
            selectedPropertyId: selected?.id,
            onSelect: (id) => setState(() => selectedPropertyId = id),
          );
          final panel = _LocationPanel(property: selected);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedAreaId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                    labelText: 'Explore area',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All sample areas'),
                    ),
                    ...state.areas.map(
                      (area) => DropdownMenuItem(
                        value: area.id,
                        child: Text('${area.name}, ${area.state}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    selectedAreaId = value ?? 'all';
                    selectedPropertyId = null;
                  }),
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(flex: 7, child: map),
                          SizedBox(width: 360, child: panel),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned.fill(child: map),
                          if (selected != null)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: 0.46,
                                widthFactor: 1,
                                child: panel,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMapInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Map preview'),
        content: const Text(
          'This offline map visual keeps the assessment reliable. Connect Google Maps or OpenStreetMap tiles and replace the normalized pin layout for live deployment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _MapCanvas extends StatelessWidget {
  const _MapCanvas({
    required this.properties,
    required this.selectedPropertyId,
    required this.onSelect,
  });

  final List<Property> properties;
  final String? selectedPropertyId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _MapPainter())),
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  children: [
                    _MapControl(icon: Icons.add_rounded, onTap: () {}),
                    const SizedBox(height: 6),
                    _MapControl(icon: Icons.remove_rounded, onTap: () {}),
                    const SizedBox(height: 12),
                    _MapControl(icon: Icons.my_location_rounded, onTap: () {}),
                  ],
                ),
              ),
              ...List.generate(properties.length, (index) {
                final property = properties[index];
                final pin = _pinPosition(property, properties);
                final selected = property.id == selectedPropertyId;
                return Positioned(
                  left: constraints.maxWidth * pin.x - 32,
                  top: constraints.maxHeight * pin.y - 22,
                  child: GestureDetector(
                    onTap: () => onSelect(property.id),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      scale: selected ? 1.12 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.navy : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          formatRinggit(property.price, compact: true),
                          style: TextStyle(
                            color: selected ? Colors.white : AppTheme.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              Positioned(
                left: 15,
                bottom: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Offline normalized map - Sample',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _PinPosition _pinPosition(Property property, List<Property> properties) {
    final minLat = properties
        .map((property) => property.latitude)
        .reduce(math.min);
    final maxLat = properties
        .map((property) => property.latitude)
        .reduce(math.max);
    final minLng = properties
        .map((property) => property.longitude)
        .reduce(math.min);
    final maxLng = properties
        .map((property) => property.longitude)
        .reduce(math.max);
    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    final normalizedX = lngRange == 0
        ? 0.5
        : (property.longitude - minLng) / lngRange;
    final normalizedY = latRange == 0
        ? 0.5
        : (maxLat - property.latitude) / latRange;
    return _PinPosition(
      x: (0.08 + normalizedX * 0.84).clamp(0.08, 0.92).toDouble(),
      y: (0.10 + normalizedY * 0.78).clamp(0.10, 0.88).toDouble(),
    );
  }
}

class _PinPosition {
  const _PinPosition({required this.x, required this.y});

  final double x;
  final double y;
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({required this.property});

  final Property? property;

  @override
  Widget build(BuildContext context) {
    if (property == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: Text('No properties in this area.')),
      );
    }
    final state = AppScope.of(context);
    final area = state.areaFor(property!.areaId);
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DDE8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PropertyArt(palette: property!.palette, height: 132),
            const SizedBox(height: 14),
            Text(property!.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              property!.address,
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
            Text(
              formatRinggit(property!.price),
              style: const TextStyle(
                color: AppTheme.green,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Area insights',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniInsight(
                    label: 'Safety',
                    value: '${area.safetyScore.round()}/100',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInsight(
                    label: 'Transit',
                    value: '${area.transportScore.round()}/100',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniInsight(
                    label: 'Schools',
                    value: '${area.schools}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInsight(
                    label: 'Hospitals',
                    value: '${area.hospitals}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: property!.facilities
                  .map(
                    (item) => Chip(
                      label: Text(item, style: const TextStyle(fontSize: 10)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PropertyDetailScreen(propertyId: property!.id),
                  ),
                ),
                child: const Text('View property details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInsight extends StatelessWidget {
  const _MiniInsight({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(onPressed: onTap, icon: Icon(icon), iconSize: 20),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEAF2E8),
    );
    final blocks = Paint()..color = const Color(0xFFF7F4EA);
    final random = math.Random(7);
    for (var index = 0; index < 34; index++) {
      final left = random.nextDouble() * size.width;
      final top = random.nextDouble() * size.height;
      final width = 25 + random.nextDouble() * 75;
      final height = 18 + random.nextDouble() * 48;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          const Radius.circular(5),
        ),
        blocks,
      );
    }
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke;
    final roadEdge = Paint()
      ..color = const Color(0xFFD7E0E4)
      ..strokeWidth = 21
      ..style = PaintingStyle.stroke;
    final paths = [
      Path()
        ..moveTo(-20, size.height * 0.25)
        ..cubicTo(
          size.width * 0.25,
          size.height * 0.18,
          size.width * 0.55,
          size.height * 0.42,
          size.width + 20,
          size.height * 0.30,
        ),
      Path()
        ..moveTo(size.width * 0.18, -20)
        ..cubicTo(
          size.width * 0.28,
          size.height * 0.25,
          size.width * 0.15,
          size.height * 0.65,
          size.width * 0.36,
          size.height + 20,
        ),
      Path()
        ..moveTo(size.width * 0.73, -20)
        ..cubicTo(
          size.width * 0.58,
          size.height * 0.32,
          size.width * 0.86,
          size.height * 0.55,
          size.width * 0.76,
          size.height + 20,
        ),
    ];
    for (final path in paths) {
      canvas.drawPath(path, roadEdge);
      canvas.drawPath(path, road);
    }
    final water = Paint()..color = const Color(0xFFB9E0EE);
    final river = Path()
      ..moveTo(-10, size.height * 0.82)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.70,
        size.width * 0.58,
        size.height * 0.96,
        size.width + 10,
        size.height * 0.78,
      )
      ..lineTo(size.width + 10, size.height * 0.86)
      ..cubicTo(
        size.width * 0.58,
        size.height * 1.03,
        size.width * 0.25,
        size.height * 0.78,
        -10,
        size.height * 0.9,
      )
      ..close();
    canvas.drawPath(river, water);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
