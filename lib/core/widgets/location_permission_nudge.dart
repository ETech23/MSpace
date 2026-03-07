import 'package:flutter/material.dart';

class LocationPermissionNudge {
  const LocationPermissionNudge._();

  static Future<bool?> showRationaleDialog(
    BuildContext context, {
    required String title,
    required String message,
    String primaryLabel = 'Allow',
    String secondaryLabel = 'Not now',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(secondaryLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
  }

  static void showSettingsBanner(
    BuildContext context, {
    required String message,
    required Future<void> Function() onOpenSettings,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          content: Text(message),
          leading: const Icon(Icons.location_off_outlined),
          actions: [
            TextButton(
              onPressed: () async {
                messenger.hideCurrentMaterialBanner();
                await onOpenSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
  }
}
