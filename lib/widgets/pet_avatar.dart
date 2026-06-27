import 'package:flutter/material.dart';
import 'package:pawtfolio/theme.dart';
import 'package:pawtfolio/transport/ag_ui_config.dart';

/// The pet's photo, loaded from the backend ([kPetImageUrl]) — not bundled into
/// the app. Falls back to a paw emoji while loading or if the backend is
/// unreachable.
class PetAvatar extends StatelessWidget {
  const PetAvatar({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // onPrimary resolves to white for our teal primary — the correct on-color
    // whether the avatar sits on the teal header or the cream empty state.
    final ring = cs.onPrimary;
    final fallback = Center(
      child: Text('🐾', style: TextStyle(fontSize: size * PawSpacing.sm / 16)),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ring,
        border: Border.all(color: ring, width: 2),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: PawSpacing.xs + 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        kPetImageUrl,
        fit: BoxFit.cover,
        cacheWidth: (size * 4).round(),
        errorBuilder: (context, error, stack) => fallback,
        // Zoom in (the source photo has a lot of floor around the dog) so the
        // pet fills the circle. Scale only the loaded image, not the fallback.
        loadingBuilder: (context, child, progress) => progress == null
            ? Transform.scale(
                scale: 1.6,
                alignment: const Alignment(0, -0.1),
                child: child,
              )
            : fallback,
      ),
    );
  }
}
