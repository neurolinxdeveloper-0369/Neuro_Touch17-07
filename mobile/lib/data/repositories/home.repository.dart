import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home.model.dart';
import '../services/api_client.dart';
import '../../core/constants/api_constants.dart';

class HomeRepository {
  final ApiClient _api;

  HomeRepository({required ApiClient api}) : _api = api;

  // --- Homes ---

  Future<List<HomeModel>> getHomes() async {
    final resp = await _api.get(ApiConstants.homes);
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['homes'] as List<dynamic>)
        .map((h) => HomeModel.fromJson(h as Map<String, dynamic>))
        .toList();
  }

  Future<HomeModel> createHome({
    required String name,
    required String homeType,
    int floorCount = 0,
    String? networkSsid,
    String? networkPassword,
  }) async {
    final resp = await _api.post(ApiConstants.homes, data: {
      'name': name,
      'home_type': homeType,
      'floor_count': floorCount,
      if (networkSsid != null) 'network_ssid': networkSsid,
      if (networkPassword != null) 'network_password': networkPassword,
    });
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return HomeModel.fromJson(data['home'] as Map<String, dynamic>);
  }

  Future<HomeModel> getHome(String homeId) async {
    final resp = await _api.get(ApiConstants.homeById(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return HomeModel.fromJson(data['home'] as Map<String, dynamic>);
  }

  Future<HomeModel> updateHome(
    String homeId, {
    String? name,
    String? networkSsid,
    String? networkPassword,
  }) async {
    final resp = await _api.put(ApiConstants.homeById(homeId), data: {
      if (name != null) 'name': name,
      if (networkSsid != null) 'network_ssid': networkSsid,
      if (networkPassword != null) 'network_password': networkPassword,
    });
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return HomeModel.fromJson(data['home'] as Map<String, dynamic>);
  }

  Future<void> deleteHome(String homeId) async {
    final resp = await _api.delete(ApiConstants.homeById(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }

  // --- Invite ---

  Future<String> generateInviteCode(String homeId) async {
    final resp = await _api.post(ApiConstants.homeInvite(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return data['invite_code'] as String;
  }

  Future<HomeModel> joinHome(String code) async {
    final resp = await _api.post(ApiConstants.joinHome, data: {'code': code});
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return HomeModel.fromJson(data['home'] as Map<String, dynamic>);
  }

  // --- Members ---

  Future<List<HomeMemberModel>> getMembers(String homeId) async {
    final resp = await _api.get(ApiConstants.homeMembers(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['members'] as List<dynamic>)
        .map((m) => HomeMemberModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<HomeMemberModel> updateMemberPermission(
    String homeId,
    String userId,
    String level,
  ) async {
    final resp = await _api.put(
      ApiConstants.homeMember(homeId, userId),
      data: {'permission_level': level},
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return HomeMemberModel.fromJson(data['member'] as Map<String, dynamic>);
  }

  Future<void> removeMember(String homeId, String userId) async {
    final resp = await _api.delete(ApiConstants.homeMember(homeId, userId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(
    api: ref.read(apiClientProvider),
  );
});
