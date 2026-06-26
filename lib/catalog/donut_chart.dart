import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pawtfolio/theme.dart';

typedef _Segment = ({String label, double value, String? color});

/// A donut chart for category breakdown / proportions.
final donutChart = CatalogItem(
  name: 'DonutChart',
  dataSchema: S.object(
    description:
        'A donut chart for category breakdown / proportions (e.g. "where the '
        'money went"). Provide pre-computed segments with exact numeric values; '
        'do not invent amounts. Not for time trends (use BarChart).',
    properties: {
      'title': S.string(),
      'centerLabel': S.string(description: 'Text shown in the hole (e.g. total)'),
      'segments': S.list(
        description: 'Slices. value is an absolute amount (number).',
        items: S.object(
          properties: {
            'label': S.string(),
            'value': S.number(),
            'color': S.string(
              enumValues: ['teal', 'orange', 'magenta', 'green', 'muted'],
            ),
          },
          required: ['label', 'value'],
        ),
      ),
    },
    required: ['segments'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final segments = (data['segments'] as List? ?? [])
        .whereType<Map>()
        .map<_Segment>(
          (m) => (
            label: m['label'] as String? ?? '',
            value: (m['value'] as num?)?.toDouble() ?? 0.0,
            color: m['color'] as String?,
          ),
        )
        .toList();
    return _DonutChart(
      title: data['title'] as String?,
      centerLabel: data['centerLabel'] as String?,
      segments: segments,
    );
  },
);

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.title,
    required this.centerLabel,
    required this.segments,
  });

  final String? title;
  final String? centerLabel;
  final List<_Segment> segments;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    pawIconBadge(Icons.donut_large, pawTeal, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title!, style: t.titleMedium)),
                  ],
                ),
              ),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 58,
                      sections: [
                        for (final s in segments)
                          PieChartSectionData(
                            value: s.value,
                            color: accentColor(context, s.color),
                            radius: 46,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  if (centerLabel != null && centerLabel!.isNotEmpty)
                    Text(
                      centerLabel!,
                      textAlign: TextAlign.center,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final s in segments)
                  _LegendDot(
                    color: accentColor(context, s.color),
                    label: s.label,
                    pct: total > 0 ? s.value / total : 0,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.pct,
  });

  final Color color;
  final String label;
  final double pct;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  ${(pct * 100).round()}%',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
