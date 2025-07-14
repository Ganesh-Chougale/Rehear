import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_track.dart';
import '../models/audio_clip.dart';
import '../services/audio_playback_service.dart';
import './audio_playback_provider.dart'; // Import the provider itself

class AudioProjectState {
  final List<AudioTrack> tracks;
  final Duration totalProjectDuration; // Maximum duration across all tracks/clips
  final bool isLoading;
  final String? error;

  AudioProjectState({
    required this.tracks,
    required this.totalProjectDuration,
    this.isLoading = false,
    this.error,
  });

  AudioProjectState copyWith({
    List<AudioTrack>? tracks,
    Duration? totalProjectDuration,
    bool? isLoading,
    String? error,
  }) {
    return AudioProjectState(
      tracks: tracks ?? this.tracks,
      totalProjectDuration: totalProjectDuration ?? this.totalProjectDuration,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

final audioEditorProvider = StateNotifierProvider<AudioEditorNotifier, AudioProjectState>((ref) {
  final audioPlaybackService = ref.read(audioPlaybackServiceProvider); // Correct access
  return AudioEditorNotifier(audioPlaybackService);
});

class AudioEditorNotifier extends StateNotifier<AudioProjectState> {
  final AudioPlaybackService _audioPlaybackService;
  final List<AudioProjectState> _history = [];
  final List<AudioProjectState> _redoStack = [];
  static const int _maxHistory = 50;

  AudioEditorNotifier(this._audioPlaybackService)
      : super(AudioProjectState(tracks: [], totalProjectDuration: Duration.zero));

  // Save current state to history before making changes
  void _saveToHistory() {
    _history.add(state);
    _redoStack.clear(); // Clear redo stack when new action is performed
    
    // Limit history size
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }

  // Undo the last action
  void undo() {
    if (_history.isEmpty) return;
    
    final previousState = _history.removeLast();
    _redoStack.add(state);
    state = previousState;
  }

  // Redo the last undone action
  void redo() {
    if (_redoStack.isEmpty) return;
    
    final nextState = _redoStack.removeLast();
    _history.add(state);
    state = nextState;
  }

  // Load an initial audio file into the first track (e.g., from Home Page)
  Future<void> loadProjectFromAudioFile(String filePath) async {
    _saveToHistory();
    // For simplicity, let's create a single track with one clip
    await _audioPlaybackService.setFilePath(filePath); // Method name fix
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
      totalProjectDuration: duration, // Initial project duration is just this clip's duration
    );
    print('AudioEditorNotifier: Loaded project with initial clip: ${initialClip.name}, duration: $duration');
  }

  // Add a new empty track
  void addTrack() {
    _saveToHistory();
    final newTrack = AudioTrack(name: 'Track ${state.tracks.length + 1}');
    state = state.copyWith(tracks: [...state.tracks, newTrack]);
    print('AudioEditorNotifier: Added new track: ${newTrack.name}');
  }

  // Add a clip to a specific track
  // This will be used by drag/drop later, but we can manually add for now
  // This method seems to be missing from the provided code snippet but was mentioned in previous steps.
  // I will add a simplified version for completion here, assuming it's intended to exist.
  Future<void> addClipToTrack(String trackId, String sourceFilePath, {Duration? startTime}) async {
    _saveToHistory();
    final trackIndex = state.tracks.indexWhere((t) => t.id == trackId);
    if (trackIndex == -1) {
      print('AudioEditorNotifier: Error: Track with ID $trackId not found.');
      return;
    }

    await _audioPlaybackService.setFilePath(sourceFilePath); // Method name fix
    final clipDuration = _audioPlaybackService.totalDuration ?? Duration.zero;
    final fileName = sourceFilePath.split('/').last;

    final newClip = AudioClip(
      sourceFilePath: sourceFilePath,
      name: fileName,
      duration: clipDuration,
      startTime: startTime ?? Duration.zero,
      sourceOffset: Duration.zero, // For simplicity, assume whole file is used initially
    );

    final updatedClips = [...state.tracks[trackIndex].clips, newClip];
    final updatedTrack = state.tracks[trackIndex].copyWith(clips: updatedClips);

    final updatedTracks = List<AudioTrack>.from(state.tracks);
    updatedTracks[trackIndex] = updatedTrack;

    // Recalculate total project duration
    final newTotalProjectDuration = _calculateTotalProjectDuration(updatedTracks);

    state = state.copyWith(
      tracks: updatedTracks,
      totalProjectDuration: newTotalProjectDuration,
    );
    print('AudioEditorNotifier: Added clip "${newClip.name}" to track "${updatedTrack.name}". New project duration: $newTotalProjectDuration');
  }

  // Move a clip from one track to another
  void moveClip(String clipId, String fromTrackId, String toTrackId, Duration newStartTime) {
    _saveToHistory();
    print('AudioEditorNotifier: Attempting to move clip $clipId from $fromTrackId to $toTrackId at $newStartTime');
    AudioClip? movedClip;
    List<AudioTrack> updatedTracks = List.from(state.tracks);

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

    int toTrackIndex = updatedTracks.indexWhere((track) => track.id == toTrackId);
    if (toTrackIndex == -1) {
      print('Error: Target track $toTrackId not found for clip $clipId');
      return;
    }

    final updatedClip = movedClip.copyWith(startTime: newStartTime);
    final List<AudioClip> clipsInToTrack = List.from(updatedTracks[toTrackIndex].clips);
    clipsInToTrack.add(updatedClip);
    updatedTracks[toTrackIndex] = updatedTracks[toTrackIndex].copyWith(clips: clipsInToTrack);

    print('AudioEditorNotifier: Added clip ${updatedClip.name} to target track ${updatedTracks[toTrackIndex].name} at new start time $newStartTime');

    final newTotalProjectDuration = _calculateTotalProjectDuration(updatedTracks);

    state = state.copyWith(
      tracks: updatedTracks,
      totalProjectDuration: newTotalProjectDuration,
    );
    print('AudioEditorNotifier: Clip moved successfully. New project duration: $newTotalProjectDuration');
  }

  // Trim a clip to the specified time range
  void trimClip({
    required String trackId,
    required String clipId,
    required Duration newStart,
    required Duration newEnd,
  }) {
    _saveToHistory();
    
    final updatedTracks = List<AudioTrack>.from(state.tracks);
    final trackIndex = updatedTracks.indexWhere((t) => t.id == trackId);
    
    if (trackIndex == -1) return;
    
    final track = updatedTracks[trackIndex];
    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    
    if (clipIndex == -1) return;
    
    final clip = track.clips[clipIndex];
    final trimmedClip = clip.trim(newStart, newEnd);
    
    final updatedClips = List<AudioClip>.from(track.clips);
    updatedClips[clipIndex] = trimmedClip;
    
    updatedTracks[trackIndex] = track.copyWith(clips: updatedClips);
    
    state = state.copyWith(
      tracks: updatedTracks,
      totalProjectDuration: _calculateTotalProjectDuration(updatedTracks),
    );
  }
  
  // Split a clip at the specified time
  void splitClip({
    required String trackId,
    required String clipId,
    required Duration splitTime,
  }) async {
    _saveToHistory();
    
    final updatedTracks = List<AudioTrack>.from(state.tracks);
    final trackIndex = updatedTracks.indexWhere((t) => t.id == trackId);
    
    if (trackIndex == -1) return;
    
    final track = updatedTracks[trackIndex];
    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    
    if (clipIndex == -1) return;
    
    final clip = track.clips[clipIndex];
    final splitClips = clip.splitAt(splitTime);
    
    if (splitClips.length < 2) return;
    
    final updatedClips = List<AudioClip>.from(track.clips);
    updatedClips.removeAt(clipIndex);
    updatedClips.insertAll(clipIndex, splitClips);
    
    updatedTracks[trackIndex] = track.copyWith(clips: updatedClips);
    
    state = state.copyWith(
      tracks: updatedTracks,
      totalProjectDuration: _calculateTotalProjectDuration(updatedTracks),
    );
  }
  
  // Cut a section from a clip and create a new clip with the cut portion
  void cutClip({
    required String trackId,
    required String clipId,
    required Duration startCut,
    required Duration endCut,
  }) async {
    _saveToHistory();
    
    final updatedTracks = List<AudioTrack>.from(state.tracks);
    final trackIndex = updatedTracks.indexWhere((t) => t.id == trackId);
    
    if (trackIndex == -1) return;
    
    final track = updatedTracks[trackIndex];
    final clipIndex = track.clips.indexWhere((c) => c.id == clipId);
    
    if (clipIndex == -1) return;
    
    final clip = track.clips[clipIndex];
    
    // Create a new clip for the cut portion
    final cutClip = clip.trim(startCut, endCut);
    
    // Create a new clip for the portion after the cut
    final afterCutClip = clip.trim(endCut, clip.endTime);
    
    // Update the original clip to end at the cut start
    final updatedClip = clip.copyWith(endTime: startCut);
    
    final updatedClips = List<AudioClip>.from(track.clips);
    updatedClips[clipIndex] = updatedClip;
    
    // Insert the cut clip after the original clip
    updatedClips.insert(clipIndex + 1, cutClip);
    
    // If there's content after the cut, insert it as well
    if (afterCutClip.duration > Duration.zero) {
      updatedClips.insert(clipIndex + 2, afterCutClip);
    }
    
    updatedTracks[trackIndex] = track.copyWith(clips: updatedClips);
    
    state = state.copyWith(
      tracks: updatedTracks,
      totalProjectDuration: _calculateTotalProjectDuration(updatedTracks),
    );
  }
  
  // Apply the actual audio processing for trim/split operations
  Future<void> _applyAudioEdit({
    required String inputPath,
    required Duration start,
    required Duration end,
    required String outputPath,
  }) async {
    try {
      await AudioEditService.trimAudio(
        inputPath: inputPath,
        start: start,
        end: end,
        outputPath: outputPath,
      );
    } catch (e) {
      print('Error applying audio edit: $e');
      rethrow;
    }
  }

  // Merge selected clips
  Future<void> mergeSelectedClips({
    required String trackId,
    required List<String> clipIds,
    String? newClipName,
  }) async {
    _saveToHistory();
    
    final trackIndex = state.tracks.indexWhere((t) => t.id == trackId);
    if (trackIndex == -1) return;
    
    final track = state.tracks[trackIndex];
    final clipsToMerge = track.clips.where((c) => clipIds.contains(c.id)).toList();
    
    if (clipsToMerge.length < 2) return;
    
    // Sort clips by start time
    clipsToMerge.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    // Prepare merge parameters
    final inputPaths = <String>[];
    final startTimes = <Duration>[];
    final durations = <Duration>[];
    
    for (final clip in clipsToMerge) {
      inputPaths.add(clip.sourceFilePath);
      startTimes.add(clip.sourceOffset);
      durations.add(clip.duration);
    }
    
    // Generate a unique output filename
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFileName = 'merged_$timestamp.m4a';
    
    try {
      // Show loading indicator
      state = state.copyWith(isLoading: true);
      
      // Merge the clips
      final mergedPath = await AudioMergeService.mergeClips(
        inputPaths: inputPaths,
        outputFileName: outputFileName,
        startTimes: startTimes,
        durations: durations,
      );
      
      if (mergedPath == null) {
        throw Exception('Failed to merge clips');
      }
      
      // Calculate the new clip's parameters
      final firstClip = clipsToMerge.first;
      final lastClip = clipsToMerge.last;
      final totalDuration = lastClip.endTime - firstClip.startTime;
      
      // Create the new merged clip
      final mergedClip = AudioClip(
        sourceFilePath: mergedPath,
        name: newClipName ?? 'Merged Clip',
        duration: totalDuration,
        startTime: firstClip.startTime,
        sourceOffset: Duration.zero,
      );
      
      // Update the track with the new merged clip and remove the original clips
      final updatedClips = List<AudioClip>.from(track.clips);
      
      // Remove the original clips
      for (final clip in clipsToMerge) {
        updatedClips.removeWhere((c) => c.id == clip.id);
      }
      
      // Add the merged clip
      updatedClips.add(mergedClip);
      
      // Sort clips by start time
      updatedClips.sort((a, b) => a.startTime.compareTo(b.startTime));
      
      // Update the track
      final updatedTrack = track.copyWith(clips: updatedClips);
      final updatedTracks = List<AudioTrack>.from(state.tracks);
      updatedTracks[trackIndex] = updatedTrack;
      
      // Update the state
      state = state.copyWith(
        tracks: updatedTracks,
        totalProjectDuration: _calculateTotalProjectDuration(updatedTracks),
        isLoading: false,
      );
      
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to merge clips: $e',
        isLoading: false,
      );
      rethrow;
    }
  }

  // Merge selected clips into a single clip
  Future<void> mergeSelectedClipsNew(Set<String> selectedClipIds) async {
    if (selectedClipIds.length < 2) {
      // Need at least 2 clips to merge
      return;
    }

    _saveToHistory();
    
    try {
      // Find all selected clips across all tracks
      final List<AudioClip> clipsToMerge = [];
      String? trackId;
      int insertIndex = 0;
      Duration startTime = Duration.zero;

      // Find the earliest clip to determine the track and position for the merged clip
      for (final track in state.tracks) {
        for (int i = 0; i < track.clips.length; i++) {
          if (selectedClipIds.contains(track.clips[i].id)) {
            if (trackId == null || track.clips[i].startTime < startTime) {
              trackId = track.id;
              startTime = track.clips[i].startTime;
              insertIndex = i;
            }
            clipsToMerge.add(track.clips[i]);
          }
        }
      }

      if (trackId == null) return;

      // Sort clips by their start time
      clipsToMerge.sort((a, b) => a.startTime.compareTo(b.startTime));

      // Prepare inputs for the merge service
      final inputPaths = clipsToMerge.map((clip) => clip.sourceFilePath).toList();
      final startTimes = clipsToMerge.map((clip) => clip.sourceOffset).toList();
      final durations = clipsToMerge.map((clip) => clip.duration).toList();

      // Generate a unique output filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputFileName = 'merged_$timestamp.m4a';

      // Call the merge service
      final mergedFilePath = await AudioMergeService.mergeClips(
        inputPaths: inputPaths,
        outputFileName: outputFileName,
        startTimes: startTimes,
        durations: durations,
      );

      if (mergedFilePath == null) {
        throw Exception('Failed to merge audio clips');
      }

      // Create a new merged clip
      final totalDuration = clipsToMerge.fold<Duration>(
        Duration.zero,
        (sum, clip) => sum + clip.duration,
      );

      final mergedClip = AudioClip(
        sourceFilePath: mergedFilePath,
        name: 'Merged ${clipsToMerge.length} clips',
        duration: totalDuration,
        startTime: startTime,
        sourceOffset: Duration.zero,
      );

      // Remove the original clips and add the merged one
      final updatedTracks = state.tracks.map((track) {
        if (track.id == trackId) {
          // Remove all selected clips from this track
          final updatedClips = track.clips.where(
            (clip) => !selectedClipIds.contains(clip.id)
          ).toList();
          
          // Insert the merged clip at the position of the earliest clip
          updatedClips.insert(insertIndex, mergedClip);
          
          return track.copyWith(clips: updatedClips);
        }
        return track;
      }).toList();

      // Update the state
      state = state.copyWith(tracks: updatedTracks);
      
    } catch (e) {
      // Revert to previous state on error
      undo();
      rethrow;
    }
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
}