// lib/models/audio_note.dart

class AudioNote {
  final String id;
  final String title;
  final String filePath;
  final DateTime creationDate;
  Duration? duration; // Will be set after loading with just_audio

  AudioNote({
    required this.id,
    required this.title,
    required this.filePath,
    required this.creationDate,
    this.duration,
  });

  // Example of a static method to create from a file path
  static Future<AudioNote> fromFilePath(String filePath) async {
    final fileName = filePath.split('/').last;
    final title = fileName.replaceAll('.m4a', '').replaceAll('rehear_audio_', '');
    // You might load the duration here using just_audio or other means
    // For simplicity, initially set duration to null or compute it later
    return AudioNote(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID for now
      title: 'Note $title',
      filePath: filePath,
      creationDate: DateTime.now(),
    );
  }

  AudioNote copyWith({
    String? id,
    String? title,
    String? filePath,
    DateTime? creationDate,
    Duration? duration,
  }) {
    return AudioNote(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      creationDate: creationDate ?? this.creationDate,
      duration: duration ?? this.duration,
    );
  }
}