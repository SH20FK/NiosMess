# NiosGram discussions, custom emoji and anonymous ballots

Host baseline: `notifications-v2-20261024T200000Z`. Apply `host.patch` only to that
reviewed tree and copy `services/*.py` into `app/services/`. The root
`feed_comments.py` is the same module retained for compatibility with the previous
package. Run `tests/check_host.py` against a synthetic in-memory DATABASE_URL;
take a SQLite backup before switching the release. Migrations are additive and repeatable.
No personal conversations, credentials or production database are included here.

- Discussion comments have stable parent IDs, metadata, deletion tombstones and emoji
  reactions. Private-channel membership is checked; pagination and metadata lookups are bounded.
- NiosAI replies to mentions and direct replies to its own comments. Generation is pinned
  to Lite Strong without fallback; output is limited to 512 provider tokens and 300 public
  Unicode codepoints. No hardcoded identity answer: one feed system prompt defines NiosAI
  and distinguishes it from the NiosMess messenger. Post background and the last reply
  are separate messages. Public output strips @ai/@niosai.
- Feed search tools check both web evidence and public NiosGram posts from the source
  author or verified authors. Duplicate queries are cached within the generation. Results
  include dates and actual post links; final internal citations are validated against
  retrieved URLs and remain complete within the output cap. Website/post text is untrusted
  evidence; prompt injection resistance is not an absolute guarantee.
- Quality feedback uses SupportTicket type `ai_quality` and a dedicated NiosAdmin queue,
  with selected post/request/answer evidence, idempotency and a daily abuse limit.
  It never enters account-sanction workflows. Client action is in the three-dot menu.
- Public/official emoji are readable without saving their pack. Private metadata requires
  ownership or membership. Resolution batches are capped at 100 codes. The public media
  route checks actual public pack ownership before serving emoji, isolates SVG content
  through CSP, and inspects uploaded image bytes rather than trusting client metadata.
- Inline :shortcode: emoji use the same rendering in messages, posts and comments.
  Adaptive PNG/SVG assets inherit text/theme color. The official PNG replacements in
  `official_emoji/` retain the existing `nios_check` and `nios_star` shortcodes and row IDs;
  install them as versioned paths, with is_adaptive=true, without deleting the old assets.
- NiosGram polls and quizzes expose only aggregate counts and the requesting user's
  own selection. Quiz answers/explanations remain hidden before that user votes, and
  the first quiz vote is immutable. Normal poll selections can be changed atomically.
  No voter list or voter ID is returned to post authors or other viewers.
- Notification metadata distinguishes ordinary E2E from secret chats. Ciphertext and
  key protocols are unchanged. Client-local ordinary previews use existing decryption;
  secret previews remain hidden. If decryption is unavailable, the ordinary fallback
  is a generic new-message label. Decrypted previews/attachment keys are not written
  into the plain chat-summary cache.

AI work follows the existing in-process after-commit task lifecycle; process failure
does not automatically repeat a paid generation. Maintenance regeneration preserves
comment IDs, replies, reactions and counts, and does not charge user quotas.
