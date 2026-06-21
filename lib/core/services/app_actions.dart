import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:lima/core/i18n/app_i18n.dart';

Future<void> launchPhone(String phone) async {
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> launchEmail(String email) async {
  final uri = Uri.parse('mailto:$email');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

/// Opens the mail composer to [email] with a prefilled subject and body.
/// Returns true if a mail app was launched.
Future<bool> launchEmailRequest(
  String email, {
  required String subject,
  required String body,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    query: 'subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
  );
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

Future<void> launchTelegramUsername(String username) async {
  final uri = Uri.parse('https://t.me/$username');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> launchMapsNavigation(double lat, double lon, String label) async {
  final uri = Uri.parse(
    'https://maps.google.com/maps?daddr=$lat,$lon&q=${Uri.encodeComponent(label)}',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.t('copied', args: {'text': text})),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> openAssetFile(BuildContext context, String assetPath) async {
  try {
    final tmpDir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${tmpDir.path}/$fileName');

    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }

    final uri = Uri.file(file.path);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('openFileFailed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('openFileError')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
