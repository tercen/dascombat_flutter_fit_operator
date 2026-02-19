import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/theme_provider.dart';
import 'left_panel_header.dart';
import 'left_panel_section.dart';

/// Data class for a panel section. Used to build both expanded and collapsed views.
class PanelSection {
  final IconData icon;
  final String label;
  final Widget content;

  const PanelSection({
    required this.icon,
    required this.label,
    required this.content,
  });
}

/// Left panel with expand/collapse, resize, and scrollable sections.
///
/// Expanded (280-400px): header (4 elements) + scrollable sections.
/// Collapsed (48px): header (icon only) + icon strip + footer (chevron).
///
/// DO NOT MODIFY this structural behavior when building apps.
/// Only replace the sections list with app-specific sections.
class LeftPanel extends StatefulWidget {
  final String appTitle;
  final IconData appIcon;
  final List<PanelSection> sections;

  const LeftPanel({
    super.key,
    required this.appTitle,
    required this.appIcon,
    required this.sections,
  });

  @override
  State<LeftPanel> createState() => _LeftPanelState();
}

class _LeftPanelState extends State<LeftPanel> {
  bool _isCollapsed = false;
  double _panelWidth = AppSpacing.panelWidth;
  bool _isResizeHovering = false;

  void _toggleCollapse() {
    setState(() {
      _isCollapsed = !_isCollapsed;
      if (!_isCollapsed) {
        _panelWidth = AppSpacing.panelWidth;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final panelBg = isDark ? AppColorsDark.panelBackground : AppColors.panelBackground;
    final borderColor = isDark ? AppColorsDark.border : AppColors.border;

    final targetWidth = _isCollapsed ? AppSpacing.panelCollapsedWidth : _panelWidth;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Panel body
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: targetWidth,
          decoration: BoxDecoration(
            color: panelBg,
            border: Border(right: BorderSide(color: borderColor)),
          ),
          child: Column(
            children: [
              // Header — uses LayoutBuilder to adapt during animation
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 200;
                  return LeftPanelHeader(
                    appIcon: widget.appIcon,
                    appTitle: widget.appTitle,
                    isCollapsed: isNarrow,
                    onToggleCollapse: _toggleCollapse,
                  );
                },
              ),
              // Content area — switches between expanded sections and collapsed icon strip
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 200) {
                      return _buildCollapsedContent(isDark);
                    }
                    return _buildExpandedContent();
                  },
                ),
              ),
              // Footer — only visible when collapsed (contains expand chevron)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 200) {
                    return _buildCollapsedFooter(isDark);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        // Resize handle (only when expanded)
        if (!_isCollapsed)
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => setState(() => _isResizeHovering = true),
            onExit: (_) => setState(() => _isResizeHovering = false),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _panelWidth = (_panelWidth + details.delta.dx).clamp(
                    AppSpacing.panelMinWidth,
                    AppSpacing.panelMaxWidth,
                  );
                });
              },
              child: Container(
                width: 4,
                color: _isResizeHovering
                    ? (isDark ? AppColorsDark.primary : AppColors.primary).withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
          ),
      ],
    );
  }

  /// Expanded content: scrollable list of sections.
  Widget _buildExpandedContent() {
    return SingleChildScrollView(
      child: Column(
        children: widget.sections.map((section) {
          return LeftPanelSection(
            icon: section.icon,
            label: section.label,
            child: section.content,
          );
        }).toList(),
      ),
    );
  }

  /// Collapsed content: vertical icon strip. Tap any icon to expand.
  Widget _buildCollapsedContent(bool isDark) {
    final iconColor = isDark ? AppColorsDark.textMuted : AppColors.textMuted;

    return SingleChildScrollView(
      child: Column(
        children: widget.sections.map((section) {
          return Tooltip(
            message: section.label,
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 500),
            child: InkWell(
              onTap: _toggleCollapse,
              child: SizedBox(
                width: double.infinity,
                height: AppSpacing.xxl,
                child: Center(
                  child: Icon(section.icon, size: 16, color: iconColor),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Collapsed footer: expand chevron filling the full bar width.
  Widget _buildCollapsedFooter(bool isDark) {
    final bgColor = isDark ? AppColorsDark.primary : AppColors.primary;

    return Tooltip(
      message: 'Expand panel',
      child: InkWell(
        onTap: _toggleCollapse,
        child: Container(
          height: AppSpacing.headerHeight,
          width: double.infinity,
          color: bgColor,
          child: const Center(
            child: Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
