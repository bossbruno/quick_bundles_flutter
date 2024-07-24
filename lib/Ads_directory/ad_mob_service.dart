import 'dart:io';
class AdMobService {
  static const String androidBannerAdUnitId =
      'ca-app-pub-1041515975395910/8402336562';
  static const String iosBannerAdUnitId =
      'ca-app-pub-1041515975395910/8832237475';

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return androidBannerAdUnitId;
    } else if (Platform.isIOS) {
      return iosBannerAdUnitId;
    } else {
      throw UnsupportedError('Unsupported platform for AdMob');
    }
  }
}
