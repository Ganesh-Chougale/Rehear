// lib/providers/recording_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_recorder_service.dart';
import '../audio_recording/recording_model.dart';
import 'dart:async'; // Import for Timer

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final recordingNotifierProvider = StateNotifierProvider<RecordingNotifier, RecordingStateModel>((ref) {
  final recorderService = ref.watch(audioRecorderServiceProvider);
  return RecordingNotifier(recorderService);
});

class RecordingNotifier extends StateNotifier<RecordingStateModel> {
  final AudioRecorderService _recorderService;
  StreamSubscription<double>? _amplitudeSubscription; // To manage amplitude stream
  Timer? _durationTimer; // To manage recording duration

  RecordingNotifier(this._recorderService) : super(RecordingStateModel()) {
    _recorderService.init().catchError((e) {
      print("Failed to initialize recorder service: $e");
    });

    // Listen to amplitude changes from the service
    _amplitudeSubscription = _recorderService.onAmplitudeChanged.listen((amplitude) {
      // You can process the amplitude here if needed before passing to UI
      // For now, we'll just update a potential state for a visualizer
      // (This could be a separate provider if the visualizer is complex)
      // For a simple bar, we might just pass the raw value to the UI directly.
    });
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel(); // Cancel amplitude subscription
    _durationTimer?.cancel(); // Cancel duration timer
    super.dispose();
  }

  Future<void> startRecording() async {
    try {
      await _recorderService.startRecording();
      state = state.copyWith(
        state: _recorderService.recordingState,
        filePath: _recorderService.currentFilePath,
        duration: Duration.zero, // Reset duration
      );
      _startDurationTimer(); // Start updating duration
    } catch (e) {
      print('Failed to start recording: $e');
      state = state.copyWith(state: RecordingState.initial);
    }
  }

  Future<void> pauseRecording() async {
    await _recorderService.pauseRecording();
    state = state.copyWith(state: _recorderService.recordingState);
    _durationTimer?.cancel(); // Pause duration timer
  }

  Future<void> resumeRecording() async {
    await _recorderService.resumeRecording();
    state = state.copyWith(state: _recorderService.recordingState);
    _startDurationTimer(); // Resume duration timer
  }

  Future<String?> stopRecording() async {
    _durationTimer?.cancel(); // Stop duration timer
    final path = await _recorderService.stopRecording();
    state = state.copyWith(
      state: _recorderService.recordingState,
      filePath: null,
      duration: Duration.zero,
    );
    return path;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel(); // Cancel any existing timer
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.state == RecordingState.recording) {
        state = state.copyWith(duration: state.duration + const Duration(seconds: 1));
      } else {
        timer.cancel();
      }
    });
  }
}