import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

enum RecordingState { initial, recording, paused, stopped }

class AudioRecorderService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentFilePath;
  RecordingState _recordingState = RecordingState.initial;
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;

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
      if (_recordingState == RecordingState.recording) {
        print('AudioRecorderService: Recording is already active');
        return;
      }

      final status = await Permission.microphone.status;
      if (!status.isGranted) {
        throw Exception("Microphone permission not granted.");
      }

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentFilePath = '${directory.path}/rehear_audio_$timestamp.m4a';

      _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
        if (recordState == RecordState.record) {
          _recordingState = RecordingState.recording;
        } else if (recordState == RecordState.pause) {
          _recordingState = RecordingState.paused;
        } else {
          _recordingState = RecordingState.stopped;
        }
      });

      _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        _amplitudeStreamController.add(amp.current);
      });

      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentFilePath!,
      );

      _recordingState = RecordingState.recording;
      print('Recording started: $_currentFilePath');
    } catch (e) {
      print('Error starting recording: $e');
      _recordingState = RecordingState.stopped;
      rethrow;
    }
  }

  Future<void> pauseRecording() async {
    if (_recordingState == RecordingState.recording) {
      await _audioRecorder.pause();
      _recordingState = RecordingState.paused;
      print('Recording paused.');
    }
  }

  Future<void> resumeRecording() async {
    if (_recordingState == RecordingState.paused) {
      await _audioRecorder.resume();
      _recordingState = RecordingState.recording;
      print('Recording resumed.');
    }
  }

  Future<String?> stopRecording() async {
    if (_recordingState == RecordingState.recording || _recordingState == RecordingState.paused) {
      final path = await _audioRecorder.stop();
      _recordingState = RecordingState.stopped;
      print('Recording stopped. File saved at: $path');
      await _disposeSubscriptions();
      _currentFilePath = null;
      return path;
    }
    return null;
  }

  Future<bool> isRecording() async {
    return _recordingState == RecordingState.recording || _recordingState == RecordingState.paused;
  }

  Future<void> _disposeSubscriptions() async {
    await _recordSub?.cancel();
    await _amplitudeSub?.cancel();
    _recordSub = null;
    _amplitudeSub = null;
  }

  Future<void> dispose() async {
    await _disposeSubscriptions();
    await _audioRecorder.dispose();
    await _amplitudeStreamController.close();
    _recordingState = RecordingState.stopped;
  }
}