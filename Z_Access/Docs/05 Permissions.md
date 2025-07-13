# Platform Permissions:  
## Android:  
`android/app/src/main/AndroidManifest.xml`  
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    ...
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />

    <application ...>
        ...
    </application>
</manifest>
```  
## IOS:  
`ios/Runner/Info.plist`:  
```plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    ...
    <key>NSMicrophoneUsageDescription</key>
    <string>ReHear needs microphone access to record your audio notes.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>ReHear needs access to your photo library to select existing audio files.</string>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>ReHear needs access to your photo library to save new audio files if you choose to export them there.</string>
    <key>UISupportsDocumentBrowser</key>
    <true/>
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>
    ...
</dict>
</plist>
```  

## Implement permission  
`rehear\lib\services\permission_service.dart`  
```dart
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
```  