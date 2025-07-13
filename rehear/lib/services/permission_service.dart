import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart'; // Required for TargetPlatform check

class PermissionService {
  /// Requests microphone permission.
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  /// Requests storage/photos permission for file picking/saving.
  /// Returns true if permission is granted, false otherwise.
  static Future<bool> requestStoragePermission(BuildContext context) async {
    PermissionStatus status;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // For iOS, file_picker often uses photos permission for general media access.
      status = await Permission.photos.status;
      if (status.isDenied) {
        status = await Permission.photos.request();
      }
    } else {
      // On Android, storage permission covers external storage access.
      status = await Permission.storage.status;
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    }
    return status.isGranted;
  }

  /// Opens the app settings to allow the user to manually grant permissions.
  static Future<void> openAppSettingsForPermission() async {
    await openAppSettings();
  }
}