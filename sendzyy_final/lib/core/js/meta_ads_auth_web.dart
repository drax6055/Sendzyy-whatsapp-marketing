// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';

extension type AdsLoginResult._(JSObject _) implements JSObject {
  external String get status;
  external String? get accessToken;
  external String? get code;
  external String? get userId;
  external String? get expiresIn;
  external String? get error;
}

@JS()
external JSPromise<AdsLoginResult> launchFacebookAdsLogin(String appId);

Future<Map<String, dynamic>?> triggerFacebookAdsLogin(String appId) async {
  try {
    final result = await launchFacebookAdsLogin(appId).toDart;
    return {
      'status': result.status,
      'accessToken': result.accessToken,
      'code': result.code,
      'userId': result.userId,
      'expiresIn': result.expiresIn,
      'error': result.error,
    };
  } catch (e) {
    return {
      'status': 'error',
      'error': e.toString(),
    };
  }
}
