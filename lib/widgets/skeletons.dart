import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: _ShimmerWrapper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                _SkeletonCircle(diameter: 48),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(width: 140, height: 16),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 100, height: 18),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                _SkeletonCircle(diameter: 44),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SkeletonBox(width: 220, height: 18),
                  SizedBox(height: 12),
                  _SkeletonBox(height: 14),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 180, height: 14),
                  SizedBox(height: 18),
                  _SkeletonBox(width: 140, height: 40, radius: 16),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SkeletonBox(height: 52, radius: 16),
            const SizedBox(height: 20),
            const _SectionHeaderSkeleton(titleWidth: 160),
            const SizedBox(height: 16),
            SizedBox(
              height: 88,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _SkeletonBox(width: 72, height: 72, radius: 20),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 68, height: 14),
                    ],
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: 6,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionHeaderSkeleton(titleWidth: 200),
            const SizedBox(height: 16),
            Column(
              children: List.generate(
                3,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: _SkeletonBox(height: 110, radius: 18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionHeaderSkeleton(titleWidth: 160),
            const SizedBox(height: 16),
            SizedBox(
              height: 132,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  return Container(
                    width: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surface,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _SkeletonCircle(diameter: 40),
                        SizedBox(height: 12),
                        _SkeletonBox(width: 90, height: 14),
                        SizedBox(height: 6),
                        _SkeletonBox(width: 64, height: 12),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopularSubcategoriesSkeleton extends StatelessWidget {
  const PopularSubcategoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeaderSkeleton(titleWidth: 180),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final widths = <double>[92, 128, 110, 104, 120];
                return _SkeletonBox(
                  width: widths[index],
                  height: 42,
                  radius: 20,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BookingListSkeleton extends StatelessWidget {
  const BookingListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: 6,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: _SkeletonBookingTile(),
          );
        },
      ),
    );
  }
}

class ServicesListSkeleton extends StatelessWidget {
  const ServicesListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 10,
        itemBuilder: (context, index) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: _SkeletonBox(height: 96, radius: 18),
          );
        },
      ),
    );
  }
}

class FixerListSkeleton extends StatelessWidget {
  const FixerListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              _SkeletonCircle(diameter: 56),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(height: 16),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 120, height: 14),
                  ],
                ),
              ),
              SizedBox(width: 12),
              _SkeletonBox(width: 36, height: 36, radius: 12),
            ],
          );
        },
      ),
    );
  }
}

class CategoriesSkeleton extends StatelessWidget {
  const CategoriesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 10,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return const _SkeletonBox(height: 64, radius: 18);
        },
      ),
    );
  }
}

class _SkeletonBookingTile extends StatelessWidget {
  const _SkeletonBookingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        children: const [
          _SkeletonCircle(diameter: 48),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(height: 16),
                SizedBox(height: 8),
                _SkeletonBox(width: 160, height: 14),
                SizedBox(height: 6),
                _SkeletonBox(width: 100, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonBox(width: 60, height: 28, radius: 12),
        ],
      ),
    );
  }
}

class _SectionHeaderSkeleton extends StatelessWidget {
  const _SectionHeaderSkeleton({required this.titleWidth});

  final double titleWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SkeletonBox(width: titleWidth, height: 18),
        const Spacer(),
        const _SkeletonBox(width: 80, height: 14),
      ],
    );
  }
}

class _ShimmerWrapper extends StatelessWidget {
  const _ShimmerWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? const Color(0xFF2D2D30)
        : const Color(0xFFE3E6EC);
    final highlightColor = isDark
        ? const Color(0xFF3C3C40)
        : const Color(0xFFF2F4F8);
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        color: Colors.white,
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(diameter / 2),
      child: Container(width: diameter, height: diameter, color: Colors.white),
    );
  }
}
