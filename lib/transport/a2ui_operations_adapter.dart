// Translates the `a2ui_operations` envelope the AG-UI A2UI backend returns
// (carried as the `content` string of a TOOL_CALL_RESULT) into GenUI
// [A2uiMessage]s that a SurfaceController can apply.
//
// Wire shape (verified against /adk-a2ui-basic-catalog):
//   content = '{"a2ui_operations":[{"version":"v0.9","createSurface":{...}}]}'
// Each array item is already exactly what `A2uiMessage.fromJson` expects.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';

/// Parses the A2UI envelope in a TOOL_CALL_RESULT's [content] into
/// [A2uiMessage]s.
///
/// Returns `null` when [content] is not an A2UI envelope (an ordinary tool
/// result), so callers can simply ignore non-A2UI tool results. Individual
/// malformed operations are skipped rather than failing the whole batch.
List<A2uiMessage>? a2uiMessagesFromToolResultContent(String content) {
  Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    return null; // not JSON -> not an A2UI envelope
  }

  final envelope = _unwrapEnvelope(decoded);
  final ops = envelope?['a2ui_operations'];
  if (ops is! List) return null;

  final messages = <A2uiMessage>[];
  for (final op in ops) {
    if (op is! Map) continue;
    try {
      messages.add(A2uiMessage.fromJson(op.cast<String, Object?>()));
    } on Object catch (e) {
      // A single bad op (e.g. unknown version) shouldn't drop the rest.
      debugPrint('a2ui: skipping unparseable operation: $e');
    }
  }
  return messages.isEmpty ? null : messages;
}

/// Locates the `{a2ui_operations: [...]}` map, peeling one `{"result": ...}`
/// wrapper (and a double-encoded JSON-string result) that an ADK tool layer can
/// add — parity with a2ui_tool.py's envelope extraction.
Map<String, Object?>? _unwrapEnvelope(Object? decoded) {
  if (decoded is! Map) return null;
  final map = decoded.cast<String, Object?>();
  if (map.containsKey('a2ui_operations')) return map;

  final inner = map['result'];
  if (inner is Map && inner.containsKey('a2ui_operations')) {
    return inner.cast<String, Object?>();
  }
  if (inner is String) {
    try {
      final reparsed = jsonDecode(inner);
      if (reparsed is Map && reparsed.containsKey('a2ui_operations')) {
        return reparsed.cast<String, Object?>();
      }
    } on FormatException {
      // fall through
    }
  }
  return null;
}
