// lib/audio_editing/audio_editor_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'waveform_display.dart';
import 'time_ruler.dart';
import 'playback_cursor.dart';
import '../services/audio_playback_service.dart';
import '../providers/audio_editor_provider.dart';
import '../models/audio_track.dart';
import '../models/audio_clip.dart';
import 'dart:async'; // For Completer

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
  late ScrollController _scrollController;

  double _waveformVisualScale = 200.0;
  Duration _currentPlaybackPosition = Duration.zero;

  static const double _minZoomScale = 50.0;
  static const double _maxZoomScale = 1000.0;
  static const double _zoomStep = 50.0;

  // Track the ID of the clip currently being dragged
  String? _draggingClipId;
  // Track the original track ID and start time of the clip being dragged
  String? _originalClipTrackId;
  Duration? _originalClipStartTime;


  @override
  void initState() {
    super.initState();
    _waveformPlayerController = ref.read(waveformPlayerControllerProvider);
    _justAudioService = ref.read(audioPlaybackServiceProvider);
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioEditorProvider.notifier).loadProjectFromAudioFile(widget.audioFilePath);
    });

    _justAudioService.positionStream.listen((position) {
      final audioProjectState = ref.read(audioEditorProvider);
      // More robust check for current playing file in a multi-track setup (simplified for now)
      if (audioProjectState.tracks.isNotEmpty && audioProjectState.tracks.first.clips.isNotEmpty &&
          _justAudioService.currentPlayingPath == audioProjectState.tracks.first.clips.first.sourceFilePath) {
        setState(() {
          _currentPlaybackPosition = position;
        });
        _waveformPlayerController.seek(position.inMilliseconds);
        _scrollToPlaybackPosition(position);
      }
    });

    _justAudioService.playerStateStream.listen((playerState) {
      final audioProjectState = ref.read(audioEditorProvider);
      if (audioProjectState.tracks.isNotEmpty && audioProjectState.tracks.first.clips.isNotEmpty &&
          _justAudioService.currentPlayingPath == audioProjectState.tracks.first.clips.first.sourceFilePath) {
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

  void _scrollToPlaybackPosition(Duration currentPosition) {
    final double positionInSeconds = currentPosition.inMilliseconds / 1000.0;
    final double pixelsToScroll = positionInSeconds * _waveformVisualScale;

    final double screenWidth = MediaQuery.of(context).size.width;
    double targetScroll = pixelsToScroll - (screenWidth / 2);

    final double maxScrollExtent = _scrollController.position.hasClients ? _scrollController.position.maxScrollExtent : 0.0;
    final double minScrollExtent = _scrollController.position.hasClients ? _scrollController.position.minScrollExtent : 0.0;

    targetScroll = targetScroll.clamp(minScrollExtent, maxScrollExtent);

    if (_scrollController.position.hasClients && (_scrollController.offset - targetScroll).abs() > (screenWidth * 0.1)) {
       _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      print('AudioEditorPage: Auto-scrolling to $targetScroll');
    }
  }

  void _zoomIn() {
    setState(() {
      _waveformVisualScale = (_waveformVisualScale + _zoomStep).clamp(_minZoomScale, _maxZoomScale);
      print('AudioEditorPage: Zoomed In. New scale: $_waveformVisualScale');
    });
    final totalProjectDuration = ref.read(audioEditorProvider).totalProjectDuration;
    if (totalProjectDuration > Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPlaybackPosition(_currentPlaybackPosition);
      });
    }
  }

  void _zoomOut() {
    setState(() {
      _waveformVisualScale = (_waveformVisualScale - _zoomStep).clamp(_minZoomScale, _maxZoomScale);
      print('AudioEditorPage: Zoomed Out. New scale: $_waveformVisualScale');
    });
    final totalProjectDuration = ref.read(audioEditorProvider).totalProjectDuration;
    if (totalProjectDuration > Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPlaybackPosition(_currentPlaybackPosition);
      });
    }
  }

  Future<void> _togglePlayback() async {
    print('AudioEditorPage: Toggling playback...');

    final projectState = ref.read(audioEditorProvider);
    if (projectState.tracks.isEmpty || projectState.tracks.first.clips.isEmpty) {
      print('AudioEditorPage: No clips to play.');
      return;
    }

    final firstClip = projectState.tracks.first.clips.first;

    if (_justAudioService.currentPlayingPath != firstClip.sourceFilePath) {
      await _justAudioService.playAudio(firstClip.sourceFilePath, initialPosition: _currentPlaybackPosition);
      print('AudioEditorPage: Playing from initial position: $_currentPlaybackPosition');
    } else if (_justAudioService.currentPlaybackState == PlaybackState.playing) {
      await _justAudioService.pauseAudio();
      print('AudioEditorPage: Paused playback.');
    } else if (_justAudioService.currentPlaybackState == PlaybackState.paused) {
      await _justAudioService.resumeAudio();
      print('AudioEditorPage: Resumed playback.');
    } else {
      await _justAudioService.playAudio(firstClip.sourceFilePath, initialPosition: _currentPlaybackPosition);
      print('AudioEditorPage: Starting playback from beginning or previous stop: $_currentPlaybackPosition');
    }
  }

  void _onCursorSeek(Duration newPosition) {
    print('AudioEditorPage: Cursor dragged to $newPosition');
    _justAudioService.seekAudio(newPosition);
    setState(() {
      _currentPlaybackPosition = newPosition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioProjectState = ref.watch(audioEditorProvider);
    final List<AudioTrack> tracks = audioProjectState.tracks;
    final Duration totalProjectDuration = audioProjectState.totalProjectDuration;

    final justAudioPlayerState = ref.watch(audioPlaybackServiceProvider.select((service) => service.playerStateStream));
    final currentPlayingPath = ref.watch(audioPlaybackServiceProvider.select((service) => service.currentPlayingPath));
    final isPlayingThisFile = tracks.isNotEmpty && tracks.first.clips.isNotEmpty && currentPlayingPath == tracks.first.clips.first.sourceFilePath;
    final isPlaying = isPlayingThisFile && (justAudioPlayerState.value?.playing ?? false);

    final double calculatedWaveformAreaWidth = totalProjectDuration.inSeconds * _waveformVisualScale;
    final double minDisplayWidth = MediaQuery.of(context).size.width;
    final double finalDisplayWidth = (calculatedWaveformAreaWidth > minDisplayWidth) ? calculatedWaveformAreaWidth : minDisplayWidth;

    const double trackHeight = 120.0; // WaveformDisplay (100) + some padding/label

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Audio Note'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () {
              ref.read(audioEditorProvider.notifier).addTrack();
            },
            tooltip: 'Add Track',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              print('Save button pressed');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: finalDisplayWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TimeRuler(
                          waveformWidth: finalDisplayWidth,
                          totalDuration: totalProjectDuration,
                        ),
                        ...tracks.map((track) {
                          // Each track is a DragTarget
                          return DragTarget<AudioClip>(
                            // Accept any AudioClip data
                            onWillAcceptWithDetails: (details) {
                              print('AudioEditorPage: Track ${track.name} will accept drag of clip: ${details.data.name}');
                              return true; // Always accept for now
                            },
                            onAcceptWithDetails: (details) {
                              final RenderBox renderBox = context.findRenderObject() as RenderBox;
                              // Convert global position to local position within the SingleChildScrollView's content area
                              final globalPosition = details.offset;
                              final localPosition = renderBox.globalToLocal(globalPosition);

                              // Calculate the horizontal position relative to the scrollable content
                              // This is crucial for placing the clip accurately
                              final double dropXInContent = localPosition.dx + _scrollController.offset;

                              // Calculate new start time based on drop position and visual scale
                              final newStartTimeMs = (dropXInContent / _waveformVisualScale * 1000).round();
                              final newStartTime = Duration(milliseconds: newStartTimeMs);

                              print('AudioEditorPage: Dropped clip "${details.data.name}" on track "${track.name}" at global position: $globalPosition, local position: $localPosition, scroll offset: ${_scrollController.offset}, calculated content X: $dropXInContent, new start time: $newStartTime');

                              // Update the clip's position and potentially move it to a new track
                              ref.read(audioEditorProvider.notifier).moveClip(
                                  details.data.id,
                                  _originalClipTrackId!, // Original track ID of the dragged clip
                                  track.id, // Target track ID
                                  newStartTime
                              );
                              setState(() {
                                _draggingClipId = null; // Reset dragging state
                                _originalClipTrackId = null;
                                _originalClipStartTime = null;
                              });
                            },
                            onLeave: (data) {
                              print('AudioEditorPage: Drag left track ${track.name}');
                            },
                            builder: (context, candidateData, rejectedData) {
                              return Container(
                                height: trackHeight,
                                decoration: BoxDecoration(
                                  color: candidateData.isNotEmpty ? Colors.blue.withOpacity(0.2) : Colors.transparent, // Highlight target track
                                  border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      color: Colors.grey[700],
                                      alignment: Alignment.center,
                                      child: Text(
                                        track.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          // Render each clip as a Draggable
                                          ...track.clips.map((clip) {
                                            final double clipX = clip.startTime.inMilliseconds / 1000.0 * _waveformVisualScale;
                                            final double clipWidth = clip.duration.inMilliseconds / 1000.0 * _waveformVisualScale;

                                            // Only display the waveform for the clip if it's NOT the one being dragged
                                            // The Draggable will create its own feedback widget.
                                            final bool isCurrentlyDraggingThisClip = (_draggingClipId == clip.id);

                                            return Positioned(
                                              left: clipX,
                                              top: 0,
                                              child: isCurrentlyDraggingThisClip
                                                  ? SizedBox(width: clipWidth, height: 100) // Render an empty space when dragging
                                                  : Draggable<AudioClip>(
                                                      data: clip, // The data passed when dragged
                                                      feedback: Material( // Visual representation during drag
                                                        elevation: 4.0,
                                                        child: Container(
                                                          width: clipWidth,
                                                          height: 100,
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue.withOpacity(0.6),
                                                            borderRadius: BorderRadius.circular(5),
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              clip.name,
                                                              style: const TextStyle(color: Colors.white, fontSize: 10),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      childWhenDragging: Container( // Widget shown at original position when dragging
                                                        width: clipWidth,
                                                        height: 100,
                                                        color: Colors.transparent, // Or a dimmed version of the waveform
                                                      ),
                                                      onDragStarted: () {
                                                        print('AudioEditorPage: Started dragging clip: ${clip.name}');
                                                        setState(() {
                                                          _draggingClipId = clip.id;
                                                          _originalClipTrackId = track.id;
                                                          _originalClipStartTime = clip.startTime;
                                                        });
                                                      },
                                                      onDragEnd: (details) {
                                                        print('AudioEditorPage: Ended dragging clip: ${clip.name}, was accepted: ${details.wasAccepted}');
                                                        if (!details.wasAccepted) {
                                                          // If not accepted, revert clip to original position (optional, but good UX)
                                                          if (_originalClipTrackId != null && _originalClipStartTime != null) {
                                                            ref.read(audioEditorProvider.notifier).moveClip(
                                                                clip.id,
                                                                _originalClipTrackId!,
                                                                _originalClipTrackId!, // Back to original track
                                                                _originalClipStartTime!
                                                            );
                                                          }
                                                        }
                                                        setState(() {
                                                          _draggingClipId = null;
                                                          _originalClipTrackId = null;
                                                          _originalClipStartTime = null;
                                                        });
                                                      },
                                                      child: WaveformDisplay(
                                                        audioFilePath: clip.sourceFilePath,
                                                        playerController: _waveformPlayerController,
                                                        waveformWidth: clipWidth,
                                                      ),
                                                    ),
                                            );
                                          }).toList(),
                                          if (track.clips.isEmpty && _draggingClipId == null) // Show 'Drag clips here' only if empty and not dragging
                                            const Center(
                                              child: Text(
                                                'Drag audio clips here',
                                                style: TextStyle(color: Colors.grey, fontSize: 12),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                PlaybackCursor(
                  waveformWidth: finalDisplayWidth,
                  waveformHeight: TimeRuler.rulerHeight + (tracks.length * trackHeight),
                  visualScale: _waveformVisualScale,
                  onSeek: _onCursorSeek,
                ),
              ],
            ),
          ),
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
                        _currentPlaybackPosition = Duration.zero;
                      });
                      print('AudioEditorPage: Stopped playback, cursor reset.');
                    }
                  },
                ),
              ],
            ),
          ),
          Text(
            'Current Position: ${_justAudioService.formatDuration(_currentPlaybackPosition)} / ${_justAudioService.formatDuration(totalProjectDuration)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Zoom Scale: ${_waveformVisualScale.toStringAsFixed(1)} px/sec',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}