import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton service that manages the tenant's default country code for phone normalisation.
///
/// BACKWARD COMPATIBILITY: Defaults to 'IN' (India +91) when no country is set,
/// ensuring zero impact on existing India-only tenants.
///
/// Usage:
///   CountryCodeService.instance.normalizeNumber('9876543210') → '919876543210' (if IN default)
///   CountryCodeService.instance.normalizeNumber('+12125550100') → '12125550100' (US number)
///   CountryCodeService.instance.defaultDialCode → '91'  (for IN)
class CountryCodeService {
  static const String _prefKey = 'tenant_default_country_iso';
  static const String _defaultIso = 'IN';

  CountryCodeService._();
  static final CountryCodeService instance = CountryCodeService._();

  String _iso = _defaultIso;

  /// Current ISO-2 country code (e.g. 'IN', 'US', 'AU')
  String get defaultIso => _iso;

  /// Dial code without '+' (e.g. '91' for IN, '1' for US, '61' for AU)
  String get defaultDialCode => _getDialCode(_iso);

  /// Country name for display (e.g. 'India', 'United States')
  String get defaultCountryName => _getCountryName(_iso);

  /// Load country from SharedPreferences on app start (after login).
  /// Also refreshes from backend if token is available.
  Future<void> loadFromPrefs(SharedPreferences prefs) async {
    final stored = prefs.getString(_prefKey);
    if (stored != null && stored.isNotEmpty) {
      _iso = stored.toUpperCase();
    }
  }

  /// Save new country locally and sync to backend.
  /// [prefs] — SharedPreferences instance
  /// [dio] — authenticated Dio instance
  Future<bool> setDefaultCountry(String iso2, SharedPreferences prefs, Dio dio) async {
    final code = iso2.trim().toUpperCase();
    if (code.isEmpty) return false;
    try {
      final response = await dio.patch(
        '/api/settings/country',
        data: {'defaultCountry': code},
      );
      if (response.statusCode == 200) {
        _iso = code;
        await prefs.setString(_prefKey, code);
        return true;
      }
    } catch (e) {
      debugPrint('[CountryCodeService] Failed to save country: $e');
    }
    return false;
  }

  /// Refresh from backend (call after login to stay in sync).
  Future<void> refreshFromBackend(Dio dio, SharedPreferences prefs) async {
    try {
      final response = await dio.get('/api/settings/country');
      if (response.statusCode == 200) {
        final iso = response.data['defaultCountry']?.toString() ?? _defaultIso;
        _iso = iso.toUpperCase();
        await prefs.setString(_prefKey, _iso);
      }
    } catch (e) {
      debugPrint('[CountryCodeService] Could not refresh country from backend: $e');
      // Keep whatever is already in memory/prefs — non-fatal
    }
  }

