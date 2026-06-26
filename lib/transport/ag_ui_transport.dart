import 'dart:async';
import 'dart:convert';

import 'package:ag_ui/ag_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:pawtfolio/catalog.dart';
import 'package:pawtfolio/transport/a2ui_operations_adapter.dart';
import 'package:pawtfolio/transport/ag_ui_config.dart';
import 'package:pawtfolio/transport/ids.dart';
import 'package:pawtfolio/transport/platform_http_client.dart';

/// A GenUI [Transport] backed by an AG-UI agent backend.
///
/// Replaces the template's direct-LLM transport. Instead of a model streaming
/// raw A2UI JSON text, an AG-UI agent emits A2UI operations as the `content` of
/// a TOOL_CALL_RESULT event; this transport parses those into [A2uiMessage]s
/// and pushes them onto [incomingMessages], where [Conversation] forwards them
/// to the [SurfaceController] for rendering.
///
/// The widget [Catalog] is injected into each run as a schema context entry so
/// the agent knows the component vocabulary it may emit. Button taps and other
/// surface interactions arrive back through [sendRequest] (wired by
/// [Conversation] from `controller.onSubmit`) and re-run the agent.
class AgUiTransport implements Transport {
  /// Creates a transport for the AG-UI backend [baseUrl] (default
  /// [kA2uiBaseUrl]) and [endpoint] (default [kA2uiEndpointPath]), injecting
  /// [catalog] into every run.
  AgUiTransport({
    required Catalog catalog,
    String? baseUrl,
    String? endpoint,
  }) : _endpoint = endpoint ?? kA2uiEndpointPath,
       _catalogSchemaJson = jsonEncode(catalog.toCapabilitiesJson()),
       _client = AgUiClient(
         config: AgUiClientConfig(baseUrl: baseUrl ?? kA2uiBaseUrl),
         // On web this is a Fetch-API client that streams the SSE body; on
         // other platforms it's null and AgUiClient builds its own.
         httpClient: createPlatformHttpClient(),
       );

  final String _endpoint;
  final String _catalogSchemaJson;
  final AgUiClient _client;

  // One thread per session; history accumulates so the agent has prior context.
  final String _threadId = uid('thread');
  final List<Message> _history = [];

  final StreamController<A2uiMessage> _messages =
      StreamController<A2uiMessage>.broadcast();
  final StreamController<String> _text = StreamController<String>.broadcast();

  /// The raw A2UI JSON of the latest surface operations, for the source panel.
  final ValueNotifier<String> a2uiSource = ValueNotifier<String>('');

  @override
  Stream<A2uiMessage> get incomingMessages => _messages.stream;

  @override
  Stream<String> get incomingText => _text.stream;

  @override
  Future<void> sendRequest(ChatMessage message) async {
    _history.add(UserMessage(id: uid('user'), content: _outboundText(message)));
    a2uiSource.value = '';

    final input = SimpleRunAgentInput(
      threadId: _threadId,
      runId: uid('run'),
      messages: _history,
      tools: const [],
      // Catalog injection rides on `context`; the `injectA2UITool` flag (which
      // makes the ADK adapter wire up the generate_a2ui tool) rides on
      // `forwardedProps`.
      context: [
        Context(
          description: kA2uiSchemaContextDescription,
          value: _catalogSchemaJson,
        ),
      ],
      state: <String, dynamic>{},
      forwardedProps: const {'injectA2UITool': true},
    );

    // Stop as soon as the surface is rendered, OR at the protocol-level end of
    // the run (RUN_FINISHED / RUN_ERROR). We must not wait for the SSE byte
    // stream to close: on web the fetch ReadableStream is held open and never
    // signals "done", so a plain await-for would block forever.
    //
    // Breaking on the A2UI result is also a deliberate latency cut: some open
    // models (e.g. Qwen3-Coder) re-dump the entire a2ui_operations JSON as a
    // trailing assistant text turn AFTER the surface is already rendered —
    // thousands of wasted tokens. Stopping once we have the surface skips that
    // dump, unlocks input immediately, and cancels the backend request.
    await for (final event in _client.runAgent(_endpoint, input)) {
      // Surface rendered — skip the agent's trailing text dump.
      if (_handleEvent(event)) break;
      if (event is RunFinishedEvent) break;
      if (event is RunErrorEvent) {
        // Surfaces as a ConversationError (SnackBar) via Conversation.
        throw StateError('AG-UI run error: ${event.message}');
      }
    }
  }

  /// Handles one AG-UI event. Returns `true` once a surface has been rendered
  /// (an A2UI operations envelope was applied), signalling the run can stop.
  bool _handleEvent(BaseEvent event) {
    // A2UI operations arrive as the JSON `content` of a TOOL_CALL_RESULT. The
    // nested render_a2ui TOOL_CALL_* streaming events are partial-paint signals
    // (only meaningful with the TS middleware) and are intentionally ignored.
    if (event is ToolCallResultEvent) {
      final messages = a2uiMessagesFromToolResultContent(event.content);
      if (messages != null) {
        messages.forEach(_messages.add);
        // Show the raw A2UI JSON the agent produced in the source panel.
        a2uiSource.value = _prettyJson(event.content);
        return true;
      }
    } else if (event is TextMessageContentEvent) {
      _text.add(event.delta);
    } else if (event is TextMessageChunkEvent) {
      final delta = event.delta;
      if (delta != null && delta.isNotEmpty) _text.add(delta);
    }
    return false;
  }

  // The text to send for this turn: a typed message carries its content as
  // text; a surface interaction (e.g. a button tap) instead carries its payload
  // as a [UiInteractionPart] whose JSON describes the action and has no text.
  String _outboundText(ChatMessage message) {
    if (message.text.trim().isNotEmpty) return message.text;
    return message.parts.uiInteractionParts
        .map((part) => part.interaction)
        .join('\n');
  }

  String _prettyJson(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } on FormatException {
      return raw;
    }
  }

  @override
  void dispose() {
    unawaited(_messages.close());
    unawaited(_text.close());
    a2uiSource.dispose();
    unawaited(_client.close());
  }
}
