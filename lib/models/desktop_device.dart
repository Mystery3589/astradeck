enum ConnectionTransport {
  wifi,
  bluetooth,
  usb,
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  failed,
  unauthorized,
}

class DesktopDevice {
  final String id;
  String name;
  String operatingSystem;
  String osVersion;
  String agentVersion;
  String ipAddress;
  int port;
  String hostname;
  ConnectionTransport transport;
  ConnectionStatus status;
  bool isTrusted;
  String? authToken;
  int latencyMs;
  DateTime? lastConnected;
  List<String> supportedFeatures;
  List<String> availableApps;
  bool isPreferred;

  DesktopDevice({
    required this.id,
    required this.name,
    this.operatingSystem = 'Windows',
    this.osVersion = '11 Pro',
    this.agentVersion = '1.4.0',
    this.ipAddress = '192.168.1.100',
    this.port = 8765,
    this.hostname = '',
    this.transport = ConnectionTransport.wifi,
    this.status = ConnectionStatus.disconnected,
    this.isTrusted = false,
    this.authToken,
    this.latencyMs = 0,
    this.lastConnected,
    List<String>? supportedFeatures,
    List<String>? availableApps,
    this.isPreferred = false,
  })  : supportedFeatures = supportedFeatures ?? [
          'volume_control',
          'brightness_control',
          'mic_mute',
          'app_launch',
          'obs_control',
          'system_mute',
        ],
        availableApps = availableApps ?? [
          'Chrome',
          'Discord',
          'Spotify',
          'OBS Studio',
          'Steam',
          'VS Code',
          'Photoshop',
          'Calculator',
        ];

  DesktopDevice copyWith({
    String? id,
    String? name,
    String? operatingSystem,
    String? osVersion,
    String? agentVersion,
    String? ipAddress,
    int? port,
    String? hostname,
    ConnectionTransport? transport,
    ConnectionStatus? status,
    bool? isTrusted,
    String? authToken,
    int? latencyMs,
    DateTime? lastConnected,
    List<String>? supportedFeatures,
    List<String>? availableApps,
    bool? isPreferred,
  }) {
    return DesktopDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      osVersion: osVersion ?? this.osVersion,
      agentVersion: agentVersion ?? this.agentVersion,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      hostname: hostname ?? this.hostname,
      transport: transport ?? this.transport,
      status: status ?? this.status,
      isTrusted: isTrusted ?? this.isTrusted,
      authToken: authToken ?? this.authToken,
      latencyMs: latencyMs ?? this.latencyMs,
      lastConnected: lastConnected ?? this.lastConnected,
      supportedFeatures: supportedFeatures ?? List.from(this.supportedFeatures),
      availableApps: availableApps ?? List.from(this.availableApps),
      isPreferred: isPreferred ?? this.isPreferred,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'operatingSystem': operatingSystem,
    'osVersion': osVersion,
    'agentVersion': agentVersion,
    'ipAddress': ipAddress,
    'port': port,
    'hostname': hostname,
    'transport': transport.name,
    'isTrusted': isTrusted,
    'authToken': authToken,
    'latencyMs': latencyMs,
    'lastConnected': lastConnected?.toIso8601String(),
    'supportedFeatures': supportedFeatures,
    'availableApps': availableApps,
    'isPreferred': isPreferred,
  };

  factory DesktopDevice.fromJson(Map<String, dynamic> json) {
    return DesktopDevice(
      id: json['id'] as String? ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Desktop PC',
      operatingSystem: json['operatingSystem'] as String? ?? 'Windows',
      osVersion: json['osVersion'] as String? ?? '11',
      agentVersion: json['agentVersion'] as String? ?? '1.4.0',
      ipAddress: json['ipAddress'] as String? ?? '192.168.1.100',
      port: json['port'] as int? ?? 8765,
      hostname: json['hostname'] as String? ?? '',
      transport: ConnectionTransport.values.firstWhere(
        (e) => e.name == json['transport'],
        orElse: () => ConnectionTransport.wifi,
      ),
      status: ConnectionStatus.disconnected,
      isTrusted: json['isTrusted'] as bool? ?? false,
      authToken: json['authToken'] as String?,
      latencyMs: json['latencyMs'] as int? ?? 0,
      lastConnected: json['lastConnected'] != null
          ? DateTime.tryParse(json['lastConnected'] as String)
          : null,
      supportedFeatures: (json['supportedFeatures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['volume_control', 'brightness_control', 'mic_mute', 'app_launch', 'obs_control'],
      availableApps: (json['availableApps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Chrome', 'Discord', 'Spotify', 'OBS Studio', 'Steam'],
      isPreferred: json['isPreferred'] as bool? ?? false,
    );
  }
}