  /// Normalize a phone number using the tenant's default country.
  ///
  /// Rules:
  ///   1. Numbers starting with '+' or '00' → explicit international (validate 7–15 digits)
  ///   2. Local-format numbers → prepend default country calling code
  ///      - For India: 10 digits always gets '91' (even if starting with 91, e.g. 9123456789)
  ///      - For US/CA: 10 digits gets '1'
  ///   3. Numbers already having country code (11–15 digits) → passed through as-is
  ///   4. Invalid → returns null
  ///
  /// Always returns E.164 digits WITHOUT the '+' sign (WhatsApp format).
  String? normalizeNumber(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final hasInternationalPrefix = s.startsWith('+') || s.startsWith('00');

    // Strip non-digits
    String digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    // Strip leading 0 (trunk prefix e.g. 09876543210 -> 9876543210)
    // Only strip when user did NOT explicitly provide an international '+' or '00' prefix
    if (!hasInternationalPrefix && digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }

    // 1. Explicit international (+ or 00 prefix)
    if (hasInternationalPrefix) {
      if (digits.length >= 7 && digits.length <= 15) {
        return digits;
      }
      return null;
    }

    final callingCode = defaultDialCode; // e.g. '91' for IN

    // 2. India default country rules (100% backward compatibility & exact precision)
    if (callingCode == '91') {
      // 10-digit Indian mobile: ALWAYS prepend 91 (e.g. 9876543210 -> 919876543210, 9123456789 -> 919123456789)
      if (digits.length == 10) {
        return '91$digits';
      }
      // 12-digit Indian number already starting with 91
      if (digits.length == 12 && digits.startsWith('91')) {
        return digits;
      }
      // Multi-country numbers already containing country codes (11–15 digits, e.g. US, AU, UK, UAE)
      if (digits.length >= 11 && digits.length <= 15) {
        return digits;
      }
      return null;
    }

    // 3. USA / Canada (calling code 1)
    if (callingCode == '1') {
      if (digits.length == 10) return '1$digits';
      if (digits.length == 11 && digits.startsWith('1')) return digits;
      if (digits.length >= 11 && digits.length <= 15) return digits;
      return null;
    }

    // 4. Other countries:
    // If number already starts with calling code and has expected full length
    if (digits.startsWith(callingCode) &&
        digits.length >= callingCode.length + 6 &&
        digits.length <= 15) {
      return digits;
    }

    // If number is local-length (6 to 11 digits), prepend calling code
    if (digits.length >= 6 && digits.length <= 11) {
      final withCode = callingCode + digits;
      if (withCode.length >= 8 && withCode.length <= 15) {
        return withCode;
      }
    }

    // Multi-country number with full international code (11–15 digits)
    if (digits.length >= 11 && digits.length <= 15) {
      return digits;
    }

    return null;
  }

  // ─── Static country data ─────────────────────────────────────────────────────

  /// Returns dial code (without +) for an ISO-2 country code.
  static String _getDialCode(String iso) {
    final country = allCountries.firstWhere(
      (c) => c['iso'] == iso.toUpperCase(),
      orElse: () => {'dialCode': _countryDialCodes[iso.toUpperCase()] ?? '91'},
    );
    return country['dialCode'] ?? '91';
  }

  static String _getCountryName(String iso) {
    final country = allCountries.firstWhere(
      (c) => c['iso'] == iso.toUpperCase(),
      orElse: () => {'name': iso},
    );
    return country['name'] ?? iso;
  }

