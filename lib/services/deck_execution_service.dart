import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/deck_models.dart';
import '../models/app_settings.dart';
import 'connection_service.dart';
import 'live_state_service.dart';
import 'profile_service.dart';

class DeckExecutionService extends ChangeNotifier {
  final ConnectionService _connectionService;
  final LiveStateService _liveStateService;
  final ProfileService _profileService;

  double _systemVolume = 65.0;
  bool _isSystemMuted = false;
  double _screenBrightness = 80.0;
  bool _isMicMuted = false;
  double _micVolume = 75.0;

  final List<String> _activityLogs = [];

  DeckExecutionService(
    this._connectionService,
    this._liveStateService,
    this._profileService,
  ) {
    // When server pushes state after auth, sync the sliders immediately
    _connectionService.onSystemState = (vol, brightness) {
      if (vol != null) {
        _systemVolume = vol.clamp(0.0, 100.0);
      }
      if (brightness != null) {
        _screenBrightness = brightness.clamp(0.0, 100.0);
      }
      notifyListeners();
    };

    // When server pushes a full state_update snapshot, forward to LiveStateService
    // and check auto-profile switching
    _connectionService.onStateUpdate = (states) {
      _liveStateService.updateStates(states);
      _checkAutoProfileSwitch(states);
    };
  }

  /// Checks whether the active window title matches any profile's auto-switch trigger
  /// and switches to that profile if found.
  void _checkAutoProfileSwitch(Map<String, dynamic> states) {
    final windowMap = states['window'];
    if (windowMap is! Map) return;
    final title = windowMap['title']?.toString() ?? '';
    if (title.isEmpty) return;

    for (final profile in _profileService.profiles) {
      final trigger = profile.autoSwitchWindowTitle;
      if (trigger != null && trigger.isNotEmpty) {
        if (title.toLowerCase().contains(trigger.toLowerCase())) {
          if (_profileService.activeProfileId != profile.id) {
            _profileService.setActiveProfile(profile.id);
            _log('Auto-switched profile → "${profile.name}" (window: $title)');
          }
          return;
        }
      }
    }
  }

  double get systemVolume => _systemVolume;
  bool get isSystemMuted => _isSystemMuted;
  double get screenBrightness => _screenBrightness;
  bool get isMicMuted => _isMicMuted;
  double get micVolume => _micVolume;
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

  void setMicVolume(double val) {
    _micVolume = val.clamp(0.0, 100.0);
    _log('Mic volume set to ${_micVolume.round()}%');
    _connectionService.sendAction('set_mic_volume', {'volume': _micVolume.round()});
    notifyListeners();
  }

  void toggleMicMute() {
    _isMicMuted = !_isMicMuted;
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
        final cmd = button.actionPayload['command']?.toString() ?? 'toggle_recording';
        _log('OBS command: $cmd');
        _connectionService.sendAction('obs_action', {
          'command': cmd,
          ...button.actionPayload,
        });
        return true;

      case ActionType.switchPage:
      case ActionType.switchProfile:
        // Handled in UI navigation
        return true;

      case ActionType.actionSequence:
        final seq = button.actionPayload['sequence'];
        String? mediaCmd = button.actionPayload['media_command'] as String?;
        if (mediaCmd == null && seq is List && seq.isNotEmpty) {
          final first = seq[0].toString().toLowerCase();
          if (first.contains('toggle') || first.contains('play')) {
            mediaCmd = 'play_pause';
          } else if (first.contains('prev')) {
            mediaCmd = 'previous';
          } else if (first.contains('next')) {
            mediaCmd = 'next';
          }
        }
        // Fallback check by button title or ID
        if (mediaCmd == null) {
          final titleLower = button.title.toLowerCase();
          if (titleLower.contains('play') || titleLower.contains('pause')) {
            mediaCmd = 'play_pause';
          } else if (titleLower.contains('prev')) {
            mediaCmd = 'previous';
          } else if (titleLower.contains('next')) {
            mediaCmd = 'next';
          }
        }

        if (mediaCmd != null) {
          _log('Dispatched media control: $mediaCmd');
          _connectionService.sendAction('media_control', {'command': mediaCmd});
        } else {
          _log('Executed action sequence payload');
        }
        return true;

      case ActionType.injectHotkey:
        final rawKeys = button.actionPayload['keys'];
        final List<String> keys = rawKeys is List
            ? rawKeys.map((e) => e.toString()).toList()
            : (button.actionPayload['combo']?.toString().split('+') ?? ['ctrl']);
        _log('Injecting hotkey: ${keys.join("+")}');
        _connectionService.sendAction('inject_hotkey', {'keys': keys});
        return true;

      case ActionType.pasteText:
        final text = button.actionPayload['text']?.toString() ?? '';
        _log('Pasting text (${text.length} chars)');
        _connectionService.sendAction('paste_text', {'text': text});
        return true;

      case ActionType.mediaControl:
        final cmd = button.actionPayload['command']?.toString() ?? 'play_pause';
        final player = button.actionPayload['player']?.toString();
        _log('Media control: $cmd${player != null ? " ($player)" : ""}');
        _connectionService.sendAction('media_control', {
          'command': cmd,
          'player': ?player,
        });
        return true;

      case ActionType.spotifyAction:
        final cmd = button.actionPayload['command']?.toString() ?? 'play_pause';
        _log('Spotify control: $cmd');
        _connectionService.sendAction('spotify_action', {'command': cmd});
        return true;

      case ActionType.discordAction:
        final cmd = button.actionPayload['command']?.toString() ?? 'toggle_mute';
        _log('Discord action: $cmd');
        final hotkey = button.actionPayload['hotkey'];
        if (hotkey is List) {
          _connectionService.sendAction('inject_hotkey', {'keys': hotkey.map((e) => e.toString()).toList()});
        } else {
          _connectionService.sendAction('inject_hotkey', {'keys': ['ctrl', 'shift', 'm']});
        }
        return true;

      case ActionType.toggleButton:
        button.toggleState = !button.toggleState;
        notifyListeners();
        final stateKey = button.toggleState ? 'on_action' : 'off_action';
        final subAction = button.actionPayload[stateKey];
        _log('Toggled "${button.title}" -> ${button.toggleState ? "ON" : "OFF"}');
        if (subAction is Map<String, dynamic>) {
          final act = subAction['action']?.toString() ?? 'hotkey';
          final payload = subAction['payload'] as Map<String, dynamic>? ?? {};
          _connectionService.sendAction(act, payload);
        } else if (subAction is Map) {
          final act = subAction['action']?.toString() ?? 'hotkey';
          final payload = Map<String, dynamic>.from(subAction['payload'] as Map? ?? {});
          _connectionService.sendAction(act, payload);
        }
        return true;

      case ActionType.folderAction:
        _log('Navigated to folder "${button.title}"');
        return true;

      case ActionType.dynamicFunction:
        final funcId = button.actionPayload['function_id'] ?? '';
        final cmd = button.actionPayload['command'] ?? button.actionPayload['definition'] ?? '';
        _log('Executing dynamic custom function "${button.title}"');
        _connectionService.sendAction('execute_function', {
          'function_id': funcId,
          'command': cmd,
        });
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
