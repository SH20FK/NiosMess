/// Legacy links keep opening inside the browser workspace, including search anchors.
String? webSettingsRedirect(Uri uri) {
  const sections = {
    '/settings/account': 'account',
    '/settings/appearance': 'appearance',
    '/settings/chats': 'chats',
    '/settings/privacy': 'privacy',
    '/settings/storage': 'storage',
    '/settings/language-region': 'languageRegion',
    '/settings/preferences': 'preferences',
    '/settings/system-device': 'about',
    '/settings/about': 'about',
    '/settings/e2ee': 'e2ee',
    '/settings/sessions': 'sessions',
    '/settings/energy-saving': 'energySaving',
    '/settings/plus': 'plus',
  };
  final section = sections[uri.path];
  if (section == null) return null;
  return Uri(
    path: '/main/settings',
    queryParameters: {...uri.queryParameters, 'section': section},
  ).toString();
}
