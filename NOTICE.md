# NiosMess — notices

NiosMess is free software: you can redistribute it and/or modify it under the
terms of the **GNU General Public License, version 3 or any later version**, as
published by the Free Software Foundation. The full text is in [`LICENSE`](LICENSE).

The source of the client is published at <https://github.com/SH20FK/NiosMess>.
Whoever receives a built client may obtain the corresponding source from that
repository, which is what the license requires.

This license covers the first-party code of the client in this repository
(`pulse_flutter/` and the packages under `packages/`). Files that carry their
own copyright header or their own license file stay under that license — for
example `packages/nios_mls/THIRD_PARTY_NOTICES.txt` and everything under
`pulse_flutter/assets/licenses/`.

`server_core/` is a separate backend, is not distributed with this repository
and is not covered by this notice.

## Code from exteraGram

Some features and algorithms here are modelled on **exteraGram for Android**, and
individual files may be ported from it. NiosMess is **not** a fork and not a
modified version of exteraGram: the client is a separate Flutter application, and
the table below lists every file that contains code taken from there. The table
is empty at the time of writing — so far we have reused ideas, not code.

- exteraGram: Copyright @exteraGram, 2022–2026
- <https://github.com/exteraSquad/exteraGram>
- Licensed under the GNU GPL v3 or later, with the additional terms in that
  repository's `ADDITIONAL_TERMS.md`

Ported files and the changes made to them keep their original notices. NiosMess
is not affiliated with or endorsed by exteraGram's authors; their name, logos and
app icons are not used as the name, logo or icon of this project, and the name
appears only to say truthfully where the code came from.

| NiosMess file | exteraGram source | Notes |
|---|---|---|
| _(none yet — ideas only)_ | | |

## Telegram for Android

Where code or protocol details come from Telegram for Android, the same GPL
obligations apply and the original notice must be kept. Telegram for Android is
licensed by Telegram FZ-LLC under the GNU GPL v2 or later; see
<https://github.com/DrKLO/Telegram>.

## Third-party components

Third-party libraries keep their own licenses. The list is bundled with the
client and shown in **Settings → About → Legal → Third-Party Licenses**; the
machine-readable copies live in `pulse_flutter/assets/licenses/` and next to the
vendored packages.
