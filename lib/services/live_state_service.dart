import 'package:flutter/foundation.dart';

/// Manages real-time state broadcasts received from the desktop companion agent.
/// Powers live button values (e.g. CPU%, RAM%, Track name, OBS status) and auto-switching.
class LiveStateService extends ChangeNotifier {
  Map<String, dynamic> _states = {};

  Map<String, dynamic> get states => Map.unmodifiable(_states);

  void updateStates(Map<String, dynamic> incoming) {
    _states = Map<String, dynamic>.from(incoming);
    notifyListeners();
  }

  /// Resolves a dot-notation path such as:
  /// - "system.cpu_percent"
  /// - "system.ram_percent"
  /// - "media.title"
  /// - "media.artist"
  /// - "spotify.track"
  /// - "obs.recording"
  /// - "window.title"
  dynamic getState(String? path) {
    if (path == null || path.isEmpty) return null;
    final parts = path.split('.');
    dynamic current = _states;
    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Returns a human-friendly formatted string for button subtitles.
  String? formatStateValue(String? path) {
    if (path == null || path.isEmpty) return null;
    final val = getState(path);
    if (val == null) return null;

    if (val is bool) {
      if (path.contains('recording') || path.contains('streaming')) {
        return val ? '● LIVE' : 'OFFLINE';
      }
      return val ? 'ON' : 'OFF';
    }

    if (val is num) {
      if (path.contains('percent') || path.contains('cpu') || path.contains('ram')) {
        return '${val.round()}%';
      }
      return val.toString();
    }

    final str = val.toString().trim();
    if (str.isEmpty) return null;
    return str;
  }

  /// Convenience getters
  int get cpuPercent => (getState('system.cpu_percent') as num?)?.round() ?? 0;
  int get ramPercent => (getState('system.ram_percent') as num?)?.round() ?? 0;
  String get mediaTitle => getState('media.title')?.toString() ?? '';
  String get mediaArtist => getState('media.artist')?.toString() ?? '';
  bool get isMediaPlaying => getState('media.playing') == true;
  String get activeWindowTitle => getState('window.title')?.toString() ?? '';
}
