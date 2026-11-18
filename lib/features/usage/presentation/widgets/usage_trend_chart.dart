import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/usage_analytics_data.dart';

/// Interactive time-series trajectory chart plotting daily AI token usage across the month.
///
/// Features:
/// 1. Smooth Bezier Curve: anti-aliased cubic spline with gradient area fill.
/// 2. Peak Day Pill Tag: compact header badge highlighting the heaviest activity burst.
/// 3. Subtle Right-Aligned Grid Numbers: (e.g. 23K, 12K, 0) providing instant scale.
/// 4. Interactive Scrubber: touch/drag to view exact day metrics in a tooltip.
/// 5. 100% pure Flutter `CustomPainter` with zero external charting dependencies.
class UsageTrendChart extends StatefulWidget {
  final UsageAnalyticsData data;
  final bool isTablet;

  const UsageTrendChart({
    super.key,
    required this.data,
    this.isTablet = false,
  });

  @override
  State<UsageTrendChart> createState() => _UsageTrendChartState();
}

class _UsageTrendChartState extends State<UsageTrendChart> {
  int? _hoveredDayIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final l10n = context.l10n;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final peak = widget.data.peakDay;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row: Title & Sleek Peak Pill Tag ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dailyActivityTrends,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.dailyTokenUsage,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Sleek Peak Pill Tag in Header
              if (peak != null && peak.hasActivity)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 5.0,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F6BFF)
                        .withValues(alpha: isDark ? 0.20 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4F6BFF)
                          .withValues(alpha: isDark ? 0.35 : 0.25),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: Color(0xFF4F6BFF),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.peakBadge(_formatPeakDate(widget.data.monthKey, peak.day)),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4F6BFF),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Interactive Chart Canvas ──────────────────────────────────────
          SizedBox(
            height: widget.isTablet ? 220 : 180,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final points = widget.data.dailyPoints;

                return GestureDetector(
                  onPanDown: (details) => _updateHover(details.localPosition,
                      constraints.maxWidth, points.length),
                  onPanUpdate: (details) => _updateHover(details.localPosition,
                      constraints.maxWidth, points.length),
                  onPanEnd: (_) => setState(() => _hoveredDayIndex = null),
                  onPanCancel: () => setState(() => _hoveredDayIndex = null),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _TrendCurvePainter(
                      points: points,
                      isDark: isDark,
                      accentColor: const Color(0xFF4F6BFF),
                      hoveredIndex: _hoveredDayIndex,
                      ctx: context
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── X-Axis Calendar Labels ─────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final daysInMonth = widget.data.dailyPoints.isNotEmpty
                  ? widget.data.dailyPoints.length
                  : 30;
              final width = constraints.maxWidth;

              // Dynamically adapt day intervals based on available horizontal space:
              // - Wide Tablet / Desktop (>= 560dp): Smaller 5-day difference (7 markers: 01, 05, 10, 15, 20, 25, 30/31)
              // - Compact Mobile (< 560dp): 7-day weekly intervals (5 markers: 01, 08, 15, 22, 30/31)
              final List<int> dayList;
              if (width >= 560.0) {
                dayList = [1, 5, 10, 15, 20, 25, daysInMonth];
              } else {
                dayList = [1, 8, 15, 22, daysInMonth];
              }

              // Deduplicate in case daysInMonth matches a step (e.g. 25 or 30)
              final uniqueDays = dayList.toSet().toList()..sort();

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: uniqueDays.map((day) {
                  final formattedDay = day.toString().padLeft(2, '0');
                  return _axisLabel(l10n.dayPrefix(formattedDay), isDark);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _updateHover(Offset localPos, double chartWidth, int totalDays) {
    if (totalDays == 0 || chartWidth <= 0) return;
    final progress = (localPos.dx / chartWidth).clamp(0.0, 1.0);
    final index = (progress * (totalDays - 1)).round();
    if (index >= 0 && index < totalDays) {
      setState(() {
        _hoveredDayIndex = index;
      });
    }
  }

  Widget _axisLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: context.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
    );
  }

  /// Formats the peak day banner date (e.g. 'Oct 15').
  static String _formatPeakDate(String monthKey, int day) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final m = int.tryParse(parts[1]);
      if (m != null && m >= 1 && m <= 12) {
        return '${months[m - 1]} $day';
      }
    }
    return 'Day $day';
  }
}

/// CustomPainter rendering smooth cubic spline curves, gradient underlay,
/// horizontal reference grid lines with subtle right-aligned numbers, and
/// interactive touch hover indicators.
class _TrendCurvePainter extends CustomPainter {
  final List<DailyUsagePoint> points;
  final bool isDark;
  final Color accentColor;
  final int? hoveredIndex;
  final BuildContext ctx;

