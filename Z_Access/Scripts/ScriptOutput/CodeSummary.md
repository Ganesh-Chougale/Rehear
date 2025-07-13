rehear\lib\home\home_page.dart:
```dart
// lib/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart'; // Import file_picker
import '../audio_recording/recording_page.dart';
import 'notes_list_view.dart';
import '../providers/notes_list_provider.dart';
import '../services/permission_service.dart'; // Import permission service
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}
class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notesListProvider.notifier).loadNotes();
    });
  }
  // Function to handle file picking
  Future<void> _pickAudioFile() async {
    // 1. Request storage permission
    final permissionService = ref.read(permissionServiceProvider); // Assuming you'll create this provider
    final granted = await permissionService.requestStoragePermission(context); // Pass context for dialogs
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied. Cannot import files.')),
      );
      return;
    }
    // 2. Use file_picker
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.audio, // Specify audio file type
        allowMultiple: false, // Allow only one file to be picked at a time
      );
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
      return;
    }
    if (result != null && result.files.single.path != null) {
      final String sourceFilePath = result.files.single.path!;
      final String fileName = result.files.single.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Importing "$fileName"...')),
      );
      try {
        // 3. Add the imported file to the notes list
        await ref.read(notesListProvider.notifier).addNote(sourceFilePath, customFileName: fileName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$fileName" imported successfully!')),
        );
      } catch (e) {
        print('Error adding imported file to notes: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import "$fileName": $e')),
        );
      }
    } else {
      // User canceled the picker
      print('File picking canceled.');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReHear Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open), // Icon for import
            onPressed: _pickAudioFile,
            tooltip: 'Import Audio',
          ),
        ],
      ),
      body: const NotesListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RecordingPage()),
          );
        },
        child: const Icon(Icons.mic), // Changed to mic for consistency with recording
        tooltip: 'Record New Note',
      ),
    );
  }
}
```

rehear\lib\home\notes_list_view.dart:
```dart
// lib/home/notes_list_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audio_note.dart';
import '../providers/notes_list_provider.dart';
import '../providers/audio_playback_provider.dart';
import '../services/audio_playback_service.dart';
import '../audio_editing/audio_editor_page.dart';
class NotesListView extends ConsumerWidget {
  const NotesListView({super.key});
  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$minutes:$seconds';
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesListProvider);
    final audioPlaybackService = ref.watch(audioPlaybackServiceProvider);
    final notesListNotifier = ref.read(notesListProvider.notifier);
    final playerState = ref.watch(audioPlaybackServiceProvider.select((service) => service.playerStateStream));
    final currentPlayingPath = ref.watch(audioPlaybackServiceProvider.select((service) => service.currentPlayingPath));
    return notes.isEmpty
        ? const Center(
            child: Text('No audio notes yet. Tap + to record one!'),
          )
        : ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              final isPlayingThisNote = currentPlayingPath == note.filePath;
              final isPlaying = isPlayingThisNote && (playerState.value?.playing ?? false);
              if (note.duration == null && audioPlaybackService.totalDuration != null && isPlayingThisNote) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(notesListProvider.notifier).updateNoteDuration(note.id, audioPlaybackService.totalDuration!);
                });
              }
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(note.title),
                  subtitle: Text(
                    '${note.creationDate.toLocal().toString().split(' ')[0]} - Duration: ${_formatDuration(note.duration)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.blue,
                          size: 30,
                        ),
                        onPressed: () async {
                          if (isPlayingThisNote && isPlaying) {
                            await audioPlaybackService.pauseAudio();
                          } else if (isPlayingThisNote && !isPlaying) {
                            await audioPlaybackService.resumeAudio();
                          } else {
                            await audioPlaybackService.playAudio(note.filePath);
                          }
                        },
                      ),
                      if (isPlayingThisNote)
                        IconButton(
                          icon: const Icon(Icons.stop),
                          onPressed: () => audioPlaybackService.stopAudio(),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          if (isPlayingThisNote) {
                            await audioPlaybackService.stopAudio();
                          }
                          final bool confirm = await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Note'),
                              content: Text('Are you sure you want to delete "${note.title}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ?? false;
                          if (confirm) {
                            await notesListNotifier.deleteNote(note.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Note "${note.title}" deleted.')),
                            );
                          }
                        },
                      ),
                      // Edit button navigates to AudioEditorPage
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          // Stop any current playback when navigating to editor
                          if (isPlayingThisNote) {
                            audioPlaybackService.stopAudio();
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AudioEditorPage(filePath: note.filePath),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
```

