// lib/audio_editing/audio_editor_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'waveform_display.dart'; // Your waveform widget
import 'time_ruler.dart'; // Your time ruler widget
import 'playback_cursor.dart'; // Your new playback cursor widget
import '../services/audio_playback_service.dart';

final waveformPlayerControllerProvider = Provider.autoDispose<PlayerController>((ref) {
  final controller = PlayerController();
  ref.onDispose(() {
    controller.dispose();
  });
  return controller;
});

class AudioEditorPage extends ConsumerStatefulWidget {
  final String audioFilePath;

  const AudioEditorPage({super.key, required this.audioFilePath});

  @override
  ConsumerState<AudioEditorPage> createState() => _AudioEditorPageState();
}

class _AudioEditorPageState extends ConsumerState<AudioEditorPage> {
  late PlayerController _waveformPlayerController;
  late AudioPlaybackService _justAudioService;
  late ScrollController _scrollController; // Controller for horizontal scrolling

  final double _waveformVisualScale = 200.0; // Pixels per second
  Duration _totalAudioDuration = Duration.zero; // To hold the actual duration of the audio

  // Track the current playback position from just_audio
  Duration _currentPlaybackPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _waveformPlayerController = ref.read(waveformPlayerControllerProvider);
    _justAudioService = ref.read(audioPlaybackServiceProvider);
    _scrollController = ScrollController();

    _initializeAudioDuration();

    // Listen to playback position updates
    _justAudioService.positionStream.listen((position) {
      if (_justAudioService.currentPlayingPath == widget.audioFilePath) {
        setState(() {
          _currentPlaybackPosition = position;
        });
        // Sync waveform player position
        _waveformPlayerController.seek(position.inMilliseconds);

        // Auto-scroll the waveform to follow the playback cursor
        _scrollToPlaybackPosition(position);
      }
    });

