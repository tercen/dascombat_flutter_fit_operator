import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/app_state_provider.dart';

/// MODE section: segmented button to switch between Fit Model and Apply Model.
///
/// WIRING PATTERN:
///   SegmentedButton.onSelectionChanged -> provider.setMode(value) -> notifyListeners() -> main content rebuilds
class ModeSection extends StatelessWidget {
  const ModeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Fit Model', label: Text('Fit Model')),
              ButtonSegment(value: 'Apply Model', label: Text('Apply Model')),
            ],
            selected: {provider.mode},
            onSelectionChanged: (values) {
              provider.setMode(values.first);
            },
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
