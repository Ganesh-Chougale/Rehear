import 'package:flutter/material.dart';

class EditorSettings {
  final GridSettings gridSettings;
  final List<Marker> markers;
  final bool snapToGrid;

  const EditorSettings({
    this.gridSettings = const GridSettings(),
    this.markers = const [],
    this.snapToGrid = true,
  });

  EditorSettings copyWith({
    GridSettings? gridSettings,
    List<Marker>? markers,
    bool? snapToGrid,
  }) {
    return EditorSettings(
      gridSettings: gridSettings ?? this.gridSettings,
      markers: markers ?? this.markers,
      snapToGrid: snapToGrid ?? this.snapToGrid,
    );
  }
}

class GridSettings {
  final Duration division;
  final int subdivisions;
  final Color color;
  final double opacity;

  const GridSettings({
    this.division = const Duration(milliseconds: 500),
    this.subdivisions = 4,
    this.color = Colors.white,
    this.opacity = 0.3,
  });

  GridSettings copyWith({
    Duration? division,
    int? subdivisions,
    Color? color,
    double? opacity,
  }) {
    return GridSettings(
      division: division ?? this.division,
      subdivisions: subdivisions ?? this.subdivisions,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
    );
  }
}

class Marker {
  final String id;
  final String name;
  final Duration position;
  final Color color;

  const Marker({
    String? id,
    required this.name,
    required this.position,
    this.color = Colors.yellow,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Marker copyWith({
    String? name,
    Duration? position,
    Color? color,
  }) {
    return Marker(
      id: id,
      name: name ?? this.name,
      position: position ?? this.position,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Marker &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
