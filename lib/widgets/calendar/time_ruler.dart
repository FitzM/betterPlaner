import 'package:flutter/material.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';

class TimeRuler extends StatelessWidget {
  final double hourHeight;

  const TimeRuler({
    super.key,
    this.hourHeight = TimeUtils.defaultHourHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 58,
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkBg : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // Spacer corresponding to Day Column Header height (approx 58px)
          const SizedBox(height: 58),

          // Hour marks for all 24 hours
          ...List.generate(TimeUtils.totalHours + 1, (index) {
            final hour = TimeUtils.startHour + index;
            return SizedBox(
              height: hourHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 0),
                  child: Text(
                    TimeUtils.formatHour(hour),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
