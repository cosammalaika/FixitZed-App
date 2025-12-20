import 'package:flutter/material.dart';

import 'package:fixitzed_app/core/app_spacing.dart';

class KeyboardSafeForm extends StatelessWidget {
  const KeyboardSafeForm({
    super.key,
    required this.child,
    this.footer,
    this.padding,
  });

  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: viewInsets + AppSpacing.lg,
              ).add(padding ?? EdgeInsets.zero),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      child,
                      if (footer != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FocusAware extends StatefulWidget {
  const FocusAware({
    super.key,
    required this.focusNode,
    required this.child,
    this.alignment = 0.25,
    this.duration = const Duration(milliseconds: 250),
  });

  final FocusNode focusNode;
  final Widget child;
  final double alignment;
  final Duration duration;

  @override
  State<FocusAware> createState() => _FocusAwareState();
}

class _FocusAwareState extends State<FocusAware> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant FocusAware oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          duration: widget.duration,
          alignment: widget.alignment,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
