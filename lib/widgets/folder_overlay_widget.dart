import 'package:flutter/material.dart';
import '../models/deck_models.dart';
import '../services/deck_execution_service.dart';
import '../services/settings_service.dart';
import '../services/live_state_service.dart';
import '../theme/astradeck_theme.dart';
import '../utils/icon_helper.dart';

/// Pop-out folder modal for buttons that hold sub-actions.
class FolderOverlayWidget extends StatelessWidget {
  final DeckButton parentButton;
  final List<DeckButton> buttons;
  final DeckExecutionService executionService;
  final SettingsService settingsService;
  final LiveStateService liveStateService;

  const FolderOverlayWidget({
    super.key,
    required this.parentButton,
    required this.buttons,
    required this.executionService,
    required this.settingsService,
    required this.liveStateService,
  });

  static Future<void> show(
    BuildContext context, {
    required DeckButton parentButton,
    required List<DeckButton> buttons,
    required DeckExecutionService executionService,
    required SettingsService settingsService,
    required LiveStateService liveStateService,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FolderOverlayWidget(
        parentButton: parentButton,
        buttons: buttons,
        executionService: executionService,
        settingsService: settingsService,
        liveStateService: liveStateService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeBundle = AstraThemeBundle.of(context);
    final s = settingsService.settings;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: themeBundle.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeBundle.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    IconHelper.getIcon(parentButton.iconName),
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    parentButton.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: themeBundle.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: themeBundle.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Sub-button Grid
              if (buttons.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No sub-actions inside this folder',
                    style: TextStyle(color: themeBundle.textSecondary),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: buttons.length > 4 ? 4 : (buttons.length > 2 ? 3 : 2),
                    crossAxisSpacing: s.buttonSpacing,
                    mainAxisSpacing: s.buttonSpacing,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: buttons.length,
                  itemBuilder: (context, idx) {
                    final btn = buttons[idx];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(s.buttonCornerRadius),
                        onTap: () {
                          executionService.executeButton(btn, s);
                          Navigator.of(context).pop();
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Color(btn.backgroundColor),
                            borderRadius: BorderRadius.circular(s.buttonCornerRadius),
                            border: Border.all(color: themeBundle.borderColor),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                IconHelper.getIcon(btn.iconName),
                                color: Color(btn.textColor),
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  btn.title,
                                  style: TextStyle(
                                    color: Color(btn.textColor),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
