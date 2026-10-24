# Feed discussion threads

Host baseline: `notifications-v2-20261024T200000Z` (preserves unified notification delivery).

Apply `host.patch` to that reviewed host tree and install `feed_comments.py` as
`app/services/feed_comments.py`. Run the in-memory integration checker with the
host virtual environment and a synthetic `DATABASE_URL`, then take a SQLite backup
and switch the release atomically. Runtime migrations are additive and repeatable.
Never apply the patch blindly to a different host revision.

- Feed comments retain a parent ID, edited time, deletion tombstone and one reaction per user.
- Channel comments retain a separate post root, so replies do not disappear from the discussion.
- Legacy channel roots are backfilled once. All reads are bounded and indexed.
- Reply parents must belong to the same post; private channels require membership.
- Sender presentation uses the same batched user/badge/status loader as ordinary messages.
- New post/comment mentions accept @ai and @niosai with token boundaries. AI is queued
  only after commit and replies under the NiosAI account. No automatic AI replies to AI replies.
- Feed generation pins `nios_lite`, disables stronger-model fallback, keeps a 160-token
  generation ceiling for all plans and hard-truncates the public answer to 100 Unicode
  codepoints. Web search, safe website reading and calculator tools are available;
  code execution/moderation tools are not available in this mode.
- All provider attempts/context/tool output use existing quota reservations and cost accounting.
  The user's saved model is not changed. Personal-chat AI behavior is preserved.
- Active viewers receive metadata-only invalidation after commit; bounded polling repairs
  missed events and reconnects. The UI displays theme colors and SVG action icons.

Limitations: queued AI work follows the existing in-process post-commit task lifecycle;
a process crash during generation does not automatically repeat a paid request.
The public 100-character reply may be shortened with an ellipsis; it is not a token budget.

Synthetic integration: `tests/check_host.py` (no live user data or paid API calls).
Flutter coverage: comment thread traversal, 10,000 nested replies, deleted/missing/cyclic
parents, page cursor after sending, failed deletion, 320px layout in both themes and
200% text. Included in the normal release suite.
