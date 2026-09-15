import 'package:flutter/foundation.dart';

// Dormant in EOchat builds (see ForkOverrides.showReleaseNotesBanner), but
// kept pointed at EOchat's own listings rather than upstream Conduit's in
// case the banner is ever re-enabled. App Store numeric id from
// scripts/asc_testflight.py's APP_ID; Play Store id from
// android/app/build.gradle.kts's applicationId.
const appleAppStoreReviewUrl =
    'https://apps.apple.com/us/app/eochat/id6763726069?action=write-review';
const googlePlayStoreUrl =
    'https://play.google.com/store/apps/details?id=nl.eo.eochat';

String reviewUrlForPlatform([TargetPlatform? platform]) {
  final resolved = platform ?? defaultTargetPlatform;
  return switch (resolved) {
    TargetPlatform.iOS || TargetPlatform.macOS => appleAppStoreReviewUrl,
    _ => googlePlayStoreUrl,
  };
}
