import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/strings/app_strings.dart';

class SourceButton extends StatelessWidget {
  const SourceButton({super.key, required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(label),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final uri = Uri.tryParse(url);
        var ok = false;
        if (uri != null && uri.scheme == 'https') {
          try {
            ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } on Object {
            ok = false;
          }
        }
        if (!ok) {
          messenger.showSnackBar(const SnackBar(content: Text(AppStrings.sourceOpenError)));
        }
      },
    );
  }
}
