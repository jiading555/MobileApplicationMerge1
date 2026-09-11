import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../models/property.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/scheme_normalizer.dart';
import 'property_art.dart';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    required this.property,
    required this.onTap,
    this.compact = false,
    this.showPropertyInfo = false,
    this.showDetailsAction = false,
    super.key,
  });

  final Property property;
  final VoidCallback onTap;
  final bool compact;
  final bool showPropertyInfo;
  final bool showDetailsAction;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: compact
            ? _CompactContent(
                property: property,
                onTap: onTap,
                favouriteIdsListenable: state.favouriteIdsListenable,
                favouriteOperationIdsListenable:
                    state.favouriteOperationIdsListenable,
                onToggleFavourite: state.toggleFavourite,
                showPropertyInfo: showPropertyInfo,
                showDetailsAction: showDetailsAction,
              )
            : _FullContent(
                property: property,
                onTap: onTap,
                favouriteIdsListenable: state.favouriteIdsListenable,
                favouriteOperationIdsListenable:
                    state.favouriteOperationIdsListenable,
                onToggleFavourite: state.toggleFavourite,
                showPropertyInfo: showPropertyInfo,
                showDetailsAction: showDetailsAction,
              ),
      ),
    );
  }
}

class _FullContent extends StatelessWidget {
  const _FullContent({
    required this.property,
    required this.onTap,
    required this.favouriteIdsListenable,
    required this.favouriteOperationIdsListenable,
    required this.onToggleFavourite,
    required this.showPropertyInfo,
    required this.showDetailsAction,
  });

  final Property property;
  final VoidCallback onTap;
  final ValueListenable<Set<String>> favouriteIdsListenable;
  final ValueListenable<Set<String>> favouriteOperationIdsListenable;
  final Future<String?> Function(String) onToggleFavourite;
  final bool showPropertyInfo;
  final bool showDetailsAction;

  @override
  Widget build(BuildContext context) {
    final enriched = showPropertyInfo || showDetailsAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            PropertyArt(
              palette: property.palette,
              height: enriched ? 112 : 164,
            ),
            Positioned(
              top: enriched ? 10 : 12,
              left: enriched ? 10 : 12,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: enriched ? 9 : 10,
                  vertical: enriched ? 5 : 6,
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
              top: enriched ? 6 : 8,
              right: enriched ? 6 : 8,
              child: _FavouriteButton(
                propertyId: property.id,
                favouriteIdsListenable: favouriteIdsListenable,
                favouriteOperationIdsListenable:
                    favouriteOperationIdsListenable,
                onToggleFavourite: onToggleFavourite,
                filled: true,
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.all(enriched ? 11 : 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: enriched ? 2 : 3),
              Text(
                property.address,
                maxLines: enriched ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
              SizedBox(height: enriched ? 6 : 12),
              Text(
                _priceText(property),
                style: TextStyle(
                  color: AppTheme.green,
                  fontSize: enriched ? 16 : 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: enriched ? 6 : 10),
              _Facts(property: property),
              if (showPropertyInfo) ...[
                const SizedBox(height: 6),
                _PropertyInfo(property: property),
              ],
              if (showDetailsAction) ...[
                const SizedBox(height: 7),
                _DetailsAction(onTap: onTap),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactContent extends StatelessWidget {
  const _CompactContent({
    required this.property,
    required this.onTap,
    required this.favouriteIdsListenable,
    required this.favouriteOperationIdsListenable,
    required this.onToggleFavourite,
    required this.showPropertyInfo,
    required this.showDetailsAction,
  });

  final Property property;
  final VoidCallback onTap;
  final ValueListenable<Set<String>> favouriteIdsListenable;
  final ValueListenable<Set<String>> favouriteOperationIdsListenable;
  final Future<String?> Function(String) onToggleFavourite;
  final bool showPropertyInfo;
  final bool showDetailsAction;

  @override
  Widget build(BuildContext context) {
    final enriched = showPropertyInfo || showDetailsAction;
    return Padding(
      padding: EdgeInsets.all(enriched ? 8 : 10),
      child: Row(
        crossAxisAlignment: enriched
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: enriched ? 104 : 112,
            child: PropertyArt(
              palette: property.palette,
              height: enriched ? 104 : 112,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          SizedBox(width: enriched ? 12 : 14),
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
                SizedBox(height: enriched ? 2 : 3),
                Text(
                  property.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                SizedBox(height: enriched ? 6 : 8),
                Text(
                  _priceText(property),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: enriched ? 6 : 7),
                _Facts(property: property, compact: true),
                if (showPropertyInfo) ...[
                  const SizedBox(height: 6),
                  _PropertyInfo(property: property, compact: true),
                ],
                if (showDetailsAction) ...[
                  const SizedBox(height: 7),
                  _DetailsAction(onTap: onTap, compact: true),
                ],
              ],
            ),
          ),
          SizedBox.square(
            dimension: enriched ? 44 : 48,
            child: _FavouriteButton(
              propertyId: property.id,
              favouriteIdsListenable: favouriteIdsListenable,
              favouriteOperationIdsListenable: favouriteOperationIdsListenable,
              onToggleFavourite: onToggleFavourite,
            ),
          ),
        ],
      ),
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton({
    required this.propertyId,
    required this.favouriteIdsListenable,
    required this.favouriteOperationIdsListenable,
    required this.onToggleFavourite,
    this.filled = false,
  });

  final String propertyId;
  final ValueListenable<Set<String>> favouriteIdsListenable;
  final ValueListenable<Set<String>> favouriteOperationIdsListenable;
  final Future<String?> Function(String) onToggleFavourite;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: favouriteIdsListenable,
      builder: (context, favouriteIds, _) {
        final isFavourite = favouriteIds.contains(propertyId);
        return ValueListenableBuilder<Set<String>>(
          valueListenable: favouriteOperationIdsListenable,
          builder: (context, operationIds, _) {
            final isBusy = operationIds.contains(propertyId);
            final icon = isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isFavourite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavourite
                        ? const Color(0xFFE54865)
                        : filled
                        ? AppTheme.ink
                        : AppTheme.muted,
                  );
            final onPressed = isBusy
                ? null
                : () async {
                    final error = await onToggleFavourite(propertyId);
                    if (error == null || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: const Color(0xFFB42318),
                      ),
                    );
                  };
            if (filled) {
              return IconButton.filledTonal(
                onPressed: onPressed,
                tooltip: isFavourite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                icon: icon,
              );
            }
            return IconButton(
              onPressed: onPressed,
              tooltip: isFavourite
                  ? 'Remove from favourites'
                  : 'Add to favourites',
              icon: icon,
            );
          },
        );
      },
    );
  }
}

class _PropertyInfo extends StatelessWidget {
  const _PropertyInfo({required this.property, this.compact = false});

  final Property property;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final source = _sourceLabel(property);
    final entries = [
      if (_propertyTypeLabel(property) case final type?)
        _InfoEntry(icon: Icons.home_work_outlined, label: type),
      if (_programmeLabel(property) case final programme?)
        _InfoEntry(
          icon: Icons.account_balance_outlined,
          label: 'Programme: $programme',
        ),
      if (_shouldShowSourceInfo(property) && source != null)
        _InfoEntry(icon: Icons.dataset_outlined, label: source),
    ];

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: compact ? 8 : 10,
      runSpacing: 4,
      children: entries
          .map((entry) => _InfoLine(entry: entry, compact: compact))
          .toList(),
    );
  }
}

class _InfoEntry {
  const _InfoEntry({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.entry, required this.compact});

