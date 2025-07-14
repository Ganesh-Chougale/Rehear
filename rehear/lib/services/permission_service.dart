import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Provider

final permissionServiceProvider = Provider<PermissionService>((ref) { // Corrected: Provider recognized
  return PermissionService();
});

class PermissionService {
  Future<bool> requestStoragePermission(BuildContext context) async {
    PermissionStatus status;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      status = await Permission.photos.status;
      if (status.isDenied) {
        status = await Permission.photos.request();
      }
    } else {
      // For Android, prefer request for MediaLocation/Storage, or manage scoped storage.
      // Permission.audio is for Android 13+, for older Android, you might need Permission.storage
      // It's good practice to request what's actually needed.
      if (await Permission.audio.isDenied) { // For Android 13+ audio files
        status = await Permission.audio.request();
      } else if (await Permission.storage.isDenied) { // For older Android versions (pre-13)
        status = await Permission.storage.request();
      } else {
        status = PermissionStatus.granted;
      }
    }

    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        _showPermissionDeniedDialog(context);
      }
      return false;
    }
    return true;
  }

  Future<bool> requestMicrophonePermission(BuildContext context) async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    if (!status.isGranted) {
      if (status.isPermanentlyDenied) {
        _showPermissionDeniedDialog(context, 'microphone');
      }
      return false;
    }
    return true;
  }

  void _showPermissionDeniedDialog(BuildContext context, [String permissionType = 'storage']) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: Text('ReHear needs $permissionType access to function properly. Please enable it in app settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}