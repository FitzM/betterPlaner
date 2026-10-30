import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/plan_colors.dart';
import '../models/view_mode.dart';
import '../providers/auth_provider.dart';
import '../providers/calendar_providers.dart';
import '../providers/layout_providers.dart';
import '../providers/task_providers.dart';
import '../widgets/calendar/calendar_grid_pane.dart';
import '../widgets/common/resizable_divider.dart';
import '../widgets/settings/firebase_setup_dialog.dart';
import '../widgets/sidebar/project_sidebar.dart';
import '../widgets/tasks/floating_task_inspector.dart';
import '../widgets/tasks/task_board_pane.dart';
import '../widgets/tasks/task_list_pane.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _mobileTabIndex = 0; // 0 = Tasks, 1 = Calendar

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final sidebarWidth = ref.watch(sidebarWidthProvider);
    final taskPaneWidth = ref.watch(taskPaneWidthProvider);
    final layoutMode = ref.watch(dashboardLayoutModeProvider);
    final activeInspectorTask = ref.watch(activeInspectorTaskProvider);

    return Scaffold(
      backgroundColor: isDark ? PlanColors.darkBg : PlanColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Error / Security Notice Banner if any
            if (authState.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.brown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authState.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.brown.shade900,
                      ),
                      icon: const Icon(Icons.settings, size: 14),
                      label: const Text(
                        'Setup Firebase',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => FirebaseSetupDialog.show(context),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => ref.read(authProvider.notifier).dismissError(),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main Responsive Body with Resizable Splitters & Floating Inspector Overlay
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Desktop / Large Web View (Width > 850px)
                        if (constraints.maxWidth >= 850) {
                          if (layoutMode == DashboardLayoutMode.multiColumnBoard) {
                            return Row(
                              children: [
                                ProjectSidebar(width: sidebarWidth),
                                ResizableDivider(
                                  onDelta: (dx) =>
                                      ref.read(sidebarWidthProvider.notifier).adjust(dx),
                                  onDoubleTap: () =>
                                      ref.read(sidebarWidthProvider.notifier).reset(),
                                ),
                                const TaskBoardPane(),
                                ResizableDivider(
                                  onDelta: (dx) =>
                                      ref.read(taskPaneWidthProvider.notifier).adjust(dx),
                                  onDoubleTap: () =>
                                      ref.read(taskPaneWidthProvider.notifier).reset(),
                                ),
                                CalendarGridPane(width: taskPaneWidth),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              ProjectSidebar(width: sidebarWidth),
                              ResizableDivider(
                                onDelta: (dx) =>
                                    ref.read(sidebarWidthProvider.notifier).adjust(dx),
                                onDoubleTap: () =>
                                    ref.read(sidebarWidthProvider.notifier).reset(),
                              ),
                              TaskListPane(width: taskPaneWidth),
                              ResizableDivider(
                                onDelta: (dx) =>
                                    ref.read(taskPaneWidthProvider.notifier).adjust(dx),
                                onDoubleTap: () =>
                                    ref.read(taskPaneWidthProvider.notifier).reset(),
                              ),
                              const CalendarGridPane(),
                            ],
                          );
                        }

                        // Tablet View (600px - 850px)
                        if (constraints.maxWidth >= 600) {
                          if (layoutMode == DashboardLayoutMode.multiColumnBoard) {
                            return Row(
                              children: [
                                const TaskBoardPane(),
                                ResizableDivider(
                                  onDelta: (dx) =>
                                      ref.read(taskPaneWidthProvider.notifier).adjust(dx),
                                  onDoubleTap: () =>
                                      ref.read(taskPaneWidthProvider.notifier).reset(),
                                ),
                                CalendarGridPane(width: taskPaneWidth),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              TaskListPane(width: taskPaneWidth),
                              ResizableDivider(
                                onDelta: (dx) =>
                                    ref.read(taskPaneWidthProvider.notifier).adjust(dx),
                                onDoubleTap: () =>
                                    ref.read(taskPaneWidthProvider.notifier).reset(),
                              ),
                              const CalendarGridPane(),
                            ],
                          );
                        }

                        // Mobile View (< 600px)
                        return IndexedStack(
                          index: _mobileTabIndex,
                          children: [
                            layoutMode == DashboardLayoutMode.multiColumnBoard
                                ? const TaskBoardPane()
                                : const TaskListPane(),
                            const CalendarGridPane(),
                          ],
                        );
                      },
                    ),
                  ),

                  // Floating Movable & Resizable Inspector Overlay (TickTick style)
                  if (activeInspectorTask != null)
                    FloatingTaskInspector(
                      key: ValueKey('inspector_${activeInspectorTask.id}'),
                      task: activeInspectorTask,
                      onClose: () {
                        ref.read(activeInspectorTaskIdProvider.notifier).state = null;
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation for mobile screens
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? BottomNavigationBar(
              currentIndex: _mobileTabIndex,
              onTap: (index) => setState(() => _mobileTabIndex = index),
              selectedItemColor: PlanColors.primary,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.check_circle_outline),
                  activeIcon: Icon(Icons.check_circle),
                  label: 'Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined),
                  activeIcon: Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
              ],
            )
          : null,
    );
  }
}
