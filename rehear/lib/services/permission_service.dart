// lib/services/permission_service.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// Riverpod provider for the permission service
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class PermissionService {
  // Request storage/media library permission
  Future<bool> requestStoragePermission(BuildContext context) async {
    PermissionStatus status;

    // Determine the appropriate permission based on platform
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // On iOS, file_picker typically uses Photo Library or Files app access
      // For general file picking, Permission.photos is a common entry point.
      // If only specific "Files" access (Document Picker) is needed,
      // it might not require explicit Permission.photos, but it's safer to request.
      status = await Permission.photos.status; // or Permission.mediaLibrary if focusing on general media
      if (status.isDenied) {
        status = await Permission.photos.request();
      }
    } else { // Android
      // On Android 13 (API 33) and above, granular media permissions are used:
      // Permission.videos, Permission.images, Permission.audio.
      // For older Android versions, Permission.storage covers READ_EXTERNAL_STORAGE.
      // `file_picker` handles these internal complexities, but requesting Permission.audio
      // or Permission.storage (for older Android) is appropriate.
      // Let's request general storage if targetting older Android or for simplicity.
      // For newer Android, the file picker will usually prompt for media access directly.
      if (await Permission.audio.isDenied) { // Android 13+ specific for audio files
         status = await Permission.audio.request();
      } else if (await Permission.storage.isDenied) { // Older Android for general storage access
         status = await Permission.storage.request();
      } else {
        status = PermissionStatus.granted; // Already granted
      }
    }

    if (!status.isGranted) {
      // If permission is permanently denied, guide user to settings
      if (status.isPermanentlyDenied) {
        _showPermissionDeniedDialog(context);
      }
      return false;
    }
    return true;
  }

  // Request microphone permission (already handled in AudioRecorderService, but good to have centralized)
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

  // Helper to show dialog if permission is permanently denied
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
              openAppSettings(); // Opens app settings for the user to grant permission
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}