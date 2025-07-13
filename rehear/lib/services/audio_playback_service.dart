// lib/services/audio_playback_service.dart

import 'package:just_audio/just_audio.dart'; // Import just_audio package
import 'package:rxdart/rxdart.dart'; // For combining streams if needed (e.g., player state)

enum PlaybackState { stopped, playing, paused, loading, buffering }

class AudioPlaybackService {
  final AudioPlayer _audioPlayer = AudioPlayer(); // Instance of AudioPlayer
  String? _currentPlayingPath; // Path of the currently loaded/playing audio

  AudioPlaybackService() {
    // Listen to changes in player state and position
    _audioPlayer.playerStateStream.listen((playerState) {
      // You can expose this stream via a BehaviorSubject for Riverpod to consume
      // For now, we'll just print for demonstration
      print('Player State: ${playerState.playing ? "Playing" : "Paused"}, Processing State: ${playerState.processingState.name}');
    });

    _audioPlayer.positionStream.listen((position) {
      // Current playback position
      // print('Current Position: $position');
    });

    // Listen to completion of playback
    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState?.currentSource == null && _audioPlayer.processingState == ProcessingState.completed) {
        print('Playback completed.');
        // Optionally reset internal state or notify UI
        _currentPlayingPath = null;
      }
    });
  }

  // Get current playback state
  PlaybackState get currentPlaybackState {
    if (_audioPlayer.processingState == ProcessingState.idle) {
      return PlaybackState.stopped;
    } else if (_audioPlayer.processingState == ProcessingState.loading || _audioPlayer.processingState == ProcessingState.buffering) {
      return PlaybackState.loading;
    } else if (_audioPlayer.playing) {
      return PlaybackState.playing;
    } else {
      return PlaybackState.paused;
    }
  }

  // Get current playback position
  Duration get currentPosition => _audioPlayer.position;

  // Get total duration of the current audio
  Duration? get totalDuration => _audioPlayer.duration;

  // Get the path of the currently playing audio
  String? get currentPlayingPath => _currentPlayingPath;

  // Load and play an audio file
  Future<void> playAudio(String filePath) async {
    try {
      if (_currentPlayingPath != filePath) {
        // If a different file is selected, load it
        await _audioPlayer.setFilePath(filePath);
        _currentPlayingPath = filePath;
      }
      // Play from current position or start
      await _audioPlayer.play();
      print('Playing: $filePath');
    } catch (e) {
      print("Error playing audio: $e");
      // Handle errors, e.g., file not found, permission denied
    }
  }

  // Pause playback
  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
    print('Playback paused.');
  }

  // Resume playback
  Future<void> resumeAudio() async {
    await _audioPlayer.play(); // just_audio uses play() to resume from pause
    print('Playback resumed.');
  }

  // Stop playback (resets position to start)
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _currentPlayingPath = null; // Clear current path
    print('Playback stopped.');
  }

  // Seek to a specific position
  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
    print('Seeked to: $position');
  }

  // Dispose of the audio player (important to release resources)
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    print('AudioPlaybackService disposed.');
  }

    String formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  // You can expose streams for UI updates
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
}