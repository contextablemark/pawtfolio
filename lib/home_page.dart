import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:pawtfolio/conversation.dart';
import 'package:pawtfolio/theme.dart';
import 'package:pawtfolio/transport/ag_ui_config.dart';
import 'package:pawtfolio/widgets/widgets.dart';

/// The single screen: a header, the latest generated A2UI surface on a scrolling
/// canvas (with confetti overlay), and a chat input. Uses genui's [Conversation]
/// via [GenUiSession] — one updating surface, not a feed. The pet's name and
/// photo are owned by the backend, not hardcoded here.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final GenUiSession _session;
  final _textController = TextEditingController();
  StreamSubscription<ConversationEvent>? _eventsSub;
  String _petName = '';

  @override
  void initState() {
    super.initState();
    _session = GenUiSession();
    // Surface agent/transport failures the pipeline would otherwise swallow.
    _eventsSub = _session.events.listen((event) {
      if (event is ConversationError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request failed: ${event.error}')),
        );
      }
    });
    unawaited(_loadPetName());
  }

  /// Pet identity is owned by the backend; fetch the name token (don't hardcode
  /// it). A plain GET (not SSE), so the default web client is fine.
  Future<void> _loadPetName() async {
    try {
      final res = await http.get(Uri.parse(kPetInfoUrl));
      if (!mounted || res.statusCode != 200) return;
      final name = (jsonDecode(res.body) as Map<String, dynamic>)['name'];
      if (name is String && name.isNotEmpty) {
        setState(() => _petName = name);
      }
    } catch (_) {
      // Keep the neutral fallback if the backend isn't reachable yet.
    }
  }

  @override
  void dispose() {
    unawaited(_eventsSub?.cancel());
    _textController.dispose();
    _session.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _session.sendMessage(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ValueListenableBuilder<ConversationState>(
          valueListenable: _session.conversationState,
          builder: (context, state, _) {
            final isProcessing = state.isWaiting;
            final latest = state.surfaces.isNotEmpty
                ? state.surfaces.last
                : null;
            return Column(
              children: [
                _AppHeader(petName: _petName),
                Expanded(
                  child: PawtfolioConfetti(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: latest == null
                              ? _EmptyState(petName: _petName)
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.only(
                                    left: PawSpacing.md,
                                    top: PawSpacing.sm,
                                    right: PawSpacing.md,
                                    bottom: PawSpacing.md,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 560,
                                      ),
                                      child: Surface(
                                        surfaceContext: _session.contextFor(
                                          latest,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        if (isProcessing)
                          const Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: SizedBox(
                                width: 240,
                                child: LinearProgressIndicator(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                MessageInput(
                  controller: _textController,
                  isProcessing: isProcessing,
                  onSend: _send,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subtitle = petName.isEmpty
        ? 'Pet finance advisor'
        : "$petName's finance advisor";
    return Container(
      width: double.infinity,
      color: cs.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: PawSpacing.md,
      ),
      child: Row(
        children: [
          const PetAvatar(size: 46),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PAWTFOLIO',
                style: t.titleLarge?.copyWith(
                  color: cs.onPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                subtitle,
                style: t.bodySmall?.copyWith(
                  color: cs.onPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.petName});

  final String petName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final who = petName.isEmpty ? 'your pet' : petName;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PawSpacing.xxl - 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PetAvatar(size: 110),
            const SizedBox(height: 12),
            Text(
              "Ask about $who's spending",
              style: t.titleMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: PawSpacing.xs + 2),
            Text(
              '"How much am I spending on $who?"  ·  "Break down food costs"  ·  '
              '"Show my spending trend"  ·  "Am I ready for an emergency?"',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
