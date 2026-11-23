/// What an automatic download rule applies to.
enum AutoDownloadMediaType { photo, video }

/// Networks an automatic download rule can cover. Roaming is not one of them:
/// platforms do not report it separately from an ordinary mobile network.
enum AutoDownloadNetwork { wifi, cellular }
