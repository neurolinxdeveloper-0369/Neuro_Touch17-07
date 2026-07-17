import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String? email;
  final String? phone;
  final String name;
  final String? profilePictureUrl;
  final String? oauthProvider;
  final bool mfaEnabled;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    this.email,
    this.phone,
    required this.name,
    this.profilePictureUrl,
    this.oauthProvider,
    this.mfaEnabled = false,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      name: json['name'] as String? ?? '',
      profilePictureUrl: json['profile_pic'] as String?,
      oauthProvider: json['auth_provider'] as String?,
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'phone': phone,
        'name': name,
        'profile_pic': profilePictureUrl,
        'auth_provider': oauthProvider,
        'mfa_enabled': mfaEnabled,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? name,
    String? profilePictureUrl,
    String? oauthProvider,
    bool? mfaEnabled,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      oauthProvider: oauthProvider ?? this.oauthProvider,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Returns display-friendly contact string
  String get contactDisplay => email ?? phone ?? 'Unknown';

  @override
  List<Object?> get props => [
        id, email, phone, name, profilePictureUrl, oauthProvider, mfaEnabled, createdAt
      ];
}
