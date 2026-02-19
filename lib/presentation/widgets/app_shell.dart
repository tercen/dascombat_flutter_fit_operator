import 'package:flutter/material.dart';
import '../../core/utils/context_detector.dart';
import 'top_bar.dart';
import 'left_panel/left_panel.dart';

/// App frame: Row → [LeftPanel, Expanded(Column → [TopBar?, MainContent])]
///
/// TopBar is conditional: hidden when embedded in Tercen Data Step (taskId present).
class AppShell extends StatelessWidget {
  final String appTitle;
  final IconData appIcon;
  final List<PanelSection> sections;
  final Widget content;

  const AppShell({
    super.key,
    required this.appTitle,
    required this.appIcon,
    required this.sections,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final showTopBar = !AppContextDetector.isInDataStep;

    return Scaffold(
      body: Row(
        children: [
          LeftPanel(
            appTitle: appTitle,
            appIcon: appIcon,
            sections: sections,
          ),
          Expanded(
            child: Column(
              children: [
                if (showTopBar) const TopBar(),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
