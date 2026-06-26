import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pawtfolio/theme.dart';

typedef _Bar = ({String label, double value});

/// A bar chart for trends over time or ranked comparisons.
final barChart = CatalogItem(
  name: 'BarChart',
  dataSchema: S.object(
    description:
        'A bar chart for trends over time ("month by month") or ranked '
        'comparisons ("top merchants"). Provide pre-computed bars with exact '
        'values; do not invent amounts.',
    properties: {
      'title': S.string(),
      'unit': S.string(description: r'Value prefix, e.g. "$".'),
      'accent': S.string(enumValues: ['teal', 'orange', 'magenta', 'green']),
      'bars': S.list(
        items: S.object(
          properties: {'label': S.string(), 'value': S.number()},
          required: ['label', 'value'],
        ),
      ),
    },
    required: ['bars'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final bars = (data['bars'] as List? ?? [])
        .whereType<Map>()
        .map<_Bar>(
          (m) => (
            label: m['label'] as String? ?? '',
            value: (m['value'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
    return _BarChart(
      title: data['title'] as String?,
      unit: data['unit'] as String? ?? '',
      accent: accentColor(itemContext.buildContext, data['accent'] as String?),
      bars: bars,
    );
  },
);

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.title,
    required this.unit,
    required this.accent,
    required this.bars,
  });

  final String? title;
  final String unit;
  final Color accent;
  final List<_Bar> bars;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final maxValue = bars.fold<double>(
      0,
      (m, b) => b.value > m ? b.value : m,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    pawIconBadge(Icons.insights, accent, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title!, style: t.titleMedium)),
                  ],
                ),
              ),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue == 0 ? 1 : maxValue * 1.2,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= bars.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              bars[i].label,
                              style: t.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < bars.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: bars[i].value,
                            color: accent,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
