import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_deck/models/deck_models.dart';
import 'package:nexus_deck/models/desktop_device.dart';
import 'package:nexus_deck/models/app_settings.dart';
import 'package:nexus_deck/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AstraDeck Model & Storage Tests', () {
    test('DeckProfile JSON serialization and default profiles', () {
      final defaultProfiles = StorageService.getDefaultProfiles();
      expect(defaultProfiles.length, equals(5));

      final first = defaultProfiles.first;
      expect(first.name, equals('Default Profile'));
      expect(first.pages.first.buttons.length, equals(9));

      final json = first.toJson();
      final revived = DeckProfile.fromJson(json);
      expect(revived.name, equals('Default Profile'));
      expect(revived.pages.first.buttons.length, equals(9));
      expect(revived.pages.first.buttons.first.title, equals('YouTube'));
    });

    test('DesktopDevice model serialization', () {
      final device = DesktopDevice(
        id: 'test_dev',
        name: 'Test Rig',
        ipAddress: '192.168.1.55',
        port: 8765,
        isTrusted: true,
      );

      final json = device.toJson();
      final revived = DesktopDevice.fromJson(json);
      expect(revived.id, equals('test_dev'));
      expect(revived.name, equals('Test Rig'));
      expect(revived.ipAddress, equals('192.168.1.55'));
      expect(revived.isTrusted, isTrue);
    });

    test('AppSettings model serialization', () {
      final settings = AppSettings(
        showButtonLabels: false,
        buttonSpacing: 18.0,
      );

      final json = settings.toJson();
      final revived = AppSettings.fromJson(json);
      expect(revived.showButtonLabels, isFalse);
      expect(revived.buttonSpacing, equals(18.0));
    });

    test('StorageService persists and restores profiles correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      final profiles = storage.loadProfiles();
      expect(profiles.isNotEmpty, isTrue);

      final customProfile = DeckProfile(
        id: 'custom_1',
        name: 'Studio Work',
        pages: [DeckPage(id: 'p1', name: 'P1', buttons: [])],
      );

      await storage.saveProfiles([...profiles, customProfile]);
      final reloaded = storage.loadProfiles();
      expect(reloaded.any((p) => p.name == 'Studio Work'), isTrue);
    });
  });
}
