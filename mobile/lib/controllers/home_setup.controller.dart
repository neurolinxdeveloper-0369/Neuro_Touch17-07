import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/home.model.dart';
import '../data/repositories/home.repository.dart';
import '../data/services/storage_service.dart';

enum HomeSetupStatus { idle, loading, success, error }

class HomeSetupState {
  final HomeSetupStatus status;
  final HomeModel? createdHome;
  final String? error;

  const HomeSetupState({
    this.status = HomeSetupStatus.idle,
    this.createdHome,
    this.error,
  });

  HomeSetupState copyWith({
    HomeSetupStatus? status,
    HomeModel? createdHome,
    String? error,
    bool clearError = false,
  }) =>
      HomeSetupState(
        status: status ?? this.status,
        createdHome: createdHome ?? this.createdHome,
        error: clearError ? null : error ?? this.error,
      );

  bool get isLoading => status == HomeSetupStatus.loading;
  bool get isSuccess => status == HomeSetupStatus.success;
}

class HomeSetupController extends StateNotifier<HomeSetupState> {
  final HomeRepository _repo;
  final StorageService _storage;

  HomeSetupController({
    required HomeRepository repo,
    required StorageService storage,
  })  : _repo = repo,
        _storage = storage,
        super(const HomeSetupState());

  Future<void> createHome({
    required String name,
    required String homeType,
    int floorCount = 0,
    String? networkSsid,
    String? networkPassword,
  }) async {
    state = state.copyWith(status: HomeSetupStatus.loading, clearError: true);
    try {
      final home = await _repo.createHome(
        name: name,
        homeType: homeType,
        floorCount: floorCount,
        networkSsid: networkSsid?.isNotEmpty == true ? networkSsid : null,
        networkPassword: networkPassword?.isNotEmpty == true ? networkPassword : null,
      );
      // Persist the new home ID locally
      await _storage.saveHomeId(home.id);
      state = state.copyWith(
        status: HomeSetupStatus.success,
        createdHome: home,
      );
    } catch (e) {
      state = state.copyWith(
        status: HomeSetupStatus.error,
        error: _parseError(e),
      );
      rethrow;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains('Connection refused') || msg.contains('SocketException')) {
      return 'Cannot reach the server. Please ensure you are connected to the network.';
    }
    if (msg.contains('Exception:')) {
      return msg.replaceFirst('Exception: ', '');
    }
    return msg;
  }
}

final homeSetupControllerProvider =
    StateNotifierProvider.autoDispose<HomeSetupController, HomeSetupState>((ref) {
  return HomeSetupController(
    repo: ref.read(homeRepositoryProvider),
    storage: ref.read(storageServiceProvider),
  );
});

/// Provider that checks whether the current user has at least one home.
/// Returns null while loading, true/false when resolved.
final hasHomeProvider = FutureProvider<bool>((ref) async {
  try {
    final homes = await ref.read(homeRepositoryProvider).getHomes();
    return homes.isNotEmpty;
  } catch (_) {
    return false;
  }
});

/// Provider that fetches the list of homes for the current user.
final userHomesProvider = FutureProvider<List<HomeModel>>((ref) async {
  return ref.read(homeRepositoryProvider).getHomes();
});
