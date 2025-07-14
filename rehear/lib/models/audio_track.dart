// lib/models/audio_track.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_clip.dart';

class AudioTrack {
  final String id;
  final String name;
  final List<AudioClip> clips;
  bool isMuted;
  bool isSoloed;
  double volume;
  double pan;

  AudioTrack({
    String? id,
    required this.name,
    List<AudioClip>? clips,
    this.isMuted = false,
    this.isSoloed = false,
    this.volume = 1.0,
    this.pan = 0.0,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        clips = clips ?? [];

  // Create a copy with updated properties
  AudioTrack copyWith({
    String? id,
    String? name,
    List<AudioClip>? clips,
    bool? isMuted,
    bool? isSoloed,
    double? volume,
    double? pan,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      clips: clips ?? List.from(this.clips),
      isMuted: isMuted ?? this.isMuted,
      isSoloed: isSoloed ?? this.isSoloed,
      volume: volume ?? this.volume,
      pan: pan ?? this.pan,
    );
  }

  // Add a clip to this track
  AudioTrack addClip(AudioClip clip) {
    if (clips.any((c) => _clipsOverlap(c, clip))) {
      throw Exception('Clips cannot overlap on the same track');
    }
    final newClips = List<AudioClip>.from(clips)..add(clip);
    return copyWith(clips: newClips);
  }

  // Remove a clip from this track
  AudioTrack removeClip(String clipId) {
    return copyWith(
      clips: clips.where((clip) => clip.id != clipId).toList(),
    );
  }

  // Update a clip in this track
  AudioTrack updateClip(String clipId, AudioClip Function(AudioClip) update) {
    final index = clips.indexWhere((clip) => clip.id == clipId);
    if (index == -1) return this;
    
    final updatedClips = List<AudioClip>.from(clips);
    updatedClips[index] = update(updatedClips[index]);
    
    return copyWith(clips: updatedClips);
  }

  // Move a clip to a new position
  AudioTrack moveClip(String clipId, Duration newStartTime) {
    return updateClip(clipId, (clip) {
      return clip.copyWith(startTime: newStartTime);
    });
  }

  // Check if two clips overlap
  bool _clipsOverlap(AudioClip a, AudioClip b) {
    return a.startTime < b.endTime && b.startTime < a.endTime;
  }

  // Get the end time of the last clip in the track
  Duration get endTime {
    if (clips.isEmpty) return Duration.zero;
    return clips.map((clip) => clip.endTime).reduce((a, b) => a > b ? a : b);
  }

  // Convert to/from JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clips': clips.map((clip) => clip.toJson()).toList(),
      'isMuted': isMuted,
      'isSoloed': isSoloed,
      'volume': volume,
      'pan': pan,
    };
  }

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id'],
      name: json['name'],
      clips: (json['clips'] as List)
          .map((clipJson) => AudioClip.fromJson(clipJson))
          .toList(),
      isMuted: json['isMuted'] ?? false,
      isSoloed: json['isSoloed'] ?? false,
      volume: (json['volume'] ?? 1.0).toDouble(),
      pan: (json['pan'] ?? 0.0).toDouble(),
    );
  }
}

// Riverpod provider for the audio editor state
final audioEditorProvider = StateNotifierProvider<AudioEditorNotifier, AudioProjectState>((ref) {
  return AudioEditorNotifier();
});

class AudioProjectState {
  final List<AudioTrack> tracks;
  final String? projectName;
  final Duration currentTime;
  final bool isPlaying;

  const AudioProjectState({
    this.tracks = const [],
    this.projectName,
    this.currentTime = Duration.zero,
    this.isPlaying = false,
  });

  AudioProjectState copyWith({
    List<AudioTrack>? tracks,
    String? projectName,
    Duration? currentTime,
    bool? isPlaying,
  }) {
    return AudioProjectState(
      tracks: tracks ?? this.tracks,
      projectName: projectName ?? this.projectName,
      currentTime: currentTime ?? this.currentTime,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  // Get the total duration of the project (end of the longest track)
  Duration get totalDuration {
    if (tracks.isEmpty) return Duration.zero;
    return tracks.map((track) => track.endTime).reduce((a, b) => a > b ? a : b);
  }
}

class AudioEditorNotifier extends StateNotifier<AudioProjectState> {
  AudioEditorNotifier() : super(const AudioProjectState());

  // Add a new empty track
  void addTrack({String? name}) {
    final trackName = name ?? 'Track ${state.tracks.length + 1}';
    state = state.copyWith(
      tracks: [...state.tracks, AudioTrack(name: trackName)],
    );
  }

  // Remove a track by ID
  void removeTrack(String trackId) {
    state = state.copyWith(
      tracks: state.tracks.where((track) => track.id != trackId).toList(),
    );
  }

  // Add a clip to a track
  void addClip({
    required String trackId,
    required AudioClip clip,
  }) {
    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == trackId) {
          return track.addClip(clip);
        }
        return track;
      }).toList(),
    );
  }

  // Remove a clip from a track
  void removeClip({
    required String trackId,
    required String clipId,
  }) {
    state = state.copyWith(
      tracks: state.tracks.map((track) {
        if (track.id == trackId) {
          return track.removeClip(clipId);
        }
        return track;
      }).toList(),
    );
  }

  // Move a clip within or between tracks
  void moveClip({
    required String sourceTrackId,
    required String clipId,
    String? targetTrackId,
    required Duration newStartTime,
  }) {
    final targetId = targetTrackId ?? sourceTrackId;
    
    // If moving between tracks, remove from source and add to target
    if (sourceTrackId != targetId) {
      // Find the clip being moved
      AudioClip? movingClip;
      for (final track in state.tracks) {
        if (track.id == sourceTrackId) {
          movingClip = track.clips.firstWhere((clip) => clip.id == clipId);
          break;
        }
      }
      
      if (movingClip != null) {
        // Update the clip's start time
        movingClip = movingClip.copyWith(startTime: newStartTime);
        
        // Remove from source track and add to target track
        state = state.copyWith(
          tracks: state.tracks.map((track) {
            if (track.id == sourceTrackId) {
              return track.removeClip(clipId);
            } else if (track.id == targetId) {
              return track.addClip(movingClip!);
            }
            return track;
          }).toList(),
        );
      }
    } else {
      // Moving within the same track
      state = state.copyWith(
        tracks: state.tracks.map((track) {
          if (track.id == sourceTrackId) {
            return track.moveClip(clipId, newStartTime);
          }
          return track;
        }).toList(),
      );
    }
  }

  // Update playback state
  void setPlaybackState(bool isPlaying) {
    state = state.copyWith(isPlaying: isPlaying);
  }

  // Update current playback time
  void setCurrentTime(Duration time) {
    state = state.copyWith(currentTime: time);
  }
}