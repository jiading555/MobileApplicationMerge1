class AppUser {
  const AppUser({required this.name, required this.email, this.phone = ''});

  final String name;
  final String email;
  final String phone;

  AppUser copyWith({String? name, String? email, String? phone}) {
    return AppUser(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }
}
