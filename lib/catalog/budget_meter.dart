import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pawtfolio/theme.dart';
import 'package:pawtfolio/widgets/confetti_overlay.dart';

/// A three-zone savings-goal meter (the "sizzle"): progress toward an emergency
/// fund, with risk-factor chips, that celebrates with confetti at 100%.
final budgetMeter = CatalogItem(
  name: 'BudgetMeter',
  dataSchema: S.object(
    description:
        'A three-zone progress bar toward a savings goal (e.g. an emergency '
        'fund). Shows current vs target, optional risk-factor chips, and '
        'celebrates at 100%. Provide current and target as exact numbers.',
    properties: {
      'title': S.string(),
      'current': S.number(description: 'Amount saved so far.'),
      'target': S.number(description: 'Goal amount.'),
      'caption': S.string(description: 'Optional summary line.'),
      'riskFactors': S.list(
        description: '1-3 short chips, e.g. "Recurring ear infections".',
        items: S.string(),
      ),
    },
    required: ['current', 'target'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    return _BudgetMeter(
      title: data['title'] as String? ?? 'Emergency fund',
      current: (data['current'] as num?)?.toDouble() ?? 0,
      target: (data['target'] as num?)?.toDouble() ?? 1,
      caption: data['caption'] as String?,
      riskFactors: (data['riskFactors'] as List? ?? [])
          .whereType<String>()
          .toList(),
    );
  },
);

class _BudgetMeter extends StatefulWidget {
  const _BudgetMeter({
    required this.title,
    required this.current,
    required this.target,
    required this.caption,
    required this.riskFactors,
  });

  final String title;
  final double current;
  final double target;
  final String? caption;
  final List<String> riskFactors;

  @override
  State<_BudgetMeter> createState() => _BudgetMeterState();
}

class _BudgetMeterState extends State<_BudgetMeter> {
  @override
  void initState() {
    super.initState();
    _maybeCelebrate();
  }

  @override
  void didUpdateWidget(covariant _BudgetMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeCelebrate();
  }

  void _maybeCelebrate() {
    final pct = widget.target > 0 ? widget.current / widget.target : 0.0;
    if (pct >= 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) PawtfolioConfetti.of(context)?.celebrate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final raw = widget.target > 0 ? widget.current / widget.target : 0.0;
    final pct = raw.clamp(0.0, 1.0);
    final fill = pct < 0.4 ? pawMagenta : (pct < 0.75 ? pawOrange : pawGreen);
    final caption =
        widget.caption ??
        '\$${widget.current.toStringAsFixed(0)} of '
            '\$${widget.target.toStringAsFixed(0)} · ${(pct * 100).round()}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                pawIconBadge(Icons.savings, pawGreen, size: 32),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.title, style: t.titleMedium)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 18,
                width: double.infinity,
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 40,
                          child: ColoredBox(
                            color: pawMagenta.withValues(alpha: 0.16),
                          ),
                        ),
                        Expanded(
                          flex: 35,
                          child: ColoredBox(
                            color: pawOrange.withValues(alpha: 0.16),
                          ),
                        ),
                        Expanded(
                          flex: 25,
                          child: ColoredBox(
                            color: pawGreen.withValues(alpha: 0.16),
                          ),
                        ),
                      ],
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      alignment: Alignment.centerLeft,
                      child: ColoredBox(color: fill),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (widget.riskFactors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final r in widget.riskFactors)
                    Chip(
                      label: Text(r),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: pawOrange.withValues(alpha: 0.12),
                      side: BorderSide(color: pawOrange.withValues(alpha: 0.3)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
