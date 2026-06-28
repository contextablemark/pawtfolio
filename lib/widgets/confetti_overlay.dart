import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pawtfolio/theme.dart';

/// Public handle a descendant widget (e.g. BudgetMeter) can use to trigger the
/// celebration without depending on the private State type.
abstract class PawConfetti {
  /// Fires the confetti burst (debounced by the controller's play state).
  void celebrate();
}

/// Wraps the surface canvas and bursts paw-colored confetti on [celebrate].
///
/// Two triggers: the BudgetMeter calls `PawtfolioConfetti.of(context)?.
/// celebrate()` when it renders at 100% (a turn behind a fresh contribution),
/// and [trigger] fires immediately from the backend tool result the turn the
/// fund hits its goal. The controller debounces, so both firing is harmless.
class PawtfolioConfetti extends StatefulWidget {
  const PawtfolioConfetti({required this.child, this.trigger, super.key});

  final Widget child;

  /// Each change to this value fires the confetti burst. Wire it to the
  /// transport's `celebrate` signal for the same-turn celebration.
  final ValueListenable<int>? trigger;

  static PawConfetti? of(BuildContext context) =>
      context.findAncestorStateOfType<_PawtfolioConfettiState>();

  @override
  State<PawtfolioConfetti> createState() => _PawtfolioConfettiState();
}

class _PawtfolioConfettiState extends State<PawtfolioConfetti>
    implements PawConfetti {
  final ConfettiController _controller = ConfettiController(
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    widget.trigger?.addListener(celebrate);
  }

  @override
  void didUpdateWidget(covariant PawtfolioConfetti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger) {
      oldWidget.trigger?.removeListener(celebrate);
      widget.trigger?.addListener(celebrate);
    }
  }

  @override
  void celebrate() {
    if (_controller.state != ConfettiControllerState.playing) {
      _controller.play();
    }
  }

  @override
  void dispose() {
    widget.trigger?.removeListener(celebrate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 24,
            maxBlastForce: 22,
            minBlastForce: 8,
            gravity: 0.25,
            colors: const [pawTeal, pawOrange, pawMagenta, pawGreen],
          ),
        ),
      ],
    );
  }
}
