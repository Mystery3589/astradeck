import 'dart:convert';

class ObsConfig {
  bool isEnabled;
  String host;
  int port;
  String password; // Kept in memory, obfuscated on disk, never logged or exported
  bool isConnected;
  String currentScene;
  List<String> availableScenes;
  String micSourceName;
  List<String> availableSources;
  bool isStreaming;
  bool isRecording;
  bool isMicMuted;

  ObsConfig({
    this.isEnabled = false,
    this.host = '192.168.1.100',
    this.port = 4455,
    this.password = '',
    this.isConnected = false,
    this.currentScene = 'Main Gameplay',
    List<String>? availableScenes,
    this.micSourceName = 'Mic/Aux',
    List<String>? availableSources,
    this.isStreaming = false,
    this.isRecording = false,
    this.isMicMuted = false,
  })  : availableScenes = availableScenes ?? [
          'Main Gameplay',
          'Intermission / Chat',
          'Be Right Back',
          'Starting Soon',
          'Ending Scene',
        ],
        availableSources = availableSources ?? [
          'Mic/Aux',
          'Desktop Audio',
          'Facecam Elgato',
          'Gameplay Capture',
          'Discord Audio',
        ];

  ObsConfig copyWith({
    bool? isEnabled,
    String? host,
    int? port,
    String? password,
    bool? isConnected,
    String? currentScene,
    List<String>? availableScenes,
    String? micSourceName,
    List<String>? availableSources,
    bool? isStreaming,
    bool? isRecording,
    bool? isMicMuted,
  }) {
    return ObsConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      host: host ?? this.host,
      port: port ?? this.port,
      password: password ?? this.password,
      isConnected: isConnected ?? this.isConnected,
      currentScene: currentScene ?? this.currentScene,
      availableScenes: availableScenes ?? List.from(this.availableScenes),
      micSourceName: micSourceName ?? this.micSourceName,
      availableSources: availableSources ?? List.from(this.availableSources),
      isStreaming: isStreaming ?? this.isStreaming,
      isRecording: isRecording ?? this.isRecording,
      isMicMuted: isMicMuted ?? this.isMicMuted,
    );
  }

  // Safe JSON for export/profile storage - NEVER includes plain text password
  Map<String, dynamic> toExportJson() => {
    'isEnabled': isEnabled,
    'host': host,
    'port': port,
    'currentScene': currentScene,
    'availableScenes': availableScenes,
    'micSourceName': micSourceName,
    'availableSources': availableSources,
  };

  // Internal storage JSON (stores password encoded)
  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'host': host,
    'port': port,
    'password': base64Encode(utf8.encode(password)),
    'currentScene': currentScene,
    'availableScenes': availableScenes,
    'micSourceName': micSourceName,
    'availableSources': availableSources,
  };

  factory ObsConfig.fromJson(Map<String, dynamic> json) {
    String decodedPassword = '';
    if (json['password'] != null) {
      try {
        decodedPassword = utf8.decode(base64Decode(json['password'] as String));
      } catch (_) {
        decodedPassword = json['password'] as String? ?? '';
      }
    }
    return ObsConfig(
      isEnabled: json['isEnabled'] as bool? ?? false,
      host: json['host'] as String? ?? '192.168.1.100',
      port: json['port'] as int? ?? 4455,
      password: decodedPassword,
      isConnected: false,
      currentScene: json['currentScene'] as String? ?? 'Main Gameplay',
      availableScenes: (json['availableScenes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Main Gameplay', 'Intermission / Chat', 'Be Right Back'],
      micSourceName: json['micSourceName'] as String? ?? 'Mic/Aux',
      availableSources: (json['availableSources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Mic/Aux', 'Desktop Audio', 'Facecam Elgato'],
    );
  }
}
