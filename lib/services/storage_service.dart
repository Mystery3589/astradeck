import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/deck_models.dart';
import '../models/desktop_device.dart';

class StorageService {
  static const String _keySettings = 'astradeck_settings_v1';
  static const String _keyProfiles = 'astradeck_profiles_v1';
  static const String _keyActiveProfileId = 'astradeck_active_profile_id';
  static const String _keyDevices = 'astradeck_devices_v1';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- App Settings ---
  AppSettings loadSettings() {
    final raw = _prefs.getString(_keySettings);
    if (raw != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(raw);
        return AppSettings.fromJson(decoded);
      } catch (e) {
        debugPrint('Failed to parse saved AppSettings, using defaults: $e');
      }
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  // --- Profiles ---
  List<DeckProfile> loadProfiles() {
    final raw = _prefs.getString(_keyProfiles);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        final profiles = list
            .map((item) => DeckProfile.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        if (profiles.isNotEmpty) {
          bool changed = false;
          for (final p in profiles) {
            for (final page in p.pages) {
              for (int i = 0; i < page.buttons.length; i++) {
                final b = page.buttons[i];
                // Migrate any legacy obsAction buttons to usable 3-function actions
                if (b.actionType == ActionType.obsAction) {
                  if (b.id == 'btn_obs' || b.id == 's_start_stream' || b.title.toLowerCase().contains('obs') || b.title.toLowerCase().contains('live')) {
                    page.buttons[i] = b.copyWith(
                      title: b.title == 'Go Live' ? 'OBS Studio' : b.title,
                      subtitle: 'App',
                      iconName: 'videocam',
                      actionType: ActionType.launchApp,
                      actionPayload: {'app': 'OBS Studio'},
                    );
                  } else if (b.id == 's_scene_main') {
                    page.buttons[i] = b.copyWith(
                      title: 'Twitch Dash',
                      subtitle: 'Live Chat',
                      iconName: 'dashboard',
                      actionType: ActionType.openWebsite,
                      actionPayload: {'url': 'https://dashboard.twitch.tv'},
                    );
                  } else if (b.id == 's_scene_chat' || b.id == 's_end_stream') {
                    page.buttons[i] = b.copyWith(
                      title: 'Discord Voice',
                      subtitle: 'Chat',
                      iconName: 'chat',
                      actionType: ActionType.launchApp,
                      actionPayload: {'app': 'Discord'},
                    );
                  } else if (b.id == 's_brb' || b.id == 'g_clip') {
                    page.buttons[i] = b.copyWith(
                      title: 'Instant Clip',
                      subtitle: 'Screenshot',
                      iconName: 'camera_alt',
                      actionType: ActionType.dynamicFunction,
                      actionPayload: {'command': 'take screenshot of active window'},
                    );
                  } else {
                    page.buttons[i] = b.copyWith(
                      subtitle: 'App',
                      actionType: ActionType.launchApp,
                      actionPayload: {'app': 'OBS Studio'},
                    );
                  }
                  changed = true;
                }
              }
            }
          }
          if (changed) {
            saveProfiles(profiles);
          }
          return profiles;
        }
      } catch (e) {
        debugPrint('Failed to load profiles, generating built-ins: $e');
      }
    }
    final defaults = getDefaultProfiles();
    saveProfiles(defaults);
    return defaults;
  }

  Future<void> saveProfiles(List<DeckProfile> profiles) async {
    final data = profiles.map((p) => p.toJson()).toList();
    await _prefs.setString(_keyProfiles, jsonEncode(data));
  }

  String getActiveProfileId(String fallback) {
    return _prefs.getString(_keyActiveProfileId) ?? fallback;
  }

  Future<void> setActiveProfileId(String id) async {
    await _prefs.setString(_keyActiveProfileId, id);
  }

