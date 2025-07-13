// lib/audio_editing/waveform_display.dart

import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'dart:io';

class WaveformDisplay extends StatefulWidget {
  final String audioFilePath;
  final PlayerController playerController;
  final double waveformWidth; // Add this parameter

  const WaveformDisplay({
    super.key,
    required this.audioFilePath,
    required this.playerController,
    required this.waveformWidth, // Make it required
  });

  @override
  State<WaveformDisplay> createState() => _WaveformDisplayState();
}

class _WaveformDisplayState extends State<WaveformDisplay> {
  late PlayerController _playerController;
  bool _isPlayerInitialized = false;

  @override
  void initState() {
    super.initState();
    _playerController = widget.playerController;
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant WaveformDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioFilePath != widget.audioFilePath) {
      _playerController = widget.playerController; // Update if the controller itself changes
      _initializePlayer(); // Re-initialize if the audio file path changes
    }
  }

  Future<void> _initializePlayer() async {
    if (!await File(widget.audioFilePath).exists()) {
      print("WaveformDisplay: Audio file does not exist at ${widget.audioFilePath}");
      setState(() {
        _isPlayerInitialized = false;
      });
      return;
    }

    try {
      await _playerController.preparePlayer(
        path: widget.audioFilePath,
        shouldExtractWaveform: true,
        showSeekLine: false,
      );
      print("WaveformDisplay: Player prepared with ${widget.audioFilePath}");

      setState(() {
        _isPlayerInitialized = true;
      });
    } catch (e) {
      print("Error initializing waveform player: $e");
      setState(() {
        _isPlayerInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlayerInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 10),
            Text('Loading Waveform...'),
            Text('(Ensure file exists and permissions are granted)'),
          ],
        ),
      );
    }

    return AudioWaveforms(
      // Use the passed waveformWidth for the size
      size: Size(widget.waveformWidth, 100), // Fixed height 100, dynamic width
      playerController: _playerController,
      enableSeekGesture: false,
      waveformType: WaveformType.long,
      animationDuration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.only(right: 10),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      playerWaveStyle: const PlayerWaveStyle(
        fixedWaveColor: Colors.blueGrey,
        liveWaveColor: Colors.blueAccent,
        showSeekLine: false,
        waveCap: StrokeCap.round,
        waveJoint: StrokeJoin.round,
        scaleFactor: 100,
      ),
    );
  }
}