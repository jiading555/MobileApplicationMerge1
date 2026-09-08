class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatarUrl,
    this.isDemo = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatarUrl;
  final bool isDemo;

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    bool clearAvatar = false,
    bool? isDemo,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: clearAvatar ? null : avatarUrl ?? this.avatarUrl,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}
