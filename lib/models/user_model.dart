enum UserRole { AE, PTL, ADMIN }

UserRole roleFromString(String? s) {
  switch ((s ?? '').toUpperCase()) {
    case 'PTL':
      return UserRole.PTL;
    case 'ADMIN':
      return UserRole.ADMIN;
    case 'AE':
    default:
      return UserRole.AE;
  }
}

String roleToString(UserRole r) {
  switch (r) {
    case UserRole.PTL:
      return 'PTL';
    case UserRole.ADMIN:
      return 'ADMIN';
    case UserRole.AE:
    default:
      return 'AE';
  }
}

class AppUser {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final UserRole role;
  final String? rslId;
  final DateTime? createdAt;
  final DateTime? lastLogin;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.role,
    this.name,
    this.email,
    this.phone,
    this.rslId,
    this.createdAt,
    this.lastLogin,
    this.isActive = true,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) {
    DateTime? dt(String? v) => (v == null) ? null : DateTime.tryParse(v);
    return AppUser(
      id: m['id'] as String,
      name: m['name'] as String?,
      email: m['email'] as String?,
      phone: m['phone'] as String?,
      role: roleFromString(m['role'] as String?),
      rslId: m['rsl_id'] as String?,
      createdAt: dt(m['created_at'] as String?),
      lastLogin: dt(m['last_login'] as String?),
      isActive: (m['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': roleToString(role),
    'rsl_id': rslId,
    'created_at': createdAt?.toIso8601String(),
    'last_login': lastLogin?.toIso8601String(),
    'is_active': isActive,
  };

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? rslId,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      rslId: rslId ?? this.rslId,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
    );
  }

  bool get isPTL => role == UserRole.PTL || role == UserRole.ADMIN;
}
