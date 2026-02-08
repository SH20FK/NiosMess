# Backend API Endpoints for Flutter Client

## Authentication

### POST /login
**Description:** User login with username and password
**Request Body (FormData):**
- `username` (string): User's username
- `password` (string): User's password

**Response:**
```json
{
  "token": "string",
  "username": "string"
}
```

### POST /register
**Description:** Register a new user account
**Request Body (JSON):**
```json
{
  "username": "string",
  "password": "string",
  "email": "string" (optional)
}
```

### POST /check_session
**Description:** Validate if session token is still valid
**Request Body (JSON):**
```json
{
  "username": "string",
  "token": "string"
}
```

---

## Chats & Messages

### GET /get_chats
**Description:** Get list of all chats for a user
**Query Parameters:**
- `username` (string): Current user's username
- `token` (string): Session token
- `version` (string): API version (e.g., "1.0")

**Response:**
```json
{
  "chats": [
    {
      "chat_id": "string",
      "name": "string",
      "type": "user|group|channel",
      "unread_count": 0,
      "username": "string",
      "isonline": true,
      "last_seen_text": "string",
      "badge_title": "string",
      "badge_text": "string",
      "badge_icon": "string"
    }
  ]
}
```

### GET /get_messages
**Description:** Get messages between two users (private chat)
**Query Parameters:**
- `me` (string): Current user's username
- `other` (string): Other user's username/chat ID
- `token` (string): Session token

**Response:**
```json
{
  "data": [
    {
      "id": "string",
      "sender": "string",
      "text": "string (obfuscated)",
      "timestamp": "string",
      "reply_to": "string" (optional),
      "is_pinned": false
    }
  ]
}
```

### GET /collective/messages
**Description:** Get messages for a group or channel
**Query Parameters:**
- `chat_id` (string): Group/Channel ID
- `username` (string): Current user's username
- `token` (string): Session token
- `limit` (number): Max messages to return (default: 50)

**Response:**
```json
{
  "messages": [
    {
      "id": "string",
      "sender": "string",
      "text": "string (obfuscated)",
      "timestamp": "string",
      "reply_to": "string" (optional),
      "is_pinned": false
    }
  ]
}
```

### POST /send_message
**Description:** Send a private message to another user
**Request Body (JSON):**
```json
{
  "sender": "string",
  "receiver": "string",
  "text": "string (obfuscated)",
  "token": "string",
  "reply_to": "string" (optional)
}
```

### POST /collective/send
**Description:** Send a message to a group or channel
**Request Body (FormData):**
- `chat_id` (string): Group/Channel ID
- `sender` (string): Sender's username
- `text` (string): Message text (obfuscated)
- `token` (string): Session token
- `reply_to` (string, optional): ID of message being replied to
- `ttl_seconds` (number, optional): Time-to-live for disappearing message

---

## Groups & Channels

### POST /groups/create
**Description:** Create a new group chat
**Request Body (FormData):**
- `name` (string): Group name
- `owner` (string): Owner's username
- `token` (string): Session token

**Response:**
```json
{
  "group_id": "string",
  "name": "string"
}
```

### POST /channels
**Description:** Create a new channel
**Request Body (JSON):**
```json
{
  "name": "string",
  "owner": "string",
  "token": "string"
}
```

### POST /groups/{chat_id}/members
**Description:** Add/remove members from a group
**Request Body (JSON):**
```json
{
  "token": "string",
  "operator": "string",
  "members": ["string"],
  "action": "add|remove"
}
```

### POST /channels/{chat_id}/members
**Description:** Add/remove members from a channel
**Request Body (JSON):** Same as groups

---

## User Profile

### GET /get_user_info
**Description:** Get detailed information about a user
**Query Parameters:**
- `username` (string): Target user's username
- `token` (string): Session token
- `my_username` (string): Current user's username

**Response:**
```json
{
  "username": "string",
  "about": "string",
  "avatar_url": "string",
  "isonline": true,
  "last_seen": "string"
}
```

### POST /set_about
**Description:** Update user's "about" text
**Request Body (FormData):**
- `username` (string): User's username
- `token` (string): Session token
- `about` (string): New about text

### POST /get_av
**Description:** Get user's avatar image
**Request Body (FormData):**
- `other` (string): Target username

