import 'package:flutter/material.dart';

class PermissionDisclosures {
  static const String locationMessage =
      'ParkLagbee collects location data only while using the app to show nearby available parking spots and calculate distance. We do not track your location in the background.';
  static const String mediaMessage =
      'ParkLagbee needs access to your camera/gallery so you can upload clear photos of your parking spot or verification documents.';

  static Future<bool> showLocationDisclosure(BuildContext context) =>
      _showDisclosure(context, locationMessage);

  static Future<bool> showMediaDisclosure(BuildContext context) =>
      _showDisclosure(context, mediaMessage);

  static Future<bool> _showDisclosure(
    BuildContext context,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Disclosure'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not Now'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
