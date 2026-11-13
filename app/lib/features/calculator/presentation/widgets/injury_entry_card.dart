import 'package:flutter/material.dart';

import '../../../../core/format/persian_number.dart';
import '../../../../core/strings/app_strings.dart';
import '../../data/diyeh_rates.dart';
import '../../domain/diyeh_calculator.dart';
import 'source_button.dart';

/// One selected injury: inputs (type, count, percent) and its amount.
/// All inputs are buttons/sliders — no typing.
class InjuryEntryCard extends StatelessWidget {
  const InjuryEntryCard({
    super.key,
    required this.rates,
    required this.result,
    required this.onChanged,
    required this.onRemove,
  });

  final DiyehRates rates;
  final EntryResult result;
  final ValueChanged<InjuryEntry> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final item = result.item;
    final entry = result.entry;
    final theme = Theme.of(context);
    final currency = rates.text(TextKeys.currencyLabel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.title, style: theme.textTheme.titleMedium)),
                IconButton(tooltip: AppStrings.remove, icon: const Icon(Icons.close), onPressed: onRemove),
              ],
            ),
            if (item.needsBase) _baseSelector(context, item, entry),
            if (item.percentInput != null) _percentSlider(context, item.percentInput!, entry),
            if (item.quantity != null) _quantityStepper(context, item.quantity!, entry),
            const SizedBox(height: 8),
            Text(
              formatToman(result.amountToman, currency),
              key: Key('amount_${entry.key}'),
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
            ),
            if (result.haramApplied)
              Text(AppStrings.haramIncluded, style: theme.textTheme.bodySmall),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                children: [
                  if (item.article != null)
                    Expanded(child: Text(item.article!, style: theme.textTheme.bodySmall))
                  else
                    const Spacer(),
                  if (item.sourceUrl != null)
                    SourceButton(url: item.sourceUrl!, label: rates.text(TextKeys.sourceButton)),
                ],
              ),
            ),
            if (item.note != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4, end: 8),
                child: Text(item.note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _baseSelector(BuildContext context, DiyehItem item, InjuryEntry entry) {
    final options = [
      for (final id in item.baseOptions)
        if (rates.approvedItem(id) != null) rates.approvedItem(id)!,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 4),
      child: DropdownButtonFormField<String>(
        key: Key('base_${entry.key}'),
        initialValue: entry.baseId,
        isExpanded: true,
        decoration: InputDecoration(labelText: item.baseLabel, border: const OutlineInputBorder(), isDense: true),
        items: [
          for (final b in options) DropdownMenuItem(value: b.id, child: Text(b.baseOptionLabel, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) {
          if (v != null) onChanged(entry.copyWith(baseId: v));
        },
      ),
    );
  }

  Widget _percentSlider(BuildContext context, PercentSpec spec, InjuryEntry entry) {
    final value = (entry.percent ?? spec.min).clamp(spec.min, spec.max);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${spec.label}: ${toPersianDigits('$value')}${AppStrings.percentSign}'),
          Row(
            children: [
              _stepButton(Icons.remove, AppStrings.decrease, value > spec.min,
                  () => onChanged(entry.copyWith(percent: value - 1))),
              Expanded(
                child: Slider(
                  key: Key('percent_${entry.key}'),
                  min: spec.min.toDouble(),
                  max: spec.max.toDouble(),
                  divisions: spec.max - spec.min,
                  value: value.toDouble(),
                  label: '${toPersianDigits('$value')}${AppStrings.percentSign}',
                  onChanged: (v) => onChanged(entry.copyWith(percent: v.round())),
                ),
              ),
              _stepButton(Icons.add, AppStrings.increase, value < spec.max,
                  () => onChanged(entry.copyWith(percent: value + 1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quantityStepper(BuildContext context, QuantitySpec spec, InjuryEntry entry) {
    final q = entry.quantity.clamp(spec.min, spec.max);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8, top: 8),
      child: Row(
        children: [
          Expanded(child: Text(spec.label)),
          _stepButton(Icons.remove, AppStrings.decrease, q > spec.min,
              () => onChanged(entry.copyWith(quantity: q - 1)),
              key: Key('qty_minus_${entry.key}')),
          SizedBox(
            width: 40,
            child: Text(toPersianDigits('$q'),
                key: Key('qty_${entry.key}'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          _stepButton(Icons.add, AppStrings.increase, q < spec.max,
              () => onChanged(entry.copyWith(quantity: q + 1)),
              key: Key('qty_plus_${entry.key}')),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, String tooltip, bool enabled, VoidCallback onTap, {Key? key}) {
    return IconButton.outlined(
      key: key,
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: enabled ? onTap : null,
    );
  }
}
