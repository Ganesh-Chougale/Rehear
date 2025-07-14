import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_note.dart';
import '../services/file_storage_service.dart';
import '../services/audio_playback_service.dart';
import './audio_playback_provider.dart'; // Import the provider itself

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

final notesListProvider = StateNotifierProvider<NotesListNotifier, List<AudioNote>>((ref) {
  final fileStorageService = ref.read(fileStorageServiceProvider);
  final audioPlaybackService = ref.read(audioPlaybackServiceProvider); // Correct access
  return NotesListNotifier(fileStorageService, audioPlaybackService);
});

class NotesListNotifier extends StateNotifier<List<AudioNote>> {
  final FileStorageService _fileStorageService;
  final AudioPlaybackService _audioPlaybackService;

  NotesListNotifier(this._fileStorageService, this._audioPlaybackService) : super([]);

  Future<void> loadNotes() async {
    final filePaths = await _fileStorageService.getAudioFilePaths();
    final List<AudioNote> loadedNotes = [];
    for (final path in filePaths) {
      final note = await AudioNote.fromFilePath(path);
      try {
        await _audioPlaybackService.setFilePath(path); // Method name fix
        note.duration = _audioPlaybackService.totalDuration;
        await _audioPlaybackService.stopAudio();
      } catch (e) {
        print("Could not load duration for ${note.title}: $e");
        note.duration = null;
      }
      loadedNotes.add(note);
    }
    state = loadedNotes;
  }

  Future<void> addNote(String sourceFilePath, {String? customFileName}) async {
    final savedPath = await _fileStorageService.saveAudioFile(sourceFilePath, customFileName: customFileName);
    final newNote = await AudioNote.fromFilePath(savedPath);
    try {
      await _audioPlaybackService.setFilePath(savedPath); // Method name fix
      newNote.duration = _audioPlaybackService.totalDuration;
      await _audioPlaybackService.stopAudio();
    } catch (e) {
      print("Could not load duration for new note ${newNote.title}: $e");
      newNote.duration = null;
    }
    state = [...state, newNote];
  }

  Future<void> deleteNote(String id) async {
    final noteToDeleteIndex = state.indexWhere((note) => note.id == id);
    if (noteToDeleteIndex != -1) {
      final noteToDelete = state[noteToDeleteIndex];
      try {
        await _fileStorageService.deleteAudioFile(noteToDelete.filePath);
        state = state.where((note) => note.id != id).toList();
        print('Note and file deleted: ${noteToDelete.title}');
      } catch (e) {
        print('Failed to delete note file: $e');
      }
    }
  }

  void updateNoteDuration(String id, Duration duration) {
    state = [
      for (final note in state)
        if (note.id == id) note.copyWith(duration: duration) else note,
    ];
  }
}