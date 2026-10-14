import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/desktop_device.dart';
import 'storage_service.dart';

DesktopDevice _makeUsbLocalhost({int port = 8765}) => DesktopDevice(
      id: 'usb_localhost',
      name: 'This PC (USB Cable)',
      operatingSystem: 'Desktop',
      osVersion: '',
      agentVersion: '2.5.0',
      ipAddress: '127.0.0.1',
      port: port,
      transport: ConnectionTransport.usb,
      isTrusted: false,
      hostname: 'localhost via adb reverse',
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

  bool _isBluetoothScanning = false;
  List<Map<String, dynamic>> _discoveredBluetoothDevices = [];

  bool _isUsbConnecting = false;
  String _usbDeviceDetails =
      'Connect phone via USB cable, then run 1-click setup on PC.';

  ConnectionService(this._storage) {
    _loadInitial();
  }

  List<DesktopDevice> get devices => _devices;
  DesktopDevice? get activeDevice => _activeDevice;
  bool get isConnected => _activeDevice?.status == ConnectionStatus.connected;
  bool get isConnecting =>
      _activeDevice?.status == ConnectionStatus.connecting || _isUsbConnecting;
  bool get isScanning => _isScanning;
  bool get isLivePolling => _isLivePolling;
  String? get lastError => _lastError;

  bool get isBluetoothScanning => _isBluetoothScanning;
  List<Map<String, dynamic>> get discoveredBluetoothDevices =>
      _discoveredBluetoothDevices;

  bool get isUsbConnecting => _isUsbConnecting;
  bool get isUsbConnected =>
      _devices.any((d) => d.id == 'usb_localhost' && d.status == ConnectionStatus.connected);
  String get usbDeviceDetails => _usbDeviceDetails;

  void _loadInitial() {
    _devices = _storage.loadDevices();
    if (!_devices.any((d) => d.id == 'usb_localhost')) {
      _devices.insert(0, _makeUsbLocalhost());
      _storage.saveDevices(_devices);
    }
    final preferred = _devices.where((d) => d.isPreferred).firstOrNull;
    if (preferred != null) {
      _activeDevice = preferred;
    } else if (_devices.isNotEmpty) {
      _activeDevice = _devices.first;
    }

    // Proactively attempt auto-connection across transports on startup
    Future.delayed(const Duration(milliseconds: 300), () => autoConnect());
  }

  // ---------------------------------------------------------------------------
  // Dynamic Port Prober
  // ---------------------------------------------------------------------------

  Future<int?> findOpenUsbPort() async {
    for (int port = 8765; port <= 8780; port++) {
      if (await _tcpProbe('127.0.0.1', port, timeout: 200)) {
        return port;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Multi-Transport Auto-Connect
  // ---------------------------------------------------------------------------

  Future<bool> autoConnect() async {
    if (isConnected) return true;

    // 1. Probe USB localhost across dynamic port range 8765-8780
    final usbPort = await findOpenUsbPort();
    if (usbPort != null) {
      final usbIndex = _devices.indexWhere((d) => d.id == 'usb_localhost');
      if (usbIndex != -1) {
        _devices[usbIndex].port = usbPort;
      } else {
        _devices.insert(0, _makeUsbLocalhost(port: usbPort));
      }
      final usbDevice = _devices.firstWhere((d) => d.id == 'usb_localhost');
      return await connectTo(usbDevice, pin: '1234');
    }

    // 2. Probe preferred device
    final preferred =
        _devices.where((d) => d.isPreferred && d.id != 'usb_localhost').firstOrNull;
    if (preferred != null) {
      if (await _tcpProbe(preferred.ipAddress, preferred.port, timeout: 600)) {
        return await connectTo(preferred, pin: '1234');
      }
    }

    // 3. Probe any trusted device
    for (final dev in _devices.where((d) => d.isTrusted && d.id != 'usb_localhost')) {
      if (await _tcpProbe(dev.ipAddress, dev.port, timeout: 400)) {
        return await connectTo(dev, pin: '1234');
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
  // USB Check / Connect Action
  // ---------------------------------------------------------------------------

  Future<void> checkUsbStatus() async {
    _isUsbConnecting = true;
    _lastError = null;
    _usbDeviceDetails = 'Probing 127.0.0.1 (ports 8765-8780)...';
    notifyListeners();

    final foundPort = await findOpenUsbPort();

    if (foundPort == null) {
      _isUsbConnecting = false;
      _usbDeviceDetails =
          'No AstraDeck server listening on 127.0.0.1.\n\nRun on PC:\n  ./server/setup.sh';
      _lastError =
          'USB companion not detected. Run 1-click setup on PC to start it.';
      notifyListeners();
      return;
    }

    final usbIndex = _devices.indexWhere((d) => d.id == 'usb_localhost');
    if (usbIndex != -1) {
      _devices[usbIndex].port = foundPort;
    } else {
      _devices.insert(0, _makeUsbLocalhost(port: foundPort));
    }
    final usbDevice = _devices.firstWhere((d) => d.id == 'usb_localhost');

    _usbDeviceDetails = 'Server active on port $foundPort — connecting...';
    notifyListeners();

    final ok = await connectTo(usbDevice, pin: '1234');
    _isUsbConnecting = false;
    if (ok) {
      _usbDeviceDetails = 'Connected via USB (Port $foundPort)';
    } else {
      _usbDeviceDetails = 'Connection failed. Ensure server is active.';
    }
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
    final ip = json['ip'] ?? sourceIp;
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
    _storage.saveDevices(_devices);
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
            _devices.add(DesktopDevice(
              id: 'dev_${DateTime.now().millisecondsSinceEpoch}_${ip.replaceAll('.', '')}',
              name: 'AstraDeck Host ($ip)',
              operatingSystem: 'Desktop',
              osVersion: '',
              agentVersion: '2.5.0',
              ipAddress: ip,
              port: port,
              transport: ConnectionTransport.wifi,
            ));
            _storage.saveDevices(_devices);
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
    await _storage.saveDevices(_devices);
    notifyListeners();
    return newDevice;
  }

  // ---------------------------------------------------------------------------
  // WebSocket Connection Lifecycle
  // ---------------------------------------------------------------------------

  Future<bool> connectTo(DesktopDevice device, {String? pin}) async {
    _lastError = null;
    final index = _devices.indexWhere((d) => d.id == device.id);
    if (index == -1) return false;

    _devices[index].status = ConnectionStatus.connecting;
    notifyListeners();

    try {
      final wsUri = Uri.parse('ws://${device.ipAddress}:${device.port}');
      _closeWs();

      _wsChannel = WebSocketChannel.connect(wsUri);
      await _wsChannel!.ready.timeout(const Duration(seconds: 5));

      final completer = Completer<bool>();

      _wsSubscription = _wsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data.toString());
            if (json['type'] == 'pong') {
              final sendTime = json['timestamp'] as int? ?? 0;
              if (sendTime > 0) {
                _devices[index].latencyMs =
                    DateTime.now().millisecondsSinceEpoch - sendTime;
                notifyListeners();
              }
            } else if (json['status'] == 'authenticated') {
              _devices[index].status = ConnectionStatus.connected;
              _devices[index].isTrusted = true;
              _devices[index].authToken = json['token'] ?? 'session_ok';
              _devices[index].lastConnected = DateTime.now();
              _activeDevice = _devices[index];
              _storage.saveDevices(_devices);
              _startHeartbeat(index);
              stopLivePolling();
              notifyListeners();
              if (!completer.isCompleted) completer.complete(true);
            } else if (json['status'] == 'unauthorized') {
              _devices[index].status = ConnectionStatus.unauthorized;
              _lastError = json['message'] ?? 'Invalid PIN';
              notifyListeners();
              if (!completer.isCompleted) completer.complete(false);
            }
          } catch (e) {
            debugPrint('WS decode: $e');
          }
        },
        onError: (err) {
          _devices[index].status = ConnectionStatus.failed;
          _lastError = 'Connection lost: $err';
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
        },
        onDone: () {
          if (_activeDevice?.id == device.id &&
              index < _devices.length &&
              _devices[index].status == ConnectionStatus.connected) {
            _devices[index].status = ConnectionStatus.disconnected;
            _activeDevice?.status = ConnectionStatus.disconnected;
            _lastError = 'Server disconnected. Reconnecting in 5s...';
            _pingTimer?.cancel();
            notifyListeners();
            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(const Duration(seconds: 5), () {
              connectTo(_devices[index], pin: pin ?? '1234');
            });
          }
        },
      );

      // Authenticate with either token or PIN
      _wsChannel!.sink.add(jsonEncode({
        'action': 'auth',
        'pin': pin ?? '1234',
        'token': device.authToken ?? '',
        'id': 1,
      }));

      return await completer.future.timeout(const Duration(seconds: 5));
    } catch (e) {
      _devices[index].status = ConnectionStatus.failed;
      _lastError = 'Cannot reach ${device.ipAddress}:${device.port}';
      notifyListeners();
      return false;
    }
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
    _closeWs();
    final target = device ?? _activeDevice;
    if (target != null) {
      final index = _devices.indexWhere((d) => d.id == target.id);
      if (index != -1) _devices[index].status = ConnectionStatus.disconnected;
      if (_activeDevice?.id == target.id) {
        _activeDevice?.status = ConnectionStatus.disconnected;
      }
    }
    notifyListeners();
  }

  void disconnectAll() {
    _closeWs();
    for (var d in _devices) {
      d.status = ConnectionStatus.disconnected;
    }
    _activeDevice = null;
    _storage.saveDevices(_devices);
    notifyListeners();
  }

  Future<void> forgetDevice(String id) async {
    if (id == 'usb_localhost') return;
    if (_activeDevice?.id == id) {
      disconnect(_activeDevice);
      _activeDevice = null;
    }
    _devices.removeWhere((d) => d.id == id);
    await _storage.saveDevices(_devices);
    notifyListeners();
  }

  Future<void> setPreferredDevice(String id) async {
    for (var d in _devices) {
      d.isPreferred = (d.id == id);
    }
    await _storage.saveDevices(_devices);
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
      await _storage.saveDevices(_devices);
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
      debugPrint('[ConnectionService] -> $action');
    } else {
      debugPrint('[ConnectionService] dropped (not connected): $action');
    }
  }

  void _startHeartbeat(int deviceIndex) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_wsChannel != null && isConnected) {
        final now = DateTime.now().millisecondsSinceEpoch;
        _wsChannel!.sink.add(
            jsonEncode({'action': 'ping', 'timestamp': now, 'id': now}));
      }
    });
  }

  Future<void> scanBluetooth() async {
    _isBluetoothScanning = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1200));
    _discoveredBluetoothDevices = [
      {
        'name': 'AstraDeck-PC-BT',
        'address': '00:1A:7D:DA:71:13',
        'paired': true,
        'rssi': -58,
      },
    ];
    _isBluetoothScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stopLivePolling();
    _closeWs();
    super.dispose();
  }
}
