// lib/models/audio_clip.dart

import 'package:uuid/uuid.dart'; // For generating unique IDs

class AudioClip {
  final String id; // Unique ID for the clip
  final String sourceFilePath; // Path to the original audio file
  final String name; // Display name of the clip (e.g., from original file name)
  final Duration startTime; // Start time of the clip within the track
  final Duration duration; // Duration of the clip itself (how much of the source audio is used)
  final Duration sourceOffset; // Start time within the sourceFilePath (e.g., if you clip from 00:10 to 00:20 of source)

  AudioClip({
    String? id,
    required this.sourceFilePath,
    required this.name,
    this.startTime = Duration.zero,
    required this.duration,
    this.sourceOffset = Duration.zero,
  }) : id = id ?? const Uuid().v4(); // Generate UUID if not provided

  // For immutability and easy modification
  AudioClip copyWith({
    String? id,
    String? sourceFilePath,
    String? name,
    Duration? startTime,
    Duration? duration,
    Duration? sourceOffset,
  }) {
    return AudioClip(
      id: id ?? this.id,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      sourceOffset: sourceOffset ?? this.sourceOffset,
    );
  }

  // Convert to/from JSON for persistence (important for saving projects)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceFilePath': sourceFilePath,
      'name': name,
      'startTimeMs': startTime.inMilliseconds,
      'durationMs': duration.inMilliseconds,
      'sourceOffsetMs': sourceOffset.inMilliseconds,
    };
  }

  factory AudioClip.fromJson(Map<String, dynamic> json) {
    return AudioClip(
      id: json['id'],
      sourceFilePath: json['sourceFilePath'],
      name: json['name'],
      startTime: Duration(milliseconds: json['startTimeMs']),
      duration: Duration(milliseconds: json['durationMs']),
      sourceOffset: Duration(milliseconds: json['sourceOffsetMs']),
    );
  }
}