  /// All supported countries: India first for default discoverability, followed by global countries.
  static const List<Map<String, String>> allCountries = [
    {'iso': 'IN', 'name': 'India',                 'dialCode': '91',  'flag': '🇮🇳'},
    {'iso': 'AF', 'name': 'Afghanistan',           'dialCode': '93',  'flag': '🇦🇫'},
    {'iso': 'AL', 'name': 'Albania',               'dialCode': '355', 'flag': '🇦🇱'},
    {'iso': 'DZ', 'name': 'Algeria',               'dialCode': '213', 'flag': '🇩🇿'},
    {'iso': 'AD', 'name': 'Andorra',               'dialCode': '376', 'flag': '🇦🇩'},
    {'iso': 'AO', 'name': 'Angola',                'dialCode': '244', 'flag': '🇦🇴'},
    {'iso': 'AR', 'name': 'Argentina',             'dialCode': '54',  'flag': '🇦🇷'},
    {'iso': 'AM', 'name': 'Armenia',               'dialCode': '374', 'flag': '🇦🇲'},
    {'iso': 'AU', 'name': 'Australia',             'dialCode': '61',  'flag': '🇦🇺'},
    {'iso': 'AT', 'name': 'Austria',               'dialCode': '43',  'flag': '🇦🇹'},
    {'iso': 'AZ', 'name': 'Azerbaijan',            'dialCode': '994', 'flag': '🇦🇿'},
    {'iso': 'BH', 'name': 'Bahrain',               'dialCode': '973', 'flag': '🇧🇭'},
    {'iso': 'BD', 'name': 'Bangladesh',            'dialCode': '880', 'flag': '🇧🇩'},
    {'iso': 'BY', 'name': 'Belarus',               'dialCode': '375', 'flag': '🇧🇾'},
    {'iso': 'BE', 'name': 'Belgium',               'dialCode': '32',  'flag': '🇧🇪'},
    {'iso': 'BZ', 'name': 'Belize',                'dialCode': '501', 'flag': '🇧🇿'},
    {'iso': 'BJ', 'name': 'Benin',                 'dialCode': '229', 'flag': '🇧🇯'},
    {'iso': 'BT', 'name': 'Bhutan',                'dialCode': '975', 'flag': '🇧🇹'},
    {'iso': 'BO', 'name': 'Bolivia',               'dialCode': '591', 'flag': '🇧🇴'},
    {'iso': 'BA', 'name': 'Bosnia and Herzegovina','dialCode': '387', 'flag': '🇧🇦'},
    {'iso': 'BW', 'name': 'Botswana',              'dialCode': '267', 'flag': '🇧🇼'},
    {'iso': 'BR', 'name': 'Brazil',                'dialCode': '55',  'flag': '🇧🇷'},
    {'iso': 'BN', 'name': 'Brunei',                'dialCode': '673', 'flag': '🇧🇳'},
    {'iso': 'BG', 'name': 'Bulgaria',              'dialCode': '359', 'flag': '🇧🇬'},
    {'iso': 'BF', 'name': 'Burkina Faso',          'dialCode': '226', 'flag': '🇧🇫'},
    {'iso': 'BI', 'name': 'Burundi',               'dialCode': '257', 'flag': '🇧🇮'},
    {'iso': 'KH', 'name': 'Cambodia',              'dialCode': '855', 'flag': '🇰🇭'},
    {'iso': 'CM', 'name': 'Cameroon',              'dialCode': '237', 'flag': '🇨🇲'},
    {'iso': 'CA', 'name': 'Canada',                'dialCode': '1',   'flag': '🇨🇦'},
    {'iso': 'CL', 'name': 'Chile',                 'dialCode': '56',  'flag': '🇨🇱'},
    {'iso': 'CN', 'name': 'China',                 'dialCode': '86',  'flag': '🇨🇳'},
    {'iso': 'CO', 'name': 'Colombia',              'dialCode': '57',  'flag': '🇨🇴'},
    {'iso': 'CR', 'name': 'Costa Rica',            'dialCode': '506', 'flag': '🇨🇷'},
    {'iso': 'HR', 'name': 'Croatia',               'dialCode': '385', 'flag': '🇭🇷'},
    {'iso': 'CU', 'name': 'Cuba',                  'dialCode': '53',  'flag': '🇨🇺'},
    {'iso': 'CY', 'name': 'Cyprus',                'dialCode': '357', 'flag': '🇨🇾'},
    {'iso': 'CZ', 'name': 'Czech Republic',        'dialCode': '420', 'flag': '🇨🇿'},
    {'iso': 'DK', 'name': 'Denmark',               'dialCode': '45',  'flag': '🇩🇰'},
    {'iso': 'DJ', 'name': 'Djibouti',              'dialCode': '253', 'flag': '🇩🇯'},
    {'iso': 'DO', 'name': 'Dominican Republic',    'dialCode': '1',   'flag': '🇩🇴'},
    {'iso': 'EC', 'name': 'Ecuador',               'dialCode': '593', 'flag': '🇪🇨'},
    {'iso': 'EG', 'name': 'Egypt',                 'dialCode': '20',  'flag': '🇪🇬'},
    {'iso': 'SV', 'name': 'El Salvador',           'dialCode': '503', 'flag': '🇸🇻'},
    {'iso': 'EE', 'name': 'Estonia',               'dialCode': '372', 'flag': '🇪🇪'},
    {'iso': 'ET', 'name': 'Ethiopia',              'dialCode': '251', 'flag': '🇪🇹'},
    {'iso': 'FI', 'name': 'Finland',               'dialCode': '358', 'flag': '🇫🇮'},
    {'iso': 'FR', 'name': 'France',                'dialCode': '33',  'flag': '🇫🇷'},
    {'iso': 'GE', 'name': 'Georgia',               'dialCode': '995', 'flag': '🇬🇪'},
    {'iso': 'DE', 'name': 'Germany',               'dialCode': '49',  'flag': '🇩🇪'},
    {'iso': 'GH', 'name': 'Ghana',                 'dialCode': '233', 'flag': '🇬🇭'},
    {'iso': 'GR', 'name': 'Greece',                'dialCode': '30',  'flag': '🇬🇷'},
    {'iso': 'GT', 'name': 'Guatemala',             'dialCode': '502', 'flag': '🇬🇹'},
    {'iso': 'HN', 'name': 'Honduras',              'dialCode': '504', 'flag': '🇭🇳'},
    {'iso': 'HK', 'name': 'Hong Kong',             'dialCode': '852', 'flag': '🇭🇰'},
    {'iso': 'HU', 'name': 'Hungary',               'dialCode': '36',  'flag': '🇭🇺'},
    {'iso': 'IS', 'name': 'Iceland',               'dialCode': '354', 'flag': '🇮🇸'},
    {'iso': 'ID', 'name': 'Indonesia',             'dialCode': '62',  'flag': '🇮🇩'},
    {'iso': 'IR', 'name': 'Iran',                  'dialCode': '98',  'flag': '🇮🇷'},
    {'iso': 'IQ', 'name': 'Iraq',                  'dialCode': '964', 'flag': '🇮🇶'},
    {'iso': 'IE', 'name': 'Ireland',               'dialCode': '353', 'flag': '🇮🇪'},
    {'iso': 'IL', 'name': 'Israel',                'dialCode': '972', 'flag': '🇮🇱'},
    {'iso': 'IT', 'name': 'Italy',                 'dialCode': '39',  'flag': '🇮🇹'},
    {'iso': 'JM', 'name': 'Jamaica',               'dialCode': '1',   'flag': '🇯🇲'},
    {'iso': 'JP', 'name': 'Japan',                 'dialCode': '81',  'flag': '🇯🇵'},
    {'iso': 'JO', 'name': 'Jordan',                'dialCode': '962', 'flag': '🇯🇴'},
    {'iso': 'KZ', 'name': 'Kazakhstan',            'dialCode': '7',   'flag': '🇰🇿'},
    {'iso': 'KE', 'name': 'Kenya',                 'dialCode': '254', 'flag': '🇰🇪'},
    {'iso': 'KW', 'name': 'Kuwait',                'dialCode': '965', 'flag': '🇰🇼'},
    {'iso': 'KG', 'name': 'Kyrgyzstan',            'dialCode': '996', 'flag': '🇰🇬'},
    {'iso': 'LA', 'name': 'Laos',                  'dialCode': '856', 'flag': '🇱🇦'},
    {'iso': 'LV', 'name': 'Latvia',                'dialCode': '371', 'flag': '🇱🇻'},
    {'iso': 'LB', 'name': 'Lebanon',               'dialCode': '961', 'flag': '🇱🇧'},
    {'iso': 'LY', 'name': 'Libya',                 'dialCode': '218', 'flag': '🇱🇾'},
    {'iso': 'LT', 'name': 'Lithuania',             'dialCode': '370', 'flag': '🇱🇹'},
    {'iso': 'LU', 'name': 'Luxembourg',            'dialCode': '352', 'flag': '🇱🇺'},
    {'iso': 'MO', 'name': 'Macau',                 'dialCode': '853', 'flag': '🇲🇴'},
    {'iso': 'MY', 'name': 'Malaysia',              'dialCode': '60',  'flag': '🇲🇾'},
    {'iso': 'MV', 'name': 'Maldives',              'dialCode': '960', 'flag': '🇲🇻'},
    {'iso': 'MT', 'name': 'Malta',                 'dialCode': '356', 'flag': '🇲🇹'},
    {'iso': 'MU', 'name': 'Mauritius',             'dialCode': '230', 'flag': '🇲🇺'},
    {'iso': 'MX', 'name': 'Mexico',                'dialCode': '52',  'flag': '🇲🇽'},
    {'iso': 'MD', 'name': 'Moldova',               'dialCode': '373', 'flag': '🇲🇩'},
    {'iso': 'MC', 'name': 'Monaco',                'dialCode': '377', 'flag': '🇲🇨'},
    {'iso': 'MN', 'name': 'Mongolia',              'dialCode': '976', 'flag': '🇲🇳'},
    {'iso': 'ME', 'name': 'Montenegro',            'dialCode': '382', 'flag': '🇲🇪'},
    {'iso': 'MA', 'name': 'Morocco',               'dialCode': '212', 'flag': '🇲🇦'},
    {'iso': 'MZ', 'name': 'Mozambique',            'dialCode': '258', 'flag': '🇲🇿'},
    {'iso': 'MM', 'name': 'Myanmar',               'dialCode': '95',  'flag': '🇲🇲'},
    {'iso': 'NA', 'name': 'Namibia',               'dialCode': '264', 'flag': '🇳🇦'},
    {'iso': 'NP', 'name': 'Nepal',                 'dialCode': '977', 'flag': '🇳🇵'},
    {'iso': 'NL', 'name': 'Netherlands',           'dialCode': '31',  'flag': '🇳🇱'},
    {'iso': 'NZ', 'name': 'New Zealand',           'dialCode': '64',  'flag': '🇳🇿'},
    {'iso': 'NG', 'name': 'Nigeria',               'dialCode': '234', 'flag': '🇳🇬'},
    {'iso': 'NO', 'name': 'Norway',                'dialCode': '47',  'flag': '🇳🇴'},
    {'iso': 'OM', 'name': 'Oman',                  'dialCode': '968', 'flag': '🇴🇲'},
    {'iso': 'PK', 'name': 'Pakistan',              'dialCode': '92',  'flag': '🇵🇰'},
    {'iso': 'PS', 'name': 'Palestine',             'dialCode': '970', 'flag': '🇵🇸'},
    {'iso': 'PA', 'name': 'Panama',                'dialCode': '507', 'flag': '🇵🇦'},
    {'iso': 'PY', 'name': 'Paraguay',              'dialCode': '595', 'flag': '🇵🇾'},
    {'iso': 'PE', 'name': 'Peru',                  'dialCode': '51',  'flag': '🇵🇪'},
    {'iso': 'PH', 'name': 'Philippines',           'dialCode': '63',  'flag': '🇵🇭'},
    {'iso': 'PL', 'name': 'Poland',                'dialCode': '48',  'flag': '🇵🇱'},
    {'iso': 'PT', 'name': 'Portugal',              'dialCode': '351', 'flag': '🇵🇹'},
    {'iso': 'QA', 'name': 'Qatar',                 'dialCode': '974', 'flag': '🇶🇦'},
    {'iso': 'RO', 'name': 'Romania',               'dialCode': '40',  'flag': '🇷🇴'},
    {'iso': 'RU', 'name': 'Russia',                'dialCode': '7',   'flag': '🇷🇺'},
    {'iso': 'RW', 'name': 'Rwanda',                'dialCode': '250', 'flag': '🇷🇼'},
    {'iso': 'SA', 'name': 'Saudi Arabia',          'dialCode': '966', 'flag': '🇸🇦'},
    {'iso': 'SN', 'name': 'Senegal',               'dialCode': '221', 'flag': '🇸🇳'},
    {'iso': 'RS', 'name': 'Serbia',                'dialCode': '381', 'flag': '🇷🇸'},
    {'iso': 'SG', 'name': 'Singapore',             'dialCode': '65',  'flag': '🇸🇬'},
    {'iso': 'SK', 'name': 'Slovakia',              'dialCode': '421', 'flag': '🇸🇰'},
    {'iso': 'SI', 'name': 'Slovenia',              'dialCode': '386', 'flag': '🇸🇮'},
    {'iso': 'ZA', 'name': 'South Africa',          'dialCode': '27',  'flag': '🇿🇦'},
    {'iso': 'KR', 'name': 'South Korea',           'dialCode': '82',  'flag': '🇰🇷'},
    {'iso': 'ES', 'name': 'Spain',                 'dialCode': '34',  'flag': '🇪🇸'},
    {'iso': 'LK', 'name': 'Sri Lanka',             'dialCode': '94',  'flag': '🇱🇰'},
    {'iso': 'SD', 'name': 'Sudan',                 'dialCode': '249', 'flag': '🇸🇩'},
    {'iso': 'SE', 'name': 'Sweden',                'dialCode': '46',  'flag': '🇸🇪'},
    {'iso': 'CH', 'name': 'Switzerland',           'dialCode': '41',  'flag': '🇨🇭'},
    {'iso': 'SY', 'name': 'Syria',                 'dialCode': '963', 'flag': '🇸🇾'},
    {'iso': 'TW', 'name': 'Taiwan',                'dialCode': '886', 'flag': '🇹🇼'},
    {'iso': 'TZ', 'name': 'Tanzania',              'dialCode': '255', 'flag': '🇹🇿'},
    {'iso': 'TH', 'name': 'Thailand',              'dialCode': '66',  'flag': '🇹🇭'},
    {'iso': 'TN', 'name': 'Tunisia',               'dialCode': '216', 'flag': '🇹🇳'},
    {'iso': 'TR', 'name': 'Turkey',                'dialCode': '90',  'flag': '🇹🇷'},
    {'iso': 'UG', 'name': 'Uganda',                'dialCode': '256', 'flag': '🇺🇬'},
    {'iso': 'UA', 'name': 'Ukraine',               'dialCode': '380', 'flag': '🇺🇦'},
    {'iso': 'AE', 'name': 'United Arab Emirates',  'dialCode': '971', 'flag': '🇦🇪'},
    {'iso': 'GB', 'name': 'United Kingdom',        'dialCode': '44',  'flag': '🇬🇧'},
    {'iso': 'US', 'name': 'United States',         'dialCode': '1',   'flag': '🇺🇸'},
    {'iso': 'UY', 'name': 'Uruguay',               'dialCode': '598', 'flag': '🇺🇾'},
    {'iso': 'UZ', 'name': 'Uzbekistan',            'dialCode': '998', 'flag': '🇺🇿'},
    {'iso': 'VE', 'name': 'Venezuela',             'dialCode': '58',  'flag': '🇻🇪'},
    {'iso': 'VN', 'name': 'Vietnam',               'dialCode': '84',  'flag': '🇻🇳'},
    {'iso': 'YE', 'name': 'Yemen',                 'dialCode': '967', 'flag': '🇾🇪'},
    {'iso': 'ZM', 'name': 'Zambia',                'dialCode': '260', 'flag': '🇿🇲'},
    {'iso': 'ZW', 'name': 'Zimbabwe',              'dialCode': '263', 'flag': '🇿🇼'},
  ];

