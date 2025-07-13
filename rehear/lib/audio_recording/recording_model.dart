// lib/audio_recording/recording_model.dart

import '../services/audio_recorder_service.dart';

class RecordingStateModel {
  final RecordingState state;
  final String? filePath;
  final Duration duration; // Current recording duration

  RecordingStateModel({
    this.state = RecordingState.initial,
    this.filePath,
    this.duration = Duration.zero,
  });

  RecordingStateModel copyWith({
    RecordingState? state,
    String? filePath,
    Duration? duration,
  }) {
    return RecordingStateModel(
      state: state ?? this.state,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
    );
  }
}