# Backend requirements for groups/channels

This document describes the backend work needed to support group and channel chats in NiosMess.

## Current frontend-backend contract (existing endpoints used by webui)
The web UI already calls the following endpoints. If any are missing or return unexpected shapes, features
break (auth, messages, media, voice, previews, unread counters).

### Auth/session
- POST /login
- POST /register
  - Request: { email, password, username, name, code? }
  - Response: { token, username } OR { status: "wait_code" }
- POST /check_session
  - Request: { token, username }
  - Response: { status: "ok" } or { token, username } (any truthy success is accepted)
- POST /ping
  - Request: { token, username }

### Chat list / search
- GET /get_chats?user={username}&token={token}&version=1.0
  - Each item should include:
    - username, name
    - isonline (boolean)
    - unread_count (number, optional)
- GET /search_users?q={query}&token={token}&my_username={username}

### User profile
- GET /get_user_info?username={target}&token={token}&my_username={username}
  - Response fields used: name, username, isonline, isfrozen, email, regdate

### Messages (1:1)
- GET /get_messages?me={username}&other={target}&token={token}
  - Returns array of message objects
- POST /send_message
  - Request: { sender, receiver, text, token, reply_to? }
  - Note: text is obfuscated by the frontend
- POST /edit_message
  - Request: { token, username, message_id, text } (text is obfuscated)
- POST /delete_message
  - Request: { token, username, message_id }

### Media upload/download
- POST /upload (multipart/form-data)
  - form fields: file, sender, receiver, token, content_type, is_voice
- GET /download/{filename}
  - Must allow auth either via query params `?token=&username=` or via headers:
    - Authorization: Bearer {token}
    - X-Token: {token}
    - X-Username: {username}
  - Must send proper Content-Type so browser can render images/audio/video
  - CORS must allow the web origin to load media (including <img>/<video>/<audio>)

## Overview
The frontend now supports **local-only groups** (stored in localStorage). To make them real, the backend needs
APIs for creating groups/channels, managing members, sending messages, and listing these chats in the chat list.

The backend report indicates a **universal "Collective Chats" system**:
- One shared table for both groups and channels, distinguished by `type`
- Unified send/list endpoints under `/collective/{chat_id}/...`
- Role checks: only `owner` can post to channels
- Built‑in obfuscation for all stored messages
- Pagination via `limit`
- Sorting by `updated_at` for chat list ordering
- Public search endpoint for collective chats

## Data models (suggested)

### Group
- id (string)
- name (string)
- owner (string, username)
- members (array of usernames)
- avatar_url (string, optional)
- created_at (timestamp)
- updated_at (timestamp)

### Channel
- id (string)
- name (string)
- owner (string, username)
- members/subscribers (array of usernames)
- avatar_url (string, optional)
- created_at (timestamp)
- updated_at (timestamp)

### Group/Channel Message
- id (string or int)
- chat_id (group/channel id)
- sender (username)
- text (string, raw)
- edited (boolean, optional)
- edited_at (timestamp, optional)
- deleted (boolean, optional)
- created_at (timestamp)
- reply_to (message id, optional)
- attachments (optional list)

### Attachment (suggested)
- name / file_name (string)
- url / file_url (string)
- mime / content_type (string, optional)
- size (number, optional)
- is_voice (boolean, optional)

## Backend v3.0 data model (from backend report)

### Table: collective_chats
- id (string, prefixed `group_` or `channel_`)
- type ("group" | "channel")
- members (JSON list of usernames / subscribers)
- updated_at (timestamp for sorting by recent activity)

### Table: group_messages
- chat_id (string)
- text (string, obfuscated)
- reply_to (message id, optional)

## Endpoints (minimum)

### Create group
POST /groups
Body:
- token
- owner (username)
- name
- members (array, optional)

Response:
- group object

### List groups for user
GET /groups?user={username}&token={token}
Response:
- array of group objects

### Add/remove members
POST /groups/{group_id}/members
Body:
- token
- owner (username)
- add (array of usernames)
- remove (array of usernames)

Response:
- updated group

### Add/remove members (backend v3.0 form)
POST /groups/{group_id}/members
Body:
- token
- operator (username)
- action ("add" | "remove")
- target (username)

Response:
- updated group

### Group messages
GET /groups/{group_id}/messages?token={token}&limit=50&after={id}
Response:
- array of messages

POST /groups/{group_id}/messages
Body:
- token
- sender
- text
- reply_to (optional)

Response:
- message object

### Universal collective send (v3.0)
POST /collective/{chat_id}/send
Body:
- token
- sender
- text (obfuscated)
- reply_to (optional)
Notes:
- If `chat_id` is a channel, only `owner` can post

### Universal collective history (v3.0)
GET /collective/{chat_id}/messages?limit=50&user={username}&token={token}
Response:
- array of messages

### Public collective search (v3.0)
GET /search_collective?query={q}
Response:
- array of groups/channels (public)

### Channels (optional MVP)
Same as groups, but:
- only owner/admin can post
- members are subscribers

Endpoints:
- POST /channels
- GET /channels?user={username}&token={token}
- POST /channels/{channel_id}/members (subscribe/unsubscribe)
- GET /channels/{channel_id}/messages
- POST /channels/{channel_id}/messages (admin-only)

## Integrations with existing endpoints

### /get_chats
Add groups/channels into the chat list response. Each item should include:
- id
- name
- type: "user" | "group" | "channel"
- last_message (optional)
- members_count (optional)

Backend v3.0 already returns mixed chat list:
- GET /get_chats
  - items include `type` so frontend can decide icon/behavior

### /get_messages
Option A: keep for user-to-user only.
Option B: allow "chat_id" parameter for groups/channels.

### /send_message
Option A: keep for user-to-user only.
Option B: accept "chat_id" + "type" to send to group/channel.

### /edit_message and /delete_message
The frontend already supports message editing and "delete for all".
If groups/channels are added, consider enabling these operations for them too.

## Auth/permissions
- Token must be required for all group/channel endpoints.
- Only owners/admins can add/remove members.
- Only owners/admins can post in channels.

## Frontend expectations
- The frontend will call:
  - GET /groups to populate group list
  - POST /groups to create
  - GET /groups/{id}/messages to load messages
  - POST /groups/{id}/messages to send
- When /get_chats includes groups, frontend can render them without extra calls.

## Notes
- Consider pagination for messages.
- Consider unread counters in chat list.
- If using obfuscation like current /send_message, apply same to group messages.
- Media must be downloadable with auth for previews and players to work.
- Backend v3.0 already applies obfuscation and pagination for collective messages.
