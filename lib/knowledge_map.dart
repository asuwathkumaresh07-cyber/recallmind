import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'domain.dart';

/// A perspective-projected concept graph built from the learner's actual cards.
class KnowledgeMap extends StatefulWidget {
  const KnowledgeMap({
    super.key,
    required this.cards,
    required this.onPractice,
  });
  final List<StudyCard> cards;
  final ValueChanged<StudyCard> onPractice;

  @override
  State<KnowledgeMap> createState() => _KnowledgeMapState();
}

class _KnowledgeMapState extends State<KnowledgeMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController rotation;
  double yaw = .35, pitch = -.2, zoom = 1;
  String? selectedId;
  bool spinning = false;

  @override
  void initState() {
    super.initState();
    rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Add a card to start your knowledge map.'),
        ),
      );
    }
    final selected = cards.firstWhere(
      (c) => c.id == selectedId,
      orElse: () => cards.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF102D28),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'YOUR KNOWLEDGE, CONNECTED',
                        style: TextStyle(
                          color: Color(0xFFBAE5D0),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: spinning
                          ? 'Pause rotation'
                          : 'Rotate automatically',
                      onPressed: () => setState(() {
                        spinning = !spinning;
                        if (spinning) {
                          rotation.repeat();
                        } else {
                          rotation.stop();
                        }
                      }),
                      icon: Icon(
                        spinning
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Reset view',
                      onPressed: () => setState(() {
                        rotation.stop();
                        rotation.value = 0;
                        spinning = false;
                        yaw = .35;
                        pitch = -.2;
                        zoom = 1;
                      }),
                      icon: const Icon(Icons.restart_alt, color: Colors.white),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 360,
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final size = Size(bounds.maxWidth, bounds.maxHeight);
                    final points = projectConcepts(
                      cards.length,
                      size,
                      yaw + rotation.value * math.pi * 2,
                      pitch,
                      zoom,
                    );
                    return Semantics(
                      label:
                          '3D knowledge map. Drag to rotate. Select a concept below to inspect or practice it.',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: GestureDetector(
                          onPanUpdate: (d) => setState(() {
                            yaw += d.delta.dx * .008;
                            pitch = (pitch + d.delta.dy * .008).clamp(
                              -1.3,
                              1.3,
                            );
                          }),
                          onTapUp: (d) {
                            final hits = List.generate(points.length, (i) => i)
                              ..sort(
                                (a, b) =>
                                    points[b].depth.compareTo(points[a].depth),
                              );
                            for (final i in hits) {
                              if ((points[i].position - d.localPosition)
                                      .distance <
                                  30) {
                                setState(() => selectedId = cards[i].id);
                                break;
                              }
                            }
                          },
                          child: CustomPaint(
                            key: const ValueKey('knowledge-graph'),
                            size: size,
                            painter: _ConceptPainter(
                              cards,
                              points,
                              selected.id,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.zoom_out, color: Colors.white70, size: 18),
                    Expanded(
                      child: Slider(
                        value: zoom,
                        min: .65,
                        max: 1.3,
                        semanticFormatterCallback: (v) =>
                            '${(v * 100).round()} percent zoom',
                        activeColor: const Color(0xFF98E4BB),
                        onChanged: (v) => setState(() => zoom = v),
                      ),
                    ),
                    const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Text(
                  'Drag to orbit · tap a node to explore\nArrows lead from a foundation to the concept it supports.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFBAD0C7),
                    fontSize: 11,
                    height: 1.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cards)
              ChoiceChip(
                label: Text(c.concept),
                selected: c.id == selected.id,
                onSelected: (_) => setState(() => selectedId = c.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE6EAE3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selected.deck.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: Color(0xFF287858),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                selected.concept,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(selected.question),
              const SizedBox(height: 16),
              Text(
                '${selected.repetitions} successful repetitions · ${selected.lapses} misses',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (selected.repetitions / 5).clamp(0, 1),
                color: const Color(0xFF287858),
                backgroundColor: const Color(0xFFE6EAE3),
              ),
              const SizedBox(height: 8),
              const Text(
                'Practice progress · 5 successful repetitions fill the bar',
                style: TextStyle(fontSize: 11, color: Color(0xFF7A827C)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => widget.onPractice(selected),
                icon: const Icon(Icons.school_outlined, size: 18),
                label: const Text('Practice this concept'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConceptPoint {
  const ConceptPoint(this.position, this.depth, this.scale);
  final Offset position;
  final double depth, scale;
}

List<ConceptPoint> projectConcepts(
  int count,
  Size size,
  double yaw,
  double pitch,
  double zoom,
) {
  return List.generate(count, (i) {
    final y = count == 1 ? 0.0 : 1 - 2 * (i + .5) / count;
    final ring = math.sqrt(1 - y * y);
    final angle = i * math.pi * (3 - math.sqrt(5));
    final x = math.cos(angle) * ring, z = math.sin(angle) * ring;
    final rx = x * math.cos(yaw) + z * math.sin(yaw);
    final rz = -x * math.sin(yaw) + z * math.cos(yaw);
    final ry = y * math.cos(pitch) - rz * math.sin(pitch);
    final depth = y * math.sin(pitch) + rz * math.cos(pitch);
    final scale = 3 / (3 - depth * .6);
    final radius = math.min(size.width * .32, size.height * .34) * zoom;
    return ConceptPoint(
      Offset(
        size.width / 2 + rx * radius * scale,
        size.height / 2 + ry * radius * scale,
      ),
      depth,
      scale,
    );
  });
}

class _ConceptPainter extends CustomPainter {
  _ConceptPainter(this.cards, this.points, this.selected);
  final List<StudyCard> cards;
  final List<ConceptPoint> points;
  final String selected;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 1; i <= 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: math.min(size.width * .8, 330) * i / 3,
          height: 270 * i / 3,
        ),
        Paint()
          ..color = const Color(0xFF22443A)
          ..style = PaintingStyle.stroke,
      );
    }
    final byConcept = <String, int>{
      for (var i = 0; i < cards.length; i++) cards[i].concept: i,
    };
    for (var i = 0; i < cards.length; i++) {
      for (final prerequisite in cards[i].prerequisites) {
        final j = byConcept[prerequisite];
        if (j == null) continue;
        final from = points[j].position, to = points[i].position;
        final highlighted = cards[i].id == selected || cards[j].id == selected;
        final paint = Paint()
          ..color = highlighted
              ? const Color(0xFFA9EAC7)
              : const Color(0xFF4B7766)
          ..strokeWidth = highlighted ? 2 : 1;
        canvas.drawLine(from, to, paint);
        final delta = to - from;
        final length = delta.distance;
        if (length > 45) {
          final unit = delta / length;
          final tip = to - unit * 22;
          final normal = Offset(-unit.dy, unit.dx);
          canvas.drawLine(tip, tip - unit * 8 + normal * 4, paint);
          canvas.drawLine(tip, tip - unit * 8 - normal * 4, paint);
        }
      }
    }
    final order = List.generate(cards.length, (i) => i)
      ..sort((a, b) => points[a].depth.compareTo(points[b].depth));
    for (final i in order) {
      final p = points[i];
      final active = cards[i].id == selected;
      final color = cards[i].lapses > cards[i].repetitions
          ? const Color(0xFFFFC98A)
          : cards[i].repetitions >= 5
          ? const Color(0xFF7CE2AC)
          : const Color(0xFF9BBDB5);
      final radius = (active ? 17.0 : 12.0) * p.scale;
      canvas.drawCircle(
        p.position,
        radius + 10,
        Paint()..color = color.withValues(alpha: active ? .16 : .06),
      );
      canvas.drawCircle(
        p.position,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.4, -.5),
            colors: [Colors.white, color, color.withValues(alpha: .65)],
          ).createShader(Rect.fromCircle(center: p.position, radius: radius)),
      );
      if (active) {
        canvas.drawCircle(
          p.position,
          radius + 5,
          Paint()
            ..color = const Color(0xFFD1F5DF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      final label = TextPainter(
        text: TextSpan(
          text: cards[i].concept,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFFCCE0D5),
            fontSize: active ? 12 : 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        maxLines: 2,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.min(125, size.width - 16));
      final left = (p.position.dx - label.width / 2).clamp(
        8.0,
        math.max(8.0, size.width - label.width - 8),
      );
      label.paint(canvas, Offset(left.toDouble(), p.position.dy + radius + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _ConceptPainter oldDelegate) => true;
}
