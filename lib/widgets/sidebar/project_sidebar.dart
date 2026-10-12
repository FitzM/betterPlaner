import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../core/utils/time_utils.dart';
import '../../models/view_mode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_providers.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';
import 'add_project_dialog.dart';
import '../settings/settings_dialog.dart';

class ProjectSidebar extends ConsumerWidget {
  final double? width;
  const ProjectSidebar({super.key, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectsStreamProvider);
    final selectedProjectId = ref.watch(selectedProjectIdProvider);
    final activeFilter = ref.watch(taskFilterProvider);
    final viewMode = ref.watch(viewModeProvider);
    final authState = ref.watch(authProvider);
    final allTasksAsync = ref.watch(tasksStreamProvider);

    final allTasks = allTasksAsync.value ?? [];
    final unscheduledCount = allTasks.where((t) => !t.isCompleted && !t.isTimeBlocked).length;
    final todayCount = allTasks.where((t) {
      if (t.isCompleted) return false;
      if (t.scheduledStart != null && TimeUtils.isToday(t.scheduledStart!)) return true;
      if (t.dueDate != null && TimeUtils.isToday(t.dueDate!)) return true;
      return false;
    }).length;

    return Container(
      width: width ?? 240,
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkSidebar : PlanColors.lightSidebar,
        border: Border(
          right: BorderSide(
            color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: PlanColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GetPlan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      TimeUtils.formatShortDate(DateTime.now()),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Calendar View Mode Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? PlanColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                ),
              ),
              child: Row(
                children: CalendarViewMode.values.map((mode) {
                  final isSelected = viewMode == mode;
                  return Expanded(
                    child: InkWell(
                      onTap: () => ref.read(viewModeProvider.notifier).setMode(mode),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? PlanColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          mode.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Quick Filter Navigation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              'VIEWS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
              ),
            ),
          ),

          _buildNavItem(
            icon: Icons.inbox_outlined,
            title: 'All Tasks',
            isSelected: activeFilter == TaskFilter.all && selectedProjectId == null,
            onTap: () {
              ref.read(selectedProjectIdProvider.notifier).select(null);
              ref.read(taskFilterProvider.notifier).setFilter(TaskFilter.all);
            },
            badgeCount: allTasks.where((t) => !t.isCompleted).length,
            isDark: isDark,
          ),
          _buildNavItem(
            icon: Icons.wb_sunny_outlined,
            title: 'Today',
            isSelected: activeFilter == TaskFilter.today && selectedProjectId == null,
            onTap: () {
              ref.read(selectedProjectIdProvider.notifier).select(null);
              ref.read(taskFilterProvider.notifier).setFilter(TaskFilter.today);
            },
            badgeCount: todayCount,
            isDark: isDark,
          ),
          _buildNavItem(
            icon: Icons.hourglass_empty_rounded,
            title: 'Unscheduled',
            isSelected: activeFilter == TaskFilter.unscheduled && selectedProjectId == null,
            onTap: () {
              ref.read(selectedProjectIdProvider.notifier).select(null);
              ref.read(taskFilterProvider.notifier).setFilter(TaskFilter.unscheduled);
            },
            badgeCount: unscheduledCount,
            badgeColor: PlanColors.primary,
            isDark: isDark,
          ),
          _buildNavItem(
            icon: Icons.date_range_outlined,
            title: 'Next 7 Days',
            isSelected: activeFilter == TaskFilter.upcoming && selectedProjectId == null,
            onTap: () {
              ref.read(selectedProjectIdProvider.notifier).select(null);
              ref.read(taskFilterProvider.notifier).setFilter(TaskFilter.upcoming);
            },
            isDark: isDark,
          ),
          _buildNavItem(
            icon: Icons.check_circle_outline_rounded,
            title: 'Completed',
            isSelected: activeFilter == TaskFilter.completed && selectedProjectId == null,
            onTap: () {
              ref.read(selectedProjectIdProvider.notifier).select(null);
              ref.read(taskFilterProvider.notifier).setFilter(TaskFilter.completed);
            },
            isDark: isDark,
          ),

          const SizedBox(height: 12),

          // Projects Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROJECTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  splashRadius: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Add Project',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddProjectDialog(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Project List
          Expanded(
            child: projectsAsync.when(
              data: (projects) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final isSelected = selectedProjectId == project.id;
                    final projectTaskCount = allTasks
                        .where((t) => t.projectId == project.id && !t.isCompleted)
                        .length;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: InkWell(
                        onTap: () {
                          if (isSelected) {
                            ref.read(selectedProjectIdProvider.notifier).select(null);
                          } else {
                            ref.read(selectedProjectIdProvider.notifier).select(project.id);
                            ref.read(taskFilterProvider.notifier).setFilter(TaskFilter.all);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? PlanColors.darkCardHover : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? Border.all(
                                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: project.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  project.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    color: isSelected
                                        ? (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary)
                                        : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (projectTaskCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$projectTaskCount',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text('Error: $err', style: const TextStyle(fontSize: 11, color: Colors.red)),
              ),
            ),
          ),

          const Divider(height: 1),

          // User Profile & Google Sign-In Footer
          Padding(
            padding: const EdgeInsets.all(12),
            child: authState.user != null && !authState.user!.isDemo
                ? Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: authState.user?.photoUrl != null
                            ? NetworkImage(authState.user!.photoUrl!)
                            : null,
                        child: authState.user?.photoUrl == null
                            ? Text(
                                authState.user!.displayName.isNotEmpty
                                    ? authState.user!.displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.user!.displayName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              authState.user!.email,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        splashRadius: 14,
                        tooltip: 'Settings',
                        onPressed: () => SettingsDialog.show(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        splashRadius: 14,
                        tooltip: 'Sign Out',
                        onPressed: () => ref.read(authProvider.notifier).signOut(),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => ref.read(authProvider.notifier).signInWithGoogle(),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? PlanColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.account_circle_outlined, size: 16, color: PlanColors.primary),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Sign In with Google',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        splashRadius: 14,
                        tooltip: 'Settings',
                        onPressed: () => SettingsDialog.show(context),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    int? badgeCount,
    Color? badgeColor,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? PlanColors.darkCardHover : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(
                    color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? PlanColors.primary
                    : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? (isDark ? PlanColors.darkTextPrimary : PlanColors.lightTextPrimary)
                        : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                  ),
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor != null
                        ? badgeColor.withValues(alpha: 0.15)
                        : (isDark ? PlanColors.darkBorder : PlanColors.lightBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: badgeColor ??
                          (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
