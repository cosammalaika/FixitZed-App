import 'package:flutter/material.dart';
import 'package:fixitzed_app/core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

enum ServiceAvailability { available, unavailable, unknown }

class ServiceListTile extends StatelessWidget {
  const ServiceListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.leadingImage,
    this.onTap,
    this.favorite = false,
    this.onFavoriteTap,
    this.availability = ServiceAvailability.unknown,
    this.showFavorite = true,
  });

  final String title;
  final String subtitle;
  final String? leadingImage;
  final VoidCallback? onTap;
  final bool favorite;
  final VoidCallback? onFavoriteTap;
  final ServiceAvailability availability;
  final bool showFavorite;

  Color _pillColor(BuildContext context) {
    final colors = Theme.of(context).fx;
    switch (availability) {
      case ServiceAvailability.available:
        return colors.successContainer;
      case ServiceAvailability.unavailable:
        return colors.warningContainer;
      case ServiceAvailability.unknown:
      default:
        return colors.surfaceTint;
    }
  }

  Color _pillTextColor(BuildContext context) {
    final colors = Theme.of(context).fx;
    switch (availability) {
      case ServiceAvailability.available:
        return colors.success;
      case ServiceAvailability.unavailable:
        return colors.warning;
      case ServiceAvailability.unknown:
      default:
        return colors.textMuted;
    }
  }

  String _pillLabel() {
    switch (availability) {
      case ServiceAvailability.available:
        return 'Fixers available';
      case ServiceAvailability.unavailable:
        return 'No fixers yet';
      case ServiceAvailability.unknown:
      default:
        return 'Availability unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).fx;
    return Material(
      color: colors.surface,
      elevation: 0,
      shadowColor: colors.shadow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: leadingImage != null && leadingImage!.isNotEmpty
                    ? ClipOval(
                        child: Image(
                          image: leadingImage!.startsWith('http')
                              ? NetworkImage(leadingImage!) as ImageProvider
                              : AssetImage(leadingImage!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.handyman_rounded, color: colors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.urbanist(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _pillColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _pillLabel(),
                        style: GoogleFonts.urbanist(
                          color: _pillTextColor(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (showFavorite)
                IconButton(
                  icon: Icon(
                    favorite ? Icons.favorite : Icons.favorite_border,
                    color: favorite ? colors.danger : colors.textMuted,
                  ),
                  onPressed: onFavoriteTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
