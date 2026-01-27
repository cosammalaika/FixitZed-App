import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ServiceAvailability {
  available,
  unavailable,
  unknown,
}

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
    switch (availability) {
      case ServiceAvailability.available:
        return Colors.green.withOpacity(0.12);
      case ServiceAvailability.unavailable:
        return Colors.orange.withOpacity(0.12);
      case ServiceAvailability.unknown:
      default:
        return Theme.of(context).colorScheme.primary.withOpacity(0.08);
    }
  }

  Color _pillTextColor(BuildContext context) {
    switch (availability) {
      case ServiceAvailability.available:
        return Colors.green.shade800;
      case ServiceAvailability.unavailable:
        return Colors.orange.shade800;
      case ServiceAvailability.unknown:
      default:
        return Theme.of(context).hintColor;
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
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.03),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.black.withOpacity(0.04),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0x1AF1592A),
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
                    : const Icon(Icons.handyman_rounded,
                        color: Color(0xFFF1592A)),
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
                      style: GoogleFonts.urbanist(color: Colors.black54),
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
                    color: favorite ? Colors.red : Colors.grey,
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
