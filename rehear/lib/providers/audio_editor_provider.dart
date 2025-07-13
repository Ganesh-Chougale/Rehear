// lib/providers/audio_editor_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_track.dart';
import '../models/audio_clip.dart';
import '../services/audio_playback_service.dart';

class AudioProjectState {
  final List<AudioTrack> tracks;
  final Duration totalProjectDuration;

  AudioProjectState({
    required this.tracks,
    required this.totalProjectDuration,
  });

  AudioProjectState copyWith({
    List<AudioTrack>? tracks,
    Duration? totalProjectDuration,
  }) {
    return AudioProjectState(
      tracks: tracks ?? this.tracks,
      totalProjectDuration: totalProjectDuration ?? this.totalProjectDuration,
    );
  }
}

final audioEditorProvider = StateNotifierProvider<AudioEditorNotifier, AudioProjectState>((ref) {
  final audioPlaybackService = ref.read(audioPlaybackServiceProvider);
  return AudioEditorNotifier(audioPlaybackService);
});

class AudioEditorNotifier extends StateNotifier<AudioProjectState> {
  final AudioPlaybackService _audioPlaybackService;

  AudioEditorNotifier(this._audioPlaybackService)
      : super(AudioProjectState(tracks: [], totalProjectDuration: Duration.zero));

  Future<void> loadProjectFromAudioFile(String filePath) async {
    await _audioPlaybackService.setFilePath(filePath);
    final duration = _audioPlaybackService.totalDuration ?? Duration.zero;
    final fileName = filePath.split('/').last;

    final initialClip = AudioClip(
      sourceFilePath: filePath,
      name: fileName,
      duration: duration,
      startTime: Duration.zero,
      sourceOffset: Duration.zero,
    );

    final initialTrack = AudioTrack(
      name: 'Track 1',
      clips: [initialClip],
    );

    state = state.copyWith(
      tracks: [initialTrack],
      totalProjectDuration: duration,
    );
    print('AudioEditorNotifier: Loaded project with initial clip: ${initialClip.name}, duration: $duration');
  }

  void addTrack() {
    final newTrack = AudioTrack(name: 'Track ${state.tracks.length + 1}');
    state = state.copyWith(tracks: [...state.tracks, newTrack]);
    print('AudioEditorNotifier: Added new track: ${newTrack.name}');
  }

  // --- New method for drag and drop ---
  void moveClip(String clipId, String fromTrackId, String toTrackId, Duration newStartTime) {
    print('AudioEditorNotifier: Attempting to move clip $clipId from $fromTrackId to $toTrackId at $newStartTime');

    AudioClip? movedClip;
    List<AudioTrack> updatedTracks = List.from(state.tracks);

    // 1. Find and remove the clip from its original track
    int fromTrackIndex = updatedTracks.indexWhere((track) => track.id == fromTrackId);
    if (fromTrackIndex == -1) {
      print('Error: Source track $fromTrackId not found for clip $clipId');
      return;
    }

    final List<AudioClip> clipsInFromTrack = List.from(updatedTracks[fromTrackIndex].clips);
    int clipIndex = clipsInFromTrack.indexWhere((clip) => clip.id == clipId);

    if (clipIndex == -1) {
      print('Error: Clip $clipId not found in source track $fromTrackId');
      return;
    }

    movedClip = clipsInFromTrack.removeAt(clipIndex);
    updatedTracks[fromTrackIndex] = updatedTracks[fromTrackIndex].copyWith(clips: clipsInFromTrack);
    print('AudioEditorNotifier: Removed clip ${movedClip.name} from original track ${updatedTracks[fromTrackIndex].name}');


    // 2. Add the clip to the new track with the new start time
    int toTrackIndex = updatedTracks.indexWhere((track) => track.id == toTrackId);
    if (toTrackIndex == -1) {
      print('Error: Target track $toTrackId not found for clip $clipId');
      return;
    }

    // Create a new version of the clip with the updated start time
    final updatedClip = movedClip.copyWith(startTime: newStartTime);
    final List<AudioClip> clipsInToTrack = List.from(updatedTracks[toTrackIndex].clips);
    clipsInToTrack.add(updatedClip); // Add the updated clip
    updatedTracks[toTrackIndex] = updatedTracks[toTrackIndex].copyWith(clips: clipsInToTrack);
    print('AudioEditorNotifier: Added clip ${updatedClip.name} to target track ${updatedTracks[toTrackIndex].name} at new start time $newStartTime');


    // 3. Recalculate total project duration
    final newTotalProjectDuration = _calculateTotalProjectDuration(updatedTracks);

    state = state.copyWith(
      tracks: updatedTracks,
      totalProjectDuration: newTotalProjectDuration,
    );
    print('AudioEditorNotifier: Clip moved successfully. New project duration: $newTotalProjectDuration');
  }

  Duration _calculateTotalProjectDuration(List<AudioTrack> tracks) {
    Duration maxDuration = Duration.zero;
    for (final track in tracks) {
      for (final clip in track.clips) {
        final clipEndTime = clip.startTime + clip.duration;
        if (clipEndTime > maxDuration) {
          maxDuration = clipEndTime;
        }
      }
    }
    return maxDuration;
  }

  // Future methods: removeClip, resizeClip, etc.
}