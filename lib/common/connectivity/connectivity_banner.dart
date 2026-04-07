import 'package:flutter/material.dart';

import 'package:fixitzed_app/core/app_theme.dart';

enum ConnectivityBannerStatus { offline, restored }

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({
    super.key,
    required this.visible,
    this.status = ConnectivityBannerStatus.offline,
  });

  final bool visible;
  final ConnectivityBannerStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.fx;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final background = switch (status) {
      ConnectivityBannerStatus.offline => colors.brand,
      ConnectivityBannerStatus.restored => colors.success,
    };
    final textColor = background.computeLuminance() > 0.45
        ? Colors.black.withValues(alpha: 0.86)
        : Colors.white;
    final message = switch (status) {
      ConnectivityBannerStatus.offline =>
        'You\'re offline. We\'ll reconnect automatically.',
      ConnectivityBannerStatus.restored => 'Internet restored',
    };

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        offset: visible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: visible ? 1 : 0,
          child: Material(
            color: background,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10 + bottomPadding),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