  _TrendCurvePainter({
    required this.points,
    required this.isDark,
    required this.accentColor,
    this.hoveredIndex, required this.ctx
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 1. Calculate Peak and Maximum Y value (Token Volume)
    double peakVal = 0.0;
    for (final p in points) {
      final val = p.totalTokens.toDouble();
      if (val > peakVal) peakVal = val;
    }
    // Add 15% headroom above highest point so peaks don't clip at top
    final maxY = peakVal > 0 ? peakVal * 1.15 : 1.0;

    // 2. Draw Horizontal Dotted/Subtle Grid Lines & Right-Aligned Numbers
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    void drawGridLineWithLabel(double val, double y) {
      final labelText = val > 0 ? _formatCompact(val.round()) : '0';
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: ctx.colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 14.0,
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Draw subtle grid line stopping just before the text
      final lineEndX = size.width - textPainter.width - 6.0;
      if (lineEndX > 0) {
        canvas.drawLine(Offset(0, y), Offset(lineEndX, y), gridPaint);
      }

      // Paint label right-aligned
      final textY =
          (y - textPainter.height / 2).clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(size.width - textPainter.width, textY));
    }

    if (peakVal > 0) {
      // Top line at actual peak height (e.g. 23K)
      final yPeak = size.height - ((peakVal / maxY) * size.height);
      drawGridLineWithLabel(peakVal, yPeak);

      // Mid line at half of peak height (e.g. 12K)
      final midVal = peakVal / 2;
      final yMid = size.height - ((midVal / maxY) * size.height);
      drawGridLineWithLabel(midVal, yMid);
    }

    // Baseline at bottom (0)
    drawGridLineWithLabel(0, size.height);

    // 3. Map Data Points to Canvas Coordinates
    final dxStep = size.width / (points.length - 1);
    final List<Offset> offsets = [];

    for (int i = 0; i < points.length; i++) {
      final val = points[i].totalTokens.toDouble();
      final x = i * dxStep;
      final y = size.height - ((val / maxY) * size.height);
      offsets.add(Offset(x, y.clamp(4.0, size.height)));
    }

    // 4. Construct Smooth Cubic Spline Path
    final path = Path();
    path.moveTo(offsets[0].dx, offsets[0].dy);

    for (int i = 0; i < offsets.length - 1; i++) {
      final current = offsets[i];
      final next = offsets[i + 1];
      final controlPoint1 =
          Offset(current.dx + (next.dx - current.dx) / 2, current.dy);
      final controlPoint2 =
          Offset(current.dx + (next.dx - current.dx) / 2, next.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        next.dx,
        next.dy,
      );
    }

    // 5. Draw Gradient Fill Under Curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: isDark ? 0.35 : 0.22),
          accentColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 6. Draw the Main Trend Line Stroke
    final strokePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // 7. Render Hover Indicator / Tooltip (if user is scrubbing)
    if (hoveredIndex != null && hoveredIndex! < offsets.length) {
      final hoverOffset = offsets[hoveredIndex!];
      final hoveredPoint = points[hoveredIndex!];

      // Vertical guide line
      final guidePaint = Paint()
        ..color = isDark ? Colors.white30 : Colors.black26
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(hoverOffset.dx, 0),
        Offset(hoverOffset.dx, size.height),
        guidePaint,
      );

      // Glowing dot at the point
      final haloPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hoverOffset, 8.0, haloPaint);

      final dotPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hoverOffset, 4.0, dotPaint);

      // Tooltip Card
      _drawTooltip(canvas, size, hoverOffset, hoveredPoint);
    }
  }

  void _drawTooltip(
    Canvas canvas,
    Size size,
    Offset point,
    DailyUsagePoint data,
  ) {
    final label =
        'Day ${data.day}: ${_formatValue(data.totalTokens)} tok · ${data.requestCount} reqs';

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final tooltipWidth = textPainter.width + 16;
    const tooltipHeight = 22.0;

    // Anchor tooltip horizontally without clipping off the edges
    double left = point.dx - (tooltipWidth / 2);
    left = left.clamp(4.0, size.width - tooltipWidth - 4.0);

    double top = point.dy - 32;
    if (top < 0) top = point.dy + 12;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, tooltipWidth, tooltipHeight),
      const Radius.circular(6),
    );

    final bgPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(bgRect, bgPaint);

    textPainter.paint(
      canvas,
      Offset(left + 8, top + (tooltipHeight - textPainter.height) / 2),
    );
  }

  static String _formatValue(int val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(1)}K';
    return val.toString();
  }

  static String _formatCompact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }

  @override
  bool shouldRepaint(covariant _TrendCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.isDark != isDark;
  }
}
