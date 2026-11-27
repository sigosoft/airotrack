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
    final company = _companyName(map);
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

  /// The company's name. The server can send `company` as a whole record
  /// ({id, user_id, company_name, …}); read the name from inside it rather
  /// than showing the record as text.
  static String _companyName(Map<String, dynamic> map) {
    const nameKeys = ['company_name', 'name', 'organisation', 'organization'];
    for (final key in ['company_name', 'company', 'organisation', 'organization']) {
      final value = map[key];
      if (value == null) continue;
      final nested = asStringKeyedMap(value);
      final text = nested != null
          ? pickString(nested, nameKeys)
          : (value is List ? '' : value.toString().trim());
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }
}
