import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draggable pill that triggers [onCompleted] when fully swiped.
class SwipeActionButton extends StatefulWidget {
  const SwipeActionButton({
    super.key,
    required this.label,
    required this.onCompleted,
    this.loadingLabel,
    this.releaseLabel,
    this.height = 56,
    this.enabled = true,
    this.icon = Icons.chevron_right_rounded,
    this.knobColor = Colors.white,
    this.trackColor = const Color(0xFFF1592A),
    this.successIcon = Icons.check_rounded,
    this.gradient,
    this.progressColor,
  });

  final String label;
  final String? loadingLabel;
  final String? releaseLabel;
  final Future<bool> Function() onCompleted;
  final double height;
  final bool enabled;
  final IconData icon;
  final IconData successIcon;
  final Color knobColor;
  final Color trackColor;
  final Gradient? gradient;
  final Color? progressColor;

  @override
  State<SwipeActionButton> createState() => _SwipeActionButtonState();
}

class _SwipeActionButtonState extends State<SwipeActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _resetController;
  Animation<double>? _resetAnimation;
  double _percent = 0;
  bool _processing = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(covariant SwipeActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled && mounted) {
      _animateReset();
    }
  }

  @override
  void dispose() {
    _resetAnimation?.removeListener(_resetTick);
    _resetAnimation = null;
    _resetController.dispose();
    super.dispose();
  }

  bool get _canInteract => widget.enabled && !_processing;

  Gradient _resolveGradient(double progress) {
    if (widget.gradient != null) return widget.gradient!;
    final base = widget.trackColor;
    final softened = _lighten(base, 0.12);
    final end = _mix(softened, base, progress.clamp(0.0, 1.0));
    final start = _mix(_darken(base, 0.18), softened, progress.clamp(0.0, 1.0));
    return LinearGradient(
      colors: [start, end],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }

  Future<void> _handleCompletion() async {
    setState(() {
      _processing = true;
      _completed = true;
    });
    bool ok = false;
    try {
      ok = await widget.onCompleted();
    } finally {
      if (!mounted) return;
      setState(() {
        _processing = false;
      });
    }
    if (!mounted) return;
    if (!ok) {
      _completed = false;
      _animateReset();
    }
  }

  void _animateReset() {
    _resetController.stop();
    _resetAnimation?.removeListener(_resetTick);
    _resetAnimation?.removeStatusListener(_handleStatus);
    _resetAnimation = Tween<double>(begin: _percent, end: 0).animate(
      CurvedAnimation(
        parent: _resetController,
        curve: Curves.easeOutCubic,
      ),
    )
      ..addListener(_resetTick)
      ..addStatusListener(_handleStatus);
    _resetController
      ..reset()
      ..forward();
  }

  void _resetTick() {
    if (!mounted) return;
    setState(() {
      _percent = _resetAnimation?.value ?? 0;
    });
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxExtent) {
    if (!_canInteract) return;
    final delta = details.delta.dx;
    final absolute = (_percent * maxExtent) + delta;
    final clamped = absolute.clamp(0, maxExtent);
    setState(() {
      _percent = maxExtent == 0 ? 0 : clamped / maxExtent;
    });
  }

  void _handleDragEnd(double maxExtent) {
    if (!_canInteract) return;
    final threshold = maxExtent <= 0 ? 0 : 0.75;
    if (_percent >= threshold) {
      setState(() {
        _percent = 1;
      });
      _handleCompletion();
    } else {
      _animateReset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = widget.height;
        final knobSize = height - 12;
        final maxExtent = math.max(0.0, width - knobSize - 12);
        final progress = _percent.clamp(0.0, 1.0);
        final offset = maxExtent * progress;
        final labelStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            );
        final showReleaseLabel =
            !_processing && !_completed && progress >= 0.75;
        final displayLabel = showReleaseLabel
            ? (widget.releaseLabel ?? 'Release to confirm')
            : widget.label;
        final baseProgressColor = widget.progressColor ?? Colors.white;
        final overlayStart =
            baseProgressColor.withOpacity(0.22 + (0.28 * progress));
        final overlayEnd =
            baseProgressColor.withOpacity(0.12 + (0.18 * progress));
        final knobColor =
            Color.lerp(widget.knobColor, Colors.white, progress * 0.35) ??
            widget.knobColor;
        final iconColor =
            Color.lerp(widget.trackColor, Colors.white, progress * 0.45) ??
            widget.trackColor;

        return Semantics(
          button: true,
          enabled: _canInteract,
          label: widget.label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _canInteract
                ? (details) => _handleDragUpdate(details, maxExtent)
                : null,
            onHorizontalDragEnd: _canInteract
                ? (_) => _handleDragEnd(maxExtent)
                : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: widget.enabled ? 1 : 0.55,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: _resolveGradient(progress),
                  borderRadius: BorderRadius.circular(height),
                  boxShadow: [
                    BoxShadow(
                      color: widget.trackColor.withOpacity(0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(height),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor:
                                progress > 0 ? progress.clamp(0.0, 1.0) : 0.001,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    overlayStart,
                                    overlayEnd,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: math.max(20, height * 0.6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [0.2, 0.45, 0.7].map((threshold) {
                              final arrowOpacity = progress >= threshold
                                  ? math.min(
                                      0.9,
                                      math.max(
                                        0.0,
                                        0.35 + (progress - threshold) * 0.9,
                                      ),
                                    )
                                  : 0.0;
                              return AnimatedOpacity(
                                duration: const Duration(milliseconds: 120),
                                opacity: arrowOpacity,
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withOpacity(
                                    0.55 + arrowOpacity * 0.4,
                                  ),
                                  size: constraints.biggest.height
                                    .clamp(12.0, 18.0)
                                    .toDouble(),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (_processing)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.loadingLabel ?? 'Processing…',
                            style: labelStyle,
                          ),
                        ],
                      )
                    else
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 170),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Container(
                          key: ValueKey<bool>(showReleaseLabel),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(
                              0.18 + (progress * 0.22),
                            ),
                            borderRadius: BorderRadius.circular(height),
                          ),
                          child: Text(
                            displayLabel,
                            style: labelStyle,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 6 + offset,
                      child: Container(
                        width: knobSize,
                        height: knobSize,
                        decoration: BoxDecoration(
                          color: knobColor,
                          borderRadius: BorderRadius.circular(knobSize / 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          _completed ? widget.successIcon : widget.icon,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  static Color _mix(Color a, Color b, double t) {
    return Color.lerp(a, b, t.clamp(0.0, 1.0)) ?? a;
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      _resetAnimation?.removeListener(_resetTick);
      _resetAnimation?.removeStatusListener(_handleStatus);
      _resetAnimation = null;
    }
  }
}
