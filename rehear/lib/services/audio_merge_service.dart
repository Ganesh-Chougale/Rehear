import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AudioMergeService {
  /// Merges multiple audio files into a single file
  /// Returns the path to the merged file, or null if merging failed
  static Future<String?> mergeClips({
    required List<String> inputPaths,
    required String outputFileName,
    List<Duration>? startTimes,
    List<Duration>? durations,
  }) async {
    try {
      // Get the app's documents directory for output
      final appDocDir = await getApplicationDocumentsDirectory();
      final outputPath = path.join(appDocDir.path, outputFileName);
      
      // Clean up any existing file with the same name
      final outputFile = File(outputPath);
      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      // Create a temporary directory for intermediate files
      final tempDir = await getTemporaryDirectory();
      final tempFiles = <String>[];
      
      try {
        // Prepare input files with filters (trimming if needed)
        final inputArguments = <String>[];
        final filterComplex = StringBuffer();
        
        for (int i = 0; i < inputPaths.length; i++) {
          final inputPath = inputPaths[i];
          final tempPath = path.join(tempDir.path, 'temp_$i${path.extension(inputPath)}');
          tempFiles.add(tempPath);
          
          // If start time or duration is specified, trim the input
          if (startTimes != null && i < startTimes.length && startTimes[i] > Duration.zero) {
            final start = startTimes[i];
            final duration = (durations != null && i < durations.length) ? durations[i] : null;
            
            var filter = 'atrim=start=${start.inMilliseconds / 1000.0}';
            if (duration != null) {
              filter += ':duration=${duration.inMilliseconds / 1000.0}';
            }
            
            // Use ffmpeg to trim the input and save as temp file
            final trimCmd = '-i "$inputPath" -af "$filter" -y "$tempPath"';
            final session = await FFmpegKit.execute(trimCmd);
            final returnCode = await session.getReturnCode();
            
            if (returnCode == null || !returnCode.isValueZero()) {
              throw Exception('Failed to trim input file: ${await session.getFailStackTrace()}');
            }
            
            inputArguments.addAll(['-i', tempPath]);
          } else {
            inputArguments.addAll(['-i', inputPath]);
          }
          
          // Add to filter complex for merging
          if (i > 0) filterComplex.write(';');
          filterComplex.write('[$i:0]');
        }
        
        // Build the filter complex for merging
        filterComplex.write('concat=n=${inputPaths.length}:v=0:a=1[out]');
        
        // Build the FFmpeg command
        final command = [
          ...inputArguments,
          '-filter_complex',
          filterComplex.toString(),
          '-map',
          '[out]',
          '-c:a',
          'aac', // Using AAC codec for better compatibility
          '-b:a',
          '192k', // 192kbps bitrate for good quality
          '-y', // Overwrite output file if it exists
          outputPath,
        ];
        
        // Execute the FFmpeg command
        final session = await FFmpegKit.executeWithArguments(command);
        final returnCode = await session.getReturnCode();
        
        if (returnCode == null || !returnCode.isValueZero()) {
          throw Exception('Failed to merge audio files: ${await session.getFailStackTrace()}');
        }
        
        // Verify the output file was created
        if (await outputFile.exists()) {
          return outputPath;
        }
        
        return null;
      } finally {
        // Clean up temporary files
        for (final file in tempFiles) {
          try {
            await File(file).delete();
          } catch (e) {
            print('Failed to delete temporary file: $e');
          }
        }
      }
    } catch (e) {
      print('Error merging audio files: $e');
      rethrow;
    }
  }
  
  /// Creates a silent audio segment of the specified duration
  static Future<String> createSilentSegment(Duration duration) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = path.join(tempDir.path, 'silence_${duration.inMilliseconds}.aac');
    
    // Create silent audio using FFmpeg's anullsrc filter
    final command = [
      '-f', 'lavfi',
      '-i', 'anullsrc=r=44100:cl=stereo',
      '-t', '${duration.inMilliseconds / 1000.0}',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-y',
      outputPath,
    ];
    
    final session = await FFmpegKit.executeWithArguments(command);
    final returnCode = await session.getReturnCode();
    
    if (returnCode == null || !returnCode.isValueZero()) {
      throw Exception('Failed to create silent segment: ${await session.getFailStackTrace()}');
    }
    
    return outputPath;
  }
}
