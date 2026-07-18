import 'package:equatable/equatable.dart';

class HomeMemberModel extends Equatable {
  final String userId;
  final String name;
  final String? email;
  final String? profilePictureUrl;
  final String permissionLevel; // 'full_access' | 'view_control'
  final DateTime joinedAt;

  const HomeMemberModel({
    required this.userId,
    required this.name,
    this.email,
    this.profilePictureUrl,
    required this.permissionLevel,
    required this.joinedAt,
  });

  factory HomeMemberModel.fromJson(Map<String, dynamic> json) {
    // Support nested user object
    final user = json['user'] as Map<String, dynamic>?;
    return HomeMemberModel(
      userId: (json['user_id'] ?? json['userId'] ?? user?['id'] ?? '') as String,
      name: (user?['name'] ?? json['name'] ?? '') as String,
      email: (user?['email'] ?? json['email']) as String?,
      profilePictureUrl:
          (user?['profile_picture_url'] ?? json['profile_picture_url']) as String?,
      permissionLevel:
          (json['permission_level'] ?? 'view_control') as String,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'email': email,
        'profile_picture_url': profilePictureUrl,
        'permission_level': permissionLevel,
        'joined_at': joinedAt.toIso8601String(),
      };

  HomeMemberModel copyWith({
    String? userId,
    String? name,
    String? email,
    String? profilePictureUrl,
    String? permissionLevel,
    DateTime? joinedAt,
  }) =>
      HomeMemberModel(
        userId: userId ?? this.userId,
        name: name ?? this.name,
        email: email ?? this.email,
        profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
        permissionLevel: permissionLevel ?? this.permissionLevel,
        joinedAt: joinedAt ?? this.joinedAt,
      );

  bool get isFullAccess => permissionLevel == 'full_access';

  @override
  List<Object?> get props =>
      [userId, name, email, profilePictureUrl, permissionLevel, joinedAt];
}

class HomeModel extends Equatable {
  final String id;
  final String name;
  final String ownerId;
  final String homeType;     // flat | villa | building | office
  final int floorCount;      // 0 for flat, user-entered for others
  final String? networkSsid;
  final String? networkPassword;
  final String? inviteCode;
  final List<HomeMemberModel> members;
  final DateTime createdAt;

  const HomeModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.homeType = 'flat',
    this.floorCount = 0,
    this.networkSsid,
    this.networkPassword,
    this.inviteCode,
    this.members = const [],
    required this.createdAt,
  });

  factory HomeModel.fromJson(Map<String, dynamic> json) {
    return HomeModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      homeType: json['home_type'] as String? ?? 'flat',
      floorCount: json['floor_count'] as int? ?? 0,
      networkSsid: json['network_ssid'] as String?,
      networkPassword: json['network_password'] as String?,
      inviteCode: json['invite_code'] as String?,
      members: (json['members'] as List<dynamic>? ?? [])
          .map((m) => HomeMemberModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner_id': ownerId,
        'home_type': homeType,
        'floor_count': floorCount,
        'network_ssid': networkSsid,
        'network_password': networkPassword,
        'invite_code': inviteCode,
        'members': members.map((m) => m.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  HomeModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? homeType,
    int? floorCount,
    String? networkSsid,
    String? networkPassword,
    String? inviteCode,
    List<HomeMemberModel>? members,
    DateTime? createdAt,
  }) =>
      HomeModel(
        id: id ?? this.id,
        name: name ?? this.name,
        ownerId: ownerId ?? this.ownerId,
        homeType: homeType ?? this.homeType,
        floorCount: floorCount ?? this.floorCount,
        networkSsid: networkSsid ?? this.networkSsid,
        networkPassword: networkPassword ?? this.networkPassword,
        inviteCode: inviteCode ?? this.inviteCode,
        members: members ?? this.members,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Display label for home type
  String get homeTypeLabel {
    switch (homeType) {
      case 'villa': return 'Villa';
      case 'building': return 'Building';
      case 'office': return 'Office';
      case 'flat':
      default: return 'Flat';
    }
  }

  /// Whether this home type supports multiple floors
  bool get hasFloors => homeType != 'flat';

  @override
  List<Object?> get props =>
      [id, name, ownerId, homeType, floorCount, networkSsid, inviteCode, members, createdAt];
}
