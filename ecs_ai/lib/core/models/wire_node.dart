class WireNode {
  /// id of the component this node is anchored to
  final String componentId;

  /// specific pin identifier on the component
  final String pinId;

  const WireNode({required this.componentId, required this.pinId});

  factory WireNode.fromJson(Map<String, dynamic> json) => WireNode(
        componentId: json['componentId'] as String,
        pinId: json['pinId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'componentId': componentId,
        'pinId': pinId,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WireNode &&
          runtimeType == other.runtimeType &&
          componentId == other.componentId &&
          pinId == other.pinId;

  @override
  int get hashCode => componentId.hashCode ^ pinId.hashCode;

  @override
  String toString() => '$componentId:$pinId';
}
