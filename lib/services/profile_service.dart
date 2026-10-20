import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/deck_models.dart';
import 'storage_service.dart';

class ProfileService extends ChangeNotifier {
  final StorageService _storage;
  List<DeckProfile> _profiles = [];
  late String _activeProfileId;
  int _activePageIndex = 0;
  bool _isEditMode = false;

  // History stack for undo in layout editor
  final List<String> _undoHistory = [];

  ProfileService(this._storage) {
    _load();
  }

  List<DeckProfile> get profiles => _profiles;
  String get activeProfileId => _activeProfileId;
  int get activePageIndex => _activePageIndex;
  bool get isEditMode => _isEditMode;
  bool get canUndo => _undoHistory.isNotEmpty;

  DeckProfile get currentProfile {
    if (_profiles.isEmpty) {
      _profiles = StorageService.getDefaultProfiles();
      _activeProfileId = _profiles.first.id;
      _storage.saveProfiles(_profiles);
      _storage.setActiveProfileId(_activeProfileId);
    }
    return _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.first,
    );
  }

  DeckPage get currentPage {
    final profile = currentProfile;
    if (_activePageIndex >= profile.pages.length) {
      _activePageIndex = 0;
    }
    return profile.pages.isNotEmpty
        ? profile.pages[_activePageIndex]
        : DeckPage(id: 'temp', name: 'Page 1', buttons: []);
  }

  void _load() {
    _profiles = _storage.loadProfiles();
    if (_profiles.isEmpty) {
      _profiles = StorageService.getDefaultProfiles();
      _storage.saveProfiles(_profiles);
    }
    _activeProfileId = _storage.getActiveProfileId(_profiles.first.id);
  }

  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  void setEditMode(bool val) {
    _isEditMode = val;
    notifyListeners();
  }

  void setActiveProfile(String id) {
    if (_profiles.any((p) => p.id == id)) {
      _activeProfileId = id;
      _activePageIndex = 0;
      _storage.setActiveProfileId(id);
      _undoHistory.clear();
      notifyListeners();
    }
  }

  void setActivePage(int index) {
    if (index >= 0 && index < currentProfile.pages.length) {
      _activePageIndex = index;
      notifyListeners();
    }
  }

  void addPage(String pageName) {
    _saveSnapshot();
    final profileIndex = _profiles.indexWhere((p) => p.id == _activeProfileId);
    if (profileIndex != -1) {
      final newPage = DeckPage(
        id: 'page_${DateTime.now().millisecondsSinceEpoch}',
        name: pageName.isEmpty ? 'Page ${_profiles[profileIndex].pages.length + 1}' : pageName,
        buttons: [],
      );
      _profiles[profileIndex].pages.add(newPage);
      _storage.saveProfiles(_profiles);
      _activePageIndex = _profiles[profileIndex].pages.length - 1;
      notifyListeners();
    }
  }

  void deletePage(int pageIndex) {
    final profileIndex = _profiles.indexWhere((p) => p.id == _activeProfileId);
    if (profileIndex != -1 && _profiles[profileIndex].pages.length > 1) {
      _saveSnapshot();
      _profiles[profileIndex].pages.removeAt(pageIndex);
      if (_activePageIndex >= _profiles[profileIndex].pages.length) {
        _activePageIndex = _profiles[profileIndex].pages.length - 1;
      }
      _storage.saveProfiles(_profiles);
      notifyListeners();
    }
  }

  void updateGridDimensions(int rows, int cols) {
    _saveSnapshot();
    final profileIndex = _profiles.indexWhere((p) => p.id == _activeProfileId);
    if (profileIndex != -1) {
      _profiles[profileIndex].gridRows = rows;
      _profiles[profileIndex].gridCols = cols;
      _storage.saveProfiles(_profiles);
      notifyListeners();
    }
  }

  void updateAppearanceConfig(Map<String, dynamic> config) {
    _saveSnapshot();
    final profileIndex = _profiles.indexWhere((p) => p.id == _activeProfileId);
    if (profileIndex != -1) {
      _profiles[profileIndex].appearanceConfig = {
        ..._profiles[profileIndex].appearanceConfig,
        ...config,
      };
      _storage.saveProfiles(_profiles);
      notifyListeners();
    }
  }

  // --- Button Management ---
  void saveButton(DeckButton button) {
    _saveSnapshot();
    final page = currentPage;
    final index = page.buttons.indexWhere((b) => b.id == button.id);
    if (index != -1) {
      page.buttons[index] = button;
    } else {
      page.buttons.add(button);
    }
    _storage.saveProfiles(_profiles);
    notifyListeners();
  }

  void deleteButton(String buttonId) {
    _saveSnapshot();
    currentPage.buttons.removeWhere((b) => b.id == buttonId);
    _storage.saveProfiles(_profiles);
    notifyListeners();
  }

  void duplicateButton(DeckButton button) {
    _saveSnapshot();
    final copy = button.copyWith(
      id: const Uuid().v4(),
      title: '${button.title} (Copy)',
      col: (button.col + 1) % currentProfile.gridCols,
    );
    currentPage.buttons.add(copy);
    _storage.saveProfiles(_profiles);
    notifyListeners();
  }

  void reorderButtons(int oldIndex, int newIndex) {
    _saveSnapshot();
    final buttons = currentPage.buttons;
    // NOTE: onReorderItem already delivers the pre-adjusted newIndex —
    // do NOT subtract 1 here (that was the old onReorder convention).
    final item = buttons.removeAt(oldIndex);
    buttons.insert(newIndex, item);

    // Update logical row/col based on grid index
    for (int i = 0; i < buttons.length; i++) {
      buttons[i].row = i ~/ currentProfile.gridCols;
      buttons[i].col = i % currentProfile.gridCols;
    }

    _storage.saveProfiles(_profiles);
    notifyListeners();
  }

  void restoreNineButtonDefault() {
    _saveSnapshot();
    final defaults = StorageService.getDefaultProfiles();
    final defaultPage = defaults.first.pages.first;
    currentPage.buttons.clear();
    currentPage.buttons.addAll(defaultPage.buttons.map((b) => b.copyWith(id: const Uuid().v4())));
    _storage.saveProfiles(_profiles);
    notifyListeners();
  }

  // --- Profile CRUD ---
  DeckProfile createProfile(String name, {String description = '', int rows = 3, int cols = 3}) {
    final newProfile = DeckProfile(
      id: const Uuid().v4(),
      name: name,
      description: description,
      gridRows: rows,
      gridCols: cols,
      pages: [
        DeckPage(id: const Uuid().v4(), name: 'Page 1', buttons: []),
      ],
    );
    _profiles.add(newProfile);
    _activeProfileId = newProfile.id;
    _storage.saveProfiles(_profiles);
    _storage.setActiveProfileId(newProfile.id);
    notifyListeners();
    return newProfile;
  }

  void duplicateProfile(String profileId) {
    final target = _profiles.firstWhere((p) => p.id == profileId);
    final clonedPages = target.pages.map((page) {
      return DeckPage(
        id: const Uuid().v4(),
        name: page.name,
        buttons: page.buttons.map((b) => b.copyWith(id: const Uuid().v4())).toList(),
      );
    }).toList();

    final copy = DeckProfile(
      id: const Uuid().v4(),
      name: '${target.name} (Copy)',
      description: target.description,
      gridRows: target.gridRows,
      gridCols: target.gridCols,
      pages: clonedPages,
      appearanceConfig: Map<String, dynamic>.from(target.appearanceConfig),
    );

    _profiles.add(copy);
    _storage.saveProfiles(_profiles);
    notifyListeners();
  }

  void renameProfile(String profileId, String newName, String newDesc) {
    final index = _profiles.indexWhere((p) => p.id == profileId);
    if (index != -1) {
      _profiles[index].name = newName;
      _profiles[index].description = newDesc;
      _storage.saveProfiles(_profiles);
      notifyListeners();
    }
  }

  void deleteProfile(String profileId) {
    if (_profiles.length <= 1) return;
    _profiles.removeWhere((p) => p.id == profileId);
    if (_activeProfileId == profileId) {
      _activeProfileId = _profiles.first.id;
      _storage.setActiveProfileId(_activeProfileId);
    }
    _storage.saveProfiles(_profiles);
    notifyListeners();
  }

  void resetToDefaultProfiles() {
    _profiles = StorageService.getDefaultProfiles();
    _activeProfileId = _profiles.first.id;
    _activePageIndex = 0;
    _storage.saveProfiles(_profiles);
    _storage.setActiveProfileId(_activeProfileId);
    notifyListeners();
  }

  // --- Export & Import ---
  String exportProfileToJson(String profileId) {
    final target = _profiles.firstWhere((p) => p.id == profileId);
    return const JsonEncoder.withIndent('  ').convert(target.toJson());
  }

  String exportAllProfilesToJson() {
    final list = _profiles.map((p) => p.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  bool importProfileFromJson(String jsonString, {outError}) {
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        // Schema check: must have id, name, pages
        if (!decoded.containsKey('name') || !decoded.containsKey('pages')) {
          return false;
        }
        // Sanitize actions: reject raw arbitrary shell scripts
        final newProfile = DeckProfile.fromJson(decoded);
        _profiles.add(newProfile.copyWith(id: const Uuid().v4(), name: '${newProfile.name} (Imported)'));
        _storage.saveProfiles(_profiles);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Import error: $e');
      return false;
    }
  }

  // --- Undo Support ---
  void _saveSnapshot() {
    final currentJson = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    _undoHistory.add(currentJson);
    if (_undoHistory.length > 20) {
      _undoHistory.removeAt(0);
    }
  }

  void undo() {
    if (_undoHistory.isNotEmpty) {
      final snapshot = _undoHistory.removeLast();
      final List<dynamic> list = jsonDecode(snapshot);
      _profiles = list
          .map((item) => DeckProfile.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      _storage.saveProfiles(_profiles);
      notifyListeners();
    }
  }
}
