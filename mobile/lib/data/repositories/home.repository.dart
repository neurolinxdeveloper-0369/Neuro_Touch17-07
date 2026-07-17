import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/home.model.dart';
import '../models/floor.model.dart';
import '../models/room.model.dart';
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

  Future<HomeModel> createHome(String name) async {
    final resp = await _api.post(ApiConstants.homes, data: {'name': name});
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

  Future<HomeModel> updateHome(String homeId, String name) async {
    final resp = await _api.put(ApiConstants.homeById(homeId), data: {'name': name});
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

  // --- Floors ---

  Future<List<FloorModel>> getFloors(String homeId) async {
    final resp = await _api.get(ApiConstants.homeFloors(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['floors'] as List<dynamic>)
        .map((f) => FloorModel.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  Future<FloorModel> createFloor(String homeId, String name) async {
    final resp = await _api.post(
      ApiConstants.homeFloors(homeId),
      data: {'name': name},
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return FloorModel.fromJson(data['floor'] as Map<String, dynamic>);
  }

  Future<FloorModel> updateFloor(
      String homeId, String floorId, String name) async {
    final resp = await _api.put(
      ApiConstants.floor(homeId, floorId),
      data: {'name': name},
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return FloorModel.fromJson(data['floor'] as Map<String, dynamic>);
  }

  Future<void> deleteFloor(String homeId, String floorId) async {
    final resp = await _api.delete(ApiConstants.floor(homeId, floorId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }

  // --- Rooms ---

  Future<List<RoomModel>> getRooms(String homeId) async {
    final resp = await _api.get(ApiConstants.homeRooms(homeId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return (data['rooms'] as List<dynamic>)
        .map((r) => RoomModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<RoomModel> createRoom(
    String homeId, {
    required String floorId,
    required String name,
    String icon = 'room',
  }) async {
    final resp = await _api.post(
      ApiConstants.homeRooms(homeId),
      data: {'floor_id': floorId, 'name': name, 'icon': icon},
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return RoomModel.fromJson(data['room'] as Map<String, dynamic>);
  }

  Future<RoomModel> updateRoom(
    String homeId,
    String roomId, {
    String? name,
    String? icon,
  }) async {
    final resp = await _api.put(
      ApiConstants.room(homeId, roomId),
      data: {
        if (name != null) 'name': name,
        if (icon != null) 'icon': icon,
      },
    );
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
    return RoomModel.fromJson(data['room'] as Map<String, dynamic>);
  }

  Future<void> deleteRoom(String homeId, String roomId) async {
    final resp = await _api.delete(ApiConstants.room(homeId, roomId));
    final data = resp.data as Map<String, dynamic>;
    if (data['success'] != true) throw Exception(data['error']);
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(
    api: ref.read(apiClientProvider),
  );
});

