# Notification delivery v2

Compatible additive patch for the **modular** handlers used by `/opt/niosmess/current`.
`patch_host.py` refuses to patch unexpected source. `deploy.py stage` copies the
current release and tests actual handlers against disposable SQLite databases;
`activate` checks the release and original source hashes again, backs up SQLite,
adds one nullable TEXT column, switches the release symlink, and checks the application OpenAPI JSON (the host has a landing-page catch-all, so HTTP 200 alone is insufficient).
A failed health check restores the previous code. The extra column is compatible
with that previous code; rollback never overwrites newly received messages.

* Device token preferences: categories, preview, sound, locale and muted chat IDs.
  Chat moderation `is_muted` is not repurposed.
* Push is independent of account-wide presence. Delivery rechecks token ownership,
  preferences and active session in a separate transaction after message commit.
* FCM carries recipient account, stable event ID, creation time and call expiry.
  Ordinary Android messages keep automatic OS display. Only v2 calls and silent
  cancellation/read controls use data-only; legacy call clients keep OS display.
* Calls use their own channel and 60-second TTL. Joining rejects expired/mismatched
  rooms. Accept/end/timeout queue cancellation for other devices. Timeout cleanup
  no longer cancels its own coroutine before committing.
* A new token is flushed before secret-device session binding. Secret push token
  selection remains restricted to the peer key and active device session.
* Read receipts reach the reader's other devices and close the matching alert.
* NiosGram post likes/comments queue activity only after commit; self-events and
  removed/dislike reactions do not notify the author. Client and device push use
  the same stable activity ID.

Local policy checks:

```powershell
python -m unittest discover -s backend_changes/notifications_v2/tests -v
```

The host integration cases require the staged application and
`NIOS_NOTIFICATION_HOST_TEST=1`; deployment supplies a non-production DATABASE_URL.
FCM is mocked in those tests: no real user receives a test push. Real Android
background/Doze delivery and OS permission/channel behavior still require devices.
No message bodies, tokens or keys should be included in deployment diagnostics.
