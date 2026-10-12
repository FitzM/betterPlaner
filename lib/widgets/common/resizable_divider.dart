import 'package:flutter/material.dart';
import '../../core/constants/plan_colors.dart';

class ResizableDivider extends StatefulWidget {
  final ValueChanged<double> onDelta;
  final VoidCallback? onDoubleTap;
  final Color? color;
  final double hitWidth;
  final double? height;

  const ResizableDivider({
    super.key,
    required this.onDelta,
    this.onDoubleTap,
    this.color,
    this.hitWidth = 8.0,
    this.height,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? PlanColors.darkBorder : PlanColors.lightBorder;
    final activeColor = PlanColors.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onDoubleTap,
        onHorizontalDragStart: (_) {
          setState(() => _isDragging = true);
        },
        onHorizontalDragUpdate: (details) {
          widget.onDelta(details.delta.dx);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
        },
        onHorizontalDragCancel: () {
          setState(() => _isDragging = false);
        },
        child: SizedBox(
          width: widget.hitWidth,
          height: widget.height,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: (_isHovered || _isDragging) ? 2.5 : 1.0,
              color: (_isHovered || _isDragging) ? activeColor : (widget.color ?? defaultColor),
            ),
          ),
        ),
      ),
    );
  }
}
