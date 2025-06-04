import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager extends CacheManager with ImageCacheManager {
  static const key = 'libCachedData';

  static final CustomCacheManager _instance = CustomCacheManager._();

  factory CustomCacheManager() {
    return _instance;
  }

  CustomCacheManager._() : super(Config(key, stalePeriod: Duration(days: 7)));
}
