// lib/services/audio_recorder_service.dart

import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async'; // Import for StreamController

enum RecordingState { initial, recording, paused, stopped }

class AudioRecorderService {
  final Record _audioRecord = Record();
  String? _currentFilePath;
  RecordingState _recordingState = RecordingState.initial;

  // StreamController to emit audio power levels
  final _amplitudeStreamController = StreamController<double>.broadcast();
  Stream<double> get onAmplitudeChanged => _amplitudeStreamController.stream;

  RecordingState get recordingState => _recordingState;
  String? get currentFilePath => _currentFilePath;

  Future<void> init() async {
    if (await Permission.microphone.isDenied) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        throw Exception("Microphone permission not granted.");
      }
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _audioRecord.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        _currentFilePath = '${directory.path}/rehear_audio_$timestamp.m4a';

        await _audioRecord.start(
          path: _currentFilePath!,
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          samplingRate: 44100,
        );
        _recordingState = RecordingState.recording;
        print('Recording started: $_currentFilePath');

        // Start listening to amplitude
        _audioRecord.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amplitude) {
          _amplitudeStreamController.add(amplitude.current); // Add current amplitude to stream
        });
      } else {
        throw Exception("Microphone permission not granted.");
      }
    } catch (e) {
      print('Error starting recording: $e');
      _recordingState = RecordingState.initial;
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    if (_recordingState == RecordingState.recording) {
      await _audioRecord.pause();
      _recordingState = RecordingState.paused;
      print('Recording paused.');
      // Stop emitting amplitude when paused
      // _amplitudeStreamController.close(); // Don't close, just stop adding
    }
  }

  Future<void> resumeRecording() async {
    if (_recordingState == RecordingState.paused) {
      await _audioRecord.resume();
      _recordingState = RecordingState.recording;
      print('Recording resumed.');
      // Re-start emitting amplitude if needed, or ensure the listener continues
      // (The existing onAmplitudeChanged listener from start() will continue by default)
    }
  }

  Future<String?> stopRecording() async {
    if (_recordingState == RecordingState.recording || _recordingState == RecordingState.paused) {
      final path = await _audioRecord.stop();
      _recordingState = RecordingState.stopped;
      print('Recording stopped. File saved at: $path');
      _currentFilePath = null;
      // You might want to close the stream controller here if you intend to create a new one on next start
      // For simplicity, we'll keep it open and just stop adding values.
      return path;
    }
    return null;
  }

  Future<bool> isRecording() => _audioRecord.isRecording();

  Future<void> dispose() async {
    if (_recordingState != RecordingState.stopped) {
      await _audioRecord.stop();
    }
    _amplitudeStreamController.close(); // Close the stream controller on dispose
    _audioRecord.dispose();
    _recordingState = RecordingState.initial;
    print('AudioRecorderService disposed.');
  }
}