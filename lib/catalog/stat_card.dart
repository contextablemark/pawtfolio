import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pawtfolio/theme.dart';

const Map<String, IconData> _icons = {
  'paw': Icons.pets,
  'food': Icons.restaurant,
  'health': Icons.favorite,
  'toys': Icons.toys,
  'grooming': Icons.content_cut,
  'savings': Icons.savings,
  'walker': Icons.directions_walk,
  'alert': Icons.warning_amber_rounded,
  'trend': Icons.trending_up,
};

/// A KPI tile: label, big value, optional sub-label, circular accent icon.
final statCard = CatalogItem(
  name: 'StatCard',
  dataSchema: S.object(
    description:
        'A KPI tile showing one headline number (label + value + optional '
        'sub-label + icon + accent color). Use for totals, averages, counts. '
        'Not for breakdowns (use DonutChart) or trends (use BarChart).',
    properties: {
      'label': S.string(description: 'Caption, e.g. "Total spent".'),
      'value': S.string(description: r'Formatted value, e.g. "$1,284".'),
      'sublabel': S.string(description: 'Optional secondary line.'),
      'icon': S.string(
        description: 'Icon key.',
        enumValues: _icons.keys.toList(),
      ),
      'accent': S.string(enumValues: ['teal', 'orange', 'magenta', 'green']),
    },
    required: ['label', 'value'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    return _StatCard(
      label: data['label'] as String? ?? '',
      value: data['value'] as String? ?? '',
      sublabel: data['sublabel'] as String?,
      icon: _icons[data['icon'] as String?] ?? Icons.pets,
      accent: accentColor(itemContext.buildContext, data['accent'] as String?),
    );
  },
);

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final String? sublabel;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            pawIconBadge(icon, accent, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.labelMedium?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: t.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  if (sublabel != null && sublabel!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel!,
                      style: t.bodySmall?.copyWith(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
