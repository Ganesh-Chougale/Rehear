import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class WaveformDisplay extends StatefulWidget {
  final String audioFilePath;
  final double waveformWidth;
  final PlayerController? playerController;

  const WaveformDisplay({
    super.key,
    required this.audioFilePath,
    required this.waveformWidth,
    this.playerController,
  });

  @override
  State<WaveformDisplay> createState() => _WaveformDisplayState();
}

class _WaveformDisplayState extends State<WaveformDisplay> {
  late PlayerController _playerController;
  bool _isWaveformReady = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _playerController = widget.playerController ?? PlayerController();
    _initializeWaveform();
  }

  @override
  void didUpdateWidget(covariant WaveformDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.audioFilePath != oldWidget.audioFilePath) {
      _initializeWaveform();
    }
  }

  Future<void> _initializeWaveform() async {
    if (_isDisposed) return;
    
    setState(() {
      _isWaveformReady = false;
    });

    try {
      await _playerController.preparePlayer(
        path: widget.audioFilePath,
        shouldExtractWaveform: true,
        noOfSamples: 100, // Adjust based on your needs
      );
      
      if (!_isDisposed) {
        setState(() {
          _isWaveformReady = true;
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _isWaveformReady = false;
        });
      }
      debugPrint('Error initializing waveform: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Only dispose the controller if it was created locally
    if (widget.playerController == null) {
      _playerController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isWaveformReady) {
      return Container(
        width: widget.waveformWidth,
        height: 100,
        color: Colors.grey[800],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: widget.waveformWidth,
      height: 100,
      color: Colors.grey[900],
      child: AudioFileWaveforms(
        size: Size(widget.waveformWidth, 100),
        playerController: _playerController,
        waveformType: WaveformType.long,
        waveformData: _playerController.waveformData,
        enableSeekGesture: true,
        padding: const EdgeInsets.only(top: 20, bottom: 20),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        playerWaveStyle: const PlayerWaveStyle(
          fixedWaveColor: Colors.blue,
          liveWaveColor: Colors.lightBlue,
          showBottom: true,
          showTop: true,
          waveCap: StrokeCap.round,
          spacing: 8,
          scaleFactor: 0.5,
        ),
      ),
    );
  }
}