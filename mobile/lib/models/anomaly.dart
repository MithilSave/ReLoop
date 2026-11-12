class AnomalyFlag {
  final String id;
  final String code;
  final String severity; // LOW, MEDIUM, HIGH, CRITICAL
  final String title;
  final String description;
  final String? batchCode;
  final String? orgName;
  final String status; // OPEN, RESOLVED
  final DateTime createdAt;

  const AnomalyFlag({
    required this.id,
    required this.code,
    required this.severity,
    required this.title,
    required this.description,
    this.batchCode,
    this.orgName,
    required this.status,
    required this.createdAt,
  });

  AnomalyFlag copyWith({
    String? id,
    String? code,
    String? severity,
    String? title,
    String? description,
    String? batchCode,
    String? orgName,
    String? status,
    DateTime? createdAt,
  }) {
    return AnomalyFlag(
      id: id ?? this.id,
      code: code ?? this.code,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      batchCode: batchCode ?? this.batchCode,
      orgName: orgName ?? this.orgName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
