/// Bearer code stays in the fragment and is never accepted from foreign hosts.
class PlusActivationLink {
  static String? codeFrom(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.userInfo.isNotEmpty || uri.hasPort) return null;
    final web =
        uri.scheme == 'https' &&
        const {'ni-os.ru', 'www.ni-os.ru'}.contains(uri.host.toLowerCase()) &&
        uri.path == '/plus/activate';
    final native =
        uri.scheme == 'niosmess' &&
        uri.host == 'plus' &&
        uri.path == '/activate';
    if ((!web && !native) || uri.hasQuery) return null;
    return RegExp(r'^[A-Za-z0-9_-]{40,128}$').hasMatch(uri.fragment)
        ? uri.fragment
        : null;
  }
}
