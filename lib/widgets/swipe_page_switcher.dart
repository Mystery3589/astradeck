import 'package:flutter/material.dart';
import '../models/deck_models.dart';
import '../theme/astradeck_theme.dart';

/// Wraps deck pages in a swipeable PageView with smooth transitions
/// and an animated dot page indicator at the bottom.
class SwipePageSwitcher extends StatefulWidget {
  final DeckProfile profile;
  final int activePageIndex;
  final ValueChanged<int> onPageChanged;
  final Widget Function(BuildContext context, DeckPage page) pageBuilder;

  const SwipePageSwitcher({
    super.key,
    required this.profile,
    required this.activePageIndex,
    required this.onPageChanged,
    required this.pageBuilder,
  });

  @override
  State<SwipePageSwitcher> createState() => _SwipePageSwitcherState();
}

class _SwipePageSwitcherState extends State<SwipePageSwitcher> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.activePageIndex);
  }

  @override
  void didUpdateWidget(covariant SwipePageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activePageIndex != widget.activePageIndex &&
        _controller.hasClients &&
        _controller.page?.round() != widget.activePageIndex) {
      _controller.animateToPage(
        widget.activePageIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeBundle = AstraThemeBundle.of(context);
    final pages = widget.profile.pages;

    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Swipeable Pages
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: pages.length,
            onPageChanged: widget.onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return widget.pageBuilder(context, pages[index]);
            },
          ),
        ),

        // Dot Page Indicator (visible when more than 1 page)
        if (pages.length > 1) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (idx) {
              final isSel = idx == widget.activePageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSel ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSel
                      ? theme.colorScheme.primary
                      : themeBundle.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
