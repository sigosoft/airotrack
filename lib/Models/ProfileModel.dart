import 'package:airotrack/Utils/ApiHelpers.dart';

class ProfileModel {
  final String name;
  final String mobile;
  final String companyName;
  final String email;
  final String avatarInitial;

  const ProfileModel({
    this.name = '',
    this.mobile = '',
    this.companyName = '',
    this.email = '',
    this.avatarInitial = 'U',
  });

  factory ProfileModel.fromJson(dynamic raw) {
    final root = asStringKeyedMap(raw) ?? {};
    // Common nests: data, data.user, data.profile, data.details
    Map<String, dynamic> map = root;
    for (final key in ['user', 'profile', 'details', 'data']) {
      final nested = asStringKeyedMap(root[key]);
      if (nested != null) {
        map = {...map, ...nested};
      }
    }

    final name = pickString(map, [
      'name',
      'full_name',
      'username',
      'user_name',
    ]);
    final mobile = pickString(map, [
      'mobile',
      'phone',
      'phone_number',
      'mobile_number',
    ]);
    final company = pickString(map, [
      'company_name',
      'company',
      'organisation',
      'organization',
    ]);
    final email = pickString(map, ['email', 'email_address']);

    final initial = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : (mobile.trim().isNotEmpty ? mobile.trim()[0] : 'U');

    return ProfileModel(
      name: name,
      mobile: mobile,
      companyName: company,
      email: email,
      avatarInitial: initial,
    );
  }
}
