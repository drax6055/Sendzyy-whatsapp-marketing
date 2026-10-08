import 'dart:async';
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>?> triggerFacebookAdsLogin(String appId) async {
  debugPrint('[MetaAdsAuth Stub] Facebook Login popup is only supported on Web platform.');
  return {
    'status': 'error',
    'error': 'Facebook Login popup is only supported on Web platform',
  };
}
