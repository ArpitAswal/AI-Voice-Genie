import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/localization/app_localizations.dart';

/// Displays an adaptive, Material 3 Month-Year Calendar Picker modal dialog.
///
/// Returns the selected month key in `'YYYY-MM'` format (e.g. `'2026-10'`),
/// or `null` if the user dismissed the picker without making a selection.
Future<String?> showMonthYearPicker({
  required BuildContext context,
  required String initialMonthKey,
  required List<String> availableMonths,
  int earliestYear = 2024,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => MonthYearPickerDialog(
      initialMonthKey: initialMonthKey,
      availableMonths: availableMonths,
      earliestYear: earliestYear,
    ),
  );
}

/// An adaptive, Material 3 calendar modal allowing users to select a billing month
/// across years using a clean 3x4 grid instead of a long, unwieldy vertical dropdown list.
///
/// Features:
/// - **Zero Vertical Scrolling**: Always displays a fixed 3x4 grid of 12 months.
/// - **Effortless Year Navigation**: `<` and `>` arrow buttons to jump between years in 1 tap.
/// - **Future Guard**: Automatically disables future months beyond the current calendar month.
/// - **Telemetry Indicator**: Highlights months containing recorded usage events with a subtle dot.
/// - **Landscape / Short-height safety**: Adapts vertical padding to fit small/landscape viewports.
class MonthYearPickerDialog extends StatefulWidget {
  final String initialMonthKey;
  final List<String> availableMonths;
  final int earliestYear;

  const MonthYearPickerDialog({
    super.key,
    required this.initialMonthKey,
    required this.availableMonths,
    this.earliestYear = 2024,
  });

  @override
  State<MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<MonthYearPickerDialog> {
  late int _viewYear;
  late final int _currentYear;
  late final int _currentMonth;

  static const List<String> _monthLabels = [
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
    'Dec',
  ];

  static const List<String> _fullMonthLabels = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;

    // Parse initial year from 'YYYY-MM'
    final parts = widget.initialMonthKey.split('-');
    final parsedYear = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    _viewYear = parsedYear ?? _currentYear;
  }

  void _previousYear() {
    if (_viewYear > widget.earliestYear) {
      setState(() {
        _viewYear--;
      });
    }
  }

  void _nextYear() {
    if (_viewYear < _currentYear) {
      setState(() {
        _viewYear++;
      });
    }
  }

  void _selectMonth(int monthNumber) {
    final formattedMonth = monthNumber.toString().padLeft(2, '0');
    final selectedKey = '$_viewYear-$formattedMonth';
    Navigator.of(context).pop(selectedKey);
  }

  void _selectCurrentMonth() {
    final formattedMonth = _currentMonth.toString().padLeft(2, '0');
    final currentKey = '$_currentYear-$formattedMonth';
    Navigator.of(context).pop(currentKey);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isShortHeight = MediaQuery.sizeOf(context).height <= 550.0;
    final isTablet = context.isTablet;

    final primaryColor =
        isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.surfaceLight;
    final dividerColor =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textTertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    final canGoBack = _viewYear > widget.earliestYear;
    final canGoForward = _viewYear < _currentYear;

    final dialogWidth = isTablet ? 380.0 : 330.0;

    return Dialog(
      backgroundColor: cardColor,
      elevation: 6.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
        side: BorderSide(color: dividerColor, width: 0.8),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: 20.0,
        vertical: isShortHeight ? 12.0 : 24.0,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 18.0,
            vertical: isShortHeight ? 12.0 : 18.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: Year Navigation Bar ─────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous year',
                    onPressed: canGoBack ? _previousYear : null,
                    icon: Icon(
                      Icons.chevron_left_rounded,
                      size: 26.0,
                      color: canGoBack ? textColor : textTertiaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  Text(
                    '$_viewYear',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next year',
                    onPressed: canGoForward ? _nextYear : null,
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      size: 26.0,
                      color: canGoForward ? textColor : textTertiaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
              Divider(color: dividerColor, height: 16.0, thickness: 0.6),
              const SizedBox(height: 6.0),

              // ── 3x4 Month Grid (12 Months) ──────────────────────────────────
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: isShortHeight ? 6.0 : 10.0,
                  crossAxisSpacing: 10.0,
                  childAspectRatio: isShortHeight ? 2.2 : 1.8,
                ),
                itemBuilder: (context, index) {
                  final monthNum = index + 1;
                  final formattedMonth = monthNum.toString().padLeft(2, '0');
                  final tileKey = '$_viewYear-$formattedMonth';

                  final isSelected = tileKey == widget.initialMonthKey;
                  final isFuture = (_viewYear > _currentYear) ||
                      (_viewYear == _currentYear && monthNum > _currentMonth);
                  final isCurrent =
                      _viewYear == _currentYear && monthNum == _currentMonth;
                  final hasData = widget.availableMonths.contains(tileKey);

                  return _buildMonthTile(
                    label: _monthLabels[index],
                    fullLabel: _fullMonthLabels[index],
                    isSelected: isSelected,
                    isFuture: isFuture,
                    isCurrent: isCurrent,
                    hasData: hasData,
                    primaryColor: primaryColor,
                    dividerColor: dividerColor,
                    textColor: textColor,
                    textTertiaryColor: textTertiaryColor,
                    onTap: isFuture ? null : () => _selectMonth(monthNum),
                  );
                },
              ),
              const SizedBox(height: 14.0),
              Divider(color: dividerColor, height: 1.0, thickness: 0.6),
              const SizedBox(height: 8.0),

              // ── Footer: Quick Actions ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectCurrentMonth,
                    icon: Icon(Icons.today_rounded, size: 16.0, color: primaryColor),
                    label: Text(
                      context.l10n.currentMonth,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      context.l10n.cancel,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w500,
                        color: textTertiaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthTile({
    required String label,
    required String fullLabel,
    required bool isSelected,
    required bool isFuture,
    required bool isCurrent,
    required bool hasData,
    required Color primaryColor,
    required Color dividerColor,
    required Color textColor,
    required Color textTertiaryColor,
    required VoidCallback? onTap,
  }) {
    Color backgroundColor;
    Color effectiveTextColor;
    Border? border;

    if (isSelected) {
      backgroundColor = primaryColor;
      effectiveTextColor = Colors.white;
    } else if (isFuture) {
      backgroundColor = Colors.transparent;
      effectiveTextColor = textTertiaryColor.withValues(alpha: 0.35);
    } else {
      backgroundColor = Colors.transparent;
      effectiveTextColor = textColor;
      if (isCurrent) {
        border = Border.all(color: primaryColor.withValues(alpha: 0.6), width: 1.2);
      } else {
        border = Border.all(color: dividerColor.withValues(alpha: 0.6), width: 0.6);
      }
    }

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            border: border,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected || isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: effectiveTextColor,
                ),
              ),
              // Subtle data presence dot (only shown when not selected and has recorded data)
              if (hasData && !isSelected && !isFuture) ...[
                const SizedBox(height: 3.0),
                Container(
                  width: 4.0,
                  height: 4.0,
                  decoration: BoxDecoration(
                    color: isCurrent ? primaryColor : AppColors.tealAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
