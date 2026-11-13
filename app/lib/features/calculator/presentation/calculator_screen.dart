import 'package:flutter/material.dart';

import '../../../core/format/persian_number.dart';
import '../../../core/strings/app_strings.dart';
import '../data/diyeh_rates.dart';
import '../data/rates_repository.dart';
import 'calculator_controller.dart';
import 'widgets/injury_entry_card.dart';
import 'widgets/injury_picker_sheet.dart';
import 'widgets/result_section.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key, required this.controller});

  final CalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rates = controller.rates;
        return Scaffold(
          appBar: AppBar(
            title: const Text(AppStrings.calculatorTitle),
            actions: [
              if (rates != null)
                IconButton(
                  key: const Key('help_button'),
                  tooltip: AppStrings.helpTooltip,
                  icon: const Text('؟', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  onPressed: () => _showHelp(context, rates),
                ),
            ],
          ),
          body: _body(context, rates),
        );
      },
    );
  }

  Widget _body(BuildContext context, DiyehRates? rates) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.failed || rates == null) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: Text(AppStrings.loadError, textAlign: TextAlign.center)),
      );
    }
    final result = controller.result!;
    final currency = rates.text(TextKeys.currencyLabel);
    final byKey = {for (final r in result.entries) r.entry.key: r};

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _RatesStatus(snapshot: controller.snapshot!, currency: currency),
          const SizedBox(height: 12),
          if (controller.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(AppStrings.emptyHint, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            ),
          for (final e in controller.entries)
            if (byKey[e.key] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InjuryEntryCard(
                  key: ValueKey('entry_${e.key}'),
                  rates: rates,
                  result: byKey[e.key]!,
                  onChanged: controller.updateEntry,
                  onRemove: () => controller.removeEntry(e.key),
                ),
              ),
          FilledButton.tonalIcon(
            key: const Key('add_injury_button'),
            icon: const Icon(Icons.add),
            label: const Text(AppStrings.addInjury),
            onPressed: () async {
              final item = await showInjuryPicker(context, rates);
              if (item != null) controller.addItem(item);
            },
          ),
          if (controller.showHaramQuestion) ...[
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                key: const Key('haram_switch'),
                title: Text(rates.text(TextKeys.haramQuestion)),
                value: controller.haramMonth,
                onChanged: controller.setHaramMonth,
              ),
            ),
          ],
          if (!result.isEmpty) ...[
            const SizedBox(height: 16),
            ResultSection(
              rates: rates,
              result: result,
              paymentOption: controller.paymentOption,
              onPaymentOptionChanged: controller.setPaymentOption,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            rates.text(TextKeys.disclaimerFooter),
            key: const Key('disclaimer_footer'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context, DiyehRates rates) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(rates.text(TextKeys.help)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppStrings.ok))],
      ),
    );
  }
}

class _RatesStatus extends StatelessWidget {
  const _RatesStatus({required this.snapshot, required this.currency});

  final RatesSnapshot snapshot;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final r = snapshot.rates;
    final origin = switch (snapshot.origin) {
      RatesOrigin.network => AppStrings.originNetwork,
      RatesOrigin.cache => AppStrings.originCache,
      RatesOrigin.bundled => AppStrings.originBundled,
    };
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppStrings.rateYear} ${toPersianDigits('${r.year}')} — ${AppStrings.fullDiyeh}: ${formatToman(r.fullDiyehToman, currency)}',
          key: const Key('rates_status'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text('${AppStrings.updatedAt}: ${formatPersianDate(r.updatedAt)} · $origin', style: style),
      ],
    );
  }
}
