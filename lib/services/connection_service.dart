import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/desktop_device.dart';
import 'storage_service.dart';

DesktopDevice _makeUsbLocalhost({int port = 8765}) => DesktopDevice(
      id: 'usb_localhost',
      name: 'This PC (ADB Reverse)',
      operatingSystem: 'Desktop',
      osVersion: '',
      agentVersion: '2.5.0',
      ipAddress: '127.0.0.1',
      port: port,
      transport: ConnectionTransport.usb,
      isTrusted: false,
      hostname: 'localhost via adb reverse',
    );

DesktopDevice _makeUsbTether({String ip = '192.168.42.1', int port = 8765}) => DesktopDevice(
      id: 'usb_tether',
      name: 'This PC (USB Tethering)',
      operatingSystem: 'Desktop',
      osVersion: '',
      agentVersion: '2.5.0',
      ipAddress: ip,
      port: port,
      transport: ConnectionTransport.usb,
      isTrusted: false,
      hostname: 'PC via USB Tethering (<1ms)',
    );

class ConnectionService extends ChangeNotifier {
  final StorageService _storage;
  List<DesktopDevice> _devices = [];
  DesktopDevice? _activeDevice;
  bool _isScanning = false;
  String? _lastError;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _livePollTimer;
  bool _isLivePolling = false;
  int _lastPingSent = 0;
  int _lastPongReceived = 0;

  /// Called when the server pushes a system_state message with current volume/brightness.
  void Function(double? volume, double? brightness)? onSystemState;

  // --- Bluetooth Platform Channel Fields ---
  static const _btMethod = MethodChannel('com.astradeck/bluetooth');
  static const _btEvents = EventChannel('com.astradeck/bluetooth_events');
  StreamSubscription? _btEventSub;
  bool _isBtConnected = false;
  String? _btConnectedAddress;
  String? _btConnectingAddress;
  Timer? _btPingTimer;

  bool _isBluetoothScanning = false;
  List<Map<String, dynamic>> _discoveredBluetoothDevices = [];

  bool _isUsbConnecting = false;
  String _usbDeviceDetails =
      'Connect phone via USB cable, then run 1-click setup on PC.';

  int _consecutiveReconnectFailures = 0;
  bool _isAutoReconnecting = false;
  bool _isManualDisconnect = false;

  ConnectionService(this._storage) {
    _initBluetoothListener();
    _loadInitial();
  }

  List<DesktopDevice> get devices => _devices;
  DesktopDevice? get activeDevice => _activeDevice;
  bool get isConnected =>
      (_activeDevice?.status == ConnectionStatus.connected) || _isBtConnected;
  bool get isConnecting =>
      _activeDevice?.status == ConnectionStatus.connecting ||
      _isUsbConnecting ||
      (_btConnectingAddress != null);
  bool get isScanning => _isScanning;
  bool get isLivePolling => _isLivePolling;
  String? get lastError => _lastError;

  int get consecutiveReconnectFailures => _consecutiveReconnectFailures;
  bool get isAutoReconnecting => _isAutoReconnecting;
  bool get isWaitingForHost =>
      !isConnected && _isAutoReconnecting && _consecutiveReconnectFailures >= 2;

  bool get isBluetoothScanning => _isBluetoothScanning;
  List<Map<String, dynamic>> get discoveredBluetoothDevices =>
      _discoveredBluetoothDevices;
  bool get isBtConnected => _isBtConnected;
  String? get btConnectedAddress => _btConnectedAddress;
  String? get btConnectingAddress => _btConnectingAddress;

  bool get isUsbConnecting => _isUsbConnecting;
  bool get isUsbConnected =>
      _devices.any((d) =>
          (d.id == 'usb_localhost' || d.id == 'usb_tether') &&
          d.status == ConnectionStatus.connected);
  String get usbDeviceDetails => _usbDeviceDetails;

  void _loadInitial() {
    _devices = _storage.loadDevices();
    // Prune any legacy transient usb entries from disk
    _devices.removeWhere((d) => d.id == 'usb_localhost' || d.id == 'usb_tether');
    _savePersistentDevices();

    final preferred = _devices.where((d) => d.isPreferred).firstOrNull;
    if (preferred != null) {
      _activeDevice = preferred;
    } else if (_devices.isNotEmpty) {
      _activeDevice = _devices.first;
    }

    // Proactively attempt auto-connection across transports on startup
    Future.delayed(const Duration(milliseconds: 300), () => autoConnect());
  }

