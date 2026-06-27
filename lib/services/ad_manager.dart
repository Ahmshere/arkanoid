import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Менеджер рекламы AdMob.
///
/// Тестовые ID (работают без регистрации) — замените на реальные перед релизом:
///   _appId     → ваш App ID из AdMob (AndroidManifest тоже нужно обновить)
///   _adUnitId  → ID рекламного блока Rewarded Video
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  // ── Замените на реальные ID после регистрации приложения в AdMob ──────────
  static const String _rewardedAdUnitId =
      'ca-app-pub-9604144074094777/3984642304';
  // ─────────────────────────────────────────────────────────────────────────

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Вызвать один раз в main() после WidgetsFlutterBinding.ensureInitialized()
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewarded();
  }

  void _loadRewarded() {
    if (_isLoading) return;
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
          _rewardedAd = null;
          _isLoading = false;
          // Повторная попытка через 30 сек
          Future.delayed(const Duration(seconds: 30), _loadRewarded);
        },
      ),
    );
  }

  /// Показать рекламу и вызвать [onRewarded] если пользователь досмотрел.
  /// [onNoAd] — если реклама ещё не загрузилась (разрешаем Continue бесплатно).
  void showRewarded({
    required void Function() onRewarded,
    required void Function() onNoAd,
  }) {
    final ad = _rewardedAd;
    if (ad == null) {
      onNoAd();
      _loadRewarded();
      return;
    }

    _rewardedAd = null; // сбрасываем до показа

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded(); // грузим следующую
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        onRewarded(); // показ не удался — даём Continue бесплатно
        _loadRewarded();
      },
    );

    ad.show(
      onUserEarnedReward: (_, __) => onRewarded(),
    );
  }

  bool get isReady => _rewardedAd != null;
}
