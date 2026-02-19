import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_colors_dark.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/models/pca_result.dart';
import '../providers/app_state_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/left_panel/left_panel.dart';
import '../widgets/left_panel/mode_section.dart';
import '../widgets/left_panel/settings_section.dart';
import '../widgets/left_panel/actions_section.dart';
import '../widgets/left_panel/info_section.dart';

/// Home screen: assembles AppShell with DASCombat-specific sections and PCA main content.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-compute on load
    Future.microtask(() {
      context.read<AppStateProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appTitle: 'DASCombat Fit',
      appIcon: Icons.science,
      sections: const [
        PanelSection(
          icon: Icons.toggle_on_outlined,
          label: 'MODE',
          content: ModeSection(),
        ),
        PanelSection(
          icon: Icons.tune,
          label: 'SETTINGS',
          content: SettingsSection(),
        ),
        PanelSection(
          icon: Icons.play_circle_outline,
          label: 'ACTIONS',
          content: ActionsSection(),
        ),
        PanelSection(
          icon: Icons.info_outline,
          label: 'INFO',
          content: InfoSection(),
        ),
      ],
      content: const _MainContent(),
    );
  }
}

/// Main content: side-by-side PCA scatter plots (Before / After).
/// The main panel respects the theme (light/dark). Only the graph chart areas
/// inside force a white background for scientific readability.
class _MainContent extends StatelessWidget {
  const _MainContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bgColor = isDark ? AppColorsDark.background : AppColors.surface;
    final textColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    final result = provider.correctionResult;