  Future<void> _savePersistentDevices() async {
    final toSave = _devices
        .where((d) => d.id != 'usb_localhost' && d.transport == ConnectionTransport.wifi)
        .toList();
    await _storage.saveDevices(toSave);
  }

  // ---------------------------------------------------------------------------
  // Android USB Tethering & ADB Probers
  // ---------------------------------------------------------------------------

  /// Opens Android's native Tethering Settings screen directly so the user
  /// can toggle "USB Tethering" with 1 tap (No Developer Options required).
  Future<void> openTetheringSettings() async {
    try {
      await _btMethod.invokeMethod('openTetheringSettings');
    } catch (e) {
      debugPrint('Error launching tethering settings: $e');
    }
  }

  /// Discovers the PC companion over a direct USB Tethering network interface (Without ADB).
  /// Inspects candidate gateways (192.168.42.1, 192.168.43.1, etc.) and active interfaces.
  Future<({String ip, int port})?> findUsbTetherGateway() async {
    final candidateIps = <String>{
      '192.168.42.1',  // Android RNDIS default
      '192.168.43.1',  // Android alternative
      '192.168.44.1',
      '10.42.0.1',     // Linux NetworkManager USB tether
      '192.168.137.1', // Windows ICS default
    };

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          final parts = ip.split('.');
          if (parts.length == 4) {
            candidateIps.add('${parts[0]}.${parts[1]}.${parts[2]}.1');
          }
        }
      }
    } catch (e) {
      debugPrint('Interface inspection for USB Tethering: $e');
    }

    // Probe candidate host IPs on ports 8765-8775
    for (final hostIp in candidateIps) {
      for (int port = 8765; port <= 8775; port++) {
        if (await _tcpProbe(hostIp, port, timeout: 140)) {
          return (ip: hostIp, port: port);
        }
      }
    }
    return null;
  }

  /// Probes ADB reverse tunnel on localhost (127.0.0.1) across dynamic ports.
  Future<int?> findOpenUsbPort() async {
    for (int port = 8765; port <= 8780; port++) {
      if (await _tcpProbe('127.0.0.1', port, timeout: 180)) {
        return port;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Multi-Transport Auto-Connect (USB Tethering First -> ADB -> Wi-Fi)
  // ---------------------------------------------------------------------------

  Future<bool> autoConnect() async {
    if (isConnected) return true;

    // 1. Probe USB Tethering gateway (PRIMARY - Zero Developer Options, <1ms)
    final tether = await findUsbTetherGateway();
    if (tether != null) {
      final tetherIndex = _devices.indexWhere((d) => d.id == 'usb_tether');
      if (tetherIndex != -1) {
        _devices[tetherIndex].ipAddress = tether.ip;
        _devices[tetherIndex].port = tether.port;
      } else {
        _devices.insert(0, _makeUsbTether(ip: tether.ip, port: tether.port));
      }
      final tetherDevice = _devices.firstWhere((d) => d.id == 'usb_tether');
      return await connectTo(tetherDevice, pin: tetherDevice.authToken != null ? null : '1234');
    }

    // 2. Probe USB localhost across dynamic port range via ADB reverse
    final usbPort = await findOpenUsbPort();
    if (usbPort != null) {
      final usbIndex = _devices.indexWhere((d) => d.id == 'usb_localhost');
      if (usbIndex != -1) {
        _devices[usbIndex].port = usbPort;
      } else {
        _devices.insert(0, _makeUsbLocalhost(port: usbPort));
      }
      final usbDevice = _devices.firstWhere((d) => d.id == 'usb_localhost');
      return await connectTo(usbDevice, pin: usbDevice.authToken != null ? null : '1234');
    }

    // 3. Probe preferred device (Wi-Fi or Bluetooth)
    final preferred =
        _devices.where((d) => d.isPreferred && d.id != 'usb_localhost' && d.id != 'usb_tether').firstOrNull;
    if (preferred != null) {
      if (await _tcpProbe(preferred.ipAddress, preferred.port, timeout: 500)) {
        return await connectTo(preferred, pin: preferred.authToken != null ? null : '1234');
      }
    }

    // 4. Probe any trusted device
    for (final dev in _devices.where((d) => d.isTrusted && d.id != 'usb_localhost' && d.id != 'usb_tether')) {
      if (await _tcpProbe(dev.ipAddress, dev.port, timeout: 350)) {
        return await connectTo(dev, pin: dev.authToken != null ? null : '1234');
      }
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Live Background Polling (During Setup Modal)
  // ---------------------------------------------------------------------------

  void startLivePolling({VoidCallback? onConnected}) {
    if (_isLivePolling) return;
    _isLivePolling = true;
    notifyListeners();

    _livePollTimer?.cancel();
    _livePollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (isConnected) {
        stopLivePolling();
        onConnected?.call();
        return;
      }
      final ok = await autoConnect();
      if (ok) {
        stopLivePolling();
        onConnected?.call();
      }
    });
  }

  void stopLivePolling() {
    _isLivePolling = false;
    _livePollTimer?.cancel();
    _livePollTimer = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // USB Check / Connect Action (Supports Both Tethering and ADB)
  // ---------------------------------------------------------------------------

  Future<void> checkUsbStatus({bool preferAdb = false}) async {
    _isUsbConnecting = true;
    _lastError = null;
    _usbDeviceDetails = preferAdb
        ? 'Probing ADB reverse on 127.0.0.1...'
        : 'Probing USB Tethering (No ADB needed)...';
    notifyListeners();

    // 1. If not preferAdb: Check USB Tethering FIRST (Zero Developer Options / Consumer mode)
    if (!preferAdb) {
      final tether = await findUsbTetherGateway();
      if (tether != null) {
        final tetherIndex = _devices.indexWhere((d) => d.id == 'usb_tether');
        if (tetherIndex != -1) {
          _devices[tetherIndex].ipAddress = tether.ip;
          _devices[tetherIndex].port = tether.port;
        } else {
          _devices.insert(0, _makeUsbTether(ip: tether.ip, port: tether.port));
        }
        final tetherDevice = _devices.firstWhere((d) => d.id == 'usb_tether');
        _usbDeviceDetails = 'Found PC on USB Tether (${tether.ip}:${tether.port}) — connecting...';
        notifyListeners();

        final ok = await connectTo(tetherDevice, pin: '1234');
        _isUsbConnecting = false;
        if (ok) {
          _usbDeviceDetails = 'Connected via USB Tethering (<1ms, ${tether.ip}:${tether.port})';
        } else {
          _usbDeviceDetails = 'Connected to USB gateway but handshake failed.';
        }
        notifyListeners();
        return;
      }
    }

    // 2. Check ADB reverse localhost (127.0.0.1)
    final foundPort = await findOpenUsbPort();
    if (foundPort != null) {
      final usbIndex = _devices.indexWhere((d) => d.id == 'usb_localhost');
      if (usbIndex != -1) {
        _devices[usbIndex].port = foundPort;
      } else {
        _devices.insert(0, _makeUsbLocalhost(port: foundPort));
      }
      final usbDevice = _devices.firstWhere((d) => d.id == 'usb_localhost');
      _usbDeviceDetails = 'Server active via ADB on port $foundPort — connecting...';
      notifyListeners();

      final ok = await connectTo(usbDevice, pin: '1234');
      _isUsbConnecting = false;
      if (ok) {
        _usbDeviceDetails = 'Connected via USB ADB reverse (Port $foundPort)';
      } else {
        _usbDeviceDetails = 'Connection failed. Ensure server is active.';
      }
      notifyListeners();
      return;
    }

    // 3. Fallback: If preferAdb was true, also try tethering as a last resort
    if (preferAdb) {
      final tether = await findUsbTetherGateway();
      if (tether != null) {
        final tetherIndex = _devices.indexWhere((d) => d.id == 'usb_tether');
        if (tetherIndex != -1) {
          _devices[tetherIndex].ipAddress = tether.ip;
          _devices[tetherIndex].port = tether.port;
        } else {
          _devices.insert(0, _makeUsbTether(ip: tether.ip, port: tether.port));
        }
        final tetherDevice = _devices.firstWhere((d) => d.id == 'usb_tether');
        _usbDeviceDetails = 'Found PC on USB Tether (${tether.ip}:${tether.port}) — connecting...';
        notifyListeners();
        final ok = await connectTo(tetherDevice, pin: '1234');
        _isUsbConnecting = false;
        if (ok) {
          _usbDeviceDetails = 'Connected via USB Tethering (${tether.ip}:${tether.port})';
        }
        notifyListeners();
        return;
      }
    }

    _isUsbConnecting = false;
    _usbDeviceDetails = preferAdb
        ? 'No ADB reverse tunnel active on 127.0.0.1.\n\nRun on PC:\n  adb reverse tcp:8765 tcp:8765'
        : 'USB not detected.\n\n1. Plug in USB cable\n2. Turn ON "USB Tethering" in Settings (tap button below)\n3. Or run 1-click PC setup.';
    _lastError = preferAdb
        ? 'ADB reverse not detected.'
        : 'USB Tethering not detected. Turn on USB Tethering in Settings.';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Wi-Fi Discovery (with Dynamic Port parsing)
  // ---------------------------------------------------------------------------

  Future<void> scanForDevices() async {
    _isScanning = true;
    _lastError = null;
    notifyListeners();

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final msg = utf8.encode('ASTRADECK_DISCOVER');
      socket.send(msg, InternetAddress('255.255.255.255'), 8765);

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null) {
            try {
              final text = utf8.decode(dg.data);
              final json = jsonDecode(text);
              if (json['type'] == 'ASTRADECK_BEACON') {
                _handleBeacon(json, dg.address.address);
              }
            } catch (_) {}
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 2500));
    } catch (e) {
      debugPrint('UDP discovery: $e');
    } finally {
      socket?.close();
    }

    if (_devices.where((d) => d.id != 'usb_localhost').isEmpty) {
      await _tcpFallbackScan();
    }

    _isScanning = false;
    notifyListeners();
  }

  void _handleBeacon(Map<String, dynamic> json, String sourceIp) {
    // sourceIp is the actual IP the phone received the packet from — guaranteed reachable!
    final ip = (sourceIp.isNotEmpty && sourceIp != '0.0.0.0' && sourceIp != '127.0.0.1')
        ? sourceIp
        : (json['ip']?.toString() ?? sourceIp);
    final port = (json['port'] as num?)?.toInt() ?? 8765;
    final name = json['name'] ?? 'AstraDeck Host';
    final exists =
        _devices.indexWhere((d) => d.ipAddress == ip && d.port == port);
    if (exists != -1) {
      _devices[exists].name = name;
      _devices[exists].operatingSystem = json['os'] ?? 'Desktop';
      _devices[exists].osVersion = json['osVersion'] ?? '';
      _devices[exists].agentVersion = json['agentVersion'] ?? '2.5.0';
    } else {
      _devices.add(DesktopDevice(
        id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        operatingSystem: json['os'] ?? 'Desktop',
        osVersion: json['osVersion'] ?? '',
        agentVersion: json['agentVersion'] ?? '2.5.0',
        ipAddress: ip,
        port: port,
        transport: ConnectionTransport.wifi,
      ));
    }
    _savePersistentDevices();
    notifyListeners();
  }

  Future<void> _tcpFallbackScan() async {
    final candidates = <String>{};
    for (final d in _devices) {
      if (d.id != 'usb_localhost') candidates.add(d.ipAddress);
    }
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4 && addr.address != '127.0.0.1') {
            for (int i = 1; i <= 20; i++) {
              candidates.add('${parts[0]}.${parts[1]}.${parts[2]}.$i');
            }
          }
        }
      }
    } catch (_) {}

    final probes = candidates.map((ip) async {
      for (int port = 8765; port <= 8768; port++) {
        if (await _tcpProbe(ip, port, timeout: 350)) {
          if (!_devices.any((d) => d.ipAddress == ip && d.port == port)) {
            final uniqueId = 'dev_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(10000)}_${ip.replaceAll('.', '')}';
            _devices.add(DesktopDevice(
              id: uniqueId,
              name: 'AstraDeck Host ($ip)',
              operatingSystem: 'Desktop',
              osVersion: '',
              agentVersion: '2.5.0',
              ipAddress: ip,
              port: port,
              transport: ConnectionTransport.wifi,
            ));
            _savePersistentDevices();
            notifyListeners();
          }
          break;
        }
      }
    });
    await Future.wait(probes);
  }

  Future<bool> _tcpProbe(String host, int port, {int timeout = 1500}) async {
    try {
      final sock =
          await Socket.connect(host, port, timeout: Duration(milliseconds: timeout));
      sock.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<DesktopDevice> addManualDevice({
    required String name,
    required String ipAddress,
    required int port,
    String hostname = '',
    ConnectionTransport transport = ConnectionTransport.wifi,
  }) async {
    final newDevice = DesktopDevice(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      name: name.isEmpty ? 'Custom Desktop ($ipAddress)' : name,
      ipAddress: ipAddress,
      port: port,
      hostname: hostname,
      transport: transport,
      isTrusted: false,
    );
    _devices.add(newDevice);
    await _savePersistentDevices();
    notifyListeners();
    return newDevice;
  }

  // ---------------------------------------------------------------------------
  // WebSocket Connection Lifecycle
  // ---------------------------------------------------------------------------

  Future<bool> connectTo(DesktopDevice device, {String? pin}) async {
    _lastError = null;
    final initialIndex = _devices.indexWhere((d) => d.id == device.id);
    if (initialIndex == -1) return false;

    _devices[initialIndex].status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final wsUri = Uri.parse('ws://${device.ipAddress}:${device.port}');
      _closeWs();

      _wsChannel = WebSocketChannel.connect(wsUri);
      await _wsChannel!.ready.timeout(const Duration(seconds: 4));

      final completer = Completer<bool>();

      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString());
            final currentIdx = _devices.indexWhere((d) => d.id == device.id);
            if (currentIdx == -1) return;

            if (json['type'] == 'pong') {
              _lastPongReceived = DateTime.now().millisecondsSinceEpoch;
              final sendTime = json['timestamp'] as int? ?? 0;
              if (sendTime > 0) {
                _devices[currentIdx].latencyMs =
                    DateTime.now().millisecondsSinceEpoch - sendTime;
                notifyListeners();
              }
            } else if (json['type'] == 'system_state') {
              // Server pushed volume/brightness after auth — notify listeners to sync
              final vol = (json['volume'] as num?)?.toDouble();
              final brightness = (json['brightness'] as num?)?.toDouble();
              onSystemState?.call(vol, brightness);
            } else if (json['status'] == 'authenticated') {
              _devices[currentIdx].status = ConnectionStatus.connected;
              _devices[currentIdx].isTrusted = true;
              _devices[currentIdx].authToken = json['token'] ?? 'session_ok';
              _devices[currentIdx].lastConnected = DateTime.now();
              _activeDevice = _devices[currentIdx];
              _consecutiveReconnectFailures = 0;
              _isAutoReconnecting = false;
              _isManualDisconnect = false;
              _storage.saveDevices(_devices.where((d) => d.transport == ConnectionTransport.wifi).toList());
              _startHeartbeat(currentIdx);
              stopLivePolling();
              notifyListeners();
              if (!completer.isCompleted) completer.complete(true);
            } else if (json['status'] == 'unauthorized') {
              _devices[currentIdx].status = ConnectionStatus.unauthorized;
              _lastError = json['message'] ?? 'Invalid PIN';
              notifyListeners();
              if (!completer.isCompleted) completer.complete(false);
            }
          } catch (e) {
            debugPrint('WS decode: $e');
          }
        },
        onError: (err) {
          final currentIdx = _devices.indexWhere((d) => d.id == device.id);
          if (currentIdx != -1) {
            _devices[currentIdx].status = ConnectionStatus.failed;
          }
          _lastError = 'Connection lost: $err';
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
          if (!_isManualDisconnect) {
            _scheduleAutoReconnect(device, pin: pin);
          }
        },
        onDone: () {
          final currentIdx = _devices.indexWhere((d) => d.id == device.id);
          if (_activeDevice?.id == device.id &&
              currentIdx != -1 &&
              _devices[currentIdx].status == ConnectionStatus.connected) {
            _devices[currentIdx].status = ConnectionStatus.disconnected;
            _activeDevice?.status = ConnectionStatus.disconnected;
            _lastError = 'Companion disconnected. Retrying...';
            _pingTimer?.cancel();
            notifyListeners();
            if (!_isManualDisconnect) {
              _scheduleAutoReconnect(device, pin: pin);
            }
          }
        },
      );

      // Authenticate with token or PIN
      final resolvedPin = pin ?? (device.authToken != null ? '' : '1234');
      _wsChannel!.sink.add(jsonEncode({
        'action': 'auth',
        'pin': resolvedPin,
        'token': device.authToken ?? '',
        'id': 1,
      }));

      try {
        return await completer.future.timeout(const Duration(seconds: 4));
      } on TimeoutException {
        if (!completer.isCompleted) completer.complete(false);
        final currentIdx = _devices.indexWhere((d) => d.id == device.id);
        if (currentIdx != -1 && _devices[currentIdx].status == ConnectionStatus.connecting) {
          _devices[currentIdx].status = ConnectionStatus.failed;
          _lastError = 'Authentication timed out';
          notifyListeners();
        }
        return false;
      }
    } catch (e) {
      final currentIdx = _devices.indexWhere((d) => d.id == device.id);
      if (currentIdx != -1) {
        _devices[currentIdx].status = ConnectionStatus.failed;
      }
      _lastError = 'Cannot reach ${device.ipAddress}:${device.port}';
      notifyListeners();
      return false;
    }
  }

  void _scheduleAutoReconnect(DesktopDevice device, {String? pin}) {
    if (_isManualDisconnect) return;
    _isAutoReconnecting = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      if (isConnected || _isManualDisconnect) {
        _isAutoReconnecting = false;
        return;
      }

      // If USB localhost, probe open ports in case companion auto-restarted on a shifted port
      if (device.id == 'usb_localhost') {
        final newPort = await findOpenUsbPort();
        if (newPort != null) {
          device.port = newPort;
          final usbIndex = _devices.indexWhere((d) => d.id == 'usb_localhost');
          if (usbIndex != -1) {
            _devices[usbIndex].port = newPort;
          }
        }
      }

      final ok = await connectTo(device, pin: pin);
      if (!ok && !_isManualDisconnect && !isConnected) {
        _consecutiveReconnectFailures++;
        notifyListeners();
        _scheduleAutoReconnect(device, pin: pin);
      }
    });
  }

  void _closeWs() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void disconnect([DesktopDevice? device]) {
    _isManualDisconnect = true;
    _isAutoReconnecting = false;
    _consecutiveReconnectFailures = 0;
    _closeWs();
    final target = device ?? _activeDevice;
    if (target != null) {
      if (target.transport == ConnectionTransport.bluetooth ||
          target.id.startsWith('bt_')) {
        disconnectBluetooth();
      }
      final index = _devices.indexWhere((d) => d.id == target.id);
      if (index != -1) _devices[index].status = ConnectionStatus.disconnected;
      if (_activeDevice?.id == target.id) {
        _activeDevice?.status = ConnectionStatus.disconnected;
      }
    }
    notifyListeners();
  }

  void disconnectAll() {
    _isManualDisconnect = true;
    _isAutoReconnecting = false;
    _consecutiveReconnectFailures = 0;
    _closeWs();
    disconnectBluetooth();
    for (var d in _devices) {
      d.status = ConnectionStatus.disconnected;
    }
    _activeDevice = null;
    _savePersistentDevices();
    notifyListeners();
  }

  Future<void> forgetDevice(String id) async {
    if (id == 'usb_localhost') return;
    if (_activeDevice?.id == id) {
      disconnect(_activeDevice);
      _activeDevice = null;
    }
    _devices.removeWhere((d) => d.id == id);
    await _savePersistentDevices();
    notifyListeners();
  }

  Future<void> setPreferredDevice(String id) async {
    for (var d in _devices) {
      d.isPreferred = (d.id == id);
    }
    await _savePersistentDevices();
    notifyListeners();
  }

  Future<void> revokeTrust(String id) async {
    final index = _devices.indexWhere((d) => d.id == id);
    if (index != -1) {
      _devices[index].isTrusted = false;
      _devices[index].authToken = null;
      if (_devices[index].status == ConnectionStatus.connected) {
        disconnect(_devices[index]);
      }
      await _savePersistentDevices();
      notifyListeners();
    }
  }

  Future<int> testConnection(DesktopDevice device) async {
    final start = DateTime.now().millisecondsSinceEpoch;
    if (_wsChannel != null && isConnected) {
      _wsChannel!.sink.add(jsonEncode({
        'action': 'ping',
        'timestamp': start,
        'id': Random().nextInt(10000),
      }));
      await Future.delayed(const Duration(milliseconds: 100));
      return device.latencyMs;
    } else if (_isBtConnected) {
      final payload = jsonEncode({
        'action': 'ping',
        'timestamp': start,
        'id': Random().nextInt(10000),
      });
      _btMethod.invokeMethod('sendData', {'data': payload});
      await Future.delayed(const Duration(milliseconds: 100));
      return device.latencyMs;
    }
    return -1;
  }

  void sendAction(String action, Map<String, dynamic> payload) {
    if (_wsChannel != null && isConnected) {
      _wsChannel!.sink.add(jsonEncode({
        'action': action,
        'payload': payload,
        'id': DateTime.now().millisecondsSinceEpoch,
      }));
      debugPrint('[ConnectionService WS] -> $action');
    } else if (_isBtConnected) {
      final data = jsonEncode({
        'action': action,
        'payload': payload,
        'id': DateTime.now().millisecondsSinceEpoch,
      });
      _btMethod.invokeMethod('sendData', {'data': data});
      debugPrint('[ConnectionService BT] -> $action');
    } else {
      debugPrint('[ConnectionService] dropped (not connected): $action');
    }
  }

  void _startHeartbeat(int deviceIndex) {
    _pingTimer?.cancel();
    _lastPingSent = DateTime.now().millisecondsSinceEpoch;
    _lastPongReceived = _lastPingSent;

    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_wsChannel != null && isConnected) {
        final now = DateTime.now().millisecondsSinceEpoch;

        // Watchdog: If cable was yanked or PC crashed, missed pongs for >3.5s triggers instant disconnect!
        if (_lastPingSent > 0 && (now - _lastPongReceived) > 3500) {
          debugPrint('[Heartbeat Watchdog] No pong for >3.5s (cable unplugged or host offline). Dropping socket.');
          _pingTimer?.cancel();
          _closeWs();
          if (deviceIndex < _devices.length) {
            _devices[deviceIndex].status = ConnectionStatus.disconnected;
          }
          if (_activeDevice != null &&
              deviceIndex < _devices.length &&
              _activeDevice!.id == _devices[deviceIndex].id) {
            _activeDevice!.status = ConnectionStatus.disconnected;
          }
          notifyListeners();
          if (!_isManualDisconnect && deviceIndex < _devices.length) {
            _scheduleAutoReconnect(_devices[deviceIndex]);
          }
          return;
        }

        _lastPingSent = now;
        _wsChannel!.sink.add(
            jsonEncode({'action': 'ping', 'timestamp': now, 'id': now}));
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Native Bluetooth Implementation
  // ---------------------------------------------------------------------------

  void _initBluetoothListener() {
    _btEventSub?.cancel();
    _btEventSub = _btEvents.receiveBroadcastStream().listen((dynamic event) {
      if (event is! Map) return;
      final type = event['event']?.toString();
      debugPrint('[BT Event] $type');

      if (type == 'device_found') {
        final address = event['address']?.toString() ?? '';
        final name = event['name']?.toString() ?? address;
        final bonded = event['bonded'] == true;
        if (address.isNotEmpty) {
          final idx = _discoveredBluetoothDevices
              .indexWhere((d) => d['address'] == address);
          if (idx != -1) {
            _discoveredBluetoothDevices[idx] = {
              'name': name,
              'address': address,
              'bonded': bonded,
            };
          } else {
            _discoveredBluetoothDevices.add({
              'name': name,
              'address': address,
              'bonded': bonded,
            });
          }
          notifyListeners();
        }
      } else if (type == 'discovery_finished') {
        _isBluetoothScanning = false;
        notifyListeners();
      } else if (type == 'connected') {
        _isBtConnected = true;
        _btConnectingAddress = null;
        final address = event['address']?.toString() ?? '';
        final name = event['name']?.toString() ?? 'Bluetooth Device';
        _btConnectedAddress = address;

        final deviceId = 'bt_$address';
        int idx = _devices.indexWhere((d) => d.id == deviceId);
        if (idx == -1) {
          final btDev = DesktopDevice(
            id: deviceId,
            name: name,
            ipAddress: address,
            port: 4,
            transport: ConnectionTransport.bluetooth,
            status: ConnectionStatus.connected,
            isTrusted: true,
            lastConnected: DateTime.now(),
          );
          _devices.add(btDev);
          idx = _devices.length - 1;
        } else {
          _devices[idx].status = ConnectionStatus.connected;
          _devices[idx].name = name;
          _devices[idx].lastConnected = DateTime.now();
        }
        _activeDevice = _devices[idx];
        // Do not persist BT devices — they are transient and auto-discovered on each scan
        _startBtHeartbeat(idx);
        notifyListeners();
      } else if (type == 'connect_failed') {
        _isBtConnected = false;
        _btConnectingAddress = null;
        _lastError = event['error']?.toString() ?? 'Bluetooth connection failed';
        if (_btConnectedAddress != null) {
          final idx =
              _devices.indexWhere((d) => d.id == 'bt_$_btConnectedAddress');
          if (idx != -1) _devices[idx].status = ConnectionStatus.failed;
        }
        notifyListeners();
      } else if (type == 'disconnected') {
        _isBtConnected = false;
        _btConnectingAddress = null;
        _btPingTimer?.cancel();
        if (_btConnectedAddress != null) {
          final idx =
              _devices.indexWhere((d) => d.id == 'bt_$_btConnectedAddress');
          if (idx != -1) _devices[idx].status = ConnectionStatus.disconnected;
        }
        if (_activeDevice?.id == 'bt_$_btConnectedAddress') {
          _activeDevice?.status = ConnectionStatus.disconnected;
        }
        _btConnectedAddress = null;
        notifyListeners();
      } else if (type == 'data') {
        try {
          final raw = event['message']?.toString() ?? '';
          if (raw.isNotEmpty) {
            final json = jsonDecode(raw);
            if (json is Map) {
              if (json['type'] == 'pong') {
                final sendTime = json['timestamp'] as int? ?? 0;
                if (sendTime > 0 && _btConnectedAddress != null) {
                  final idx = _devices
                      .indexWhere((d) => d.id == 'bt_$_btConnectedAddress');
                  if (idx != -1) {
                    _devices[idx].latencyMs =
                        DateTime.now().millisecondsSinceEpoch - sendTime;
                    notifyListeners();
                  }
                }
              } else if (json['type'] == 'system_state') {
                final vol = (json['volume'] as num?)?.toDouble();
                final brightness = (json['brightness'] as num?)?.toDouble();
                onSystemState?.call(vol, brightness);
              }
            }
          }
        } catch (e) {
          debugPrint('BT data decode error: $e');
        }
      }
    }, onError: (err) {
      debugPrint('[BT Event Stream Error] $err');
    });
  }

  Future<bool> isBluetoothSupported() async {
    try {
      final res = await _btMethod.invokeMethod<bool>('isBluetoothSupported');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      final res = await _btMethod.invokeMethod<bool>('isBluetoothEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestEnableBluetooth() async {
    try {
      await _btMethod.invokeMethod('requestEnableBluetooth');
    } catch (e) {
      debugPrint('Error enabling bluetooth: $e');
    }
  }

  Future<void> scanBluetooth() async {
    _isBluetoothScanning = true;
    _discoveredBluetoothDevices = [];
    notifyListeners();

    try {
      // 1. Check & request permissions
      final hasPerm =
          await _btMethod.invokeMethod<bool>('checkPermissions') ?? false;
      if (!hasPerm) {
        await _btMethod.invokeMethod('requestPermissions');
      }

      // 2. Check if Bluetooth is enabled
      final isEnabled =
          await _btMethod.invokeMethod<bool>('isBluetoothEnabled') ?? false;
      if (!isEnabled) {
        await _btMethod.invokeMethod('requestEnableBluetooth');
        _isBluetoothScanning = false;
        notifyListeners();
        return;
      }

      // 3. Fetch bonded devices first
      final bonded =
          await _btMethod.invokeListMethod<dynamic>('getBondedDevices') ?? [];
      for (final dev in bonded) {
        if (dev is Map) {
          final address = dev['address']?.toString() ?? '';
          final name = dev['name']?.toString() ?? address;
          if (address.isNotEmpty) {
            _discoveredBluetoothDevices.add({
              'name': name,
              'address': address,
              'bonded': true,
            });
          }
        }
      }
      notifyListeners();

      // 4. Start discovery for nearby unbonded devices
      await _btMethod.invokeMethod('startDiscovery');
    } catch (e) {
      debugPrint('scanBluetooth error: $e');
      _isBluetoothScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopBluetoothScan() async {
    try {
      await _btMethod.invokeMethod('stopDiscovery');
    } catch (_) {}
    _isBluetoothScanning = false;
    notifyListeners();
  }

  Future<void> connectBluetooth(String address,
      {String name = 'Bluetooth Device'}) async {
    _btConnectingAddress = address;
    _lastError = null;
    notifyListeners();

    try {
      await _btMethod.invokeMethod('connect', {'address': address});
    } catch (e) {
      _btConnectingAddress = null;
      _lastError = 'Failed to initiate BT connection: $e';
      notifyListeners();
    }
  }

  Future<void> disconnectBluetooth() async {
    try {
      await _btMethod.invokeMethod('disconnect');
    } catch (_) {}
    _isBtConnected = false;
    _btConnectedAddress = null;
    _btConnectingAddress = null;
    _btPingTimer?.cancel();
    notifyListeners();
  }

  void _startBtHeartbeat(int deviceIndex) {
    _btPingTimer?.cancel();
    _btPingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isBtConnected) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final payload =
            jsonEncode({'action': 'ping', 'timestamp': now, 'id': now});
        _btMethod.invokeMethod('sendData', {'data': payload});
      }
    });
  }

  @override
  void dispose() {
    _btEventSub?.cancel();
    _btPingTimer?.cancel();
    disconnectBluetooth();
    stopLivePolling();
    _closeWs();
    super.dispose();
  }
}
