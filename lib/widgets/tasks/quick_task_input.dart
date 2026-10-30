import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_colors.dart';
import '../../models/project_item.dart';
import '../../providers/project_providers.dart';
import '../../providers/task_providers.dart';

class QuickTaskInput extends ConsumerStatefulWidget {
  final String? defaultProjectId;
  const QuickTaskInput({super.key, this.defaultProjectId});

  @override
  ConsumerState<QuickTaskInput> createState() => _QuickTaskInputState();
}

class _QuickTaskInputState extends ConsumerState<QuickTaskInput> {
  final _titleController = TextEditingController();
  final _focusNode = FocusNode();

  int _selectedDuration = 30; // 30 minutes default
  final String _selectedPriority = 'none';
  String? _selectedProjectId;

  static const List<int> _durations = [15, 30, 45, 60, 90];

  @override
  void dispose() {
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final projects = ref.read(projectsStreamProvider).value ?? [];
    final currentFilteredProject = ref.read(selectedProjectIdProvider);

    ProjectItem? defaultProject;
    for (final p in projects) {
      if (p.isDefault) {
        defaultProject = p;
        break;
      }
    }
    defaultProject ??= projects.isNotEmpty ? projects.first : null;

    final targetProjectId = _selectedProjectId ?? widget.defaultProjectId ?? currentFilteredProject ?? defaultProject?.id ?? 'proj_inbox';

    ref.read(taskControllerProvider).addTask(
          title: title,
          projectId: targetProjectId,
          estimatedMinutes: _selectedDuration,
          priority: _selectedPriority,
        );

    _titleController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projects = ref.watch(projectsProvider);
    final effectiveProjectId = widget.defaultProjectId ?? ref.watch(selectedProjectIdProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? PlanColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? PlanColors.darkBorder : PlanColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Add a new task (e.g. Write report)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_rounded, color: PlanColors.primary, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Add Task (Enter)',
                onPressed: _submit,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Duration & Project Selector
          Wrap(
            spacing: 4,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Est:',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? PlanColors.darkTextMuted : PlanColors.lightTextMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ..._durations.map((duration) {
                final isSelected = _selectedDuration == duration;
                return InkWell(
                  onTap: () => setState(() => _selectedDuration = duration),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? PlanColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? PlanColors.primary
                            : (isDark ? PlanColors.darkBorder : PlanColors.lightBorder),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      duration >= 60 ? '${duration ~/ 60}h' : '${duration}m',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? PlanColors.primary
                            : (isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary),
                      ),
                    ),
                  ),
                );
              }),

              // Project selector if no project is filtered
              if (effectiveProjectId == null && projects.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedProjectId ?? projects.first.id,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? PlanColors.darkTextSecondary : PlanColors.lightTextSecondary,
                      ),
                      items: projects.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: p.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 100),
                                child: Text(
                                  p.name,
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedProjectId = val);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
