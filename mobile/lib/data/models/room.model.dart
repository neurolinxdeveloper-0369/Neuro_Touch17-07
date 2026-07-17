import 'package:equatable/equatable.dart';

class RoomModel extends Equatable {
  final String id;
  final String floorId;
  final String homeId;
  final String name;
  final String icon;
  final int orderIndex;

  const RoomModel({
    required this.id,
    required this.floorId,
    required this.homeId,
    required this.name,
    this.icon = 'room',
    this.orderIndex = 0,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
        id: json['id'] as String,
        floorId: json['floor_id'] as String? ?? '',
        homeId: json['home_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? 'room',
        orderIndex: json['order_index'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'floor_id': floorId,
        'home_id': homeId,
        'name': name,
        'icon': icon,
        'order_index': orderIndex,
      };

  RoomModel copyWith({
    String? id,
    String? floorId,
    String? homeId,
    String? name,
    String? icon,
    int? orderIndex,
  }) =>
      RoomModel(
        id: id ?? this.id,
        floorId: floorId ?? this.floorId,
        homeId: homeId ?? this.homeId,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        orderIndex: orderIndex ?? this.orderIndex,
      );

  @override
  List<Object?> get props => [id, floorId, homeId, name, icon, orderIndex];
}
