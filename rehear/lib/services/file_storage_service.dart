// lib/services/file_storage_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  // Get the directory where audio notes will be stored
  Future<Directory> get _localAudiosDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/ReHearAudios');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true); // Create if it doesn't exist
    }
    return audioDir;
  }

  // Save an audio file (e.g., from recording or import)
  // This method typically handles moving/copying a file to the app's designated directory
  Future<String> saveAudioFile(String sourceFilePath, {String? customFileName}) async {
    try {
      final localDir = await _localAudiosDirectory;
      final sourceFile = File(sourceFilePath);
      
      String fileName = customFileName ?? sourceFile.path.split('/').last;
      // Ensure unique filename if one with the same name already exists
      int counter = 0;
      String newFilePath = '${localDir.path}/$fileName';
      while (await File(newFilePath).exists()) {
        counter++;
        final nameWithoutExtension = fileName.split('.').first;
        final extension = fileName.split('.').last;
        newFilePath = '${localDir.path}/${nameWithoutExtension}_$counter.$extension';
      }

      final newFile = await sourceFile.copy(newFilePath);
      print('File saved to: ${newFile.path}');
      return newFile.path;
    } catch (e) {
      print('Error saving audio file: $e');
      rethrow;
    }
  }

  // Get a list of all audio file paths stored by the app
  Future<List<String>> getAudioFilePaths() async {
    try {
      final localDir = await _localAudiosDirectory;
      final List<String> filePaths = [];
      final entities = localDir.listSync(recursive: false); // List only direct children

      for (var entity in entities) {
        if (entity is File && _isAudioFile(entity.path)) {
          filePaths.add(entity.path);
        }
      }
      return filePaths;
    } catch (e) {
      print('Error getting audio file paths: $e');
      return [];
    }
  }

  // Delete an audio file
  Future<void> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('File deleted: $filePath');
      } else {
        print('File not found, cannot delete: $filePath');
      }
    } catch (e) {
      print('Error deleting audio file: $e');
      rethrow;
    }
  }

  // Helper to check if a file path indicates an audio file
  bool _isAudioFile(String path) {
    final lowerCasePath = path.toLowerCase();
    return lowerCasePath.endsWith('.m4a') ||
           lowerCasePath.endsWith('.mp3') ||
           lowerCasePath.endsWith('.wav') ||
           lowerCasePath.endsWith('.aac'); // Add other formats as needed
  }
}