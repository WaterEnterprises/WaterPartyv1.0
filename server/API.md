# WaterParty API Specification

> **Version:** 1.0  
> **Base URL:** `http://<host>:<port>` (default port `8080`)  
> **Protocol:** HTTP/1.1 + WebSocket (RFC 6455)  
> **Last Updated:** 2026-02-26

---

## Table of Contents

1. [Overview](#overview)
2. [Configuration](#configuration)
3. [Authentication](#authentication)
4. [CORS](#cors)
5. [Data Models](#data-models)
6. [HTTP REST Endpoints](#http-rest-endpoints)
   - [Health Check](#1-health-check)
   - [Register](#2-register)
   - [Login](#3-login)
   - [Profile](#4-profile)
   - [Upload](#5-upload)
   - [Assets](#6-assets)
7. [WebSocket Protocol](#websocket-protocol)
   - [Connection](#connection)
   - [Message Envelope](#message-envelope)
   - [Events Reference](#events-reference)

---

## Overview

WaterParty's backend is a monolithic Go server providing:

- **REST API** for authentication, file uploads, and asset serving.
- **WebSocket API** for all real-time operations: parties, chat, direct messages, notifications, social features, and crowdfunding.

All responses use `application/json` unless otherwise noted. The WebSocket carries JSON-encoded `WSMessage` envelopes.

---

## Configuration

| Environment Variable     | Required | Default | Description                             |
|--------------------------|----------|---------|-----------------------------------------|
| `DATABASE_URL`           | Yes*     | —       | PostgreSQL connection string            |
| `INTERNAL_DATABASE_URL`  | Yes*     | —       | Fallback if `DATABASE_URL` is not set   |
| `PORT`                   | No       | `8080`  | TCP port to listen on                   |

> \* At least one of `DATABASE_URL` or `INTERNAL_DATABASE_URL` must be set.

### Server Timeouts

| Timeout      | Value   |
|--------------|---------|
| Read         | 5s      |
| Write        | 10s     |
| Idle         | 120s    |

---

## Authentication

Authentication is **credential-based** (email + bcrypt password). There is no token/JWT system — the server returns the full `User` object on successful login or registration.

For WebSocket connections, the user is identified by a `uid` query parameter. If omitted, an anonymous session ID is generated.

---

## CORS

All HTTP endpoints (except `/ws` and `/health`) are wrapped with CORS middleware:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: POST, GET, OPTIONS, PUT, DELETE
Access-Control-Allow-Headers: Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization
```

`OPTIONS` requests return `200 OK` with no body.

---

## Data Models

### User

```jsonc
{
  "ID":              "uuid",
  "RealName":        "string",
  "PhoneNumber":     "string",
  "Email":           "string",
  "ProfilePhotos":   ["asset_hash", ...],       // SHA-256 hashes
  "Age":             0,                          // Auto-calculated from DOB
  "DateOfBirth":     "2000-01-15T00:00:00Z",     // ISO 8601, optional
  "HeightCm":        175,
  "Gender":          "string",
  "DrinkingPref":    "string",
  "SmokingPref":     "string",
  "TopArtists":      ["string", ...],
  "JobTitle":        "string",
  "Company":         "string",
  "School":          "string",
  "Degree":          "string",
  "InstagramHandle": "string",
  "LinkedinHandle":  "string",
  "XHandle":         "string",
  "TikTokHandle":    "string",
  "IsVerified":      false,
  "TrustScore":      0.0,
  "EloScore":        0.0,
  "PartiesHosted":   0,
  "FlakeCount":      0,
  "WalletData": {
    "Type": "PayPal",                            // "PayPal", "Bank", "Crypto"
    "Data": "user@example.com"
  },
  "LocationLat":     0.0,
  "LocationLon":     0.0,
  "Bio":             "string",
  "Thumbnail":       "asset_hash",
  "LastActiveAt":    "2026-02-26T14:00:00Z",     // optional
  "CreatedAt":       "2026-02-26T14:00:00Z"      // optional
}
```

> **Note:** `PasswordHash` is never included in JSON responses (tagged `json:"-"`).

---

### Party

```jsonc
{
  "ID":                 "uuid",
  "HostID":             "uuid",
  "Title":              "string",
  "Description":        "string",
  "PartyPhotos":        ["asset_hash", ...],
  "StartTime":          "2026-03-01T20:00:00Z",  // ISO 8601
  "DurationHours":      2,                       // default: 2
  "Status":             "OPEN",                  // OPEN | LOCKED | LIVE | COMPLETED | CANCELLED
  "IsLocationRevealed": false,
  "Address":            "string",
  "City":               "string",
  "GeoLat":             0.0,
  "GeoLon":             0.0,
  "MaxCapacity":        50,
  "CurrentGuestCount":  0,
  "AutoLockOnFull":     false,
  "VibeTags":           ["chill", "house-music"],
  "Rules":              ["No phones", ...],
  "ChatRoomID":         "uuid",
  "Thumbnail":          "asset_hash",
  "RotationPool":       { /* Crowdfunding, optional */ },
  "CreatedAt":          "2026-02-26T14:00:00Z",
  "UpdatedAt":          "2026-02-26T14:00:00Z"
}
```

**PartyStatus enum:** `OPEN`, `LOCKED`, `LIVE`, `COMPLETED`, `CANCELLED`

---

### ChatRoom

```jsonc
{
  "ID":              "uuid",
  "PartyID":         "uuid",
  "HostID":          "uuid",
  "Title":           "string",
  "ImageUrl":        "string",
  "IsGroup":         true,
  "ParticipantIDs":  ["uuid", ...],
  "IsActive":        true,
  "CreatedAt":       "2026-02-26T14:00:00Z",
  "PartyStartTime":  "2026-03-01T20:00:00Z"     // optional
}
```

---

### ChatMessage

```jsonc
{
  "ID":              "uuid",
  "ChatID":          "uuid",
  "SenderID":        "uuid",
  "Type":            "TEXT",                     // TEXT | IMAGE | VIDEO | AUDIO | SYSTEM | AI | PAYMENT
  "Content":         "Hello!",
  "MediaURL":        "asset_hash",
  "ThumbnailURL":    "asset_hash",
  "Metadata":        {},                         // arbitrary JSON
  "ReplyToID":       "uuid",                     // optional
  "CreatedAt":       "2026-02-26T14:00:00Z",
  "SenderName":      "string",                  // populated at broadcast time
  "SenderThumbnail": "asset_hash"               // populated at broadcast time
}
```

**MessageType enum:** `TEXT`, `IMAGE`, `VIDEO`, `AUDIO`, `SYSTEM`, `AI`, `PAYMENT`

---

### Crowdfunding

```jsonc
{
  "ID":            "uuid",
  "PartyID":       "uuid",
  "TargetAmount":  100.00,
  "CurrentAmount": 45.50,
  "Currency":      "USD",
  "Contributors":  [
    { "UserID": "uuid", "Amount": 25.00, "PaidAt": "2026-02-26T14:00:00Z" }
  ],
  "IsFunded":      false
}
```

---

### Notification

```jsonc
{
  "ID":        "uuid",
  "UserID":    "uuid",
  "Type":      "string",
  "Title":     "string",
  "Body":      "string",
  "Data":      "string",
  "IsRead":    false,
  "CreatedAt": "2026-02-26T14:00:00Z"
}
```

---

### PartyAnalytics

```jsonc
{
  "PartyID":           "uuid",
  "TotalViews":        0,
  "TotalApplications": 0,
  "AcceptedCount":     0,
  "PendingCount":      0,
  "DeclinedCount":     0,
  "CurrentGuestCount": 0
}
```

---

## HTTP REST Endpoints

### 1. Health Check

```
GET /health
```

Returns server liveness status. Useful for load balancers and Kubernetes probes.

| Field       | Value |
|-------------|-------|
| **Response** | `200 OK` — body: `OK` (plain text) |

---

### 2. Register

```
POST /register
```

Creates a new user account. Age is auto-calculated from `DateOfBirth`.

#### Request Body

```jsonc
{
  "user": {
    "RealName":        "Jane Doe",
    "PhoneNumber":     "+1234567890",
    "Email":           "jane@example.com",
    "ProfilePhotos":   ["hash1"],
    "DateOfBirth":     "2000-05-15T00:00:00Z",
    "HeightCm":        170,
    "Gender":          "Female",
    "DrinkingPref":    "Social",
    "SmokingPref":     "Never",
    "TopArtists":      ["Dua Lipa"],
    "JobTitle":        "Designer",
    "Company":         "Acme Inc",
    "School":          "MIT",
    "Degree":          "BS CS",
    "InstagramHandle": "@jane",
    "LinkedinHandle":  "jane-doe",
    "XHandle":         "@janedoe",
    "TikTokHandle":    "@jane",
    "Bio":             "Hello world!",
    "WalletData":      { "Type": "PayPal", "Data": "jane@paypal.com" },
    "LocationLat":     40.7128,
    "LocationLon":     -74.0060
  },
  "password": "securepassword123"
}
```

#### Responses

| Status | Body | Description |
|--------|------|-------------|
| `200`  | `User` object (with `ID`, `CreatedAt`) | Account created |
| `400`  | `{"error": "User already registered"}` | Duplicate email |
| `400`  | Plain text error | Malformed JSON |
| `405`  | Plain text error | Non-POST method |
| `500`  | Plain text error | Internal DB error |

---

### 3. Login

```
POST /login
```

Authenticates a user and returns their full profile.

#### Request Body

```json
{
  "email": "jane@example.com",
  "password": "securepassword123"
}
```

> Email is case-insensitive and trimmed before lookup.

#### Responses

| Status | Body | Description |
|--------|------|-------------|
| `200`  | `User` object (password hash cleared) | Valid credentials |
| `401`  | `{"error": "User not found"}` | No account with this email |
| `401`  | `{"error": "Invalid credentials"}` | Wrong password |
| `400`  | Plain text error | Malformed JSON |
| `405`  | Plain text error | Non-POST method |

---

### 4. Profile

```
GET    /profile?id=<uuid>
DELETE /profile?id=<uuid>
```

#### `GET /profile`

Returns a user's public profile by ID.

| Parameter | Location | Required | Description |
|-----------|----------|----------|-------------|
| `id`      | Query    | Yes      | User UUID   |

| Status | Body | Description |
|--------|------|-------------|
| `200`  | `User` object | Found |
| `400`  | Plain text error | Missing `id` |
| `404`  | Plain text error | User not found |

#### `DELETE /profile`

Permanently deletes a user account and all associated data (messages, party applications, chat rooms, hosted parties).

| Status | Body | Description |
|--------|------|-------------|
| `200`  | `{"status": "deleted"}` | Deleted |
| `400`  | Plain text error | Missing `id` |
| `500`  | Plain text error | Deletion failed |

---

### 5. Upload

```
POST /upload
POST /upload?thumbnail=true
```

Uploads a file (max **10 MB**) to the database-backed asset store. Returns the SHA-256 content hash.

#### Request

- **Content-Type:** `multipart/form-data`
- **Form Field:** `file` — the binary file

| Parameter    | Location | Required | Description |
|--------------|----------|----------|-------------|
| `thumbnail`  | Query    | No       | If `"true"`, also generates a 150×150 JPEG thumbnail |

#### Response

```jsonc
{
  "hash":          "sha256hex...",
  "thumbnailHash": "sha256hex..."  // only if thumbnail=true and image is valid
}
```

| Status | Body | Description |
|--------|------|-------------|
| `200`  | JSON with hash(es) | Upload successful |
| `400`  | Plain text error | No file or invalid file |
| `405`  | Plain text error | Non-POST method |
| `500`  | Plain text error | Storage error |

---

### 6. Assets

```
GET /assets/<hash>
```

Serves a previously uploaded asset (image, video, etc.) by its SHA-256 hash.

| Parameter | Location | Required | Description |
|-----------|----------|----------|-------------|
| `hash`    | Path     | Yes      | SHA-256 hex hash |

#### Response Headers

```
Content-Type: <original mime type>
Content-Length: <byte count>
Cache-Control: public, max-age=31536000, immutable
ETag: <hash>
```

| Status | Body | Description |
|--------|------|-------------|
| `200`  | Binary data | Asset found |
| `400`  | Plain text error | Hash missing |
| `404`  | Plain text error | Asset not found |
| `405`  | Plain text error | Non-GET method |

---

## WebSocket Protocol

### Connection

```
ws://<host>:<port>/ws?uid=<user-uuid>
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `uid`     | Recommended | User's UUID. If omitted, an anonymous session ID `anonymous_HHMMSS` is assigned. |

**Connection Parameters:**

| Setting          | Value |
|------------------|-------|
| Read buffer      | 2048 bytes |
| Write buffer     | 2048 bytes |
| Max message size | 4096 bytes |
| Pong wait        | 60s |
| Ping period      | 54s |
| Write wait       | 10s |
| Send buffer      | 256 messages |

**Keep-alive:** The server sends WebSocket `PING` frames every 54s. Clients must respond with `PONG` within 60s or the connection is dropped.

---

### Message Envelope

All WebSocket communication uses a single JSON envelope:

```json
{
  "Event":   "EVENT_NAME",
  "Payload": { ... },
  "Token":   "optional"
}
```

| Field     | Type     | Description                           |
|-----------|----------|---------------------------------------|
| `Event`   | `string` | Event identifier (SCREAMING_SNAKE)    |
| `Payload` | `any`    | Event-specific data                   |
| `Token`   | `string` | Optional auth token (reserved)        |

---

### Events Reference

Events are grouped by domain. For each event:
- **→** = Client sends to server
- **←** = Server sends to client

---

#### Chat Rooms

##### → `JOIN_ROOM`

Join a WebSocket room to receive real-time messages for that chat.

```json
{ "Event": "JOIN_ROOM", "Payload": { "RoomID": "uuid" } }
```

> No response event. The client silently joins the room.

---

##### → `GET_CHATS`

Retrieve all chat rooms the user participates in, with last message preview.

```json
{ "Event": "GET_CHATS", "Payload": null }
```

##### ← `CHATS_LIST`

```jsonc
{
  "Event": "CHATS_LIST",
  "Payload": [
    {
      "ID":                 "uuid",
      "PartyID":            "uuid",
      "HostID":             "uuid",
      "Title":              "Pool Party 🏊",
      "ImageUrl":           "asset_hash",
      "IsGroup":            true,
      "ParticipantIDs":     ["uuid", ...],
      "IsActive":           true,
      "CreatedAt":          "...",
      "RecentMessages":     [],
      "UnreadCount":        0,
      "LastMessageContent": "Hey everyone!",
      "LastMessageAt":      "...",
      "StartTime":          "..."          // party start time, if applicable
    }
  ]
}
```

---

##### → `GET_CHAT_HISTORY`

Fetch paginated message history for a chat room.

```json
{ "Event": "GET_CHAT_HISTORY", "Payload": { "ChatID": "uuid", "Limit": 50 } }
```

> `Limit` defaults to `50` if ≤ 0.

##### ← `CHAT_HISTORY`

```json
{ "Event": "CHAT_HISTORY", "Payload": [ ChatMessage, ... ] }
```

---

#### Messaging

##### → `SEND_MESSAGE`

Send a message to a chat room. The server enriches it with sender info and timestamps.

```jsonc
{
  "Event": "SEND_MESSAGE",
  "Payload": {
    "ChatID":       "uuid",
    "Type":         "TEXT",            // TEXT | IMAGE | VIDEO | AUDIO | SYSTEM | AI | PAYMENT
    "Content":      "Hello!",
    "MediaURL":     "",                // optional asset hash
    "ThumbnailURL": "",                // optional
    "Metadata":     {},                // optional
    "ReplyToID":    ""                 // optional, UUID of message being replied to
  }
}
```

##### ← `NEW_MESSAGE` (broadcast to room)

```json
{ "Event": "NEW_MESSAGE", "Payload": ChatMessage }
```

> Sent to all clients in the `ChatID` room, including the sender.

---

#### Direct Messages

##### → `SEND_DM`

Send a private direct message to another user.

```json
{ "Event": "SEND_DM", "Payload": { "RecipientID": "uuid", "Content": "Hey!" } }
```

> A deterministic DM chat ID is generated: `min(sender,recipient)_max(sender,recipient)`.

##### ← `NEW_MESSAGE` (to sender + recipient only)

Same `NEW_MESSAGE` event as room messages, but delivered only to the sender and recipient.

---

##### → `GET_DMS`

Retrieve the user's direct message conversations.

```json
{ "Event": "GET_DMS", "Payload": null }
```

##### ← `DMS_LIST`

```json
{ "Event": "DMS_LIST", "Payload": [ /* DM conversation objects */ ] }
```

---

##### → `GET_DM_MESSAGES`

Fetch message history for a specific DM conversation.

```json
{ "Event": "GET_DM_MESSAGES", "Payload": { "OtherUserID": "uuid", "Limit": 50 } }
```

##### ← `DM_MESSAGES`

```json
{ "Event": "DM_MESSAGES", "Payload": [ ChatMessage, ... ] }
```

---

##### → `DELETE_DM_MESSAGE`

Delete a message (only the sender's own messages).

```json
{ "Event": "DELETE_DM_MESSAGE", "Payload": { "MessageID": "uuid" } }
```

##### ← `MESSAGE_DELETED`

```json
{ "Event": "MESSAGE_DELETED", "Payload": { "MessageID": "uuid" } }
```

---

#### Parties — Discovery & Feed

##### → `GET_FEED`

Retrieve nearby open parties, excluding parties the user has already swiped on or hosts.

```json
{ "Event": "GET_FEED", "Payload": { "Lat": 40.7128, "Lon": -74.0060, "RadiusKm": 50 } }
```

> `RadiusKm` defaults to `50` if ≤ 0. If `Lat`/`Lon` are both `0`, location filtering is skipped. Results are capped at **50 parties**, ordered by `created_at DESC`.

##### ← `FEED_UPDATE`

```json
{ "Event": "FEED_UPDATE", "Payload": [ Party, ... ] }
```

---

##### → `SWIPE`

Record a swipe action on a party.

```json
{ "Event": "SWIPE", "Payload": { "PartyID": "uuid", "Direction": "right" } }
```

| Direction | Effect |
|-----------|--------|
| `"right"` | Creates a `PENDING` application |
| `"left"`  | Creates a `DECLINED` application |

> This is an upsert — re-swiping updates the status. No response event.

---

##### → `APPLY_TO_PARTY`

Explicitly apply to a party (alternative to swiping right).

```json
{ "Event": "APPLY_TO_PARTY", "Payload": { "PartyID": "uuid" } }
```

> Party must be in `OPEN` status.

##### ← `APPLICATION_SUBMITTED`

```json
{ "Event": "APPLICATION_SUBMITTED", "Payload": { "PartyID": "uuid", "Status": "PENDING" } }
```

---

##### → `REJECT_PARTY`

Explicitly reject a party (alternative to swiping left).

```json
{ "Event": "REJECT_PARTY", "Payload": { "PartyID": "uuid" } }
```

##### ← `APPLICATION_REJECTED`

```json
{ "Event": "APPLICATION_REJECTED", "Payload": { "PartyID": "uuid", "Status": "DECLINED" } }
```

---

#### Parties — Management (Host)

##### → `CREATE_PARTY`

Create a new party. The sender becomes the host.

```jsonc
{
  "Event": "CREATE_PARTY",
  "Payload": {
    "Title":              "Rooftop Vibes 🌆",      // required
    "Description":        "Chill sunset party",
    "PartyPhotos":        ["asset_hash"],            // required, ≥ 1
    "StartTime":          "2026-03-01T20:00:00Z",    // required, ISO 8601
    "DurationHours":      3,                         // default: 2
    "Status":             "OPEN",
    "Address":            "123 Main St",             // required
    "City":               "New York",                // required
    "GeoLat":             40.7128,
    "GeoLon":             -74.0060,
    "MaxCapacity":        50,                        // required, > 0
    "AutoLockOnFull":     true,
    "IsLocationRevealed": false,
    "VibeTags":           ["chill", "sunset"],
    "Rules":              ["No smoking"],
    "ChatRoomID":         "uuid",                    // required, client-generated
    "Thumbnail":          "asset_hash"
  }
}
```

**Validation rules:**
- `Title`, `StartTime`, `ChatRoomID`, `Address`, `City` are required
- `PartyPhotos` must have at least one entry
- `MaxCapacity` must be > 0

**Auto-geocoding:** If `Address` is `"MY CURRENT LOCATION"` or `City` is `"DETECTED ON PUBLISH"`, and coordinates are provided, the server auto-resolves them using Nominatim (OpenStreetMap).

##### ← `PARTY_CREATED` (to creator)

```json
{ "Event": "PARTY_CREATED", "Payload": Party }
```

##### ← `NEW_CHAT_ROOM` (to creator)

```json
{ "Event": "NEW_CHAT_ROOM", "Payload": ChatRoom }
```

##### ← `NEW_PARTY` (global broadcast)

```json
{ "Event": "NEW_PARTY", "Payload": Party }
```

---

##### → `UPDATE_PARTY`

Update a party's details. Only the host can update.

```jsonc
{
  "Event": "UPDATE_PARTY",
  "Payload": {
    "ID":                 "uuid",                   // required
    "Title":              "Updated Title",
    "Description":        "New description",
    "Status":             "OPEN",
    "IsLocationRevealed": true,
    "Address":            "456 Oak Ave",
    "City":               "Brooklyn",
    "MaxCapacity":        100,
    "Thumbnail":          "asset_hash"
  }
}
```

##### ← `PARTY_UPDATED`

```json
{ "Event": "PARTY_UPDATED", "Payload": Party }
```

---

##### → `UPDATE_PARTY_STATUS`

Change a party's lifecycle status. Host-only.

```json
{ "Event": "UPDATE_PARTY_STATUS", "Payload": { "PartyID": "uuid", "Status": "LIVE" } }
```

| Valid Status Values |
|---------------------|
| `LIVE`, `COMPLETED`, `CANCELLED` |

##### ← `PARTY_STATUS_UPDATED` (to host + party room)

```json
{ "Event": "PARTY_STATUS_UPDATED", "Payload": Party }
```

---

##### → `DELETE_PARTY`

Permanently delete a party. Host-only.

```json
{ "Event": "DELETE_PARTY", "Payload": { "PartyID": "uuid" } }
```

##### ← `PARTY_DELETED` (to host + room + global)

```json
{ "Event": "PARTY_DELETED", "Payload": { "PartyID": "uuid", "ChatRoomID": "uuid" } }
```

---

##### → `GET_PARTY_DETAILS`

Fetch full details for a single party.

```json
{ "Event": "GET_PARTY_DETAILS", "Payload": { "PartyID": "uuid" } }
```

##### ← `PARTY_DETAILS`

```json
{ "Event": "PARTY_DETAILS", "Payload": Party }
```

---

##### → `GET_MY_PARTIES` / `GET_MATCHED_PARTIES`

Retrieve parties the user is associated with (hosted or matched). Both event names are equivalent.

```json
{ "Event": "GET_MY_PARTIES", "Payload": null }
```

##### ← `MY_PARTIES`

```json
{ "Event": "MY_PARTIES", "Payload": [ Party, ... ] }
```

---

##### → `GET_PARTY_ANALYTICS`

Get analytics/stats for a party. Host-only.

```json
{ "Event": "GET_PARTY_ANALYTICS", "Payload": { "PartyID": "uuid" } }
```

##### ← `PARTY_ANALYTICS`

```json
{ "Event": "PARTY_ANALYTICS", "Payload": PartyAnalytics }
```

---

#### Parties — Applicants

##### → `GET_APPLICANTS`

Get all applicants for a party (all statuses).

```json
{ "Event": "GET_APPLICANTS", "Payload": { "PartyID": "uuid" } }
```

##### ← `APPLICANTS_LIST`

```jsonc
{
  "Event": "APPLICANTS_LIST",
  "Payload": {
    "PartyID": "uuid",
    "Applicants": [
      {
        "PartyID":   "uuid",
        "UserID":    "uuid",
        "Status":    "PENDING",         // PENDING | ACCEPTED | DECLINED | WAITLIST
        "AppliedAt": "...",
        "User": {
          "ID":            "uuid",
          "RealName":      "string",
          "ProfilePhotos": ["hash"],
          "Age":           25,
          "EloScore":      4.5,
          "Bio":           "string",
          "TrustScore":    0.9,
          "Thumbnail":     "hash"
        }
      }
    ]
  }
}
```

> Results are sorted by `EloScore DESC`.

---

##### → `UPDATE_APPLICATION`

Accept or decline an applicant. Host-only. Accepting auto-adds the user to the party's chat room.

```json
{ "Event": "UPDATE_APPLICATION", "Payload": { "PartyID": "uuid", "UserID": "uuid", "Status": "ACCEPTED" } }
```

| Valid Status Values |
|---------------------|
| `ACCEPTED`, `DECLINED` |

##### ← `APPLICATION_UPDATED` (to host)

```json
{ "Event": "APPLICATION_UPDATED", "Payload": { "PartyID": "uuid", "UserID": "uuid", "Status": "ACCEPTED" } }
```

##### ← `APPLICATION_UPDATED` + `NEW_CHAT_ROOM` (to accepted user, if online)

When a user is accepted, they also receive the chat room details:
```json
{ "Event": "NEW_CHAT_ROOM", "Payload": ChatRoom }
```

---

##### → `GET_MATCHED_USERS`

Get only accepted applicants for a party. Host-only.

```json
{ "Event": "GET_MATCHED_USERS", "Payload": { "PartyID": "uuid" } }
```

##### ← `MATCHED_USERS`

```json
{ "Event": "MATCHED_USERS", "Payload": [ /* same format as APPLICANTS_LIST items */ ] }
```

---

##### → `UNMATCH_USER`

Remove an accepted user from a party (set to DECLINED). Host-only.

```json
{ "Event": "UNMATCH_USER", "Payload": { "PartyID": "uuid", "UserID": "uuid" } }
```

##### ← `USER_UNMATCHED`

```json
{ "Event": "USER_UNMATCHED", "Payload": { "PartyID": "uuid", "UserID": "uuid" } }
```

---

##### → `LEAVE_PARTY`

Leave a party the user was accepted to. Hosts cannot leave — they must delete instead.

```json
{ "Event": "LEAVE_PARTY", "Payload": { "PartyID": "uuid" } }
```

##### ← `PARTY_LEFT`

```json
{ "Event": "PARTY_LEFT", "Payload": { "PartyID": "uuid" } }
```

---

#### User Profile

##### → `GET_USER`

Retrieve the current user's full profile.

```json
{ "Event": "GET_USER", "Payload": null }
```

##### ← `PROFILE_UPDATED`

```json
{ "Event": "PROFILE_UPDATED", "Payload": User }
```

---

##### → `UPDATE_PROFILE`

Update the current user's profile. The server forces the ID to match the WebSocket session's UID.

```jsonc
{
  "Event": "UPDATE_PROFILE",
  "Payload": {
    "RealName":        "Jane Doe",
    "PhoneNumber":     "+1234567890",
    "ProfilePhotos":   ["hash1", "hash2"],
    "Bio":             "Updated bio",
    "LocationLat":     40.7128,
    "LocationLon":     -74.0060,
    "InstagramHandle": "@jane",
    "LinkedinHandle":  "jane-doe",
    "XHandle":         "@janedoe",
    "TikTokHandle":    "@jane",
    "WalletData":      { "Type": "Bank", "Data": "IBAN123" },
    "JobTitle":        "Senior Designer",
    "Company":         "Acme Inc",
    "School":          "MIT",
    "Degree":          "MS CS",
    "Age":             26,
    "HeightCm":        170,
    "Gender":          "Female",
    "DrinkingPref":    "Social",
    "SmokingPref":     "Never",
    "Thumbnail":       "hash"
  }
}
```

##### ← `PROFILE_UPDATED`

```json
{ "Event": "PROFILE_UPDATED", "Payload": User }
```

---

##### → `DELETE_USER`

Delete the current user's account. Users can only delete their own account.

```json
{ "Event": "DELETE_USER", "Payload": { "UserID": "uuid" } }
```

##### ← `USER_DELETED`

```json
{ "Event": "USER_DELETED", "Payload": { "UserID": "uuid" } }
```

---

#### Social Features

##### → `SEARCH_USERS`

Search for users by name.

```json
{ "Event": "SEARCH_USERS", "Payload": { "Query": "Jane", "Limit": 20 } }
```

##### ← `USERS_SEARCH_RESULTS`

```json
{ "Event": "USERS_SEARCH_RESULTS", "Payload": [ User, ... ] }
```

---

##### → `BLOCK_USER`

Block another user. Cannot block yourself.

```json
{ "Event": "BLOCK_USER", "Payload": { "UserID": "uuid" } }
```

##### ← `USER_BLOCKED`

```json
{ "Event": "USER_BLOCKED", "Payload": { "UserID": "uuid" } }
```

---

##### → `UNBLOCK_USER`

Unblock a previously blocked user.

```json
{ "Event": "UNBLOCK_USER", "Payload": { "UserID": "uuid" } }
```

##### ← `USER_UNBLOCKED`

```json
{ "Event": "USER_UNBLOCKED", "Payload": { "UserID": "uuid" } }
```

---

##### → `GET_BLOCKED_USERS`

Get the list of blocked user IDs.

```json
{ "Event": "GET_BLOCKED_USERS", "Payload": null }
```

##### ← `BLOCKED_USERS_LIST`

```json
{ "Event": "BLOCKED_USERS_LIST", "Payload": ["uuid", ...] }
```

---

##### → `REPORT_USER`

Report a user for policy violations.

```json
{ "Event": "REPORT_USER", "Payload": { "UserID": "uuid", "Reason": "Harassment", "Details": "Optional extra info" } }
```

> Both `UserID` and `Reason` are required.

##### ← `USER_REPORTED`

```json
{ "Event": "USER_REPORTED", "Payload": { "UserID": "uuid" } }
```

---

##### → `REPORT_PARTY`

Report a party for policy violations.

```json
{ "Event": "REPORT_PARTY", "Payload": { "PartyID": "uuid", "Reason": "Scam", "Details": "Looks fake" } }
```

> Both `PartyID` and `Reason` are required.

##### ← `PARTY_REPORTED`

```json
{ "Event": "PARTY_REPORTED", "Payload": { "PartyID": "uuid" } }
```

---

#### Geocoding

##### → `REVERSE_GEOCODE`

Convert coordinates to a human-readable address and city using OpenStreetMap Nominatim.

```json
{ "Event": "REVERSE_GEOCODE", "Payload": { "lat": 40.7128, "lon": -74.0060 } }
```

> Both `lat` and `lon` must be non-zero.

##### ← `GEOCODE_RESULT`

```json
{
  "Event": "GEOCODE_RESULT",
  "Payload": {
    "address": "123 Main St, Manhattan, NYC, NY, USA",
    "city":    "New York",
    "lat":     "40.712800",
    "lon":     "-74.006000"
  }
}
```

---

#### Crowdfunding

##### → `ADD_CONTRIBUTION`

Add a monetary contribution to a party's crowdfunding pool.

```json
{ "Event": "ADD_CONTRIBUTION", "Payload": { "PartyID": "uuid", "Amount": 25.00 } }
```

> `Amount` must be > 0.

##### ← `FUNDRAISER_UPDATED` (to contributor + party room)

```json
{ "Event": "FUNDRAISER_UPDATED", "Payload": Crowdfunding }
```

---

##### → `GET_FUNDRAISER_STATE`

Get the current crowdfunding state for a party.

```json
{ "Event": "GET_FUNDRAISER_STATE", "Payload": { "PartyID": "uuid" } }
```

##### ← `FUNDRAISER_STATE`

```json
{ "Event": "FUNDRAISER_STATE", "Payload": Crowdfunding }
```

> If no crowdfunding pool exists, a default empty pool is returned.

---

#### Notifications

##### → `GET_NOTIFICATIONS`

Retrieve the user's 20 most recent notifications.

```json
{ "Event": "GET_NOTIFICATIONS", "Payload": null }
```

##### ← `NOTIFICATIONS_LIST`

```json
{ "Event": "NOTIFICATIONS_LIST", "Payload": [ Notification, ... ] }
```

---

##### → `MARK_NOTIFICATION_READ`

Mark a single notification as read.

```json
{ "Event": "MARK_NOTIFICATION_READ", "Payload": { "NotificationID": "uuid" } }
```

##### ← `NOTIFICATION_MARKED_READ`

```json
{ "Event": "NOTIFICATION_MARKED_READ", "Payload": { "NotificationID": "uuid" } }
```

---

##### → `MARK_ALL_NOTIFICATIONS_READ`

Mark all notifications as read for the current user.

```json
{ "Event": "MARK_ALL_NOTIFICATIONS_READ", "Payload": null }
```

##### ← `ALL_NOTIFICATIONS_MARKED_READ`

```json
{ "Event": "ALL_NOTIFICATIONS_MARKED_READ", "Payload": { "status": "success" } }
```

---

#### Error Handling

All WebSocket errors are sent as:

```json
{
  "Event": "ERROR",
  "Payload": {
    "message": "Human-readable error description",
    "errors":  ["field1 is required", ...]         // optional, for validation
  }
}
```

Errors are sent only to the requesting client, never broadcast.

---

## Database Schema Summary

| Table                | Description                                      |
|----------------------|--------------------------------------------------|
| `users`              | User accounts and profiles                       |
| `parties`            | Party listings                                   |
| `party_applications` | User ↔ Party join requests (PK: party_id, user_id) |
| `chat_rooms`         | Group and DM chat rooms                          |
| `chat_messages`      | All chat messages (group + DM)                   |
| `assets`             | Binary file storage (content-addressed by SHA-256) |
| `crowdfunding`       | Party crowdfunding pools                         |

### Key Indexes

| Index                          | Table           | Column(s)  |
|--------------------------------|-----------------|------------|
| `idx_users_email`              | `users`         | `email`    |
| `idx_parties_status`           | `parties`       | `status`   |
| `idx_parties_host_id`          | `parties`       | `host_id`  |
| `idx_chat_messages_chat_id`    | `chat_messages` | `chat_id`  |
| `idx_assets_hash`              | `assets`        | `hash`     |
