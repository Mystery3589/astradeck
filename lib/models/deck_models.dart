enum ActionType {
  openWebsite,
  launchApp,
  toggleMicMute,
  setVolume,
  toggleSystemMute,
  setBrightness,
  obsAction,
  switchPage,
  switchProfile,
  actionSequence,
}

extension ActionTypeExtension on ActionType {
  String get displayName {
    switch (this) {
      case ActionType.openWebsite:
        return 'Open Website / URL';
      case ActionType.launchApp:
        return 'Launch Desktop App';
      case ActionType.toggleMicMute:
        return 'Toggle Microphone';
      case ActionType.setVolume:
        return 'Set System Volume';
      case ActionType.toggleSystemMute:
        return 'Toggle System Mute';
      case ActionType.setBrightness:
        return 'Set Screen Brightness';
      case ActionType.obsAction:
        return 'OBS Studio Command';
      case ActionType.switchPage:
        return 'Switch Deck Page';
      case ActionType.switchProfile:
        return 'Switch Profile';
      case ActionType.actionSequence:
        return 'Execute Action Sequence';
    }
  }

  String get id => name;

  static ActionType fromString(String val) {
    return ActionType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => ActionType.openWebsite,
    );
  }
}

enum ButtonShape {
  roundedRect,
  circle,
  square,
  squircle,
}

class DeckButton {
  final String id;
  String title;
  String subtitle;
  String iconName;
  double iconSize;
  int backgroundColor;
  int textColor;
  ButtonShape shape;
  int row;
  int col;
  int rowSpan;
  int colSpan;
  ActionType actionType;
  Map<String, dynamic> actionPayload;
  ActionType? longPressActionType;
  Map<String, dynamic>? longPressPayload;
  bool requiresConfirmation;
  bool hapticFeedback;
  bool isEnabled;

  DeckButton({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.iconName,
    this.iconSize = 32.0,
    this.backgroundColor = 0xFF1E293B, // Slate 800
    this.textColor = 0xFFFFFFFF,
    this.shape = ButtonShape.roundedRect,
    required this.row,
    required this.col,
    this.rowSpan = 1,
    this.colSpan = 1,
    required this.actionType,
    required this.actionPayload,
    this.longPressActionType,
    this.longPressPayload,
    this.requiresConfirmation = false,
    this.hapticFeedback = true,
    this.isEnabled = true,
  });

