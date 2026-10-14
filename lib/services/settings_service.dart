import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import 'storage_service.dart';

class SettingsService extends ChangeNotifier {
  final StorageService _storage;
  late AppSettings _settings;

  SettingsService(this._storage) {
    _settings = _storage.loadSettings();
  }

  AppSettings get settings => _settings;

  void updateSettings({
    ThemeMode? themeMode,
    Color? accentColor,
    bool? showButtonLabels,
    bool? iconOnlyMode,
    double? buttonSpacing,
    double? buttonCornerRadius,
    double? textScaleFactor,
    String? backgroundStyle,
    double? animationSpeed,
    bool? hapticFeedbackEnabled,
    bool? lockOrientationLandscape,
    double? volumeStep,
    double? brightnessStep,
    String? currentAudioOutput,
    String? currentDisplay,
    bool? useHardwareBrightness,
    bool? autoDiscoverWifi,
    bool? autoReconnectLastDevice,
    int? connectionTimeoutSeconds,
    bool? requirePinForSensitiveActions,
    bool? redactLogs,
    bool? analyticsEnabled,
    bool? notifyOnDisconnect,
    bool? notifyOnProfileSwitch,
  }) {
    _settings = _settings.copyWith(
      themeMode: themeMode,
      accentColor: accentColor,
      showButtonLabels: showButtonLabels,
      iconOnlyMode: iconOnlyMode,
      buttonSpacing: buttonSpacing,
      buttonCornerRadius: buttonCornerRadius,
      textScaleFactor: textScaleFactor,
      backgroundStyle: backgroundStyle,
      animationSpeed: animationSpeed,
      hapticFeedbackEnabled: hapticFeedbackEnabled,
      lockOrientationLandscape: lockOrientationLandscape,
      volumeStep: volumeStep,
      brightnessStep: brightnessStep,
      currentAudioOutput: currentAudioOutput,
      currentDisplay: currentDisplay,
      useHardwareBrightness: useHardwareBrightness,
      autoDiscoverWifi: autoDiscoverWifi,
      autoReconnectLastDevice: autoReconnectLastDevice,
      connectionTimeoutSeconds: connectionTimeoutSeconds,
      requirePinForSensitiveActions: requirePinForSensitiveActions,
      redactLogs: redactLogs,
      analyticsEnabled: analyticsEnabled,
      notifyOnDisconnect: notifyOnDisconnect,
      notifyOnProfileSwitch: notifyOnProfileSwitch,
    );
    _storage.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _settings = AppSettings();
    await _storage.saveSettings(_settings);
    notifyListeners();
  }
}
