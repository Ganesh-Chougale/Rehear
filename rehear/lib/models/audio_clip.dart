// lib/models/audio_clip.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class VolumePoint {
  final Duration time;
  final double volume;

  const VolumePoint({required this.time, required this.volume});
}

class AudioClip {
  final String id;
  final String sourceFilePath;
  final String name;
  final Duration startTime;  // Start time within the source file
  final Duration endTime;    // End time within the source file
  final Duration position;   // Position in the track timeline
  final double volume;
  final bool isMuted;
  final Map<String, dynamic>? effects;
  final String? tempFilePath; // For edited versions of the clip
  final List<VolumePoint> volumeAutomation;

  const AudioClip({
    String? id,
    required this.sourceFilePath,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.position,
    this.volume = 1.0,
    this.isMuted = false,
    this.effects,
    this.tempFilePath,
    List<VolumePoint>? volumeAutomation,
  })  : id = id ?? const Uuid().v4(),
        volumeAutomation = volumeAutomation ?? [
          VolumePoint(time: Duration.zero, volume: 1.0),
          VolumePoint(time: endTime - startTime, volume: 1.0),
        ];

  Duration get duration => endTime - startTime;
  
  bool get isEdited => tempFilePath != null;

  // Get volume at a specific time in the clip
  double getVolumeAt(Duration time) {
    if (volumeAutomation.isEmpty) return volume;
    if (volumeAutomation.length == 1) return volumeAutomation.first.volume * volume;
    
    // Find the surrounding points
    VolumePoint? before;
    VolumePoint? after;
    
    for (final point in volumeAutomation) {
      if (point.time <= time) {
        before = point;
      } else {
        after = point;
        break;
      }
    }
    
    // Handle edge cases
    if (before == null) return volumeAutomation.first.volume * volume;
    if (after == null) return volumeAutomation.last.volume * volume;
    
    // Linear interpolation between points
    final timeDelta = (time - before.time).inMicroseconds / 
                     (after.time - before.time).inMicroseconds;
    final interpolatedVolume = before.volume + (after.volume - before.volume) * timeDelta;
    
    return interpolatedVolume * volume;
  }

  // Add or update a volume automation point
  AudioClip withVolumePoint(VolumePoint point) {
    final updatedPoints = List<VolumePoint>.from(volumeAutomation);
    final existingIndex = updatedPoints.indexWhere(
      (p) => p.time == point.time
    );
    
    if (existingIndex != -1) {
      updatedPoints[existingIndex] = point;
    } else {
      updatedPoints.add(point);
      updatedPoints.sort((a, b) => a.time.compareTo(b.time));
    }
    
    return copyWith(volumeAutomation: updatedPoints);
  }
  
  // Remove a volume automation point (keeps at least 2 points)
  AudioClip removeVolumePoint(VolumePoint point) {
    if (volumeAutomation.length <= 2) return this;
    
    final updatedPoints = volumeAutomation.where(
      (p) => p != point
    ).toList();
    
    return copyWith(volumeAutomation: updatedPoints);
  }

  AudioClip copyWith({
    String? id,
    String? sourceFilePath,
    String? name,
    Duration? startTime,
    Duration? endTime,
    Duration? position,
    double? volume,
    bool? isMuted,
    Map<String, dynamic>? effects,
    String? tempFilePath,
    List<VolumePoint>? volumeAutomation,
  }) {
    return AudioClip(
      id: id ?? this.id,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      position: position ?? this.position,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      effects: effects ?? this.effects,
      tempFilePath: tempFilePath ?? this.tempFilePath,
      volumeAutomation: volumeAutomation ?? this.volumeAutomation,
    );
  }

  // Create a new clip that's a trimmed version of this one
  AudioClip trim(Duration newStart, Duration newEnd) {
    assert(newStart >= startTime && newEnd <= endTime && newStart < newEnd);
    
    return copyWith(
      startTime: newStart,
      endTime: newEnd,
      position: position + (newStart - startTime),
    );
  }

  // Split the clip at the specified time (relative to the clip's own timeline)
  List<AudioClip> splitAt(Duration splitTime) {
    final absoluteSplitTime = startTime + splitTime;
    
    if (splitTime <= Duration.zero || splitTime >= duration) {
      return [this];
    }
    
    final firstPart = copyWith(
      endTime: absoluteSplitTime,
    );
    
    final secondPart = copyWith(
      startTime: absoluteSplitTime,
      position: position + splitTime,
    );
    
    return [firstPart, secondPart];
  }

  // Apply an effect to this clip
  AudioClip withEffect(String effectId, Map<String, dynamic> effectParams) {
    final updatedEffects = Map<String, dynamic>.from(effects ?? {});
    updatedEffects[effectId] = effectParams;
    
    return copyWith(effects: updatedEffects);
  }

  // Remove an effect
  AudioClip withoutEffect(String effectId) {
    if (effects == null || !effects!.containsKey(effectId)) {
      return this;
    }
    
    final updatedEffects = Map<String, dynamic>.from(effects!);
    updatedEffects.remove(effectId);
    
    return copyWith(
      effects: updatedEffects.isNotEmpty ? updatedEffects : null,
    );
  }

  // Convert to a map for serialization
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceFilePath': sourceFilePath,
      'name': name,
      'startTime': startTime.inMicroseconds,
      'endTime': endTime.inMicroseconds,
      'position': position.inMicroseconds,
      'volume': volume,
      'isMuted': isMuted,
      'effects': effects,
      'tempFilePath': tempFilePath,
      'volumeAutomation': volumeAutomation.map((point) => {
        'time': point.time.inMicroseconds,
        'volume': point.volume,
      }).toList(),
    };
  }

  // Create from a map (for deserialization)
  factory AudioClip.fromMap(Map<String, dynamic> map) {
    return AudioClip(
      id: map['id'],
      sourceFilePath: map['sourceFilePath'],
      name: map['name'],
      startTime: Duration(microseconds: map['startTime'] as int),
      endTime: Duration(microseconds: map['endTime'] as int),
      position: Duration(microseconds: map['position'] as int),
      volume: (map['volume'] as num).toDouble(),
      isMuted: map['isMuted'] as bool? ?? false,
      effects: map['effects'] as Map<String, dynamic>?,
      tempFilePath: map['tempFilePath'] as String?,
      volumeAutomation: (map['volumeAutomation'] as List<dynamic>?)?.map((point) => VolumePoint(
        time: Duration(microseconds: point['time'] as int),
        volume: point['volume'] as double,
      )).toList() ?? [],
    );
  }
}