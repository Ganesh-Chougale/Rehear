// lib/providers/recording_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_recorder_service.dart';
import '../audio_recording/recording_model.dart';
import 'dart:async'; // Import for Timer
import 'notes_list_provider.dart'; // Import notes list provider

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final recordingNotifierProvider = StateNotifierProvider<RecordingNotifier, RecordingStateModel>((ref) {
  final recorderService = ref.watch(audioRecorderServiceProvider);
  final notesListNotifier = ref.read(notesListProvider.notifier); // Read the notes list notifier
  return RecordingNotifier(recorderService, notesListNotifier);
});

class RecordingNotifier extends StateNotifier<RecordingStateModel> {
  final AudioRecorderService _recorderService;
  final NotesListNotifier _notesListNotifier; // Inject notes list notifier
  StreamSubscription<double>? _amplitudeSubscription;
  Timer? _durationTimer;

  RecordingNotifier(this._recorderService, this._notesListNotifier) : super(RecordingStateModel()) {
    _recorderService.init().catchError((e) {
      print("Failed to initialize recorder service: $e");
    });
    // _amplitudeSubscription = _recorderService.onAmplitudeChanged.listen((amplitude) {
    //   // Handle amplitude updates if you implement real-time display in Step 2.1.2
    // });
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> startRecording() async {
    try {
      await _recorderService.startRecording();
      state = state.copyWith(
        state: _recorderService.recordingState,
        filePath: _recorderService.currentFilePath,
        duration: Duration.zero,
      );
      _startDurationTimer();
    } catch (e) {
      print('Failed to start recording: $e');
      state = state.copyWith(state: RecordingState.initial);
    }
  }

  Future<void> pauseRecording() async {
    await _recorderService.pauseRecording();
    state = state.copyWith(state: _recorderService.recordingState);
    _durationTimer?.cancel();
  }

  Future<void> resumeRecording() async {
    await _recorderService.resumeRecording();
    state = state.copyWith(state: _recorderService.recordingState);
    _startDurationTimer();
  }

  Future<String?> stopRecording() async {
    _durationTimer?.cancel();
    final path = await _recorderService.stopRecording();
    state = state.copyWith(
      state: _recorderService.recordingState,
      filePath: null,
      duration: Duration.zero,
    );
    if (path != null) {
      // Add the new recording to the notes list
      await _notesListNotifier.addNote(path);
    }
    return path;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.state == RecordingState.recording) {
        state = state.copyWith(duration: state.duration + const Duration(seconds: 1));
      } else {
        timer.cancel();
      }
    });
  }
}