// lib/providers/notes_list_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_note.dart';
import '../services/file_storage_service.dart'; // Import the new service
import '../services/audio_playback_service.dart'; // To potentially get duration

// Provider for the FileStorageService instance
final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService();
});

final notesListProvider = StateNotifierProvider<NotesListNotifier, List<AudioNote>>((ref) {
  final fileStorageService = ref.read(fileStorageServiceProvider);
  final audioPlaybackService = ref.read(audioPlaybackServiceProvider); // Also read playback service
  return NotesListNotifier(fileStorageService, audioPlaybackService);
});

class NotesListNotifier extends StateNotifier<List<AudioNote>> {
  final FileStorageService _fileStorageService;
  final AudioPlaybackService _audioPlaybackService; // Inject playback service

  NotesListNotifier(this._fileStorageService, this._audioPlaybackService) : super([]);

  // Load existing notes from storage
  Future<void> loadNotes() async {
    final filePaths = await _fileStorageService.getAudioFilePaths();
    final List<AudioNote> loadedNotes = [];
    for (final path in filePaths) {
      final note = await AudioNote.fromFilePath(path);
      // Try to get duration immediately if possible for better UX
      try {
        await _audioPlaybackService.setFilePath(path); // Temporarily load to get duration
        note.duration = _audioPlaybackService.totalDuration;
        await _audioPlaybackService.stopAudio(); // Stop after getting duration
      } catch (e) {
        print("Could not load duration for ${note.title}: $e");
        note.duration = null; // Mark as unknown duration
      }
      loadedNotes.add(note);
    }
    state = loadedNotes;
  }

  // Add a new note after recording or importing
  Future<void> addNote(String sourceFilePath, {String? customFileName}) async {
    final savedPath = await _fileStorageService.saveAudioFile(sourceFilePath, customFileName: customFileName);
    final newNote = await AudioNote.fromFilePath(savedPath);

    // Try to get duration for the newly added note
    try {
      await _audioPlaybackService.setFilePath(savedPath);
      newNote.duration = _audioPlaybackService.totalDuration;
      await _audioPlaybackService.stopAudio();
    } catch (e) {
      print("Could not load duration for new note ${newNote.title}: $e");
      newNote.duration = null;
    }
    
    state = [...state, newNote];
  }

  // Remove a note and its corresponding file
  Future<void> deleteNote(String id) async {
    final noteToDeleteIndex = state.indexWhere((note) => note.id == id);
    if (noteToDeleteIndex != -1) {
      final noteToDelete = state[noteToDeleteIndex];
      try {
        await _fileStorageService.deleteAudioFile(noteToDelete.filePath);
        state = state.where((note) => note.id != id).toList(); // Remove from state
        print('Note and file deleted: ${noteToDelete.title}');
      } catch (e) {
        print('Failed to delete note file: $e');
        // Optionally, don't remove from state if file deletion failed
      }
    }
  }

  // Update a note's duration (e.g., if loaded asynchronously in UI)
  void updateNoteDuration(String id, Duration duration) {
    state = [
      for (final note in state)
        if (note.id == id) note.copyWith(duration: duration) else note,
    ];
  }
}