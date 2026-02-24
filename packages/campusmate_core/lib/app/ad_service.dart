import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService I = AdService._();

  static const bool _enabled = bool.fromEnvironment(
    'ENABLE_ADS',
    defaultValue: true,
  );
  static const String _androidBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID_ANDROID',
    defaultValue: '',
  );

  static const String _androidTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  bool _initialized = false;

  bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  bool get isEnabled => _enabled && isSupportedPlatform;

  String? get bannerUnitId {
    if (!isEnabled) return null;
    final configured = _androidBannerUnitId.trim();
    if (configured.isNotEmpty) return configured;
    return _androidTestBannerUnitId;
  }

  bool get canLoadBanner => bannerUnitId != null;

  Future<void> init() async {
    if (_initialized || !canLoadBanner) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  BannerAd createBannerAd({
    required VoidCallback onLoaded,
    required void Function(LoadAdError error) onFailedToLoad,
  }) {
    final unitId = bannerUnitId;
    if (unitId == null) {
      throw StateError('Banner ad unit id is not configured for this build.');
    }

    return BannerAd(
      adUnitId: unitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (_, error) => onFailedToLoad(error),
      ),
    );
  }
}