rehear\lib\main.dart:
```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import ProviderScope
import 'home/home_page.dart'; // Import your home page
void main() {
  runApp(
    // Wrap your app with ProviderScope to use Riverpod
    const ProviderScope(
      child: ReHearApp(),
    ),
  );
}
class ReHearApp extends StatelessWidget {
  const ReHearApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReHear', // Changed title to ReHear
      theme: ThemeData(
        primarySwatch: Colors.blue, // Using a primary color relevant to ReHear
      ),
      home: const HomePage(), // Your starting page
    );
  }
}
```

rehear\lib\models\marker.dart:
```dart

```

rehear\lib\providers\notes_list_provider.dart:
```dart
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
```

rehear\lib\providers\recording_provider.dart:
```dart
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
```

rehear\lib\services\file_storage_service.dart:
```dart
// lib/services/file_storage_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
class FileStorageService {
  // Get the directory where audio notes will be stored
  Future<Directory> get _localAudiosDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/ReHearAudios');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true); // Create if it doesn't exist
    }
    return audioDir;
  }
  // Save an audio file (e.g., from recording or import)
  // This method typically handles moving/copying a file to the app's designated directory
  Future<String> saveAudioFile(String sourceFilePath, {String? customFileName}) async {
    try {
      final localDir = await _localAudiosDirectory;
      final sourceFile = File(sourceFilePath);
      String fileName = customFileName ?? sourceFile.path.split('/').last;
      // Ensure unique filename if one with the same name already exists
      int counter = 0;
      String newFilePath = '${localDir.path}/$fileName';
      while (await File(newFilePath).exists()) {
        counter++;
        final nameWithoutExtension = fileName.split('.').first;
        final extension = fileName.split('.').last;
        newFilePath = '${localDir.path}/${nameWithoutExtension}_$counter.$extension';
      }
      final newFile = await sourceFile.copy(newFilePath);
      print('File saved to: ${newFile.path}');
      return newFile.path;
    } catch (e) {
      print('Error saving audio file: $e');
      rethrow;
    }
  }
  // Get a list of all audio file paths stored by the app
  Future<List<String>> getAudioFilePaths() async {
    try {
      final localDir = await _localAudiosDirectory;
      final List<String> filePaths = [];
      final entities = localDir.listSync(recursive: false); // List only direct children
      for (var entity in entities) {
        if (entity is File && _isAudioFile(entity.path)) {
          filePaths.add(entity.path);
        }
      }
      return filePaths;
    } catch (e) {
      print('Error getting audio file paths: $e');
      return [];
    }
  }
  // Delete an audio file
  Future<void> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('File deleted: $filePath');
      } else {
        print('File not found, cannot delete: $filePath');
      }
    } catch (e) {
      print('Error deleting audio file: $e');
      rethrow;
    }
  }
  // Helper to check if a file path indicates an audio file
  bool _isAudioFile(String path) {
    final lowerCasePath = path.toLowerCase();
    return lowerCasePath.endsWith('.m4a') ||
           lowerCasePath.endsWith('.mp3') ||
           lowerCasePath.endsWith('.wav') ||
           lowerCasePath.endsWith('.aac'); // Add other formats as needed
  }
}
```

rehear\lib\utils\app_constants.dart:
```dart

```

rehear\lib\utils\date_time_formatter.dart:
```dart

```

rehear\lib\widgets\app_bar_widgets.dart:
```dart

```

rehear\lib\widgets\custom_buttons.dart:
```dart

```

rehear\lib\widgets\shared_ui_components.dart:
```dart

```

