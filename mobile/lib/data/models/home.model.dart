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
  final String? inviteCode;
  final List<HomeMemberModel> members;
  final DateTime createdAt;

  const HomeModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.inviteCode,
    this.members = const [],
    required this.createdAt,
  });

  factory HomeModel.fromJson(Map<String, dynamic> json) {
    return HomeModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
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
        'invite_code': inviteCode,
        'members': members.map((m) => m.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };

  HomeModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? inviteCode,
    List<HomeMemberModel>? members,
    DateTime? createdAt,
  }) =>
      HomeModel(
        id: id ?? this.id,
        name: name ?? this.name,
        ownerId: ownerId ?? this.ownerId,
        inviteCode: inviteCode ?? this.inviteCode,
        members: members ?? this.members,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [id, name, ownerId, inviteCode, members, createdAt];
}
