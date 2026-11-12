class CostBreakdownItem {
  final String optionName;
  final String type;
  final double purchaseCost;
  final double collectionCost;
  final double transportCost;
  final double sortingCost;
  final double storageCost;
  final double rejectionCost;
  final double totalCost;
  final double usableKg;
  final double costPerUsableKg;

  const CostBreakdownItem({
    required this.optionName,
    required this.type,
    required this.purchaseCost,
    required this.collectionCost,
    required this.transportCost,
    required this.sortingCost,
    required this.storageCost,
    required this.rejectionCost,
    required this.totalCost,
    required this.usableKg,
    required this.costPerUsableKg,
  });
}
