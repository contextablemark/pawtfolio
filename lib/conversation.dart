import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:pawtfolio/catalog.dart';
import 'package:pawtfolio/transport/ag_ui_transport.dart';

/// Owns the GenUI pipeline for a single screen and disposes it as a unit.
///
/// Ties together the GenUI [SurfaceController] (which renders), the
/// [AgUiTransport] (which runs an AG-UI agent backend and turns the A2UI it
/// emits into [A2uiMessage]s), and the [Conversation] that combines them. These
/// have independent lifecycles, so this holder builds and tears everything down
/// with a single call instead of the UI juggling three disposables.
class GenUiSession {
  /// Creates the pipeline, optionally overriding the agent backend [baseUrl].
  GenUiSession({String? baseUrl}) {
    // The catalog defines the widgets the agent may use: it both renders
    // surfaces and is injected into the agent run so the agent knows the
    // vocabulary it can emit.
    final catalog = buildCatalog();

    // The controller renders surfaces from the catalog and tracks which ones
    // currently exist.
    _controller = SurfaceController(catalogs: [catalog]);

    // The transport runs the AG-UI agent and feeds the A2UI operations it
    // returns back to the controller as parsed messages.
    _transport = AgUiTransport(catalog: catalog, baseUrl: baseUrl);

    // The conversation ties the controller and transport together and exposes
    // the combined state (active surfaces, waiting status) the UI listens to.
    _conversation = Conversation(
      controller: _controller,
      transport: _transport,
    );
  }

  late final SurfaceController _controller;
  late final AgUiTransport _transport;
  late final Conversation _conversation;

  /// The raw A2UI JSON of the current (or most recent) agent turn, updated as
  /// the run streams in.
  ValueListenable<String> get a2uiSource => _transport.a2uiSource;

  /// Ticks when the emergency fund reaches its goal, so the UI can celebrate in
  /// the same turn the contribution lands (the BudgetMeter render lags a turn).
  ValueListenable<int> get celebrate => _transport.celebrate;

  /// The current state of the conversation, including active surfaces and
  /// waiting status.
  ValueListenable<ConversationState> get conversationState =>
      _conversation.state;

  /// A stream of conversation events (surface changes, content, errors).
  Stream<ConversationEvent> get events => _conversation.events;

  /// Sends a user message to the agent and starts the conversation.
  void sendMessage(String text) =>
      _conversation.sendRequest(ChatMessage.user(text));

  /// Looks up the render context for a surface by its id.
  ///
  /// Pass the result to a [Surface] widget to render that surface. Surface ids
  /// come from [ConversationState.surfaces].
  SurfaceContext contextFor(String surfaceId) =>
      _controller.contextFor(surfaceId);

  /// Disposes the whole pipeline: cancels conversation subscriptions, and
  /// closes the transport and controller.
  void dispose() {
    _conversation.dispose();
    _transport.dispose();
    _controller.dispose();
  }
}
