// lib/models/audio_track.dart

import 'package:uuid/uuid.dart';
import 'audio_clip.dart'; // Import the AudioClip model

class AudioTrack {
  final String id; // Unique ID for the track
  final String name; // Name of the track (e.g., "Voice 1", "Music")
  final List<AudioClip> clips; // List of audio clips on this track

  AudioTrack({
    String? id,
    required this.name,
    this.clips = const [],
  }) : id = id ?? const Uuid().v4();

  AudioTrack copyWith({
    String? id,
    String? name,
    List<AudioClip>? clips,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      clips: clips ?? this.clips,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'clips': clips.map((clip) => clip.toJson()).toList(),
    };
  }

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id'],
      name: json['name'],
      clips: (json['clips'] as List)
          .map((clipJson) => AudioClip.fromJson(clipJson))
          .toList(),
    );
  }
}