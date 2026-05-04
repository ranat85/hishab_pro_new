import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobHelper {
  // Ad Unit IDs from AdMob console
  // Android Banner Ad Unit ID
  static const String androidBannerId =
      'ca-app-pub-1804241075926589/5748215962';
  // iOS Banner Ad Unit ID
  static const String iosBannerId = 'ca-app-pub-1804241075926589/2004501367';

  // Get platform-specific banner ad unit ID
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return androidBannerId;
    } else if (Platform.isIOS) {
      return iosBannerId;
    }
    throw UnsupportedError('Unsupported platform for AdMob');
  }

  // Initialize banner ad
  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // Ad loaded successfully
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
  }
}
