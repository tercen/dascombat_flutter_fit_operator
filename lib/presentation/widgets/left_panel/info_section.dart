import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_dark.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/version/version_info.dart';
import '../../providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:web/web.dart' as web;

/// Standard INFO section. Required in every Tercen app.
/// Displays GitHub repository link with version/commit hash.
class InfoSection extends StatelessWidget {
  const InfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final linkColor = isDark ? AppColorsDark.link : AppColors.link;
    final textColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    final versionDisplay = VersionInfo.commitHash.isNotEmpty
        ? VersionInfo.commitHash.length > 7
            ? VersionInfo.commitHash.substring(0, 7)
            : VersionInfo.commitHash
        : VersionInfo.version;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(FontAwesomeIcons.github, size: 14, color: textColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _repoName,
                style: AppTextStyles.bodySmall.copyWith(color: textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (versionDisplay.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: () => _openUrl('${VersionInfo.gitRepo}/commit/${VersionInfo.commitHash}'),
                child: Text(
                  versionDisplay,
                  style: AppTextStyles.bodySmall.copyWith(color: linkColor),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String get _repoName {
    final uri = Uri.tryParse(VersionInfo.gitRepo);
    if (uri == null) return VersionInfo.gitRepo;
    return uri.pathSegments.lastOrNull ?? VersionInfo.gitRepo;
  }

  void _openUrl(String url) {
    web.window.open(url, '_blank');
  }
}
