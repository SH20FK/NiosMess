/// Barrel for the extracted chat-detail pieces.
///
/// The screen itself (`screens/chat_detail_screen.dart`) keeps its `State` and
/// the `Theme`/`ref.listen` wiring; these files hold the build body and the
/// three isolated scopes it mounts.
library;

export 'chat_composer_scope.dart';
export 'chat_detail_body.dart';
export 'chat_header_scope.dart';
export 'chat_messages_scope.dart';
