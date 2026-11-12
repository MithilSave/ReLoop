enum UserRole {
  generator,
  collector,
  recycler,
  ngo,
  eprBody,
  admin,
}

class DemoPersona {
  final String id;
  final String name;
  final UserRole role;
  final String orgId;
  final String orgName;
  final String orgTypeLabel;
  final String email;
  final String avatar;
  final String description;

  const DemoPersona({
    required this.id,
    required this.name,
    required this.role,
    required this.orgId,
    required this.orgName,
    required this.orgTypeLabel,
    required this.email,
    required this.avatar,
    required this.description,
  });
}
