import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../models/property.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'property_art.dart';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    required this.property,
    required this.onTap,
    this.compact = false,
    super.key,
  });

  final Property property;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: compact
            ? _CompactContent(property: property, state: state)
            : _FullContent(property: property, state: state),
      ),
    );
  }
}

class _FullContent extends StatelessWidget {
  const _FullContent({required this.property, required this.state});

  final Property property;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            PropertyArt(palette: property.palette, height: 164),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'FOR VIEWING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                onPressed: () => state.toggleFavourite(property.id),
                icon: Icon(
                  state.isFavourite(property.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: state.isFavourite(property.id)
                      ? const Color(0xFFE54865)
                      : AppTheme.ink,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                property.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Text(
                _priceText(property),
                style: const TextStyle(
                  color: AppTheme.green,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _Facts(property: property),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactContent extends StatelessWidget {
  const _CompactContent({required this.property, required this.state});

  final Property property;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: PropertyArt(
              palette: property.palette,
              height: 112,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  property.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  _priceText(property),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                _Facts(property: property),
              ],
            ),
          ),
          IconButton(
            onPressed: () => state.toggleFavourite(property.id),
            icon: Icon(
              state.isFavourite(property.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: state.isFavourite(property.id)
                  ? const Color(0xFFE54865)
                  : AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 5,
      children: [
        if (property.bedrooms != null)
          _Fact(icon: Icons.bed_rounded, label: '${property.bedrooms}'),
        if (property.bathrooms != null)
          _Fact(icon: Icons.bathtub_outlined, label: '${property.bathrooms}'),
        if (property.sizeSqft != null)
          _Fact(
            icon: Icons.square_foot_rounded,
            label: '${property.sizeSqft} sqft',
          ),
        if (property.bedrooms == null &&
            property.bathrooms == null &&
            property.sizeSqft == null)
          _Fact(
            icon: Icons.account_balance_outlined,
            label: _sourceFactLabel(property),
          ),
      ],
    );
  }
}

String _sourceFactLabel(Property property) {
  if (property.isGovernmentRecord) {
    return 'TEDUH / KPKT';
  }
  return 'Sample listing';
}

String _priceText(Property property) {
  final min = property.priceMin;
  final max = property.priceMax;
  if (min != null && max != null && min != max) {
    return '${formatRinggit(min)} - ${formatRinggit(max)}';
  }
  final price = property.price ?? min ?? max;
  return price == null ? 'Price unavailable' : formatRinggit(price);
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    );
  }
}