  final _InfoEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(entry.icon, size: compact ? 14 : 15, color: AppTheme.muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? 104 : 178),
          child: Text(
            entry.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: AppTheme.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailsAction extends StatelessWidget {
  const _DetailsAction({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? null : double.infinity,
      height: compact ? 40 : 38,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        label: const Text('View Details'),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.property, this.compact = false});

  final Property property;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: compact ? 8 : 9,
      runSpacing: 4,
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
            maxWidth: compact ? 120 : null,
          ),
      ],
    );
  }
}

String? _propertyTypeLabel(Property property) {
  final candidates = [
    property.verifiedPropertyType,
    ...property.unitOptions.map((option) => option.unitType),
    ...property.unitTypes,
    property.type,
  ];
  for (final candidate in candidates) {
    final text = _cleanOptionalText(candidate);
    if (text == null) {
      continue;
    }
    final normalized = text.toLowerCase();
    if (property.isGovernmentRecord &&
        (normalized == 'public housing' || normalized == 'public')) {
      continue;
    }
    return _displayText(text);
  }
  return null;
}

String? _programmeLabel(Property property) {
  final scheme = _cleanOptionalText(property.scheme);
  if (scheme == null) {
    return null;
  }
  final normalized = SchemeNormalizer.normalize(scheme);
  return normalized.isEmpty ? null : normalized;
}

String? _sourceLabel(Property property) {
  return property.isGovernmentRecord ? 'TEDUH / KPKT' : null;
}

bool _shouldShowSourceInfo(Property property) {
  return _sourceLabel(property) != null &&
      (property.bedrooms != null ||
          property.bathrooms != null ||
          property.sizeSqft != null);
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

String? _cleanOptionalText(String? value) {
  final text = value?.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text == null || text.isEmpty) {
    return null;
  }
  final normalized = text.toLowerCase();
  if (normalized == 'n/a' ||
      normalized == 'na' ||
      normalized == 'unknown' ||
      normalized == 'not available' ||
      normalized == 'not applicable' ||
      normalized == 'property type not available') {
    return null;
  }
  return text;
}

String _displayText(String value) {
  if (value.contains(RegExp(r'[a-z]'))) {
    return value;
  }
  return value
      .split(' ')
      .map((word) => word.length <= 3 ? word : _titleCaseWord(word))
      .join(' ');
}

String _titleCaseWord(String word) {
  if (word.isEmpty) {
    return word;
  }
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, this.maxWidth});

  final IconData icon;
  final String label;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final fact = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ),
      ],
    );
    if (maxWidth == null) {
      return fact;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: fact,
    );
  }
}
