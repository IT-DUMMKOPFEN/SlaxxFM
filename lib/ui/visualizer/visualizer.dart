import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n.dart';
import '../../services/audio_analyzer.dart';
import '../../services/player_service.dart';
import '../../services/settings.dart';
import '../brand.dart';
import 'dancers.dart';
import 'effects.dart';

String effectName(String id) => tr('fx_$id');

/// Sound visualizer: click / tap switches to the next effect.
class Visualizer extends StatefulWidget {
  final double radius;
  const Visualizer({super.key, this.radius = 20});

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  final Map<String, VisEffect> _effects = {};
  final Dancers _dancers = Dancers();
  bool _showLabel = false;
  Timer? _labelTimer;
  int _idleSkip = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    analyzer.tick();
    // idle (nothing playing, everything faded): ~15 fps is enough
    if (!player.active && analyzer.level < .01) {
      if (++_idleSkip % 4 != 0) return;
    }
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _labelTimer?.cancel();
    _frame.dispose();
    super.dispose();
  }

  void _next() {
    settings.nextEffect();
    setState(() => _showLabel = true);
    _labelTimer?.cancel();
    _labelTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showLabel = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final enabled = settings.enabledEffects;
        final showDancers = settings.dancers;
        if (enabled.isEmpty && !showDancers) return const SizedBox.shrink();
        var id = settings.currentEffect;
        if (!enabled.contains(id)) id = enabled.isEmpty ? '' : enabled.first;
        final effect =
            id.isEmpty ? null : _effects.putIfAbsent(id, () => createEffect(id));
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: MouseRegion(
            cursor: enabled.length > 1
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled.length > 1 ? _next : null,
              child: Stack(fit: StackFit.expand, children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF040A15), kBrandNavy],
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _VisPainter(
                        effect, showDancers ? _dancers : null, _frame),
                  ),
                ),
                // effect name after a click
                Positioned(
                  left: 12,
                  top: 10,
                  child: AnimatedOpacity(
                    opacity: _showLabel ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: _Chip(text: id.isEmpty ? '' : effectName(id)),
                  ),
                ),
                // BPM / source
                Positioned(
                  right: 10,
                  top: 10,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (context, f, __) {
                      if (!player.active) return const SizedBox.shrink();
                      final music = analyzer.music > .5;
                      final measured = analyzer.bpmMeasured;
                      return _Chip(
                        text: music
                            ? '♪ ${analyzer.bpm.round()} BPM${measured ? '' : ' ~'}'
                            : tr('speech'),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBrandSky.withValues(alpha: .35)),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _VisPainter extends CustomPainter {
  final VisEffect? effect;
  final Dancers? dancers;
  _VisPainter(this.effect, this.dancers, Listenable repaint)
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    effect?.paint(canvas, size, analyzer);
    dancers?.paint(canvas, size, analyzer);
  }

  @override
  bool shouldRepaint(covariant _VisPainter old) =>
      old.effect != effect || old.dancers != dancers;
}
