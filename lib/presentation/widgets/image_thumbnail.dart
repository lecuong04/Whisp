import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whisp/custom_cache_manager.dart';

class ImageThumbnail extends StatelessWidget {
  final bool isTargetMessage;
  final String url;

  const ImageThumbnail({
    super.key,
    required this.isTargetMessage,
    required this.url,
  });

  static Future<void> imageViewer({
    required BuildContext context,
    required String url,
  }) async {
    await showAdaptiveDialog(
      barrierDismissible: true,
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onLongPress: () async {
                  var uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: CachedNetworkImage(
                  imageUrl: url,
                  cacheManager: CustomCacheManager(),
                  progressIndicatorBuilder:
                      (context, url, progress) =>
                          const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          isTargetMessage
              ? BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: BorderRadius.circular(10),
              )
              : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          onDoubleTap: () async {
            await imageViewer(context: context, url: url);
          },
          child: CachedNetworkImage(
            imageUrl: url,
            width: 200,
            fit: BoxFit.cover,
            placeholder:
                (context, url) => SizedBox.square(
                  dimension: 128,
                  child: Center(child: CircularProgressIndicator()),
                ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
            cacheManager: CustomCacheManager(),
          ),
        ),
      ),
    );
  }
}