    // Shiny-style: the LayoutBuilder + two plot boxes are ALWAYS present,
    // from the very first frame.  Only the *pixels inside* each box change
    // when data arrives.  Zero layout recalculation, zero jitter.
    return Container(
      color: bgColor,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final plotWidth = (constraints.maxWidth - AppSpacing.md) / 2;
                final plotSize = math.min(plotWidth, constraints.maxHeight);
                return Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: plotSize,
                        height: plotSize,
                        child: _PlotBox(
                          title: 'Before',
                          pcaResult: result?.before,
                          batchLabels: result?.batchLabels,
                          isLoading: provider.isLoading,
                          error: provider.error,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(
                        width: plotSize,
                        height: plotSize,
                        child: _PlotBox(
                          title: 'After',
                          pcaResult: result?.after,
                          batchLabels: result?.batchLabels,
                          isLoading: provider.isLoading,
                          error: provider.error,
                          textColor: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (result != null)
            _BatchLegend(batchLabels: result.batchLabels, isDark: isDark)
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Batch color mapping -- consistent colors for each batch label.
Color _batchColor(String batch, List<String> allBatches) {
  const colors = [
    Color(0xFFE53E3E), // red
    Color(0xFF3182CE), // blue
    Color(0xFF38A169), // green
    Color(0xFFD69E2E), // yellow
    Color(0xFF805AD5), // purple
    Color(0xFFDD6B20), // orange
    Color(0xFF319795), // teal
    Color(0xFFD53F8C), // pink
  ];
  final index = allBatches.indexOf(batch);
  return colors[index % colors.length];
}

/// Shared color legend for batch labels.
class _BatchLegend extends StatelessWidget {
  final List<String> batchLabels;
  final bool isDark;

  const _BatchLegend({required this.batchLabels, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Batch: ', style: AppTextStyles.label.copyWith(color: textColor)),
        const SizedBox(width: AppSpacing.sm),
        ...batchLabels.map((batch) {
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _batchColor(batch, batchLabels),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(batch, style: AppTextStyles.bodySmall.copyWith(color: textColor)),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Plot box with fixed outer structure (Container → Column → Expanded).
/// The outer shell is identical across loading / error / data states so
/// the layout engine never recalculates sizes — only the pixels inside
/// the Expanded area change, exactly like Shiny's plotOutput.
class _PlotBox extends StatelessWidget {
  final String title;
  final PcaResult? pcaResult;
  final List<String>? batchLabels;
  final bool isLoading;
  final String? error;
  final Color textColor;

  const _PlotBox({
    required this.title,
    required this.pcaResult,
    required this.batchLabels,
    required this.isLoading,
    required this.error,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: pcaResult != null && batchLabels != null
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return _PcaCanvas(
                        pcaResult: pcaResult!,
                        batchLabels: batchLabels!,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      );
                    },
                  )
                : Center(
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : error != null
                            ? Text(error!, style: AppTextStyles.bodySmall.copyWith(color: textColor), textAlign: TextAlign.center)
                            : const SizedBox.shrink(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Interactive canvas that paints PCA scatter points with hover tooltips.
class _PcaCanvas extends StatefulWidget {
  final PcaResult pcaResult;
  final List<String> batchLabels;
  final double width;
  final double height;

  const _PcaCanvas({
    required this.pcaResult,
    required this.batchLabels,
    required this.width,
    required this.height,
  });

  @override
  State<_PcaCanvas> createState() => _PcaCanvasState();
}

class _PcaCanvasState extends State<_PcaCanvas> {
  int? _hoveredIndex;
  Offset? _hoverPosition;

  // Chart margins for axis labels
  static const double _leftMargin = 56.0;
  static const double _bottomMargin = 40.0;
  static const double _topMargin = 8.0;
  static const double _rightMargin = 12.0;

  @override
  Widget build(BuildContext context) {
    final points = widget.pcaResult.points;
    if (points.isEmpty) {
      return const Center(child: Text('No data'));
    }

    // Compute axis ranges with padding
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final p in points) {
      if (p.pc1 < minX) minX = p.pc1;
      if (p.pc1 > maxX) maxX = p.pc1;
      if (p.pc2 < minY) minY = p.pc2;
      if (p.pc2 > maxY) maxY = p.pc2;
    }
    final rangeX = maxX - minX;
    final rangeY = maxY - minY;
    final padX = rangeX * 0.1;
    final padY = rangeY * 0.1;
    minX -= padX;
    maxX += padX;
    minY -= padY;
    maxY += padY;

    final plotWidth = widget.width - _leftMargin - _rightMargin;
    final plotHeight = widget.height - _topMargin - _bottomMargin;

    Offset dataToScreen(double x, double y) {
      final sx = _leftMargin + (x - minX) / (maxX - minX) * plotWidth;
      final sy = _topMargin + (1 - (y - minY) / (maxY - minY)) * plotHeight;
      return Offset(sx, sy);
    }

    return MouseRegion(
      onHover: (event) {
        final pos = event.localPosition;
        int? closest;
        double closestDist = 15.0; // max hover distance in pixels
        for (var i = 0; i < points.length; i++) {
          final sp = dataToScreen(points[i].pc1, points[i].pc2);
          final dist = (sp - pos).distance;
          if (dist < closestDist) {
            closestDist = dist;
            closest = i;
          }
        }
        setState(() {
          _hoveredIndex = closest;
          _hoverPosition = pos;
        });
      },
      onExit: (_) {
        setState(() {
          _hoveredIndex = null;
          _hoverPosition = null;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(widget.width, widget.height),
            painter: _PcaPlotPainter(
              points: points,
              batchLabels: widget.batchLabels,
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              leftMargin: _leftMargin,
              bottomMargin: _bottomMargin,
              topMargin: _topMargin,
              rightMargin: _rightMargin,
              varianceExplainedPc1: widget.pcaResult.varianceExplainedPc1,
              varianceExplainedPc2: widget.pcaResult.varianceExplainedPc2,
              hoveredIndex: _hoveredIndex,
            ),
          ),
          // Tooltip overlay
          if (_hoveredIndex != null && _hoverPosition != null)
            Positioned(
              left: _hoverPosition!.dx + 12,
              top: _hoverPosition!.dy - 30,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    '${points[_hoveredIndex!].sampleName}\nBatch: ${points[_hoveredIndex!].batch}',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom painter for the PCA scatter plot.
class _PcaPlotPainter extends CustomPainter {
  final List<PcaPoint> points;
  final List<String> batchLabels;
  final double minX, maxX, minY, maxY;
  final double leftMargin, bottomMargin, topMargin, rightMargin;
  final double varianceExplainedPc1;
  final double varianceExplainedPc2;
  final int? hoveredIndex;

  _PcaPlotPainter({
    required this.points,
    required this.batchLabels,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.leftMargin,
    required this.bottomMargin,
    required this.topMargin,
    required this.rightMargin,
    required this.varianceExplainedPc1,
    required this.varianceExplainedPc2,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;

    // Plot area background
    final plotRect = Rect.fromLTWH(leftMargin, topMargin, plotWidth, plotHeight);
    canvas.drawRect(plotRect, Paint()..color = const Color(0xFFFAFAFA));

    // Grid lines and axis ticks
    _drawAxes(canvas, size, plotRect, plotWidth, plotHeight);

    // Draw data points
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final sx = leftMargin + (p.pc1 - minX) / (maxX - minX) * plotWidth;
      final sy = topMargin + (1 - (p.pc2 - minY) / (maxY - minY)) * plotHeight;

      final color = _batchColor(p.batch, batchLabels);
      final radius = (i == hoveredIndex) ? 7.0 : 5.0;

      // Point fill
      canvas.drawCircle(
        Offset(sx, sy),
        radius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      // Point stroke
      canvas.drawCircle(
        Offset(sx, sy),
        radius,
        Paint()
          ..color = color.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawAxes(Canvas canvas, Size size, Rect plotRect, double plotWidth, double plotHeight) {
    // Plot border
    canvas.drawRect(plotRect, Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    // X-axis ticks and labels
    final xTicks = _niceTickValues(minX, maxX, 5);
    for (final tick in xTicks) {
      final sx = leftMargin + (tick - minX) / (maxX - minX) * plotWidth;
      if (sx < leftMargin || sx > leftMargin + plotWidth) continue;

      // Grid line
      canvas.drawLine(
        Offset(sx, topMargin),
        Offset(sx, topMargin + plotHeight),
        Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 0.5,
      );

      // Tick label
      final tp = TextPainter(
        text: TextSpan(
          text: tick.toStringAsFixed(1),
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(sx - tp.width / 2, topMargin + plotHeight + 4));
    }

    // Y-axis ticks and labels
    final yTicks = _niceTickValues(minY, maxY, 5);
    for (final tick in yTicks) {
      final sy = topMargin + (1 - (tick - minY) / (maxY - minY)) * plotHeight;
      if (sy < topMargin || sy > topMargin + plotHeight) continue;

      // Grid line
      canvas.drawLine(
        Offset(leftMargin, sy),
        Offset(leftMargin + plotWidth, sy),
        Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 0.5,
      );

      // Tick label
      final tp = TextPainter(
        text: TextSpan(
          text: tick.toStringAsFixed(1),
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftMargin - tp.width - 6, sy - tp.height / 2));
    }

    // X-axis label with variance explained
    final xLabel = TextPainter(
      text: TextSpan(
        text: 'PC1 (${varianceExplainedPc1.toStringAsFixed(1)}%)',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    xLabel.paint(
      canvas,
      Offset(leftMargin + plotWidth / 2 - xLabel.width / 2, size.height - xLabel.height - 2),
    );

    // Y-axis label with variance explained (rotated)
    final yLabel = TextPainter(
      text: TextSpan(
        text: 'PC2 (${varianceExplainedPc2.toStringAsFixed(1)}%)',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(12, topMargin + plotHeight / 2 + yLabel.width / 2);
    canvas.rotate(-math.pi / 2);
    yLabel.paint(canvas, Offset.zero);
    canvas.restore();
  }

  /// Generate nice tick values for an axis range.
  List<double> _niceTickValues(double min, double max, int approxCount) {
    final range = max - min;
    if (range <= 0) return [min];
    final rawStep = range / approxCount;
    final magnitude = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final residual = rawStep / magnitude;
    double niceStep;
    if (residual <= 1.5) {
      niceStep = magnitude;
    } else if (residual <= 3.0) {
      niceStep = 2.0 * magnitude;
    } else if (residual <= 7.0) {
      niceStep = 5.0 * magnitude;
    } else {
      niceStep = 10.0 * magnitude;
    }
    final startTick = (min / niceStep).ceil() * niceStep;
    final ticks = <double>[];
    for (var t = startTick; t <= max; t += niceStep) {
      ticks.add(t);
    }
    return ticks;
  }

  @override
  bool shouldRepaint(covariant _PcaPlotPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.points != points;
  }
}
