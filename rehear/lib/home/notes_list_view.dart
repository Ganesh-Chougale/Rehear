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