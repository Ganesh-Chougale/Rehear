// lib/providers/audio_playback_provider.dart (create this new file)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_playback_service.dart';

final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  // Ensure the service is disposed when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});