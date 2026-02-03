# Backend endpoints needed (front-only tracking)

This file tracks backend endpoints required by frontend features implemented from the roadmap.

## M01 Realtime (WebSocket)
- WS URL: wss://<host>/ws
- Auth: token and username as query params, plus an auth payload on open:
  - { "type": "auth", "token": "...", "username": "..." }
- Inbound events (JSON):
  - new_message: { chat_id, chat_type, message:{...} } or a message payload with chat_id
  - edit_message: { chat_id, message_id, text, edited_at? }
  - delete_message: { chat_id, message_id }
  - typing: { chat_id, username, active }
  - presence: { username, is_online }
  - read_receipt: { chat_id, message_id? , last_read_id? }
  - delivered_receipt: { chat_id, message_id? , last_delivered_id? }
- Outbound events sent by client:
  - typing: { chat_id, chat_type, username, receiver?, active }

## M02 Delivery/read statuses
- POST /mark_read
  - form-data: chat_id, username, token, last_id? (direct chats)
- POST /collective/mark_read
  - form-data: chat_id, username, token (group/channel)
- Message fields on GET:
  - status / message_status
  - read_at / delivered_at / seen_at (optional)

## M03 Unread counters
- GET /get_chats should return unread_count for each chat_id/username.

## M04 Multi-device sessions
- GET /sessions/list?username=&token=
  - Response: array of sessions (id, device/user_agent, last_active, ip, current?)
- POST /sessions/logout
  - Body: { token, username, session_id } or { token, username, all_except_current: true }

## M06 Forward messages (optional metadata)
- Optional: POST /forward_message or accept forward metadata in existing send endpoints
  - Fields: forward_from, forward_message_id

## M07 Pin message
- POST /messages/pin
  - Body: { token, username, chat_id, chat_type, message_id, pinned }
- GET /chats/pinned?username=&token=
  - Response: map of chat_id -> pinned_message_id (or message object)
- /get_messages should return pin metadata (pinned_message_id or pinned flag per message)

## M08 Pin chat
- POST /chats/pin
  - Body: { token, username, chat_id, pinned }
- /get_chats should return pinned (boolean) and order pinned chats above others

## M09 Scheduled messages
- POST /messages/schedule
  - Body: { token, sender, chat_id, chat_type, text, reply_to?, send_at }
- GET /messages/scheduled?username=&token=&chat_id=
  - Response: list of pending scheduled messages
- POST /messages/scheduled/cancel
  - Body: { token, username, schedule_id }

## M10 Self-destruct (TTL)
- Accept ttl or expires_at in /send_message and /collective/send
  - Body: { ttl_seconds } or { expires_at }
- Messages payload should include expires_at
- Backend should delete/expire and broadcast delete events

## M11 Polls
- POST /polls/create
  - Body: { token, username, chat_id, chat_type, question, options[], multiple }
  - Response: poll_id + message payload
- POST /polls/vote
  - Body: { token, username, poll_id, option_index }
- GET /polls/{poll_id}?username=&token=
  - Response: counts[], my_votes[], total

## M12 Geolocation
- Allow LOCATION payloads in text or add POST /send_location
  - Body: { token, username, chat_id, chat_type, lat, lon, label? }

## M13 Contacts
- Allow CONTACT payloads in text or add POST /send_contact
  - Body: { token, username, chat_id, chat_type, name, phone?, email?, username? }

## M14 Server-side message search
- GET /search_messages?chat_id=&q=&username=&token=&chat_type=
  - Response: array of message objects or { results: [...] }

## M15 Saved messages (server chat)
- POST /send_chat
  - Body: { token, username, chat_id="__favorites__", text, reply_to? }
- GET /get_chat_messages?chat_id=__favorites__&username=&token=&limit=

## M16 Link previews (smart cards)
- GET /link_preview?url=&username=&token=
  - Response:
    {
      "url": "https://...",
      "title": "...",
      "description": "...",
      "image": "https://.../cover.jpg",
      "site_name": "YouTube/Spotify/Domain",
      "type": "youtube|spotify|soundcloud|article|link"
    }
- Notes:
  - Backend should fetch meta tags (og:title, og:description, og:image).
  - For YouTube: can return best thumbnail if og:image missing.
  - For Spotify: return album/track art if available.