    // Listen to playback state changes
    _justAudioService.playerStateStream.listen((playerState) {
      if (_justAudioService.currentPlayingPath == widget.audioFilePath) {
        if (playerState.playing && _waveformPlayerController.playerState != PlayerState.playing) {
          _waveformPlayerController.startPlayer();
        } else if (!playerState.playing && _waveformPlayerController.playerState == PlayerState.playing) {
          _waveformPlayerController.pausePlayer();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeAudioDuration() async {
    await _justAudioService.setFilePath(widget.audioFilePath);
    final duration = _justAudioService.totalDuration;
    if (duration != null) {
      setState(() {
        _totalAudioDuration = duration;
      });
      print('AudioEditorPage: Total audio duration: $_totalAudioDuration'); // Debug
    } else {
      print('AudioEditorPage: Could not get total audio duration.'); // Debug
    }
  }

  void _scrollToPlaybackPosition(Duration currentPosition) {
    final double positionInSeconds = currentPosition.inMilliseconds / 1000.0;
    final double pixelsToScroll = positionInSeconds * _waveformVisualScale;

    final double screenWidth = MediaQuery.of(context).size.width;
    // Aim to keep the cursor roughly in the center of the visible area
    double targetScroll = pixelsToScroll - (screenWidth / 2);

    final double maxScrollExtent = _scrollController.position.maxScrollExtent;
    final double minScrollExtent = _scrollController.position.minScrollExtent;

    targetScroll = targetScroll.clamp(minScrollExtent, maxScrollExtent);

    // Only animate if the difference is significant to avoid jitter
    if ((_scrollController.offset - targetScroll).abs() > (screenWidth * 0.1)) { // Scroll if cursor is near edges
       _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      print('AudioEditorPage: Auto-scrolling to $targetScroll'); // Debug
    }
  }

  Future<void> _togglePlayback() async {
    print('AudioEditorPage: Toggling playback...'); // Debug
    if (_justAudioService.currentPlayingPath != widget.audioFilePath) {
      await _justAudioService.playAudio(widget.audioFilePath, initialPosition: _currentPlaybackPosition);
      print('AudioEditorPage: Playing from initial position: $_currentPlaybackPosition'); // Debug
    } else if (_justAudioService.currentPlaybackState == PlaybackState.playing) {
      await _justAudioService.pauseAudio();
      print('AudioEditorPage: Paused playback.'); // Debug
    } else if (_justAudioService.currentPlaybackState == PlaybackState.paused) {
      await _justAudioService.resumeAudio();
      print('AudioEditorPage: Resumed playback.'); // Debug
    } else {
      await _justAudioService.playAudio(widget.audioFilePath, initialPosition: _currentPlaybackPosition);
      print('AudioEditorPage: Starting playback from beginning or previous stop: $_currentPlaybackPosition'); // Debug
    }
  }

  // New callback for when the cursor is dragged
  void _onCursorSeek(Duration newPosition) {
    print('AudioEditorPage: Cursor dragged to $newPosition'); // Debug
    _justAudioService.seekAudio(newPosition);
    setState(() {
      _currentPlaybackPosition = newPosition; // Update local state immediately
    });
  }

  @override
  Widget build(BuildContext context) {
    final justAudioPlayerState = ref.watch(audioPlaybackServiceProvider.select((service) => service.playerStateStream));
    final isPlayingThisFile = ref.watch(audioPlaybackServiceProvider.select((service) => service.currentPlayingPath)) == widget.audioFilePath;
    final isPlaying = isPlayingThisFile && (justAudioPlayerState.value?.playing ?? false);

    final double calculatedWaveformWidth = _totalAudioDuration.inSeconds * _waveformVisualScale;
    final double minWaveformWidth = MediaQuery.of(context).size.width;
    final double finalWaveformWidth = (calculatedWaveformWidth > minWaveformWidth) ? calculatedWaveformWidth : minWaveformWidth;

    // Define the combined height for the ruler and waveform for the cursor
    const double combinedDisplayHeight = 30 + 100; // Ruler height + Waveform height

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Audio Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // Implement save functionality here
              print('Save button pressed'); // Debug
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Use a Stack to overlay the cursor on top of the scrollable content
          SizedBox(
            height: combinedDisplayHeight, // Explicit height for the Stack area
            child: Stack(
              children: [
                // Scrollable content (Time Ruler and Waveform)
                SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      TimeRuler(
                        waveformWidth: finalWaveformWidth,
                        totalDuration: _totalAudioDuration,
                      ),
                      WaveformDisplay(
                        audioFilePath: widget.audioFilePath,
                        playerController: _waveformPlayerController,
                        waveformWidth: finalWaveformWidth, // Pass the calculated width
                      ),
                    ],
                  ),
                ),
                // Playback Cursor, positioned absolutely within the Stack
                PlaybackCursor(
                  waveformWidth: finalWaveformWidth,
                  waveformHeight: combinedDisplayHeight, // Cursor spans both ruler and waveform
                  visualScale: _waveformVisualScale,
                  onSeek: _onCursorSeek,
                ),
              ],
            ),
          ),
          // Playback controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 50,
                  icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  onPressed: _togglePlayback,
                ),
                IconButton(
                  iconSize: 50,
                  icon: const Icon(Icons.stop_circle_filled),
                  onPressed: () async {
                    if (isPlayingThisFile) {
                      await _justAudioService.stopAudio();
                      setState(() {
                        _currentPlaybackPosition = Duration.zero; // Reset cursor on stop
                      });
                      print('AudioEditorPage: Stopped playback, cursor reset.'); // Debug
                    }
                  },
                ),
              ],
            ),
          ),
          // Display current playback position
          Text(
            'Current Position: ${_justAudioService.formatDuration(_currentPlaybackPosition)} / ${_justAudioService.formatDuration(_totalAudioDuration)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          // Other editing tools will go here (timeline, clip manager etc.)
        ],
      ),
    );
  }
}