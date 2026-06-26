import 'package:confetti/confetti.dart';
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
/// Client-side only — no backend event. The BudgetMeter calls
/// `PawtfolioConfetti.of(context)?.celebrate()` when it reaches 100%.
class PawtfolioConfetti extends StatefulWidget {
  const PawtfolioConfetti({required this.child, super.key});

  final Widget child;

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
  void celebrate() {
    if (_controller.state != ConfettiControllerState.playing) {
      _controller.play();
    }
  }

  @override
  void dispose() {
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
