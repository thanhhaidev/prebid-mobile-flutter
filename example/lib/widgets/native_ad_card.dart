import 'package:flutter/material.dart';
import 'package:prebid_mobile_sdk/prebid_mobile_sdk.dart';

/// Renders a native ad response as a Material card.
class NativeAdCard extends StatelessWidget {
  final PrebidNativeAdResponse response;
  const NativeAdCard({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (response.imageUrl != null)
            Image.network(
              response.imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, e, st) => const SizedBox(
                height: 160,
                child: Center(child: Icon(Icons.broken_image)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (response.sponsoredBy != null)
                  Text(
                    'Sponsored by ${response.sponsoredBy}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                if (response.title != null)
                  Text(
                    response.title!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (response.text != null)
                  Text(
                    response.text!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (response.callToAction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.tonal(
                      onPressed: () {},
                      child: Text(response.callToAction!),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
