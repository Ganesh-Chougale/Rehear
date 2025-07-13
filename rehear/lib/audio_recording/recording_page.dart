// lib/audio_recording/recording_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recording_provider.dart';
import '../services/audio_recorder_service.dart'; // Import the enum

class RecordingPage extends ConsumerWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingNotifierProvider);
    final recordingNotifier = ref.read(recordingNotifierProvider.notifier);
    final audioRecorderService = ref.watch(audioRecorderServiceProvider); // Get service to listen to amplitude

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record New Note'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Recording State: ${recordingState.state.name.toUpperCase()}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            Text(
              // Format duration to MM:SS
              'Duration: ${recordingState.duration.inMinutes.toString().padLeft(2, '0')}:'
              '${(recordingState.duration.inSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),

            // Real-time Audio Level Indicator
            // Use StreamBuilder to react to amplitude changes
            StreamBuilder<double>(
              stream: audioRecorderService.onAmplitudeChanged,
              builder: (context, snapshot) {
                // Default to 0 if no data or not recording
                double amplitude = snapshot.hasData && recordingState.state == RecordingState.recording
                    ? snapshot.data!
                    : 0.0;

                // Normalize amplitude for a visual bar (e.g., scale from -60dB to 0dB)
                // A simple scaling might involve clamping and mapping to a 0-1 range
                double normalizedAmplitude = (amplitude.abs() / 60).clamp(0.0, 1.0); // Assuming max -60dB for quiet, 0dB for loud

                return Container(
                  width: 200,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: normalizedAmplitude,
                      child: Container(
                        color: Colors.red.withOpacity(0.7), // Visual bar color
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (recordingState.state == RecordingState.initial || recordingState.state == RecordingState.stopped)
                  FloatingActionButton(
                    heroTag: 'startBtn', // Unique heroTag
                    onPressed: () async {
                      await recordingNotifier.startRecording();
                    },
                    child: const Icon(Icons.mic),
                  ),
                if (recordingState.state == RecordingState.recording) ...[
                  FloatingActionButton(
                    heroTag: 'pauseBtn', // Unique heroTag
                    onPressed: () => recordingNotifier.pauseRecording(),
                    child: const Icon(Icons.pause),
                  ),
                  FloatingActionButton(
                    heroTag: 'stopBtn1', // Unique heroTag
                    onPressed: () async {
                      final filePath = await recordingNotifier.stopRecording();
                      if (filePath != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Recording saved to: $filePath')),
                        );
                        // Save the file path to your notes list
                      }
                    },
                    child: const Icon(Icons.stop),
                  ),
                ],
                if (recordingState.state == RecordingState.paused) ...[
                  FloatingActionButton(
                    heroTag: 'resumeBtn', // Unique heroTag
                    onPressed: () => recordingNotifier.resumeRecording(),
                    child: const Icon(Icons.play_arrow),
                  ),
                  FloatingActionButton(
                    heroTag: 'stopBtn2', // Unique heroTag
                    onPressed: () async {
                      final filePath = await recordingNotifier.stopRecording();
                      if (filePath != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Recording saved to: $filePath')),
                        );
                        // Save the file path to your notes list
                      }
                    },
                    child: const Icon(Icons.stop),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}