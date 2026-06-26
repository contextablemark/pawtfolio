import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pawtfolio/theme.dart';

const Map<String, String> _severityAccent = {
  'info': 'teal',
  'good': 'green',
  'warning': 'orange',
  'urgent': 'magenta',
};

const Map<String, IconData> _severityIcon = {
  'info': Icons.info_outline,
  'good': Icons.check_circle_outline,
  'warning': Icons.warning_amber_rounded,
  'urgent': Icons.priority_high_rounded,
};

/// A highlighted proactive callout. At most one per surface, usually last.
final insightAlert = CatalogItem(
  name: 'InsightAlert',
  dataSchema: S.object(
    description:
        'A highlighted callout for a proactive insight or warning (e.g. an '
        'unusual expense). Use at most one per surface, placed last.',
    properties: {
      'severity': S.string(enumValues: ['info', 'good', 'warning', 'urgent']),
      'title': S.string(description: 'Short headline.'),
      'message': S.string(description: 'One or two sentences.'),
    },
    required: ['title', 'message'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final severity = data['severity'] as String? ?? 'info';
    return _InsightAlert(
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      accent: accentColor(
        itemContext.buildContext,
        _severityAccent[severity] ?? 'teal',
      ),
      icon: _severityIcon[severity] ?? Icons.info_outline,
    );
  },
);

class _InsightAlert extends StatelessWidget {
  const _InsightAlert({
    required this.title,
    required this.message,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String message;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pawIconBadge(icon, accent, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: t.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
