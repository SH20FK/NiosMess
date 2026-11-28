/// Legacy links keep opening inside the browser workspace, including search anchors.
String? webSettingsRedirect(Uri uri) {
  const sections = {
    '/settings/account': 'account',
    '/settings/appearance': 'appearance',
    '/settings/appearance/accent': 'appearance',
    '/settings/appearance/shape': 'appearance',
    '/settings/chats': 'chats',
    '/settings/privacy': 'privacy',
    '/settings/security': 'security',
    '/settings/storage': 'storage',
    '/settings/language-region': 'languageRegion',
    '/settings/notifications': 'notifications',
    '/settings/preferences': 'notifications',
    '/settings/system-device': 'about',
    '/settings/about': 'about',
    '/settings/e2ee': 'e2ee',
    '/settings/sessions': 'sessions',
    // The delivery rules that did the saving live on Notifications now.
    '/settings/energy-saving': 'notifications',
    '/settings/plus': 'plus',
    '/settings/plus/store': 'plus',
  };
  final section = sections[uri.path];
  if (section == null) return null;
  return Uri(
    path: '/main/settings',
    queryParameters: {...uri.queryParameters, 'section': section},
    // An empty fragment would leave a bare '#' at the end of the address.
    fragment: uri.fragment.isEmpty ? null : uri.fragment,
  ).toString();
}
