/// Matches the current account without ever displaying its username as a chat.
bool matchesSavedMessagesQuery({
  required String query,
  required String username,
  required String displayName,
  required String savedTitle,
}) {
  final value = query.trim().toLowerCase();
  if (value.isEmpty) return false;
  final userQuery = value.startsWith('@') ? value.substring(1) : value;
  if (userQuery.isEmpty) return false;
  return (username.isNotEmpty && username.toLowerCase().contains(userQuery)) ||
      (displayName.isNotEmpty && displayName.toLowerCase().contains(value)) ||
      savedTitle.toLowerCase().contains(value);
}
