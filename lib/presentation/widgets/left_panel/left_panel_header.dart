import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';

/// Accent-colored header for the left panel.
///
/// Expanded: icon + title + theme toggle + collapse chevron (left to right).
/// Collapsed: icon only (centered). Theme toggle and chevron move to footer.
class LeftPanelHeader extends StatelessWidget {
  final IconData appIcon;
  final String appTitle;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const LeftPanelHeader({
    super.key,
    required this.appIcon,
    required this.appTitle,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppColorsDark.primary : AppColors.primary;

    return Container(
      height: AppSpacing.headerHeight,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: isCollapsed ? _buildCollapsed() : _buildExpanded(context),
    );
  }

  Widget _buildCollapsed() {
    return Center(
      child: Icon(appIcon, color: Colors.white, size: 20),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();

    return Row(
      children: [
        Icon(appIcon, color: Colors.white, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            appTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Theme toggle
        IconButton(
          icon: Icon(
            themeProvider.isDarkMode ? Icons.wb_sunny : Icons.dark_mode,
            color: Colors.white,
            size: 20,
          ),
          onPressed: themeProvider.toggleTheme,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: themeProvider.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
        ),
        // Collapse chevron
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
          onPressed: onToggleCollapse,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: 'Collapse panel',
        ),
      ],
    );
  }
}
