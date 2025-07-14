import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_clip.dart';
import '../models/audio_track.dart';
import '../models/marker.dart';
import '../providers/audio_editor_provider.dart';
import '../providers/editor_settings_provider.dart';
import '../services/audio_playback_service.dart';
import 'widgets/draggable_clip.dart';
import 'widgets/track_widget.dart';
import 'timeline_ruler.dart';
import 'editing_toolbar.dart';
import 'grid_overlay.dart';
import 'volume_automation_editor.dart';
import 'marker_dialog.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'markers_overlay.dart';

class AudioEditorPage extends ConsumerStatefulWidget {
  final String? initialAudioPath;

  const AudioEditorPage({super.key, this.initialAudioPath});

  @override
  ConsumerState<AudioEditorPage> createState() => _AudioEditorPageState();
}

class _AudioEditorPageState extends ConsumerState<AudioEditorPage> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _tracksScrollController = ScrollController();
  final double _waveformVisualScale = 200.0; // pixels per second
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  String? _selectedClipId;
  String? _selectedTrackId;
  final ValueNotifier<DurationRange?> _selectionRange = ValueNotifier<DurationRange?>(null);
  final ValueNotifier<bool> _showVolumeAutomation = ValueNotifier(false);
  final Set<String> _selectedClipIds = {};
  final GlobalKey _tracksContainerKey = GlobalKey();
  final ValueNotifier<Duration?> _playheadPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> _showGrid = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _tracksScrollController.dispose();
    _selectionRange.dispose();
    _showVolumeAutomation.dispose();
    _playheadPosition.dispose();
    _showGrid.dispose();
    super.dispose();
  }

  Future<void> _initializeAudio() async {
    if (widget.initialAudioPath != null) {
      await _addAudioToNewTrack(widget.initialAudioPath!);
    }
  }

  Future<void> _addAudioToNewTrack(String audioPath) async {
    final fileName = audioPath.split('/').last;
    
    // Get audio duration (you'll need to implement this)
    final duration = await _getAudioDuration(audioPath);
    
    final clip = AudioClip(
      sourceFilePath: audioPath,
      name: fileName,
      duration: duration,
      startTime: Duration.zero,
    );
    
    // Add a new track with this clip
    ref.read(audioEditorProvider.notifier).addTrack();
    final tracks = ref.read(audioEditorProvider).tracks;
    final newTrackId = tracks.last.id;
    
    ref.read(audioEditorProvider.notifier).addClip(
      trackId: newTrackId,
      clip: clip,
    );
  }

  Future<Duration> _getAudioDuration(String path) async {
    // Implement audio duration detection
    // This is a placeholder - you might use just_audio or another package
    return const Duration(seconds: 30);
  }

  void _handlePlayPause() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  Future<void> _startPlayback() async {
    // Implement playback logic
    setState(() => _isPlaying = true);
    // Start playback and update position
  }

  Future<void> _pausePlayback() async {
    // Implement pause logic
    setState(() => _isPlaying = false);
  }

  void _stopPlayback() {
    setState(() {
      _isPlaying = false;
      _currentPosition = Duration.zero;
    });
    // Stop playback
  }

  void _handleClipTap(AudioClip clip) {
    // Handle clip tap (e.g., show clip details)
    debugPrint('Clip tapped: ${clip.name}');
  }

  void _handleClipMoved(AudioClip clip, String sourceTrackId, Duration newStartTime) {
    ref.read(audioEditorProvider.notifier).moveClip(
      sourceTrackId: sourceTrackId,
      clipId: clip.id,
      newStartTime: newStartTime,
    );
  }

  void _handleClipDroppedOnTrack(AudioClip clip, String sourceTrackId, String targetTrackId) {
    ref.read(audioEditorProvider.notifier).moveClip(
      sourceTrackId: sourceTrackId,
      targetTrackId: targetTrackId,
      clipId: clip.id,
      newStartTime: clip.startTime, // Keep the same start time
    );
  }

  void _addNewTrack() {
    ref.read(audioEditorProvider.notifier).addTrack();
  }

  void _handleSelectionChanged(Duration start, Duration end) {
    _selectionRange.value = DurationRange(start, end);
  }

  void _seekToPosition(Duration position) {
    // Implement seek functionality
    setState(() {
      _currentPosition = position;
    });
    // Update audio playback position if playing
    if (_isPlaying) {
      // _audioPlayer.seek(position);
    }
  }

  void _handleClipDragUpdate(DragUpdateDetails details, String trackId, String clipId) {
    // Calculate the new position based on drag delta
    final delta = details.delta.dx / _waveformVisualScale;
    final deltaDuration = Duration(milliseconds: (delta * 1000).round());
    
    ref.read(audioEditorProvider.notifier).moveClip(
      clipId: clipId,
      fromTrackId: trackId,
      toTrackId: trackId, // Same track for now, could be changed for cross-track drag
      newStartTime: _currentPosition + deltaDuration,
    );
  }

  void _skipToStart() {
    _seekToPosition(Duration.zero);
  }

  Future<void> _mergeSelectedClips() async {
    if (_selectedClipIds.length < 2) return;
    
    try {
      await ref.read(audioEditorProvider.notifier).mergeSelectedClips(_selectedClipIds);
      
      // Clear selection after merge
      setState(() {
        _selectedClipIds.clear();
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clips merged successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to merge clips: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addMarkerAtCurrentPosition() async {
    final editorSettings = ref.read(editorSettingsProvider);
    final marker = await showDialog<Marker>(
      context: context,
      builder: (context) => MarkerDialog(
        position: _playheadPosition.value,
      ),
    );
    
    if (marker != null) {
      ref.read(editorSettingsProvider.notifier).addMarker(marker);
    }
  }

  void _onMarkerTap(Marker marker) {
    // Seek to marker position
    _seekToPosition(marker.position);
  }

  void _onMarkerLongPress(Marker marker) {
    showModalBottomSheet(
      context: context,
      builder: (context) => MarkerContextMenu(
        marker: marker,
        onEdit: () async {
          Navigator.pop(context);
          final updatedMarker = await showDialog<Marker>(
            context: context,
            builder: (context) => MarkerDialog(marker: marker),
          );
          if (updatedMarker != null) {
            ref.read(editorSettingsProvider.notifier).updateMarker(updatedMarker);
          }
        },
        onDelete: () {
          ref.read(editorSettingsProvider.notifier).removeMarker(marker.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Duration _snapToGrid(Duration position) {
    final editorSettings = ref.read(editorSettingsProvider);
    if (!editorSettings.snapToGrid) return position;
    
    final divisionMs = editorSettings.gridSettings.division.inMilliseconds;
    final snappedMs = (position.inMilliseconds / divisionMs).round() * divisionMs;
    return Duration(milliseconds: snappedMs);
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(audioEditorProvider);
    final editorSettings = ref.watch(editorSettingsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Editor'),
        actions: [
          // Grid controls
          PopupMenuButton<Duration>(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Grid Settings',
            onSelected: (value) {
              ref.read(editorSettingsProvider.notifier).setGridDivision(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: Duration(milliseconds: 1000),
                child: Text('1 second'),
              ),
              const PopupMenuItem(
                value: Duration(milliseconds: 500),
                child: Text('1/2 second'),
              ),
              const PopupMenuItem(
                value: Duration(milliseconds: 250),
                child: Text('1/4 second'),
              ),
            ],
          ),
          
          // Snap to grid toggle
          IconButton(
            icon: Icon(
              editorSettings.snapToGrid ? Icons.grain : Icons.grain_outlined,
              color: editorSettings.snapToGrid ? Colors.blue : null,
            ),
            onPressed: () {
              ref.read(editorSettingsProvider.notifier).toggleSnapToGrid();
            },
            tooltip: 'Snap to Grid',
          ),
          
          // Volume automation toggle
          IconButton(
            icon: const Icon(Icons.graphic_eq),
            onPressed: () {
              _showVolumeAutomation.value = !_showVolumeAutomation.value;
            },
            tooltip: 'Show Volume Automation',
          ),
          
          const SizedBox(width: 16),
          
          // Transport controls
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: _skipToStart,
            tooltip: 'Skip to Start',
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _handlePlayPause,
            tooltip: _isPlaying ? 'Pause' : 'Play',
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _stopPlayback,
            tooltip: 'Stop',
          ),
          // Add grid toggle button
          IconButton(
            icon: ValueListenableBuilder<bool>(
              valueListenable: _showGrid,
              builder: (context, showGrid, _) => Icon(
                Icons.grid_on,
                color: showGrid ? Theme.of(context).primaryColor : null,
              ),
            ),
            onPressed: () => _showGrid.value = !_showGrid.value,
          ),
          // Add add marker button
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _addMarkerAtCurrentPosition,
          ),
        ],
      ),
      body: Column(
        children: [
          // Timeline ruler with markers
          SizedBox(
            height: 60,
            child: Stack(
              children: [
                TimelineRuler(
                  duration: projectState.totalDuration,
                  currentPosition: _currentPosition,
                  onSeek: _seekToPosition,
                  showMarkers: true,
                  markers: editorSettings.markers,
                  onMarkerTap: _onMarkerTap,
                  onAddMarker: _addMarkerAtCurrentPosition,
                ),
                // Grid overlay
                Positioned.fill(
                  child: GridOverlay(
                    width: MediaQuery.of(context).size.width,
                    height: 60,
                    pixelsPerSecond: _waveformVisualScale,
                    onAddMarker: _addMarkerAtCurrentPosition,
                    onMarkerTap: _onMarkerTap,
                  ),
                ),
              ],
            ),
          ),
          
          // Volume automation editor (conditionally shown)
          ValueListenableBuilder<bool>(
            valueListenable: _showVolumeAutomation,
            builder: (context, showAutomation, _) {
              if (!showAutomation || _selectedClipId == null) return const SizedBox.shrink();
              
              final clip = _findSelectedClip();
              if (clip == null) return const SizedBox.shrink();
              
              return Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volume Automation: ${clip.name}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: VolumeAutomationEditor(
                        clip: clip,
                        onAutomationChanged: (updatedClip) {
                          _updateClip(updatedClip);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Tracks area
          Expanded(
            child: Stack(
              children: [
                // Tracks with horizontal scrolling
                SingleChildScrollView(
                  controller: _tracksScrollController,
                  child: Column(
                    key: _tracksContainerKey,
                    children: [
                      ...projectState.tracks.map((track) => TrackWidget(
                        key: ValueKey(track.id),
                        track: track,
                        pixelsPerSecond: _waveformVisualScale,
                        onClipTap: _handleClipTap,
                        onClipMoved: (clip, _, newTime) => _handleClipMoved(clip, track.id, newTime),
                        onClipDroppedOnTrack: _handleClipDroppedOnTrack,
                        selectedClipId: _selectedClipId,
                        showVolumeAutomation: _showVolumeAutomation.value,
                      )).toList(),
                      
                      // Add track button
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ElevatedButton.icon(
                          onPressed: _addNewTrack,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Track'),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Grid overlay for tracks
                ValueListenableBuilder<bool>(
                  valueListenable: _showGrid,
                  builder: (context, showGrid, _) {
                    if (!showGrid) return const SizedBox.shrink();
                    return Positioned.fill(
                      child: IgnorePointer(
                        child: GridOverlay(
                          width: projectState.totalDuration.inMilliseconds / 1000 * _waveformVisualScale,
                          height: MediaQuery.of(context).size.height - 200, // Adjust based on your layout
                          pixelsPerSecond: _waveformVisualScale,
                          scrollController: _horizontalScrollController,
                        ),
                      ),
                    );
                  },
                ),
                // Markers overlay
                ValueListenableBuilder<bool>(
                  valueListenable: _showGrid,
                  builder: (context, showGrid, _) {
                    return MarkersOverlay(
                      width: MediaQuery.of(context).size.width,
                      height: 60,
                      pixelsPerSecond: _waveformVisualScale,
                      scrollController: _horizontalScrollController,
                      onMarkerTap: _onMarkerTap,
                      onMarkerLongPress: _onMarkerLongPress,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditingToolbar() {
    return Consumer(
      builder: (context, ref, _) {
        return EditingToolbar(
          canUndo: ref.watch(audioEditorProvider.select((s) => s.canUndo)),
          canRedo: ref.watch(audioEditorProvider.select((s) => s.canRedo)),
          onUndo: () => ref.read(audioEditorProvider.notifier).undo(),
          onRedo: () => ref.read(audioEditorProvider.notifier).redo(),
          onCut: _handleCut,
          onTrim: _handleTrim,
          onSplit: _handleSplit,
          onMergeClips: _mergeSelectedClips,
          selectedClipIds: _selectedClipIds.toList(),
          playheadPosition: _currentPosition,
          onSelectionChanged: _updateSelection,
          selectionRange: _selectionRange,
        );
      },
    );
  }
  
  AudioClip? _findSelectedClip() {
    if (_selectedClipId == null || _selectedTrackId == null) return null;
    
    final track = ref.read(audioEditorProvider).tracks
        .firstWhere((t) => t.id == _selectedTrackId);
    
    return track.clips.firstWhereOrNull((c) => c.id == _selectedClipId);
  }
  
  void _updateClip(AudioClip updatedClip) {
    if (_selectedTrackId == null) return;
    
    ref.read(audioEditorProvider.notifier).updateClip(
      trackId: _selectedTrackId!,
      clip: updatedClip,
    );
  }
  
  void _handleAddMarker(Duration position) {
    final snappedPosition = _snapToGrid(position);
    
    showDialog(
      context: context,
      builder: (context) => MarkerDialog(
        initialName: 'Marker ${ref.read(editorSettingsProvider).markers.length + 1}',
        onSave: (name, color) {
          ref.read(editorSettingsProvider.notifier).addMarker(
            Marker(
              name: name,
              position: snappedPosition,
              color: color,
            ),
          );
        },
      ),
    );
  }
  
  void _handleMarkerTap(Marker marker) {
    // Seek to marker position
    _seekToPosition(marker.position);
    
    // Show marker details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${marker.name}'),
            Text('Position: ${_formatDuration(marker.position)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editMarker(marker);
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () {
              ref.read(editorSettingsProvider.notifier).removeMarker(marker.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _editMarker(Marker marker) {
    showDialog(
      context: context,
      builder: (context) => MarkerDialog(
        initialName: marker.name,
        initialColor: marker.color,
        onSave: (name, color) {
          ref.read(editorSettingsProvider.notifier).updateMarker(
            marker.copyWith(
              name: name,
              color: color,
            ),
          );
        },
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}