  // --- Desktop Devices ---
  List<DesktopDevice> loadDevices() {
    final raw = _prefs.getString(_keyDevices);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        return list
            .map((item) => DesktopDevice.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } catch (e) {
        debugPrint('Failed to load devices: $e');
      }
    }
    return [];
  }

  Future<void> saveDevices(List<DesktopDevice> devices) async {
    final data = devices.map((d) => d.toJson()).toList();
    await _prefs.setString(_keyDevices, jsonEncode(data));
  }

  // --- Full Wipe ---
  Future<void> clearAllData() async {
    await _prefs.clear();
  }

  // --- Default Profiles Seed ---
  static List<DeckProfile> getDefaultProfiles() {
    // 1. Default Profile: YouTube, Discord, Instagram, X, Chrome, Steam, Twitch, WhatsApp, OBS
    final defaultButtons = [
      DeckButton(
        id: 'btn_yt',
        title: 'YouTube',
        subtitle: 'Media',
        iconName: 'play_arrow',
        backgroundColor: 0xFFFF0000,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 0,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://youtube.com'},
      ),
      DeckButton(
        id: 'btn_discord',
        title: 'Discord',
        subtitle: 'Chat',
        iconName: 'chat',
        backgroundColor: 0xFF5865F2,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 1,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Discord'},
      ),
      DeckButton(
        id: 'btn_instagram',
        title: 'Instagram',
        subtitle: 'Social',
        iconName: 'camera_alt',
        backgroundColor: 0xFFE1306C,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 2,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://instagram.com'},
      ),
      DeckButton(
        id: 'btn_x',
        title: 'X / Twitter',
        subtitle: 'Feed',
        iconName: 'alternate_email',
        backgroundColor: 0xFF14171A,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 0,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://x.com'},
      ),
      DeckButton(
        id: 'btn_chrome',
        title: 'Chrome',
        subtitle: 'Browser',
        iconName: 'public',
        backgroundColor: 0xFF1E88E5,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 1,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Chrome'},
      ),
      DeckButton(
        id: 'btn_steam',
        title: 'Steam',
        subtitle: 'Games',
        iconName: 'sports_esports',
        backgroundColor: 0xFF171A21,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 2,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Steam'},
      ),
      DeckButton(
        id: 'btn_twitch',
        title: 'Twitch',
        subtitle: 'Streams',
        iconName: 'tv',
        backgroundColor: 0xFF9146FF,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 0,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://twitch.tv'},
      ),
      DeckButton(
        id: 'btn_whatsapp',
        title: 'WhatsApp',
        subtitle: 'Messages',
        iconName: 'message',
        backgroundColor: 0xFF25D366,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 1,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://web.whatsapp.com'},
      ),
      DeckButton(
        id: 'btn_obs',
        title: 'OBS Studio',
        subtitle: 'App',
        iconName: 'videocam',
        backgroundColor: 0xFF302E31,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 2,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'OBS Studio'},
      ),
    ];

    // 2. Streaming Profile (100% Usable with 3 Core Functions)
    final streamButtons = [
      DeckButton(
        id: 's_start_stream',
        title: 'OBS Studio',
        subtitle: 'App',
        iconName: 'videocam',
        backgroundColor: 0xFFDC2626,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 0,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'OBS Studio'},
      ),
      DeckButton(
        id: 's_scene_main',
        title: 'Twitch Dash',
        subtitle: 'Live Chat',
        iconName: 'dashboard',
        backgroundColor: 0xFF9146FF,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 1,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://dashboard.twitch.tv'},
      ),
      DeckButton(
        id: 's_scene_chat',
        title: 'Discord Voice',
        subtitle: 'Chat',
        iconName: 'chat',
        backgroundColor: 0xFF5865F2,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 2,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Discord'},
      ),
      DeckButton(
        id: 's_mic_mute',
        title: 'Mute Mic',
        subtitle: 'Hardware',
        iconName: 'mic_off',
        backgroundColor: 0xFFB91C1C,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 0,
        actionType: ActionType.toggleMicMute,
        actionPayload: {},
      ),
      DeckButton(
        id: 's_brb',
        title: 'Instant Clip',
        subtitle: 'Screenshot',
        iconName: 'camera_alt',
        backgroundColor: 0xFFD97706,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 1,
        actionType: ActionType.dynamicFunction,
        actionPayload: {'command': 'take screenshot of active window'},
      ),
      DeckButton(
        id: 's_soundboard',
        title: 'Airhorn SFX',
        subtitle: 'Audio FX',
        iconName: 'volume_up',
        backgroundColor: 0xFF059669,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 2,
        actionType: ActionType.dynamicFunction,
        actionPayload: {'command': 'play notification sound'},
      ),
      DeckButton(
        id: 's_vol_down',
        title: 'Vol -10%',
        subtitle: 'Master',
        iconName: 'volume_down',
        backgroundColor: 0xFF334155,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 0,
        actionType: ActionType.setVolume,
        actionPayload: {'step': -10},
      ),
      DeckButton(
        id: 's_vol_up',
        title: 'Vol +10%',
        subtitle: 'Master',
        iconName: 'volume_up',
        backgroundColor: 0xFF334155,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 1,
        actionType: ActionType.setVolume,
        actionPayload: {'step': 10},
      ),
      DeckButton(
        id: 's_end_stream',
        title: 'Stream Focus',
        subtitle: 'DND Mode',
        iconName: 'do_not_disturb',
        backgroundColor: 0xFF475569,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 2,
        actionType: ActionType.dynamicFunction,
        actionPayload: {'command': 'toggle do not disturb notifications'},
      ),
    ];

    // 3. Gaming Profile
    final gamingButtons = [
      DeckButton(
        id: 'g_discord',
        title: 'Discord Overlay',
        subtitle: 'Voice',
        iconName: 'headset_mic',
        backgroundColor: 0xFF5865F2,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 0,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Discord'},
      ),
      DeckButton(
        id: 'g_spotify',
        title: 'Spotify Track',
        subtitle: 'Play/Pause',
        iconName: 'music_note',
        backgroundColor: 0xFF1DB954,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 1,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Spotify'},
      ),
      DeckButton(
        id: 'g_steam',
        title: 'Steam Games',
        subtitle: 'Library',
        iconName: 'sports_esports',
        backgroundColor: 0xFF171A21,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 2,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Steam'},
      ),
      DeckButton(
        id: 'g_mic',
        title: 'Push-To-Mute',
        subtitle: 'Microphone',
        iconName: 'mic',
        backgroundColor: 0xFFEF4444,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 0,
        actionType: ActionType.toggleMicMute,
        actionPayload: {},
      ),
      DeckButton(
        id: 'g_bright_up',
        title: 'Brightness +',
        subtitle: 'Display',
        iconName: 'brightness_high',
        backgroundColor: 0xFFF59E0B,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 1,
        actionType: ActionType.setBrightness,
        actionPayload: {'step': 15},
      ),
      DeckButton(
        id: 'g_bright_down',
        title: 'Brightness -',
        subtitle: 'Display',
        iconName: 'brightness_low',
        backgroundColor: 0xFF475569,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 2,
        actionType: ActionType.setBrightness,
        actionPayload: {'step': -15},
      ),
      DeckButton(
        id: 'g_clip',
        title: 'Instant Replay',
        subtitle: 'Save Clip',
        iconName: 'video_library',
        backgroundColor: 0xFF8B5CF6,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 0,
        actionType: ActionType.dynamicFunction,
        actionPayload: {'command': 'take screenshot of active window'},
      ),
      DeckButton(
        id: 'g_mute_sys',
        title: 'Mute Audio',
        subtitle: 'Master',
        iconName: 'volume_off',
        backgroundColor: 0xFFDC2626,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 1,
        actionType: ActionType.toggleSystemMute,
        actionPayload: {},
      ),
      DeckButton(
        id: 'g_calc',
        title: 'Stats / Calc',
        subtitle: 'Tools',
        iconName: 'calculate',
        backgroundColor: 0xFF0284C7,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 2,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Calculator'},
      ),
    ];

    // 4. Productivity Profile
    final productivityButtons = [
      DeckButton(
        id: 'p_vscode',
        title: 'VS Code',
        subtitle: 'Editor',
        iconName: 'code',
        backgroundColor: 0xFF007ACC,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 0,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'VS Code'},
      ),
      DeckButton(
        id: 'p_github',
        title: 'GitHub',
        subtitle: 'PRs & Repos',
        iconName: 'hub',
        backgroundColor: 0xFF24292E,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 1,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://github.com'},
      ),
      DeckButton(
        id: 'p_notion',
        title: 'Notion',
        subtitle: 'Workspace',
        iconName: 'edit_note',
        backgroundColor: 0xFF000000,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 2,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://notion.so'},
      ),
      DeckButton(
        id: 'p_slack',
        title: 'Slack / Teams',
        subtitle: 'Workspace',
        iconName: 'chat_bubble',
        backgroundColor: 0xFF4A154B,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 0,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Slack'},
      ),
      DeckButton(
        id: 'p_zoom',
        title: 'Zoom Mute',
        subtitle: 'Meetings',
        iconName: 'mic_external_off',
        backgroundColor: 0xFF2D8CFF,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 1,
        actionType: ActionType.toggleMicMute,
        actionPayload: {},
      ),
      DeckButton(
        id: 'p_cal',
        title: 'Google Calendar',
        subtitle: 'Schedule',
        iconName: 'calendar_month',
        backgroundColor: 0xFF1A73E8,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 2,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://calendar.google.com'},
      ),
      DeckButton(
        id: 'p_focus',
        title: 'Focus Music',
        subtitle: 'Lofi Girl',
        iconName: 'headphones',
        backgroundColor: 0xFFE11D48,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 0,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://www.youtube.com/watch?v=jfKfPfyJRdk'},
      ),
      DeckButton(
        id: 'p_mail',
        title: 'Inbox Zero',
        subtitle: 'Gmail',
        iconName: 'mail',
        backgroundColor: 0xFFEA4335,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 1,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://mail.google.com'},
      ),
      DeckButton(
        id: 'p_calc',
        title: 'Calculator',
        subtitle: 'Utility',
        iconName: 'calculate',
        backgroundColor: 0xFF334155,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 2,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Calculator'},
      ),
    ];

    // 5. Media Control Profile
    final mediaButtons = [
      DeckButton(
        id: 'm_prev',
        title: 'Previous',
        subtitle: 'Track',
        iconName: 'skip_previous',
        backgroundColor: 0xFF1E293B,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 0,
        actionType: ActionType.actionSequence,
        actionPayload: {'sequence': ['spotify_prev']},
      ),
      DeckButton(
        id: 'm_play',
        title: 'Play / Pause',
        subtitle: 'Media',
        iconName: 'play_arrow',
        backgroundColor: 0xFF10B981,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 1,
        actionType: ActionType.actionSequence,
        actionPayload: {'sequence': ['spotify_toggle']},
      ),
      DeckButton(
        id: 'm_next',
        title: 'Next',
        subtitle: 'Track',
        iconName: 'skip_next',
        backgroundColor: 0xFF1E293B,
        textColor: 0xFFFFFFFF,
        row: 0,
        col: 2,
        actionType: ActionType.actionSequence,
        actionPayload: {'sequence': ['spotify_next']},
      ),
      DeckButton(
        id: 'm_vol_down',
        title: 'Volume Down',
        subtitle: '-5%',
        iconName: 'volume_down',
        backgroundColor: 0xFF334155,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 0,
        actionType: ActionType.setVolume,
        actionPayload: {'step': -5},
      ),
      DeckButton(
        id: 'm_mute',
        title: 'Mute Audio',
        subtitle: 'Toggle',
        iconName: 'volume_off',
        backgroundColor: 0xFFEF4444,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 1,
        actionType: ActionType.toggleSystemMute,
        actionPayload: {},
      ),
      DeckButton(
        id: 'm_vol_up',
        title: 'Volume Up',
        subtitle: '+5%',
        iconName: 'volume_up',
        backgroundColor: 0xFF334155,
        textColor: 0xFFFFFFFF,
        row: 1,
        col: 2,
        actionType: ActionType.setVolume,
        actionPayload: {'step': 5},
      ),
      DeckButton(
        id: 'm_spotify',
        title: 'Spotify App',
        subtitle: 'Music',
        iconName: 'music_note',
        backgroundColor: 0xFF1DB954,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 0,
        actionType: ActionType.launchApp,
        actionPayload: {'app': 'Spotify'},
      ),
      DeckButton(
        id: 'm_yt_music',
        title: 'YT Music',
        subtitle: 'Stream',
        iconName: 'album',
        backgroundColor: 0xFFFF0000,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 1,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://music.youtube.com'},
      ),
      DeckButton(
        id: 'm_netflix',
        title: 'Netflix',
        subtitle: 'Movies',
        iconName: 'movie',
        backgroundColor: 0xFFE50914,
        textColor: 0xFFFFFFFF,
        row: 2,
        col: 2,
        actionType: ActionType.openWebsite,
        actionPayload: {'url': 'https://netflix.com'},
      ),
    ];

    return [
      DeckProfile(
        id: 'profile_default',
        name: 'Default Profile',
        description: 'Standard 9-button layout with popular apps and shortcuts',
        gridRows: 3,
        gridCols: 3,
        pages: [
          DeckPage(id: 'p_def_1', name: 'Main Apps', buttons: defaultButtons),
        ],
      ),
      DeckProfile(
        id: 'profile_streaming',
        name: 'Streaming',
        description: 'OBS scene switcher, mic controls, and broadcast shortcuts',
        gridRows: 3,
        gridCols: 3,
        pages: [
          DeckPage(id: 'p_stream_1', name: 'Live Deck', buttons: streamButtons),
        ],
      ),
      DeckProfile(
        id: 'profile_gaming',
        name: 'Gaming',
        description: 'Voice chat, volume, instant replay, and display controls',
        gridRows: 3,
        gridCols: 3,
        pages: [
          DeckPage(id: 'p_game_1', name: 'Battle Station', buttons: gamingButtons),
        ],
      ),
      DeckProfile(
        id: 'profile_productivity',
        name: 'Productivity',
        description: 'Coding, tasks, workspace communication, and documentation',
        gridRows: 3,
        gridCols: 3,
        pages: [
          DeckPage(id: 'p_prod_1', name: 'Work Desk', buttons: productivityButtons),
        ],
      ),
      DeckProfile(
        id: 'profile_media',
        name: 'Media Control',
        description: 'Player controls, volume steps, Spotify, and streaming',
        gridRows: 3,
        gridCols: 3,
        pages: [
          DeckPage(id: 'p_media_1', name: 'Jukebox', buttons: mediaButtons),
        ],
      ),
    ];
  }
}