**Response:** Binary image data (bytes)

### GET /avatar/{username}
**Description:** Direct URL to user's avatar
**URL Pattern:** `{apiBase}/avatar/{username}`

---

## Sessions Management

### GET /get_sessions
**Description:** Get list of active sessions for user
**Query Parameters:**
- `username` (string): User's username
- `token` (string): Session token

**Response:**
```json
{
  "data": [
    {
      "id": "string",
      "device": "string",
      "ip": "string",
      "created_at": "string"
    }
  ]
}
```

### POST /sessions/logout_other
**Description:** Logout all other sessions except current
**Request Body (JSON):**
```json
{
  "username": "string",
  "token": "string"
}
```

---

## Message Actions

### POST /delete_message
**Description:** Delete a message
**Request Body (JSON):**
```json
{
  "username": "string",
  "token": "string",
  "message_id": "string"
}
```

### POST /edit_message
**Description:** Edit an existing message
**Request Body (JSON):**
```json
{
  "username": "string",
  "token": "string",
  "message_id": "string",
  "text": "string (obfuscated)"
}
```

### POST /messages/pin
**Description:** Pin or unpin a message
**Request Body (FormData):**
- `username` (string): User's username
- `token` (string): Session token
- `chat_id` (string): Chat ID
- `chat_type` (string): "user", "group", or "channel"
- `message_id` (string): Message ID to pin/unpin
- `pinned` (boolean): true to pin, false to unpin

### POST /messages/react
**Description:** Add/remove reaction on a private message
**Request Body (JSON):**
```json
{
  "username": "string",
  "token": "string",
  "message_id": "string",
  "emoji": "string",
  "active": true
}
```

**Response:**
```json
{
  "counts": {"emoji": count},
  "mine": {"emoji": true}
}
```

### POST /collective/react
**Description:** Add/remove reaction on a group/channel message
**Request Body (JSON):**
```json
{
  "username": "string",
  "token": "string",
  "message_id": "string",
  "emoji": "string",
  "active": true,
  "chat_id": "string"
}
```

---

## File Upload

### POST /upload
**Description:** Upload a file (image, audio, document)
**Request Body (FormData):**
- `sender` (string): Sender's username
- `receiver` (string): Receiver's username or chat ID
- `token` (string): Session token
- `file` (File): Binary file data
- `reply_to` (string, optional): Message ID being replied to
- `ttl_seconds` (number, optional): Time-to-live for disappearing file

**Response:**
```json
{
  "filename": "string",
  "url": "string"
}
```

### GET /download/{filename}
**Description:** Download a file
**URL Pattern:** `{apiBase}/download/{filename}`

---

## Message Payload Types

The Flutter client supports special message formats using prefixes:

### POLL
Format: `POLL:{json}`
```json
{
  "id": "poll_timestamp",
  "question": "Question text?",
  "options": [
    {"id": "opt_1", "text": "Option 1"},
    {"id": "opt_2", "text": "Option 2"}
  ],
  "multiple": false
}
```

### LOCATION
Format: `LOCATION:{json}`
```json
{
  "lat": 55.7558,
  "lon": 37.6173,
  "label": "Location name"
}
```

### CONTACT
Format: `CONTACT:{json}`
```json
{
  "name": "Contact Name",
  "phones": ["+1234567890"],
  "emails": ["email@example.com"]
}
```

### MEDIA
Format: `MEDIA:{json}`
```json
{
  "filename": "image.jpg",
  "mime": "image/jpeg"
}
```

### FILE
Format: `FILE:{filename}`

---

## Obfuscation

All message text is obfuscated before sending using a custom obfuscation algorithm. The Flutter client uses `Obfuscator.obfuscate()` before sending and `Obfuscator.deobfuscate()` when receiving messages.

---

## Error Handling

All endpoints return standard HTTP status codes:
- `200` - Success
- `400` - Bad Request (missing parameters)
- `401` - Unauthorized (invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `500` - Server Error

Error responses include:
```json
{
  "detail": "Error message",
  "message": "Error message",
  "error": "Error message"
}
```

---

## Base URL Configuration

The API base URL is configured in `lib/core/constants.dart`:
```dart
class AppConfig {
  static const String apiBase = 'https://your-api-domain.com';
}
```

