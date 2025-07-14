import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

enum PlaybackState { stopped, playing, paused, loading, buffering }

class AudioPlaybackService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentPlayingPath;

  // Use BehaviorSubject for streams that need a 'current value' or initial value
  final BehaviorSubject<PlayerState> _playerStateSubject = BehaviorSubject<PlayerState>();
  final BehaviorSubject<Duration> _positionSubject = BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration?> _durationSubject = BehaviorSubject<Duration?>.seeded(null);


  AudioPlaybackService() {
    _audioPlayer.playerStateStream.listen((playerState) {
      print('PlayerState:${playerState.playing ? "Playing" : "Paused"},ProcessingState:${playerState.processingState.name}');
      _playerStateSubject.add(playerState); // Add to our BehaviorSubject
    });

    _audioPlayer.positionStream.listen((position) {
      _positionSubject.add(position); // Add to our BehaviorSubject
    });

    _audioPlayer.durationStream.listen((duration) {
      _durationSubject.add(duration); // Add to our BehaviorSubject
    });

    _audioPlayer.sequenceStateStream.listen((sequenceState) {
      if (sequenceState?.currentSource == null && _audioPlayer.processingState == ProcessingState.completed) {
        print('Playback completed.');
        _currentPlayingPath = null;
      }
    });
  }

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

  Duration get currentPosition => _audioPlayer.position;
  Duration? get totalDuration => _audioPlayer.duration;
  String? get currentPlayingPath => _currentPlayingPath;

  // Added setFilePath method as it was missing
  Future<void> setFilePath(String filePath) async {
    if (_currentPlayingPath != filePath) {
      await _audioPlayer.setFilePath(filePath);
      _currentPlayingPath = filePath;
      print('AudioPlaybackService: File path set to $filePath');
    }
  }

  // Modified playAudio to accept optional initialPosition
  Future<void> playAudio(String filePath, {Duration? initialPosition}) async {
    try {
      if (_currentPlayingPath != filePath) {
        await _audioPlayer.setFilePath(filePath);
        _currentPlayingPath = filePath;
      }
      if (initialPosition != null) {
        await _audioPlayer.seek(initialPosition);
        print('Playing: $filePath from initial position: $initialPosition');
      } else {
        await _audioPlayer.play();
        print('Playing: $filePath');
      }
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
    print('Playback paused.');
  }

  Future<void> resumeAudio() async {
    await _audioPlayer.play();
    print('Playback resumed.');
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
    _currentPlayingPath = null;
    print('Playback stopped.');
  }

  // Added seekAudio method as it was missing
  Future<void> seekAudio(Duration position) async {
    await _audioPlayer.seek(position);
    print('Seeked to: $position');
  }


  Future<void> dispose() async {
    await _audioPlayer.dispose();
    _playerStateSubject.close();
    _positionSubject.close();
    _durationSubject.close();
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

  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration?> get durationStream => _durationSubject.stream;
}