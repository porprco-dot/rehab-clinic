import 'package:flutter/material.dart';

import '../../../../core/format/persian_number.dart';
import '../../../../core/strings/app_strings.dart';
import '../../data/diyeh_rates.dart';
import '../../domain/diyeh_calculator.dart';

/// Total, fixed notes and the optional payment schedule.
class ResultSection extends StatelessWidget {
  const ResultSection({
    super.key,
    required this.rates,
    required this.result,
    required this.paymentOption,
    required this.onPaymentOptionChanged,
  });

  final DiyehRates rates;
  final CalculationResult result;
  final PaymentOption? paymentOption;
  final ValueChanged<String?> onPaymentOptionChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = rates.text(TextKeys.currencyLabel);
    final schedule = rates.paymentSchedule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.total, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                const SizedBox(height: 4),
                Text(
                  formatToman(result.totalToman, currency),
                  key: const Key('total_amount'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (result.showMultipleInjuriesNote) ...[
                  const SizedBox(height: 8),
                  Text(
                    rates.text(TextKeys.multipleInjuriesNote),
                    key: const Key('multiple_injuries_note'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rates.text(TextKeys.paymentQuestion), style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text(AppStrings.noPaymentSchedule),
                      selected: paymentOption == null,
                      onSelected: (_) => onPaymentOptionChanged(null),
                    ),
                    for (final o in schedule.options)
                      ChoiceChip(
                        key: Key('payment_${o.id}'),
                        label: Text(o.title),
                        selected: paymentOption?.id == o.id,
                        onSelected: (_) => onPaymentOptionChanged(o.id),
                      ),
                  ],
                ),
                if (paymentOption != null) ...[
                  const SizedBox(height: 12),
                  Text(paymentOption!.description),
                  const SizedBox(height: 8),
                  for (final inst in DiyehCalculator.schedule(result.totalToman, paymentOption!))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text('${schedule.periodLabel} ${toPersianDigits('${inst.yearNumber}')}')),
                          Text(formatToman(inst.amountToman, currency), key: Key('installment_${inst.yearNumber}')),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(schedule.article, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
