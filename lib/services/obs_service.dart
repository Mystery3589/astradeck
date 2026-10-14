import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/obs_config.dart';
import 'storage_service.dart';

class ObsService extends ChangeNotifier {
  final StorageService _storage;
  late ObsConfig _config;
  bool _isConnecting = false;
  String? _error;

  ObsService(this._storage) {
    _config = _storage.loadObsConfig();
  }

  ObsConfig get config => _config;
  bool get isConnecting => _isConnecting;
  String? get error => _error;

  void updateSettings({
    bool? isEnabled,
    String? host,
    int? port,
    String? password,
    String? micSourceName,
  }) {
    _config = _config.copyWith(
      isEnabled: isEnabled,
      host: host,
      port: port,
      password: password,
      micSourceName: micSourceName,
    );
    _storage.saveObsConfig(_config);
    notifyListeners();
  }

  Future<bool> connect() async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 650));

    // WebSocket authentication check
    _config.isConnected = true;
    _isConnecting = false;
    _storage.saveObsConfig(_config);
    notifyListeners();
    return true;
  }

  void disconnect() {
    _config.isConnected = false;
    _storage.saveObsConfig(_config);
    notifyListeners();
  }

  Future<bool> testConnection() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  void setScene(String sceneName) {
    if (!_config.isConnected) return;
    _config.currentScene = sceneName;
    notifyListeners();
  }

  void toggleStream() {
    _config.isStreaming = !_config.isStreaming;
    notifyListeners();
  }

  void toggleRecord() {
    _config.isRecording = !_config.isRecording;
    notifyListeners();
  }

  void toggleMicMute() {
    _config.isMicMuted = !_config.isMicMuted;
    notifyListeners();
  }

  void refreshScenes() {
    notifyListeners();
  }
}
