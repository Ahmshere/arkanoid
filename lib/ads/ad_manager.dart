import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Thin wrapper around rewarded ads.
/// Call [AdManager.instance.loadRewardedAd()] early (e.g. after game starts).
/// Call [AdManager.instance.showRewardedAd(onRewarded)] on "Continue" tap.
class AdManager {
  AdManager._();
  static final instance = AdManager._();

  // ⚠️ Replace with your real Ad Unit ID before release
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917'; // Google test ID

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  void loadRewardedAd() {
    if (_rewardedAd != null || _isLoading) return;
    _isLoading = true;
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          // Silently fail; UI should handle gracefully
        },
      ),
    );
  }

  /// Show the rewarded ad. Calls [onRewarded] if the user earns the reward.
  /// Calls [onFailed] if the ad isn't ready (so you can decide to continue anyway or not).
  void showRewardedAd({
    required void Function() onRewarded,
    required void Function() onFailed,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      onFailed();
      loadRewardedAd(); // preload for next time
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // preload next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        onFailed();
        loadRewardedAd();
      },
    );

    ad.show(
      onUserEarnedReward: (_, reward) => onRewarded(),
    );
  }

  bool get isReady => _rewardedAd != null;
}
