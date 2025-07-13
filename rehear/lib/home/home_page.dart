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