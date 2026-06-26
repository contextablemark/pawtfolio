import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:pawtfolio/theme.dart';

const Map<String, IconData> _icons = {
  'food': Icons.restaurant,
  'health': Icons.favorite,
  'grooming': Icons.content_cut,
  'toys': Icons.toys,
  'walker': Icons.directions_walk,
  'savings': Icons.savings,
  'paw': Icons.pets,
};

typedef _Row = ({
  String merchant,
  String? category,
  String? date,
  double amount,
  String? icon,
  bool reimbursable,
});

/// An itemized list of expense rows.
final expenseList = CatalogItem(
  name: 'ExpenseList',
  dataSchema: S.object(
    description:
        'An itemized list of individual expense rows. Provide pre-computed '
        'rows. Use for "show me the transactions / bills", not aggregates.',
    properties: {
      'title': S.string(),
      'rows': S.list(
        items: S.object(
          properties: {
            'merchant': S.string(),
            'category': S.string(),
            'date': S.string(description: 'ISO date, e.g. 2026-03-12'),
            'amount': S.number(),
            'icon': S.string(enumValues: _icons.keys.toList()),
            'reimbursable': S.boolean(),
          },
          required: ['merchant', 'amount'],
        ),
      ),
    },
    required: ['rows'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final rows = (data['rows'] as List? ?? [])
        .whereType<Map>()
        .map<_Row>(
          (m) => (
            merchant: m['merchant'] as String? ?? '',
            category: m['category'] as String?,
            date: m['date'] as String?,
            amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
            icon: m['icon'] as String?,
            reimbursable: m['reimbursable'] as bool? ?? false,
          ),
        )
        .toList();
    return _ExpenseList(title: data['title'] as String?, rows: rows);
  },
);

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.title, required this.rows});

  final String? title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  title!,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            for (final r in rows) _ExpenseRow(row: r),
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final subtitle = [
      if (row.category != null && row.category!.isNotEmpty) row.category,
      if (row.date != null && row.date!.isNotEmpty) row.date,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: pawTeal.withValues(alpha: 0.12),
            child: Icon(_icons[row.icon] ?? Icons.pets, size: 18, color: pawTeal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.merchant, style: t.bodyLarge),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: t.bodySmall?.copyWith(color: Colors.black54),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${row.amount.toStringAsFixed(2)}',
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (row.reimbursable)
                Text(
                  'reimbursable',
                  style: t.labelSmall?.copyWith(color: pawGreen),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
