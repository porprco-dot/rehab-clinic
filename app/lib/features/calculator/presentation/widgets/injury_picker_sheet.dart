import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../data/diyeh_rates.dart';

/// Grouped list of approved injuries; pending items never appear here.
Future<DiyehItem?> showInjuryPicker(BuildContext context, DiyehRates rates) {
  return showModalBottomSheet<DiyehItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => _PickerList(rates: rates, scrollController: scroll),
    ),
  );
}

class _PickerList extends StatelessWidget {
  const _PickerList({required this.rates, required this.scrollController});

  final DiyehRates rates;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final approved = rates.approvedItems;
    final groups = [
      for (final g in rates.groups)
        if (approved.any((it) => it.groupId == g.id)) g,
    ];
    return ListView(
      controller: scrollController,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(AppStrings.chooseInjury, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final g in groups)
          ExpansionTile(
            key: Key('group_${g.id}'),
            title: Text(g.title),
            children: [
              for (final it in approved.where((it) => it.groupId == g.id))
                ListTile(
                  key: Key('pick_${it.id}'),
                  title: Text(it.title),
                  subtitle: it.article == null ? null : Text(it.article!),
                  onTap: () => Navigator.pop(context, it),
                ),
            ],
          ),
      ],
    );
  }
}
