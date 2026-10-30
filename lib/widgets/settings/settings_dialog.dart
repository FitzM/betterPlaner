import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../providers/calendar_providers.dart';
import '../../providers/settings_provider.dart';
import 'firebase_setup_dialog.dart';
import 'ticktick_import_dialog.dart';

class SettingsDialog extends ConsumerWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final visibleHours = ref.watch(calendarZoomProvider);

    return Dialog(
      backgroundColor: isDark ? PlanColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 20, color: PlanColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Calendar & Task Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Setting 1: Default Click-to-Create Duration
              Text(
                'DEFAULT CLICK TIME BLOCK DURATION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'When clicking on the calendar, a block of this duration will be created centered on your click.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60, 90].map((mins) {
                  final isSelected = settings.defaultTaskDuration == mins;
                  return ChoiceChip(
                    label: Text('${mins}m'),
                    selected: isSelected,
                    selectedColor: PlanColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      ref.read(settingsProvider.notifier).setDefaultDuration(mins);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Setting 2: Calendar Zoom Visible Hours
              Text(
                'CURRENT CALENDAR ZOOM LEVEL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Adjust how many hours of the day fit within your screen viewport (3h to 24h).',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: visibleHours,
                      min: 3.0,
                      max: 24.0,
                      divisions: 7,
                      label: '${visibleHours.round()} hours',
                      activeColor: PlanColors.primary,
                      onChanged: (val) {
                        ref.read(calendarZoomProvider.notifier).setVisibleHours(val);
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PlanColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${visibleHours.round()}h',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PlanColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Setting 3: Integrations & Cloud Sync
              Text(
                'DATA & CLOUD SYNC',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        TickTickImportDialog.show(context);
                      },
                      icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF388E3C)),
                      label: const Text('Import TickTick', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        FirebaseSetupDialog.show(context);
                      },
                      icon: const Icon(Icons.cloud_sync_outlined, size: 16, color: PlanColors.primary),
                      label: const Text('Firebase Setup', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Close / Done button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PlanColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
