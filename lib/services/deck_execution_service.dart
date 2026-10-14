import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/deck_models.dart';
import '../models/app_settings.dart';
import 'connection_service.dart';
import 'obs_service.dart';

class DeckExecutionService extends ChangeNotifier {
  final ConnectionService _connectionService;
  final ObsService _obsService;

  double _systemVolume = 65.0;
  bool _isSystemMuted = false;
  double _screenBrightness = 80.0;
  bool _isMicMuted = false;

  final List<String> _activityLogs = [];

  DeckExecutionService(this._connectionService, this._obsService);

  double get systemVolume => _systemVolume;
  bool get isSystemMuted => _isSystemMuted;
  double get screenBrightness => _screenBrightness;
  bool get isMicMuted => _isMicMuted;
  List<String> get activityLogs => List.unmodifiable(_activityLogs);

  void setSystemVolume(double val) {
    _systemVolume = val.clamp(0.0, 100.0);
    _log('System volume set to ${_systemVolume.round()}%');
    _connectionService.sendAction('set_volume', {'volume': _systemVolume.round()});
    notifyListeners();
  }

  void adjustVolume(double delta) {
    _systemVolume = (_systemVolume + delta).clamp(0.0, 100.0);
    _log('Adjusted volume by ${delta > 0 ? "+" : ""}${delta.round()}%');
    _connectionService.sendAction('adjust_volume', {'step': delta.round()});
    notifyListeners();
  }

  void toggleSystemMute() {
    _isSystemMuted = !_isSystemMuted;
    _log('System mute: $_isSystemMuted');
    _connectionService.sendAction('toggle_mute', {});
    notifyListeners();
  }

  void setBrightness(double val) {
    _screenBrightness = val.clamp(0.0, 100.0);
    _log('Screen brightness set to ${_screenBrightness.round()}%');
    _connectionService.sendAction('set_brightness', {'brightness': _screenBrightness.round()});
    notifyListeners();
  }

  void adjustBrightness(double delta) {
    _screenBrightness = (_screenBrightness + delta).clamp(0.0, 100.0);
    _log('Adjusted brightness by ${delta > 0 ? "+" : ""}${delta.round()}%');
    _connectionService.sendAction('adjust_brightness', {'step': delta.round()});
    notifyListeners();
  }

  void toggleMicMute() {
    _isMicMuted = !_isMicMuted;
    _obsService.toggleMicMute();
    _log('Microphone mute toggled: $_isMicMuted');
    _connectionService.sendAction('toggle_mic_mute', {});
    notifyListeners();
  }

  Future<bool> executeButton(DeckButton button, AppSettings settings) async {
    if (!button.isEnabled) return false;

    if (button.hapticFeedback && settings.hapticFeedbackEnabled) {
      HapticFeedback.lightImpact();
    }

    _log('Executed button "${button.title}" (${button.actionType.name})');

    switch (button.actionType) {
      case ActionType.openWebsite:
        final url = button.actionPayload['url'] ?? 'https://google.com';
        _log('Opening browser URL: $url');
        _connectionService.sendAction('open_website', {'url': url});
        return true;

      case ActionType.launchApp:
        final app = button.actionPayload['app'] ?? button.title;
        _log('Dispatched desktop app launch command: $app');
        _connectionService.sendAction('launch_app', {'app': app});
        return true;

      case ActionType.toggleMicMute:
        toggleMicMute();
        return true;

      case ActionType.setVolume:
        final step = (button.actionPayload['step'] as num?)?.toDouble() ?? settings.volumeStep;
        adjustVolume(step);
        return true;

      case ActionType.toggleSystemMute:
        toggleSystemMute();
        return true;

      case ActionType.setBrightness:
        final step = (button.actionPayload['step'] as num?)?.toDouble() ?? settings.brightnessStep;
        adjustBrightness(step);
        return true;

      case ActionType.obsAction:
        final cmd = button.actionPayload['command'] ?? '';
        if (cmd == 'toggle_stream') {
          _obsService.toggleStream();
        } else if (cmd == 'toggle_record') {
          _obsService.toggleRecord();
        } else if (cmd == 'switch_scene') {
          _obsService.setScene(button.actionPayload['scene'] ?? '');
        }
        _log('Dispatched OBS command: $cmd');
        _connectionService.sendAction('launch_app', {'app': 'obs'});
        return true;

      case ActionType.switchPage:
      case ActionType.switchProfile:
        // Handled in UI navigation
        return true;

      case ActionType.actionSequence:
        _log('Executed action sequence payload');
        return true;
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _activityLogs.insert(0, '[$timestamp] $message');
    if (_activityLogs.length > 50) {
      _activityLogs.removeLast();
    }
    notifyListeners();
  }

  void clearLogs() {
    _activityLogs.clear();
    notifyListeners();
  }
}
