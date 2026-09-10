import '../data/repositories/area_profile_repository.dart';
import '../data/repositories/property_repository.dart';
import '../models/area_profile.dart';
import '../models/property.dart';
import 'open_data_service.dart';
import 'teduh_service.dart';

class GovernmentSyncService {
  GovernmentSyncService({
    OpenDataService? openDataService,
    TeduhService? teduhService,
    AreaProfileRepository areaProfileRepository = const AreaProfileRepository(),
    PropertyRepository propertyRepository = const PropertyRepository(),
  }) : this._(
         openDataService ?? OpenDataService(),
         teduhService ?? TeduhService(),
         areaProfileRepository,
         propertyRepository,
       );

  GovernmentSyncService._(
    this._openDataService,
    this._teduhService,
    this._areaProfileRepository,
    this._propertyRepository,
  );

  final OpenDataService _openDataService;
  final TeduhService _teduhService;
  final AreaProfileRepository _areaProfileRepository;
  final PropertyRepository _propertyRepository;

  static const sharedTables = ['area_profiles', 'properties'];

  Future<GovernmentSyncResult> sync() async {
    final areaProfiles = AreaProfileRepository.mergeProfileData(
      await _openDataService.fetchAreaProfiles(),
    ).values.toList();
    final upsertedAreaProfiles = await _areaProfileRepository
        .upsertAreaProfiles(areaProfiles);

    final teduhProjects = await _teduhService.fetchProjects();
    final upsertedTeduhProjects = await _propertyRepository.upsertProperties(
      teduhProjects,
    );

    return GovernmentSyncResult(
      areaProfiles: areaProfiles,
      upsertedAreaProfiles: upsertedAreaProfiles,
      teduhProjects: teduhProjects,
      upsertedTeduhProjects: upsertedTeduhProjects,
      syncedAt: DateTime.now().toUtc(),
    );
  }
}

class GovernmentSyncResult {
  const GovernmentSyncResult({
    required this.areaProfiles,
    required this.upsertedAreaProfiles,
    required this.teduhProjects,
    required this.upsertedTeduhProjects,
    required this.syncedAt,
  });

  final List<AreaProfile> areaProfiles;
  final int upsertedAreaProfiles;
  final List<Property> teduhProjects;
  final int upsertedTeduhProjects;
  final DateTime syncedAt;
}
