import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';

class CompactTimePickerResult {
  final DateTime? date;
  final bool isAllDay;
  final bool isTimeBlocked;
  final DateTime? start;
  final DateTime? end;
  final int durationMinutes;

  const CompactTimePickerResult({
    required this.date,
    required this.isAllDay,
    required this.isTimeBlocked,
    this.start,
    this.end,
    this.durationMinutes = 30,
  });
}

class CompactTimePickerPopup extends StatefulWidget {
  final DateTime? initialDate;
  final bool initialIsAllDay;
  final bool initialIsTimeBlocked;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final int initialDurationMinutes;

  const CompactTimePickerPopup({
    super.key,
    this.initialDate,
    this.initialIsAllDay = false,
    this.initialIsTimeBlocked = true,
    this.initialStart,
    this.initialEnd,
    this.initialDurationMinutes = 30,
  });

  static Future<CompactTimePickerResult?> show(
    BuildContext context, {
    DateTime? initialDate,
    bool initialIsAllDay = false,
    bool initialIsTimeBlocked = true,
    DateTime? initialStart,
    DateTime? initialEnd,
    int initialDurationMinutes = 30,
  }) {
    return showDialog<CompactTimePickerResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: CompactTimePickerPopup(
          initialDate: initialDate,
          initialIsAllDay: initialIsAllDay,
          initialIsTimeBlocked: initialIsTimeBlocked,
          initialStart: initialStart,
          initialEnd: initialEnd,
          initialDurationMinutes: initialDurationMinutes,
        ),
      ),
    );
  }

  @override
  State<CompactTimePickerPopup> createState() => _CompactTimePickerPopupState();
}

class _CompactTimePickerPopupState extends State<CompactTimePickerPopup> {
  late DateTime _selectedDate;
  late bool _isAllDay;
  late bool _isTimeBlocked;
  late TimeOfDay _startTime;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = widget.initialDate ?? widget.initialStart ?? now;
    _isAllDay = widget.initialIsAllDay;
    _isTimeBlocked = widget.initialIsTimeBlocked && !_isAllDay;

    final start = widget.initialStart ?? now;
    _startTime = TimeOfDay(hour: start.hour, minute: (start.minute ~/ 5) * 5);
    _durationMinutes = widget.initialDurationMinutes > 0 ? widget.initialDurationMinutes : 30;

    if (widget.initialStart != null && widget.initialEnd != null) {
      final diff = widget.initialEnd!.difference(widget.initialStart!).inMinutes;
      if (diff > 0) _durationMinutes = diff;
    }
  }

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _endDateTime => _startDateTime.add(Duration(minutes: _durationMinutes));

  void _apply() {
    if (!_isTimeBlocked && !_isAllDay) {
      // Unscheduled
      Navigator.of(context).pop(const CompactTimePickerResult(
        date: null,
        isAllDay: false,
        isTimeBlocked: false,
        start: null,
        end: null,
      ));
      return;
    }

    if (_isAllDay) {
      final dateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      Navigator.of(context).pop(CompactTimePickerResult(
        date: dateOnly,
        isAllDay: true,
        isTimeBlocked: false,
        start: dateOnly,
        end: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59),
        durationMinutes: 0,
      ));
    } else {
      Navigator.of(context).pop(CompactTimePickerResult(
        date: _selectedDate,
        isAllDay: false,
        isTimeBlocked: true,
        start: _startDateTime,
        end: _endDateTime,
        durationMinutes: _durationMinutes,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 16, color: PlanColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Date & Duration',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                splashRadius: 14,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mode Toggle Chips (All-Day vs Specific Time)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isDark ? PlanColors.darkBg : PlanColors.lightSidebar,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isAllDay = true;
                        _isTimeBlocked = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _isAllDay
                            ? (isDark ? PlanColors.darkCardHover : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _isAllDay
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wb_sunny_rounded,
                            size: 12,
                            color: _isAllDay ? Colors.orange : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'All-Day / Anytime',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _isAllDay ? FontWeight.w700 : FontWeight.w500,
                              color: _isAllDay
                                  ? (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary)
                                  : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isAllDay = false;
                        _isTimeBlocked = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !_isAllDay && _isTimeBlocked
                            ? (isDark ? PlanColors.darkCardHover : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: !_isAllDay && _isTimeBlocked
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: !_isAllDay && _isTimeBlocked ? PlanColors.primary : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Time & Duration',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: !_isAllDay && _isTimeBlocked ? FontWeight.w700 : FontWeight.w500,
                              color: !_isAllDay && _isTimeBlocked
                                  ? (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary)
                                  : (isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quick Date Chips (Today, Tomorrow, +2 Days)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateChip('Today', DateTime.now()),
                _buildDateChip('Tomorrow', DateTime.now().add(const Duration(days: 1))),
                _buildDateChip('+2 Days', DateTime.now().add(const Duration(days: 2))),
                _buildDateChip('Next Week', DateTime.now().add(const Duration(days: 7))),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Mini Calendar Date Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? PlanColors.darkBg : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 14, color: PlanColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEE, MMM d, y').format(_selectedDate),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: Text(
                    'Change Date',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PlanColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Specific Time & Duration Controls
          if (!_isAllDay && _isTimeBlocked) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Start Time Picker Button
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _startTime,
                      );
                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? PlanColors.darkCardHover : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'START TIME',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _startTime.format(context),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Resulting Range Display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? PlanColors.darkCardHover : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'END TIME',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('h:mm a').format(_endDateTime),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: PlanColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick Duration Chips
            Text(
              'DURATION: ${TimeUtils.formatDuration(_durationMinutes)}',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [15, 30, 45, 60, 90, 120].map((mins) {
                final isSelected = _durationMinutes == mins;
                return InkWell(
                  onTap: () => setState(() => _durationMinutes = mins),
                  borderRadius: BorderRadius.circular(5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? PlanColors.primary
                          : (isDark ? PlanColors.darkBg : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected ? PlanColors.primary : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      TimeUtils.formatDuration(mins),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 14),

          // Bottom Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isAllDay = false;
                    _isTimeBlocked = false;
                  });
                  _apply();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 11)),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PlanColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(String label, DateTime targetDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = TimeUtils.isSameDay(_selectedDate, targetDate);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedDate = targetDate),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? PlanColors.primary.withValues(alpha: 0.15)
                : (isDark ? PlanColors.darkBg : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isSelected ? PlanColors.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? PlanColors.primary
                  : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

