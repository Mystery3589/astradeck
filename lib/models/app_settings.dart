import 'package:flutter/material.dart';
import '../theme/astradeck_theme.dart';

class AppSettings {
  // Theme & Appearance
  ThemeMode themeMode;
  AstraThemePreset themePreset;
  Color accentColor;
  bool showButtonLabels;
  bool iconOnlyMode;
  double buttonSpacing;
  double buttonCornerRadius;
  double textScaleFactor;
  String backgroundStyle; // 'solid', 'gradient', 'mesh'
  double animationSpeed; // 0.5 (slow) to 1.5 (fast)
  bool hapticFeedbackEnabled;
  bool lockOrientationLandscape;

  // Audio & Brightness
  double volumeStep;
  double brightnessStep;
  String currentAudioOutput;
  List<String> audioOutputs;
  String currentDisplay;
  List<String> displays;
  bool useHardwareBrightness;

  // Connection & Auto-reconnect
  bool autoDiscoverWifi;
  bool autoReconnectLastDevice;
  int connectionTimeoutSeconds;
  String preferredDeviceId;

  // Security & Privacy
  bool requirePinForSensitiveActions;
  bool redactLogs;
  bool analyticsEnabled;

  // Notifications
  bool notifyOnDisconnect;
  bool notifyOnProfileSwitch;

  AppSettings({
    this.themeMode = ThemeMode.dark,
    this.themePreset = AstraThemePreset.midnight,
    this.accentColor = const Color(0xFF6366F1), // Indigo accent
    this.showButtonLabels = true,
    this.iconOnlyMode = false,
    this.buttonSpacing = 12.0,
    this.buttonCornerRadius = 16.0,
    this.textScaleFactor = 1.0,
    this.backgroundStyle = 'gradient',
    this.animationSpeed = 1.0,
    this.hapticFeedbackEnabled = true,
    this.lockOrientationLandscape = false,
    this.volumeStep = 5.0,
    this.brightnessStep = 10.0,
    this.currentAudioOutput = 'Default Speakers (Realtek Audio)',
    List<String>? audioOutputs,
    this.currentDisplay = 'Primary Monitor (1920x1080@144Hz)',
    List<String>? displays,
    this.useHardwareBrightness = true,
    this.autoDiscoverWifi = true,
    this.autoReconnectLastDevice = true,
    this.connectionTimeoutSeconds = 5,
    this.preferredDeviceId = '',
    this.requirePinForSensitiveActions = true,
    this.redactLogs = true,
    this.analyticsEnabled = false,
    this.notifyOnDisconnect = true,
    this.notifyOnProfileSwitch = false,
  })  : audioOutputs = audioOutputs ?? [
          'Default Speakers (Realtek Audio)',
          'Headphones (HyperX Cloud II)',
          'Digital Output (Optical SPDIF)',
        ],
        displays = displays ?? [
          'Primary Monitor (1920x1080@144Hz)',
          'Secondary Display (2560x1440@60Hz)',
        ];

