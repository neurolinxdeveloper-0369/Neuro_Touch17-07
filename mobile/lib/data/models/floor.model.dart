import 'package:equatable/equatable.dart';

class FloorModel extends Equatable {
  final String id;
  final String homeId;
  final String name;
  final int orderIndex;

  const FloorModel({
    required this.id,
    required this.homeId,
    required this.name,
    this.orderIndex = 0,
  });

  factory FloorModel.fromJson(Map<String, dynamic> json) => FloorModel(
        id: json['id'] as String,
        homeId: json['home_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        orderIndex: json['order_index'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'home_id': homeId,
        'name': name,
        'order_index': orderIndex,
      };

  FloorModel copyWith({
    String? id,
    String? homeId,
    String? name,
    int? orderIndex,
  }) =>
      FloorModel(
        id: id ?? this.id,
        homeId: homeId ?? this.homeId,
        name: name ?? this.name,
        orderIndex: orderIndex ?? this.orderIndex,
      );

  @override
  List<Object?> get props => [id, homeId, name, orderIndex];
}
