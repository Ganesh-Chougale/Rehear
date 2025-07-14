import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AudioEditService {
  /// Trim audio file to specified duration range
  static Future<String?> trimAudio({
    required String inputPath,
    required Duration start,
    required Duration end,
    String? outputPath,
  }) async {
    try {
      outputPath ??= await _generateOutputPath(inputPath, 'trimmed');
      
      final startMs = start.inMilliseconds;
      final durationMs = end.inMilliseconds - startMs;
      
      final command = [
        '-i', inputPath,
        '-ss', '${startMs}ms',
        '-t', '${durationMs}ms',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-y',
        outputPath,
      ];
      
      final session = await FFmpegKit.executeWithArguments(command);
      final returnCode = await session.getReturnCode();
      
      if (returnCode == null || !returnCode.isValueZero()) {
        throw Exception('Failed to trim audio: ${await session.getFailStackTrace()}');
      }
      
      return outputPath;
    } catch (e) {
      print('Error trimming audio: $e');
      rethrow;
    }
  }

  /// Split audio at specified position
  static Future<List<String>> splitAudio({
    required String inputPath,
    required Duration splitAt,
    String? outputDir,
  }) async {
    try {
      outputDir ??= (await getTemporaryDirectory()).path;
      final baseName = path.basenameWithoutExtension(inputPath);
      
      // First part
      final firstPartPath = path.join(outputDir, '${baseName}_part1.m4a');
      await trimAudio(
        inputPath: inputPath,
        start: Duration.zero,
        end: splitAt,
        outputPath: firstPartPath,
      );
      
      // Second part
      final secondPartPath = path.join(outputDir, '${baseName}_part2.m4a');
      await trimAudio(
        inputPath: inputPath,
        start: splitAt,
        end: Duration(hours: 1), // Arbitrary large duration to get to the end
        outputPath: secondPartPath,
      );
      
      return [firstPartPath, secondPartPath];
    } catch (e) {
      print('Error splitting audio: $e');
      rethrow;
    }
  }

  /// Cut out a section from the audio
  static Future<String> cutAudio({
    required String inputPath,
    required Duration startCut,
    required Duration endCut,
    String? outputPath,
  }) async {
    try {
      outputPath ??= await _generateOutputPath(inputPath, 'cut');
      
      // Create parts before and after the cut
      final tempDir = await getTemporaryDirectory();
      final baseName = path.basenameWithoutExtension(inputPath);
      
      // Part before cut
      final beforeCutPath = path.join(tempDir.path, '${baseName}_before.m4a');
      await trimAudio(
        inputPath: inputPath,
        start: Duration.zero,
        end: startCut,
        outputPath: beforeCutPath,
      );
      
      // Part after cut
      final afterCutPath = path.join(tempDir.path, '${baseName}_after.m4a');
      await trimAudio(
        inputPath: inputPath,
        start: endCut,
        end: Duration(hours: 1), // Arbitrary large duration
        outputPath: afterCutPath,
      );
      
      // Combine the two parts
      final concatListPath = path.join(tempDir.path, 'concat_list.txt');
      await File(concatListPath).writeAsString(
        "file '${beforeCutPath.replaceAll('\\', '/')}'\nfile '${afterCutPath.replaceAll('\\', '/')}'",
      );
      
      final command = [
        '-f', 'concat',
        '-safe', '0',
        '-i', concatListPath,
        '-c', 'copy',
        '-y',
        outputPath,
      ];
      
      final session = await FFmpegKit.executeWithArguments(command);
      final returnCode = await session.getReturnCode();
      
      // Clean up temporary files
      await Future.wait([
        File(beforeCutPath).delete(),
        File(afterCutPath).delete(),
        File(concatListPath).delete(),
      ]);
      
      if (returnCode == null || !returnCode.isValueZero()) {
        throw Exception('Failed to cut audio: ${await session.getFailStackTrace()}');
      }
      
      return outputPath;
    } catch (e) {
      print('Error cutting audio: $e');
      rethrow;
    }
  }
  
  static Future<String> _generateOutputPath(String inputPath, String suffix) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final fileName = '${path.basenameWithoutExtension(inputPath)}_$suffix${path.extension(inputPath)}';
    return path.join(appDocDir.path, fileName);
  }
}
