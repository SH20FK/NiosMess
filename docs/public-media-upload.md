# Public media uploads

Avatars and sticker assets use authenticated multipart HTTP upload followed by a
small WebSocket operation containing only the completed upload ID and metadata.
They do not use private chat blob retention or expose an arbitrary file path.
The server verifies the upload owner and completeness before adopting it, derives
the actual type, dimensions and duration from bytes, and keeps permanent assets
under the existing avatars/stickers namespaces. Legacy inline uploads remain
supported. Runtime media validation requires the distribution's `ffprobe`.

The server limits concurrent media processing and probe execution, uses generated
local filenames, fixed demuxers, a file/pipe protocol allowlist, bounded probe
output and timeouts. Private chat media authorization and retention are unchanged.
No server-side duration limit relies on a client-provided value.

The client preserves video container extensions, formats still stickers outside
the UI isolate and preserves animated image bytes. Video avatars reuse the
existing visibility-aware playback and decoder budget, with the normal themed
initials as fallback. Network throughput and codec support still depend on the
device and its connection; local fixture timing is not a network benchmark.

NiosGram comment creation and reload return the same author and timestamp fields,
with both message and legacy author fields for compatibility. Feed author and
reaction metadata load in two batch queries per page instead of per-post queries.
