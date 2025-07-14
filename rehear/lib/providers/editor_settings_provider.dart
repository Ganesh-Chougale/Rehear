import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/editor_settings.dart';

final editorSettingsProvider = StateNotifierProvider<EditorSettingsNotifier, EditorSettings>(
  (ref) => EditorSettingsNotifier(),
);

class EditorSettingsNotifier extends StateNotifier<EditorSettings> {
  EditorSettingsNotifier() : super(const EditorSettings());

  // Grid settings
  void setGridDivision(Duration division) {
    state = state.copyWith(
      gridSettings: state.gridSettings.copyWith(division: division),
    );
  }

  void setGridSubdivisions(int subdivisions) {
    state = state.copyWith(
      gridSettings: state.gridSettings.copyWith(subdivisions: subdivisions),
    );
  }

  void toggleSnapToGrid() {
    state = state.copyWith(snapToGrid: !state.snapToGrid);
  }

  // Markers
  void addMarker(Marker marker) {
    state = state.copyWith(
      markers: [...state.markers, marker],
    );
  }

  void updateMarker(Marker marker) {
    state = state.copyWith(
      markers: state.markers.map((m) => m.id == marker.id ? marker : m).toList(),
    );
  }

  void removeMarker(String markerId) {
    state = state.copyWith(
      markers: state.markers.where((m) => m.id != markerId).toList(),
    );
  }

  // Snap time to grid if enabled
  Duration snapTime(Duration time) {
    if (!state.snapToGrid) return time;
    
    final division = state.gridSettings.division;
    final micros = time.inMicroseconds;
    final divisionMicros = division.inMicroseconds;
    
    if (divisionMicros == 0) return time;
    
    final snappedMicros = (micros / divisionMicros).round() * divisionMicros;
    return Duration(microseconds: snappedMicros);
  }
}
