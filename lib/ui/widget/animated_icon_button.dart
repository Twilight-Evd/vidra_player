import 'package:flutter/material.dart';

import '../../utils/event_control.dart';

/// 带动画效果的 IconButton
class AnimatedIconButton extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 图标大小
  final double? iconSize;

  /// 图标颜色
  final Color? color;

  /// 禁用状态下的颜色
  final Color? disabledColor;

  /// 点击回调
  final VoidCallback? onPressed;

  /// 动画完成回调
  final VoidCallback? onCompleted;

  /// 是否启用防抖
  final bool debounce;

  /// 工具提示
  final String? tooltip;

  /// 内边距
  final EdgeInsetsGeometry padding;

  /// 对齐方式
  final AlignmentGeometry alignment;

  /// 视觉密度
  final VisualDensity? visualDensity;

  /// 约束
  final BoxConstraints? constraints;

  /// 是否自动获取焦点
  final bool autofocus;

  /// 鼠标指针样式
  final MouseCursor? mouseCursor;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 选中状态（用于切换图标）
  final bool isSelected;

  /// 选中时的图标
  final IconData? selectedIcon;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    this.iconSize,
    this.color,
    this.disabledColor,
    this.onPressed,
    this.onCompleted,
    this.debounce = false,
    this.tooltip,
    this.padding = const EdgeInsets.all(8.0),
    this.alignment = Alignment.center,
    this.visualDensity,
    this.constraints,
    this.autofocus = false,
    this.mouseCursor,
    this.focusNode,
    this.isSelected = false,
    this.selectedIcon,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late final Debounce? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _scaleAnimation.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse().then((value) {
          widget.onCompleted?.call();
        });
      }
    });

    _debounce = widget.debounce
        ? Debounce(const Duration(milliseconds: 300))
        : null;
  }

  void _handleTap() {
    if (widget.onPressed == null) return;

    if (widget.debounce) {
      _debounce!.call(() {
        _executeTap();
      });
    } else {
      _executeTap();
    }
  }

  void _executeTap() {
    widget.onPressed?.call();
    _controller.forward();
  }

  @override
  void dispose() {
    _debounce?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconTheme = IconTheme.of(context);

    // 获取图标大小
    final double effectiveIconSize = widget.iconSize ?? iconTheme.size ?? 24.0;

    // 获取图标颜色
    final Color? effectiveColor = widget.onPressed == null
        ? (widget.disabledColor ?? theme.disabledColor)
        : widget.color ?? iconTheme.color;

    // 获取鼠标指针
    final MouseCursor effectiveMouseCursor =
        widget.mouseCursor ??
        (widget.onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click);

    // 选择要显示的图标
    final IconData effectiveIcon =
        widget.isSelected && widget.selectedIcon != null
        ? widget.selectedIcon!
        : widget.icon;

    Widget result = ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Icon(effectiveIcon, key: ValueKey(effectiveIcon)),
        ),
        iconSize: effectiveIconSize,
        color: effectiveColor,
        padding: widget.padding,
        alignment: widget.alignment,
        visualDensity: widget.visualDensity,
        constraints: widget.constraints,
        onPressed: widget.onPressed != null ? _handleTap : null,
        tooltip: widget.tooltip,
        autofocus: widget.autofocus,
        mouseCursor: effectiveMouseCursor,
        focusNode: widget.focusNode,
        isSelected: widget.isSelected,
      ),
    );

    return result;
  }
}