  DeckButton copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconName,
    double? iconSize,
    int? backgroundColor,
    int? textColor,
    ButtonShape? shape,
    int? row,
    int? col,
    int? rowSpan,
    int? colSpan,
    ActionType? actionType,
    Map<String, dynamic>? actionPayload,
    ActionType? longPressActionType,
    Map<String, dynamic>? longPressPayload,
    bool? requiresConfirmation,
    bool? hapticFeedback,
    bool? isEnabled,
  }) {
    return DeckButton(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
      iconSize: iconSize ?? this.iconSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      shape: shape ?? this.shape,
      row: row ?? this.row,
      col: col ?? this.col,
      rowSpan: rowSpan ?? this.rowSpan,
      colSpan: colSpan ?? this.colSpan,
      actionType: actionType ?? this.actionType,
      actionPayload: actionPayload != null ? Map<String, dynamic>.from(actionPayload) : Map<String, dynamic>.from(this.actionPayload),
      longPressActionType: longPressActionType ?? this.longPressActionType,
      longPressPayload: longPressPayload != null ? Map<String, dynamic>.from(longPressPayload) : (this.longPressPayload != null ? Map<String, dynamic>.from(this.longPressPayload!) : null),
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'iconName': iconName,
    'iconSize': iconSize,
    'backgroundColor': backgroundColor,
    'textColor': textColor,
    'shape': shape.name,
    'row': row,
    'col': col,
    'rowSpan': rowSpan,
    'colSpan': colSpan,
    'actionType': actionType.name,
    'actionPayload': actionPayload,
    'longPressActionType': longPressActionType?.name,
    'longPressPayload': longPressPayload,
    'requiresConfirmation': requiresConfirmation,
    'hapticFeedback': hapticFeedback,
    'isEnabled': isEnabled,
  };

  factory DeckButton.fromJson(Map<String, dynamic> json) {
    return DeckButton(
      id: json['id'] as String? ?? 'btn_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Action',
      subtitle: json['subtitle'] as String? ?? '',
      iconName: json['iconName'] as String? ?? 'play_arrow',
      iconSize: (json['iconSize'] as num?)?.toDouble() ?? 32.0,
      backgroundColor: json['backgroundColor'] as int? ?? 0xFF1E293B,
      textColor: json['textColor'] as int? ?? 0xFFFFFFFF,
      shape: ButtonShape.values.firstWhere(
        (e) => e.name == json['shape'],
        orElse: () => ButtonShape.roundedRect,
      ),
      row: json['row'] as int? ?? 0,
      col: json['col'] as int? ?? 0,
      rowSpan: json['rowSpan'] as int? ?? 1,
      colSpan: json['colSpan'] as int? ?? 1,
      actionType: ActionTypeExtension.fromString(json['actionType'] as String? ?? 'openWebsite'),
      actionPayload: json['actionPayload'] is Map ? Map<String, dynamic>.from(json['actionPayload']) : {},
      longPressActionType: json['longPressActionType'] != null ? ActionTypeExtension.fromString(json['longPressActionType']) : null,
      longPressPayload: json['longPressPayload'] is Map ? Map<String, dynamic>.from(json['longPressPayload']) : null,
      requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}

class DeckPage {
  final String id;
  String name;
  List<DeckButton> buttons;

  DeckPage({
    required this.id,
    required this.name,
    required this.buttons,
  });

  DeckPage copyWith({
    String? id,
    String? name,
    List<DeckButton>? buttons,
  }) {
    return DeckPage(
      id: id ?? this.id,
      name: name ?? this.name,
      buttons: buttons ?? this.buttons.map((b) => b.copyWith()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'buttons': buttons.map((b) => b.toJson()).toList(),
  };

  factory DeckPage.fromJson(Map<String, dynamic> json) {
    return DeckPage(
      id: json['id'] as String? ?? 'page_1',
      name: json['name'] as String? ?? 'Page 1',
      buttons: (json['buttons'] as List<dynamic>? ?? [])
          .map((b) => DeckButton.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
    );
  }
}

class DeckProfile {
  final String id;
  String name;
  String description;
  int gridRows;
  int gridCols;
  List<DeckPage> pages;
  String? defaultDesktopId;
  String? obsConfigRef;
  Map<String, dynamic> appearanceConfig;

  DeckProfile({
    required this.id,
    required this.name,
    this.description = '',
    this.gridRows = 3,
    this.gridCols = 3,
    required this.pages,
    this.defaultDesktopId,
    this.obsConfigRef,
    Map<String, dynamic>? appearanceConfig,
  }) : appearanceConfig = appearanceConfig ?? {
          'buttonSpacing': 12.0,
          'buttonRadius': 16.0,
          'buttonPadding': 8.0,
          'showLabels': true,
          'iconOnly': false,
        };

  DeckProfile copyWith({
    String? id,
    String? name,
    String? description,
    int? gridRows,
    int? gridCols,
    List<DeckPage>? pages,
    String? defaultDesktopId,
    String? obsConfigRef,
    Map<String, dynamic>? appearanceConfig,
  }) {
    return DeckProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      gridRows: gridRows ?? this.gridRows,
      gridCols: gridCols ?? this.gridCols,
      pages: pages ?? this.pages.map((p) => p.copyWith()).toList(),
      defaultDesktopId: defaultDesktopId ?? this.defaultDesktopId,
      obsConfigRef: obsConfigRef ?? this.obsConfigRef,
      appearanceConfig: appearanceConfig != null ? Map<String, dynamic>.from(appearanceConfig) : Map<String, dynamic>.from(this.appearanceConfig),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'gridRows': gridRows,
    'gridCols': gridCols,
    'pages': pages.map((p) => p.toJson()).toList(),
    'defaultDesktopId': defaultDesktopId,
    'obsConfigRef': obsConfigRef,
    'appearanceConfig': appearanceConfig,
  };

  factory DeckProfile.fromJson(Map<String, dynamic> json) {
    return DeckProfile(
      id: json['id'] as String? ?? 'profile_default',
      name: json['name'] as String? ?? 'Default Profile',
      description: json['description'] as String? ?? '',
      gridRows: json['gridRows'] as int? ?? 3,
      gridCols: json['gridCols'] as int? ?? 3,
      pages: (json['pages'] as List<dynamic>? ?? [])
          .map((p) => DeckPage.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      defaultDesktopId: json['defaultDesktopId'] as String?,
      obsConfigRef: json['obsConfigRef'] as String?,
      appearanceConfig: json['appearanceConfig'] is Map
          ? Map<String, dynamic>.from(json['appearanceConfig'])
          : null,
    );
  }
}