  AppSettings copyWith({
    ThemeMode? themeMode,
    AstraThemePreset? themePreset,
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
    List<String>? audioOutputs,
    String? currentDisplay,
    List<String>? displays,
    bool? useHardwareBrightness,
    bool? autoDiscoverWifi,
    bool? autoReconnectLastDevice,
    int? connectionTimeoutSeconds,
    String? preferredDeviceId,
    bool? requirePinForSensitiveActions,
    bool? redactLogs,
    bool? analyticsEnabled,
    bool? notifyOnDisconnect,
    bool? notifyOnProfileSwitch,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      themePreset: themePreset ?? this.themePreset,
      accentColor: accentColor ?? this.accentColor,
      showButtonLabels: showButtonLabels ?? this.showButtonLabels,
      iconOnlyMode: iconOnlyMode ?? this.iconOnlyMode,
      buttonSpacing: buttonSpacing ?? this.buttonSpacing,
      buttonCornerRadius: buttonCornerRadius ?? this.buttonCornerRadius,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      animationSpeed: animationSpeed ?? this.animationSpeed,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      lockOrientationLandscape: lockOrientationLandscape ?? this.lockOrientationLandscape,
      volumeStep: volumeStep ?? this.volumeStep,
      brightnessStep: brightnessStep ?? this.brightnessStep,
      currentAudioOutput: currentAudioOutput ?? this.currentAudioOutput,
      audioOutputs: audioOutputs ?? List.from(this.audioOutputs),
      currentDisplay: currentDisplay ?? this.currentDisplay,
      displays: displays ?? List.from(this.displays),
      useHardwareBrightness: useHardwareBrightness ?? this.useHardwareBrightness,
      autoDiscoverWifi: autoDiscoverWifi ?? this.autoDiscoverWifi,
      autoReconnectLastDevice: autoReconnectLastDevice ?? this.autoReconnectLastDevice,
      connectionTimeoutSeconds: connectionTimeoutSeconds ?? this.connectionTimeoutSeconds,
      preferredDeviceId: preferredDeviceId ?? this.preferredDeviceId,
      requirePinForSensitiveActions: requirePinForSensitiveActions ?? this.requirePinForSensitiveActions,
      redactLogs: redactLogs ?? this.redactLogs,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      notifyOnDisconnect: notifyOnDisconnect ?? this.notifyOnDisconnect,
      notifyOnProfileSwitch: notifyOnProfileSwitch ?? this.notifyOnProfileSwitch,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'themePreset': themePreset.name,
    'accentColor': accentColor.toARGB32(),
    'showButtonLabels': showButtonLabels,
    'iconOnlyMode': iconOnlyMode,
    'buttonSpacing': buttonSpacing,
    'buttonCornerRadius': buttonCornerRadius,
    'textScaleFactor': textScaleFactor,
    'backgroundStyle': backgroundStyle,
    'animationSpeed': animationSpeed,
    'hapticFeedbackEnabled': hapticFeedbackEnabled,
    'lockOrientationLandscape': lockOrientationLandscape,
    'volumeStep': volumeStep,
    'brightnessStep': brightnessStep,
    'currentAudioOutput': currentAudioOutput,
    'audioOutputs': audioOutputs,
    'currentDisplay': currentDisplay,
    'displays': displays,
    'useHardwareBrightness': useHardwareBrightness,
    'autoDiscoverWifi': autoDiscoverWifi,
    'autoReconnectLastDevice': autoReconnectLastDevice,
    'connectionTimeoutSeconds': connectionTimeoutSeconds,
    'preferredDeviceId': preferredDeviceId,
    'requirePinForSensitiveActions': requirePinForSensitiveActions,
    'redactLogs': redactLogs,
    'analyticsEnabled': analyticsEnabled,
    'notifyOnDisconnect': notifyOnDisconnect,
    'notifyOnProfileSwitch': notifyOnProfileSwitch,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => ThemeMode.dark,
      ),
      themePreset: AstraThemePresetExtension.fromString(json['themePreset'] as String?),
      accentColor: json['accentColor'] != null
          ? Color(json['accentColor'] as int)
          : const Color(0xFF6366F1),
      showButtonLabels: json['showButtonLabels'] as bool? ?? true,
      iconOnlyMode: json['iconOnlyMode'] as bool? ?? false,
      buttonSpacing: (json['buttonSpacing'] as num?)?.toDouble() ?? 12.0,
      buttonCornerRadius: (json['buttonCornerRadius'] as num?)?.toDouble() ?? 16.0,
      textScaleFactor: (json['textScaleFactor'] as num?)?.toDouble() ?? 1.0,
      backgroundStyle: json['backgroundStyle'] as String? ?? 'gradient',
      animationSpeed: (json['animationSpeed'] as num?)?.toDouble() ?? 1.0,
      hapticFeedbackEnabled: json['hapticFeedbackEnabled'] as bool? ?? true,
      lockOrientationLandscape: json['lockOrientationLandscape'] as bool? ?? false,
      volumeStep: (json['volumeStep'] as num?)?.toDouble() ?? 5.0,
      brightnessStep: (json['brightnessStep'] as num?)?.toDouble() ?? 10.0,
      currentAudioOutput: json['currentAudioOutput'] as String? ?? 'Default Speakers (Realtek Audio)',
      audioOutputs: (json['audioOutputs'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      currentDisplay: json['currentDisplay'] as String? ?? 'Primary Monitor (1920x1080@144Hz)',
      displays: (json['displays'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      useHardwareBrightness: json['useHardwareBrightness'] as bool? ?? true,
      autoDiscoverWifi: json['autoDiscoverWifi'] as bool? ?? true,
      autoReconnectLastDevice: json['autoReconnectLastDevice'] as bool? ?? true,
      connectionTimeoutSeconds: json['connectionTimeoutSeconds'] as int? ?? 5,
      preferredDeviceId: json['preferredDeviceId'] as String? ?? '',
      requirePinForSensitiveActions: json['requirePinForSensitiveActions'] as bool? ?? true,
      redactLogs: json['redactLogs'] as bool? ?? true,
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? false,
      notifyOnDisconnect: json['notifyOnDisconnect'] as bool? ?? true,
      notifyOnProfileSwitch: json['notifyOnProfileSwitch'] as bool? ?? false,
    );
  }
}
