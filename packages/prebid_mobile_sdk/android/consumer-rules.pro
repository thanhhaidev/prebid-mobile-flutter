# Applied to apps that depend on this plugin.

# MultiformatAdHostApiImpl.findGmaBannerViews finds Google Mobile Ads banner
# views (AdView / AdManagerAdView) by their superclass name, so the core
# plugin needn't depend on GMA. Keep that name through R8 obfuscation, or the
# Prebid banner impression tracker never activates in minified release apps.
-keepnames class com.google.android.gms.ads.BaseAdView