  static const Map<String, String> _countryDialCodes = {
    'IN': '91',  'US': '1',   'GB': '44',  'AU': '61',  'CA': '1',
    'AE': '971', 'SA': '966', 'SG': '65',  'MY': '60',  'PH': '63',
    'ID': '62',  'TH': '66',  'VN': '84',  'BD': '880', 'PK': '92',
    'LK': '94',  'NP': '977', 'NG': '234', 'ZA': '27',  'KE': '254',
    'GH': '233', 'ET': '251', 'TZ': '255', 'UG': '256', 'EG': '20',
    'MA': '212', 'DZ': '213', 'BR': '55',  'MX': '52',  'AR': '54',
    'CO': '57',  'CL': '56',  'PE': '51',  'DE': '49',  'FR': '33',
    'IT': '39',  'ES': '34',  'NL': '31',  'SE': '46',  'NO': '47',
    'DK': '45',  'FI': '358', 'PL': '48',  'RU': '7',   'TR': '90',
    'IL': '972', 'JP': '81',  'KR': '82',  'CN': '86',  'HK': '852',
    'TW': '886', 'NZ': '64',  'QA': '974', 'KW': '965', 'BH': '973',
    'OM': '968', 'JO': '962', 'LB': '961', 'MM': '95',  'KH': '855',
    'MV': '960', 'MU': '230', 'AF': '93',  'IR': '98',  'IQ': '964',
    'PS': '970', 'SY': '963', 'YE': '967', 'SD': '249', 'SO': '252',
    'CM': '237', 'SN': '221', 'CI': '225', 'MZ': '258', 'ZM': '260',
    'ZW': '263', 'AO': '244', 'PT': '351', 'GR': '30',  'RO': '40',
    'HU': '36',  'CZ': '420', 'AT': '43',  'CH': '41',  'BE': '32',
    'UA': '380', 'VE': '58',  'PG': '675',
  };
}
