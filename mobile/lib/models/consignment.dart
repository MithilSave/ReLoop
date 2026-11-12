class Consignment {
  final String id;
  final String consignmentCode;
  final String collectorOrgId;
  final String collectorName;
  final String destinationRecyclerId;
  final String destinationRecyclerName;
  final String vehicleNo;
  final List<String> batchIds;
  final String status; // CREATED, IN_TRANSIT, ARRIVED, RECEIVED
  final DateTime createdAt;

  const Consignment({
    required this.id,
    required this.consignmentCode,
    required this.collectorOrgId,
    required this.collectorName,
    required this.destinationRecyclerId,
    required this.destinationRecyclerName,
    required this.vehicleNo,
    required this.batchIds,
    required this.status,
    required this.createdAt,
  });

  Consignment copyWith({
    String? id,
    String? consignmentCode,
    String? collectorOrgId,
    String? collectorName,
    String? destinationRecyclerId,
    String? destinationRecyclerName,
    String? vehicleNo,
    List<String>? batchIds,
    String? status,
    DateTime? createdAt,
  }) {
    return Consignment(
      id: id ?? this.id,
      consignmentCode: consignmentCode ?? this.consignmentCode,
      collectorOrgId: collectorOrgId ?? this.collectorOrgId,
      collectorName: collectorName ?? this.collectorName,
      destinationRecyclerId: destinationRecyclerId ?? this.destinationRecyclerId,
      destinationRecyclerName: destinationRecyclerName ?? this.destinationRecyclerName,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      batchIds: batchIds ?? this.batchIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
