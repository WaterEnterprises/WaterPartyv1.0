# WaterParty API Specification

This document provides the complete WebSocket API specification for the WaterParty application.

## Table of Contents

1. [WebSocket Connection](#websocket-connection)
2. [Client-to-Server API (Requests)](#client-to-server-api-requests)
3. [Server-to-Client API (Responses)](#server-to-client-api-responses)
4. [Data Models](#data-models)
5. [Error Handling](#error-handling)
6. [Authentication](#authentication)

---

## WebSocket Connection

### Connection URL

```
ws://<server-address>/ws
```

Authentication is handled by passing the user ID in the WebSocket connection query string:

```
ws://<server-address>/ws?uid=<user-id>
```

### Message Format

All WebSocket messages use a JSON envelope format:

```json
{
  "Event": "EVENT_NAME",
  "Payload": { ... }
}
```

---

## Client-to-Server API (Requests)

The client sends these events to the server to perform actions.

### 1. REVERSE_GEOCODE

Convert latitude and longitude coordinates to city and address using reverse geocoding.

**Request:**
```json
{
  "Event": "REVERSE_GEOCODE",
  "Payload": {
    "Lat": 40.7128,
    "Lon": -74.0060
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Lat | double | Yes | Latitude coordinate |
| Lon | double | Yes | Longitude coordinate |

**Server Response:** [`GEOCODE_RESULT`](#geocode_result)

**Error Response:**
```json
{
  "Event": "ERROR",
  "Payload": {
    "message": "Invalid coordinates: latitude and longitude cannot be zero"
  }
}
```

**Notes:**
- Uses Nominatim (OpenStreetMap) API for reverse geocoding
- Returns full address (display_name) and city name
- Coordinates (0, 0) are rejected as invalid

---

### 2. CREATE_PARTY

Create a new party event.

**Request:**
```json
{
  "Event": "CREATE_PARTY",
  "Payload": {
    "Title": "Party Title",
    "Description": "Party description",
    "StartTime": "2024-12-25T20:00:00Z",
    "DurationHours": 3,
    "Address": "123 Main St",
    "City": "New York",
    "MaxCapacity": 50,
    "PartyPhotos": ["base64 image or URL"],
    "VibeTags": ["chill", "dance"],
    "Rules": ["No smoking", "No drugs"],
    "GeoLat": 40.7128,
    "GeoLon": -74.0060,
    "ChatRoomID": "uuid",
    "Thumbnail": "base64 or URL",
    "AutoLockOnFull": true,
    "IsLocationRevealed": true
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Title | string | Yes | Party title |
| Description | string | Yes | Party description |
| StartTime | string | Yes | Start time in ISO 8601 format |
| DurationHours | int | Yes | Duration in hours (default: 2) |
| Address | string | Yes | Party address (use "MY CURRENT LOCATION" for auto-detect) |
| City | string | Yes | City name (use "DETECTED ON PUBLISH" for auto-detect) |
| MaxCapacity | int | Yes | Maximum number of attendees |
| PartyPhotos | array[string] | Yes | List of party photos (base64 or URLs) - at least one required |
| VibeTags | array[string] | No | List of vibe tags |
| Rules | array[string] | No | List of party rules |
| GeoLat | double | Yes | Geographic latitude |
| GeoLon | double | Yes | Geographic longitude |
| ChatRoomID | string | Yes | UUID for the chat room |
| Thumbnail | string | No | Party thumbnail image |
| AutoLockOnFull | bool | No | Auto-lock party when full |
| IsLocationRevealed | bool | No | Whether location is revealed to applicants |

**Special Address Handling:**
- If `Address` is "MY CURRENT LOCATION", the server auto-detects the address from coordinates
- If `City` is "DETECTED ON PUBLISH", the server auto-detects the city from coordinates

**Server Response:** [`PARTY_CREATED`](#party_created) or [`ERROR`](#error)

---

### 3. SEND_MESSAGE

Send a chat message to a party room.

**Request:**
```json
{
  "Event": "SEND_MESSAGE",
  "Payload": {
    "ChatID": "party-uuid",
    "Content": "Hello everyone!",
    "Type": "text"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| ChatID | string | Yes | The party UUID (chat room ID) |
| Content | string | Yes | Message content |
| Type | string | No | Message type (default: "text") |

**Server Response:** [`NEW_MESSAGE`](#new_message) (broadcast to room)

---

### 4. SEND_DM

Send a direct message to another user.

**Request:**
```json
{
  "Event": "SEND_DM",
  "Payload": {
    "RecipientID": "user-uuid",
    "Content": "Hey!"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| RecipientID | string | Yes | UUID of the recipient user |
| Content | string | Yes | Message content |

**Server Response:** [`NEW_MESSAGE`](#new_message) (sent to recipient and back to sender)

---

### 5. JOIN_ROOM

Join a chat room to receive messages from that room.

**Request:**
```json
{
  "Event": "JOIN_ROOM",
  "Payload": {
    "RoomID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| RoomID | string | Yes | UUID of the party/chat room |

---

### 6. GET_CHATS

Get all chat rooms for the current user.

**Request:**
```json
{
  "Event": "GET_CHATS"
}
```

**Server Response:** [`CHATS_LIST`](#chats_list)

---

### 7. GET_MY_PARTIES

Get parties created by the current user.

**Request:**
```json
{
  "Event": "GET_MY_PARTIES"
}
```

**Server Response:** [`MY_PARTIES`](#my_parties)

---

### 8. GET_MATCHED_PARTIES

Get parties matched to the current user.

**Request:**
```json
{
  "Event": "GET_MATCHED_PARTIES"
}
```

**Server Response:** [`MY_PARTIES`](#my_parties) (with matched parties)

---

### 9. UPDATE_PROFILE

Update the current user's profile.

**Request:**
```json
{
  "Event": "UPDATE_PROFILE",
  "Payload": {
    "RealName": "John Doe",
    "Bio": "Looking for parties!",
    "Thumbnail": "base64 or URL"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| RealName | string | No | User's real name |
| Bio | string | No | User's bio |
| Thumbnail | string | No | Profile thumbnail (base64 or URL) |

**Server Response:** [`PROFILE_UPDATED`](#profile_updated)

---

### 10. GET_USER

Get the current user's profile.

**Request:**
```json
{
  "Event": "GET_USER"
}
```

**Server Response:** [`PROFILE_UPDATED`](#profile_updated)

---

### 11. SWIPE

Swipe on a party (like or pass).

**Request:**
```json
{
  "Event": "SWIPE",
  "Payload": {
    "PartyID": "party-uuid",
    "Direction": "right"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |
| Direction | string | Yes | "right" for like/pending, "left" for pass/declined |

**Server Response:** No direct response (application saved to database)

---

### 12. GET_FEED

Get a feed of nearby parties.

**Request:**
```json
{
  "Event": "GET_FEED",
  "Payload": {
    "Lat": 40.7128,
    "Lon": -74.0060,
    "RadiusKm": 50
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Lat | double | No | Current latitude (if 0, returns all parties) |
| Lon | double | No | Current longitude (if 0, returns all parties) |
| RadiusKm | double | No | Search radius in kilometers (default: 50) |

**Server Response:** [`FEED_UPDATE`](#feed_update)

---

### 13. DELETE_PARTY

Delete a party (host only).

**Request:**
```json
{
  "Event": "DELETE_PARTY",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party to delete |

**Server Response:** [`PARTY_DELETED`](#party_deleted)

**Notes:**
- Only the party host can delete the party
- Broadcasts to party chat room and globally

---

### 14. GET_APPLICANTS

Get list of applicants for a party (host only).

**Request:**
```json
{
  "Event": "GET_APPLICANTS",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`APPLICANTS_LIST`](#applicants_list)

---

### 15. UPDATE_APPLICATION

Accept or reject a party application (host only).

**Request:**
```json
{
  "Event": "UPDATE_APPLICATION",
  "Payload": {
    "PartyID": "party-uuid",
    "UserID": "user-uuid",
    "Status": "ACCEPTED"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |
| UserID | string | Yes | UUID of the applicant |
| Status | string | Yes | "ACCEPTED" or "DECLINED" |

**Server Response:** [`APPLICATION_UPDATED`](#application_updated)

**Notes:**
- If accepted, notifies the user and sends them the chat room details

---

### 16. APPLY_TO_PARTY

Apply to join a party.

**Request:**
```json
{
  "Event": "APPLY_TO_PARTY",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`APPLICATION_SUBMITTED`](#application_submitted)

**Notes:**
- Cannot apply to parties that are not OPEN
- Cannot apply to your own party

---

### 17. REJECT_PARTY

Reject/ignore a party (set application status to DECLINED).

**Request:**
```json
{
  "Event": "REJECT_PARTY",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`APPLICATION_REJECTED`](#application_rejected)

---

### 18. LEAVE_PARTY

Leave a party (for non-hosts). Hosts cannot leave - they must delete the party.

**Request:**
```json
{
  "Event": "LEAVE_PARTY",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`PARTY_LEFT`](#party_left) or [`ERROR`](#error)

**Notes:**
- Hosts cannot leave - they must delete the party instead

---

### 19. GET_PARTY_DETAILS

Get detailed information about a party.

**Request:**
```json
{
  "Event": "GET_PARTY_DETAILS",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`PARTY_DETAILS`](#party_details)

---

### 20. GET_CHAT_HISTORY

Get chat history for a party room.

**Request:**
```json
{
  "Event": "GET_CHAT_HISTORY",
  "Payload": {
    "ChatID": "party-uuid",
    "Limit": 50
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| ChatID | string | Yes | UUID of the chat room |
| Limit | int | No | Maximum number of messages (default: 50) |

**Server Response:** [`CHAT_HISTORY`](#chat_history)

---

### 21. GET_MATCHED_USERS

Get list of matched/accepted users for a party (host only).

**Request:**
```json
{
  "Event": "GET_MATCHED_USERS",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`MATCHED_USERS`](#matched_users)

---

### 22. UPDATE_PARTY

Update an existing party (host only).

**Request:**
```json
{
  "Event": "UPDATE_PARTY",
  "Payload": {
    "ID": "party-uuid",
    "Title": "Updated Title",
    "Description": "Updated description",
    "StartTime": "2024-12-25T20:00:00Z",
    "DurationHours": 4,
    "Address": "456 New St",
    "City": "Boston",
    "MaxCapacity": 75,
    "PartyPhotos": ["url1", "url2"],
    "VibeTags": ["chill", "dance", "music"],
    "Rules": ["No smoking"],
    "GeoLat": 42.3601,
    "GeoLon": -71.0589,
    "AutoLockOnFull": true,
    "IsLocationRevealed": false,
    "Thumbnail": "base64 or URL"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| ID | string | Yes | UUID of the party to update |
| Title | string | No | Party title |
| Description | string | No | Party description |
| StartTime | string | No | Start time in ISO 8601 format |
| DurationHours | int | No | Duration in hours |
| Address | string | No | Party address |
| City | string | No | City name |
| MaxCapacity | int | No | Maximum number of attendees |
| PartyPhotos | array[string] | No | List of party photos |
| VibeTags | array[string] | No | List of vibe tags |
| Rules | array[string] | No | List of party rules |
| GeoLat | double | No | Geographic latitude |
| GeoLon | double | No | Geographic longitude |
| AutoLockOnFull | bool | No | Auto-lock party when full |
| IsLocationRevealed | bool | No | Whether location is revealed |
| Thumbnail | string | No | Party thumbnail |

**Server Response:** [`PARTY_UPDATED`](#party_updated)

---

### 23. UNMATCH_USER

Remove a matched user from a party (host only).

**Request:**
```json
{
  "Event": "UNMATCH_USER",
  "Payload": {
    "PartyID": "party-uuid",
    "UserID": "user-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |
| UserID | string | Yes | UUID of the user to unmatch |

**Server Response:** [`USER_UNMATCHED`](#user_unmatched)

---

### 24. DELETE_USER

Delete the current user's account.

**Request:**
```json
{
  "Event": "DELETE_USER",
  "Payload": {
    "UserID": "user-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| UserID | string | Yes | UUID of the user to delete (must be own ID) |

**Server Response:** [`USER_DELETED`](#user_deleted)

---

### 25. GET_DMS

Get all direct message conversations for the current user.

**Request:**
```json
{
  "Event": "GET_DMS"
}
```

**Server Response:** [`DMS_LIST`](#dms_list)

---

### 26. GET_DM_MESSAGES

Get direct message history with another user.

**Request:**
```json
{
  "Event": "GET_DM_MESSAGES",
  "Payload": {
    "OtherUserID": "user-uuid",
    "Limit": 50
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| OtherUserID | string | Yes | UUID of the other user |
| Limit | int | No | Maximum number of messages (default: 50) |

**Server Response:** [`DM_MESSAGES`](#dm_messages)

---

### 27. DELETE_DM_MESSAGE

Delete a direct message.

**Request:**
```json
{
  "Event": "DELETE_DM_MESSAGE",
  "Payload": {
    "MessageID": "message-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| MessageID | string | Yes | UUID of the message to delete |

**Server Response:** [`MESSAGE_DELETED`](#message_deleted)

---

### 28. ADD_CONTRIBUTION

Add a monetary contribution to a party's fundraiser/rotation pool.

**Request:**
```json
{
  "Event": "ADD_CONTRIBUTION",
  "Payload": {
    "PartyID": "party-uuid",
    "Amount": 10.00
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |
| Amount | double | Yes | Contribution amount (must be > 0) |

**Server Response:** [`FUNDRAISER_UPDATED`](#fundraiser_updated)

**Notes:**
- Broadcasts updated pool state to party chat room

---

### 29. GET_FUNDRAISER_STATE

Get the current state of a party's fundraiser.

**Request:**
```json
{
  "Event": "GET_FUNDRAISER_STATE",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`FUNDRAISER_STATE`](#fundraiser_state)

---

### 30. GET_NOTIFICATIONS

Get notifications for the current user.

**Request:**
```json
{
  "Event": "GET_NOTIFICATIONS"
}
```

**Server Response:** [`NOTIFICATIONS_LIST`](#notifications_list)

---

### 31. MARK_NOTIFICATION_READ

Mark a notification as read.

**Request:**
```json
{
  "Event": "MARK_NOTIFICATION_READ",
  "Payload": {
    "NotificationID": "notification-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| NotificationID | string | Yes | UUID of the notification |

**Server Response:** [`NOTIFICATION_MARKED_READ`](#notification_marked_read)

---

### 32. MARK_ALL_NOTIFICATIONS_READ

Mark all notifications as read.

**Request:**
```json
{
  "Event": "MARK_ALL_NOTIFICATIONS_READ"
}
```

**Server Response:** [`ALL_NOTIFICATIONS_MARKED_READ`](#all_notifications_marked_read)

---

### 33. SEARCH_USERS

Search for users by name.

**Request:**
```json
{
  "Event": "SEARCH_USERS",
  "Payload": {
    "Query": "John",
    "Limit": 20
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Query | string | Yes | Search query |
| Limit | int | No | Maximum results (default: 20) |

**Server Response:** [`USERS_SEARCH_RESULTS`](#users_search_results)

---

### 34. BLOCK_USER

Block a user.

**Request:**
```json
{
  "Event": "BLOCK_USER",
  "Payload": {
    "UserID": "user-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| UserID | string | Yes | UUID of the user to block |

**Server Response:** [`USER_BLOCKED`](#user_blocked)

**Notes:**
- Cannot block yourself

---

### 35. UNBLOCK_USER

Unblock a user.

**Request:**
```json
{
  "Event": "UNBLOCK_USER",
  "Payload": {
    "UserID": "user-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| UserID | string | Yes | UUID of the user to unblock |

**Server Response:** [`USER_UNBLOCKED`](#user_unblocked)

---

### 36. GET_BLOCKED_USERS

Get list of blocked user IDs.

**Request:**
```json
{
  "Event": "GET_BLOCKED_USERS"
}
```

**Server Response:** [`BLOCKED_USERS_LIST`](#blocked_users_list)

---

### 37. REPORT_USER

Report a user for violations.

**Request:**
```json
{
  "Event": "REPORT_USER",
  "Payload": {
    "UserID": "user-uuid",
    "Reason": "inappropriate behavior",
    "Details": "Additional details..."
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| UserID | string | Yes | UUID of the user to report |
| Reason | string | Yes | Reason for report |
| Details | string | No | Additional details |

**Server Response:** [`USER_REPORTED`](#user_reported)

---

### 38. REPORT_PARTY

Report a party for violations.

**Request:**
```json
{
  "Event": "REPORT_PARTY",
  "Payload": {
    "PartyID": "party-uuid",
    "Reason": "inappropriate content",
    "Details": "Additional details..."
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party to report |
| Reason | string | Yes | Reason for report |
| Details | string | No | Additional details |

**Server Response:** [`PARTY_REPORTED`](#party_reported)

---

### 39. GET_PARTY_ANALYTICS

Get analytics for a party (host only).

**Request:**
```json
{
  "Event": "GET_PARTY_ANALYTICS",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |

**Server Response:** [`PARTY_ANALYTICS`](#party_analytics)

---

### 40. UPDATE_PARTY_STATUS

Update party status (host only).

**Request:**
```json
{
  "Event": "UPDATE_PARTY_STATUS",
  "Payload": {
    "PartyID": "party-uuid",
    "Status": "LIVE"
  }
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| PartyID | string | Yes | UUID of the party |
| Status | string | Yes | "LIVE", "COMPLETED", or "CANCELLED" |

**Server Response:** [`PARTY_STATUS_UPDATED`](#party_status_updated)

**Notes:**
- Broadcasts status change to party chat room

---

## Server-to-Client API (Responses)

The server sends these events to the client to notify of updates.

### 1. NEW_MESSAGE

New chat message received.

**Payload:**
```json
{
  "Event": "NEW_MESSAGE",
  "Payload": {
    "ChatID": "chat-room-uuid",
    "SenderID": "user-uuid",
    "SenderName": "John",
    "SenderThumbnail": "base64 or URL",
    "Content": "Hello!",
    "Type": "text",
    "CreatedAt": "2024-12-25T20:00:00Z"
  }
}
```

---

### 2. NEW_PARTY

New party created (global broadcast).

**Payload:**
```json
{
  "Event": "NEW_PARTY",
  "Payload": { ...Party object... }
}
```

---

### 3. PARTY_CREATED

Confirmation of party creation.

**Payload:**
```json
{
  "Event": "PARTY_CREATED",
  "Payload": {
    "ID": "party-uuid",
    "HostID": "user-uuid",
    "Title": "Party Title",
    "Description": "Party description",
    "StartTime": "2024-12-25T20:00:00Z",
    "DurationHours": 3,
    "Status": "OPEN",
    "Address": "123 Main St",
    "City": "New York",
    "MaxCapacity": 50,
    "CurrentGuestCount": 0,
    "PartyPhotos": ["base64 or URL"],
    "VibeTags": ["chill", "dance"],
    "Rules": ["No smoking"],
    "GeoLat": 40.7128,
    "GeoLon": -74.0060,
    "IsLocationRevealed": true,
    "AutoLockOnFull": true,
    "ChatRoomID": "uuid",
    "Thumbnail": "base64 or URL",
    "CreatedAt": "2024-12-20T10:00:00Z",
    "UpdatedAt": "2024-12-20T10:00:00Z"
  }
}
```

---

### 4. NEW_CHAT_ROOM

New chat room available.

**Payload:**
```json
{
  "Event": "NEW_CHAT_ROOM",
  "Payload": {
    "ID": "chat-room-uuid",
    "PartyID": "party-uuid",
    "Title": "Party Chat",
    "LastMessage": "See you there!",
    "LastMessageTime": "2024-12-25T19:00:00Z",
    "UnreadCount": 0
  }
}
```

---

### 5. CHATS_LIST

List of user's chat rooms.

**Payload:**
```json
{
  "Event": "CHATS_LIST",
  "Payload": [
    {
      "ID": "chat-room-uuid",
      "PartyID": "party-uuid",
      "Title": "Party Chat",
      "LastMessage": "See you there!",
      "LastMessageTime": "2024-12-25T19:00:00Z",
      "UnreadCount": 0
    }
  ]
}
```

---

### 6. MY_PARTIES

User's parties list (created or matched).

**Payload:**
```json
{
  "Event": "MY_PARTIES",
  "Payload": [
    { ...Party object... }
  ]
}
```

---

### 7. PROFILE_UPDATED

Profile update confirmation or user data fetch result.

**Payload:**
```json
{
  "Event": "PROFILE_UPDATED",
  "Payload": {
    "ID": "user-uuid",
    "RealName": "John Doe",
    "Bio": "Looking for parties!",
    "Thumbnail": "base64 or URL"
  }
}
```

---

### 8. GEOCODE_RESULT

Reverse geocoding result.

**Payload:**
```json
{
  "Event": "GEOCODE_RESULT",
  "Payload": {
    "address": "New York, NY, United States",
    "city": "New York",
    "lat": "40.712800",
    "lon": "-74.006000"
  }
}
```

---

### 9. ERROR

Error message.

**Payload:**
```json
{
  "Event": "ERROR",
  "Payload": {
    "message": "Error description",
    "errors": ["error1", "error2"]
  }
}
```

---

### 10. FEED_UPDATE

Feed of nearby parties update.

**Payload:**
```json
{
  "Event": "FEED_UPDATE",
  "Payload": [
    { ...Party object... }
  ]
}
```

---

### 11. PARTY_DELETED

Party has been deleted.

**Payload:**
```json
{
  "Event": "PARTY_DELETED",
  "Payload": {
    "PartyID": "party-uuid",
    "ChatRoomID": "chat-room-uuid"
  }
}
```

---

### 12. APPLICANTS_LIST

List of party applicants (for host).

**Payload:**
```json
{
  "Event": "APPLICANTS_LIST",
  "Payload": {
    "PartyID": "party-uuid",
    "Applicants": [
      {
        "UserID": "user-uuid",
        "UserName": "John",
        "UserThumbnail": "base64 or URL",
        "Status": "PENDING"
      }
    ]
  }
}
```

---

### 13. APPLICATION_UPDATED

Application status updated.

**Payload:**
```json
{
  "Event": "APPLICATION_UPDATED",
  "Payload": {
    "PartyID": "party-uuid",
    "UserID": "user-uuid",
    "Status": "ACCEPTED"
  }
}
```

---

### 14. APPLICATION_SUBMITTED

Application submitted to a party.

**Payload:**
```json
{
  "Event": "APPLICATION_SUBMITTED",
  "Payload": {
    "PartyID": "party-uuid",
    "Status": "PENDING"
  }
}
```

---

### 15. APPLICATION_REJECTED

Application rejected/party rejected.

**Payload:**
```json
{
  "Event": "APPLICATION_REJECTED",
  "Payload": {
    "PartyID": "party-uuid",
    "Status": "DECLINED"
  }
}
```

---

### 16. PARTY_LEFT

User has left a party.

**Payload:**
```json
{
  "Event": "PARTY_LEFT",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

---

### 17. PARTY_DETAILS

Detailed party information.

**Payload:**
```json
{
  "Event": "PARTY_DETAILS",
  "Payload": { ...Party object... }
}
```

---

### 18. CHAT_HISTORY

Chat message history.

**Payload:**
```json
{
  "Event": "CHAT_HISTORY",
  "Payload": [
    {
      "ChatID": "chat-room-uuid",
      "SenderID": "user-uuid",
      "SenderName": "John",
      "SenderThumbnail": "base64 or URL",
      "Content": "Hello!",
      "Type": "text",
      "CreatedAt": "2024-12-25T20:00:00Z"
    }
  ]
}
```

---

### 19. MATCHED_USERS

List of matched users for a party.

**Payload:**
```json
{
  "Event": "MATCHED_USERS",
  "Payload": [
    {
      "UserID": "user-uuid",
      "UserName": "John",
      "UserThumbnail": "base64 or URL",
      "Status": "ACCEPTED"
    }
  ]
}
```

---

### 20. PARTY_UPDATED

Party has been updated.

**Payload:**
```json
{
  "Event": "PARTY_UPDATED",
  "Payload": { ...Party object... }
}
```

---

### 21. USER_UNMATCHED

User has been unmatched from a party.

**Payload:**
```json
{
  "Event": "USER_UNMATCHED",
  "Payload": {
    "PartyID": "party-uuid",
    "UserID": "user-uuid"
  }
}
```

---

### 22. USER_DELETED

User account has been deleted.

**Payload:**
```json
{
  "Event": "USER_DELETED",
  "Payload": {
    "UserID": "user-uuid"
  }
}
```

---

### 23. DMS_LIST

List of direct message conversations.

**Payload:**
```json
{
  "Event": "DMS_LIST",
  "Payload": [
    {
      "ChatID": "user1-user2-uuid",
      "OtherUserID": "user-uuid",
      "OtherUserName": "John",
      "OtherUserThumbnail": "base64 or URL",
      "LastMessage": "Hey!",
      "LastMessageTime": "2024-12-25T20:00:00Z",
      "UnreadCount": 0
    }
  ]
}
```

---

### 24. DM_MESSAGES

Direct message history.

**Payload:**
```json
{
  "Event": "DM_MESSAGES",
  "Payload": [
    {
      "ChatID": "user1-user2-uuid",
      "SenderID": "user-uuid",
      "SenderName": "John",
      "Content": "Hey!",
      "Type": "text",
      "CreatedAt": "2024-12-25T20:00:00Z"
    }
  ]
}
```

---

### 25. MESSAGE_DELETED

Message has been deleted.

**Payload:**
```json
{
  "Event": "MESSAGE_DELETED",
  "Payload": {
    "MessageID": "message-uuid"
  }
}
```

---

### 26. FUNDRAISER_UPDATED

Fundraiser/pool state updated after contribution.

**Payload:**
```json
{
  "Event": "FUNDRAISER_UPDATED",
  "Payload": {
    "PartyID": "party-uuid",
    "Currency": "USD",
    "TotalAmount": 100.00,
    "IsFunded": true,
    "Contributions": [
      {
        "UserID": "user-uuid",
        "Amount": 10.00,
        "PaidAt": "2024-12-25T20:00:00Z"
      }
    ]
  }
}
```

---

### 27. FUNDRAISER_STATE

Current state of a party's fundraiser.

**Payload:**
```json
{
  "Event": "FUNDRAISER_STATE",
  "Payload": {
    "PartyID": "party-uuid",
    "Currency": "USD",
    "TotalAmount": 100.00,
    "IsFunded": true,
    "Contributions": [...]
  }
}
```

---

### 28. NOTIFICATIONS_LIST

User's notifications.

**Payload:**
```json
{
  "Event": "NOTIFICATIONS_LIST",
  "Payload": [
    {
      "ID": "notification-uuid",
      "UserID": "user-uuid",
      "Type": "application_accepted",
      "Title": "Application Accepted",
      "Message": "Your application to Party Title has been accepted!",
      "PartyID": "party-uuid",
      "IsRead": false,
      "CreatedAt": "2024-12-25T20:00:00Z"
    }
  ]
}
```

---

### 29. NOTIFICATION_MARKED_READ

Notification marked as read.

**Payload:**
```json
{
  "Event": "NOTIFICATION_MARKED_READ",
  "Payload": {
    "NotificationID": "notification-uuid"
  }
}
```

---

### 30. ALL_NOTIFICATIONS_MARKED_READ

All notifications marked as read.

**Payload:**
```json
{
  "Event": "ALL_NOTIFICATIONS_MARKED_READ",
  "Payload": {
    "status": "success"
  }
}
```

---

### 31. USERS_SEARCH_RESULTS

User search results.

**Payload:**
```json
{
  "Event": "USERS_SEARCH_RESULTS",
  "Payload": [
    {
      "ID": "user-uuid",
      "RealName": "John Doe",
      "Thumbnail": "base64 or URL"
    }
  ]
}
```

---

### 32. USER_BLOCKED

User has been blocked.

**Payload:**
```json
{
  "Event": "USER_BLOCKED",
  "Payload": {
    "UserID": "user-uuid"
  }
}
```

---

### 33. USER_UNBLOCKED

User has been unblocked.

**Payload:**
```json
{
  "Event": "USER_UNBLOCKED",
  "Payload": {
    "UserID": "user-uuid"
  }
}
```

---

### 34. BLOCKED_USERS_LIST

List of blocked user IDs.

**Payload:**
```json
{
  "Event": "BLOCKED_USERS_LIST",
  "Payload": ["user-uuid-1", "user-uuid-2"]
}
```

---

### 35. USER_REPORTED

User report submitted.

**Payload:**
```json
{
  "Event": "USER_REPORTED",
  "Payload": {
    "UserID": "user-uuid"
  }
}
```

---

### 36. PARTY_REPORTED

Party report submitted.

**Payload:**
```json
{
  "Event": "PARTY_REPORTED",
  "Payload": {
    "PartyID": "party-uuid"
  }
}
```

---

### 37. PARTY_ANALYTICS

Party analytics data (for host).

**Payload:**
```json
{
  "Event": "PARTY_ANALYTICS",
  "Payload": {
    "PartyID": "party-uuid",
    "TotalViews": 150,
    "TotalApplications": 25,
    "AcceptedCount": 20,
    "RejectedCount": 5,
    "PendingCount": 0,
    "MessagesCount": 50,
    "UniqueChatters": 15
  }
}
```

---

### 38. PARTY_STATUS_UPDATED

Party status has been updated.

**Payload:**
```json
{
  "Event": "PARTY_STATUS_UPDATED",
  "Payload": { ...Party object with updated status... }
}
```

---

## Data Models

### Party

```json
{
  "ID": "uuid",
  "HostID": "user-uuid",
  "Title": "Party Title",
  "Description": "Party description",
  "StartTime": "2024-12-25T20:00:00Z",
  "DurationHours": 3,
  "Status": "OPEN",
  "Address": "123 Main St",
  "City": "New York",
  "MaxCapacity": 50,
  "CurrentGuestCount": 10,
  "PartyPhotos": ["url1", "url2"],
  "VibeTags": ["chill", "dance"],
  "Rules": ["No smoking"],
  "GeoLat": 40.7128,
  "GeoLon": -74.0060,
  "IsLocationRevealed": true,
  "AutoLockOnFull": true,
  "ChatRoomID": "uuid",
  "Thumbnail": "base64 or URL",
  "CreatedAt": "2024-12-20T10:00:00Z",
  "UpdatedAt": "2024-12-20T10:00:00Z"
}
```

### ChatRoom

```json
{
  "ID": "uuid",
  "PartyID": "party-uuid",
  "Title": "Party Chat",
  "LastMessage": "See you there!",
  "LastMessageTime": "2024-12-25T19:00:00Z",
  "UnreadCount": 0
}
```

### ChatMessage

```json
{
  "ChatID": "chat-room-uuid",
  "SenderID": "user-uuid",
  "SenderName": "John",
  "SenderThumbnail": "base64 or URL",
  "Content": "Hello!",
  "Type": "text",
  "CreatedAt": "2024-12-25T20:00:00Z"
}
```

### User

```json
{
  "ID": "uuid",
  "RealName": "John Doe",
  "Bio": "Looking for parties!",
  "Thumbnail": "base64 or URL"
}
```

### PartyApplication

```json
{
  "UserID": "user-uuid",
  "UserName": "John",
  "UserThumbnail": "base64 or URL",
  "Status": "PENDING"
}
```

### Notification

```json
{
  "ID": "uuid",
  "UserID": "user-uuid",
  "Type": "application_accepted",
  "Title": "Application Accepted",
  "Message": "Your application to Party Title has been accepted!",
  "PartyID": "party-uuid",
  "IsRead": false,
  "CreatedAt": "2024-12-25T20:00:00Z"
}
```

### Contribution

```json
{
  "UserID": "user-uuid",
  "Amount": 10.00,
  "PaidAt": "2024-12-25T20:00:00Z"
}
```

---

## Error Handling

Errors are returned with the `ERROR` event. Common error messages include:

| Error Message | Description |
|---------------|-------------|
| Invalid coordinates: latitude and longitude cannot be zero | Invalid geocoding request |
| Party not found | Party ID doesn't exist |
| Not authorized | User doesn't have permission |
| Party is not accepting applications | Party status is not OPEN |
| Host cannot leave party, please delete instead | Host tried to leave their own party |
| Not authorized to edit this party | User is not the party host |
| Not authorized to view matched users | User is not the party host |
| Not authorized to unmatch users | User is not the party host |
| Not authorized to view analytics | User is not the party host |
| Failed to create party | Database error during party creation |
| Failed to update party | Database error during party update |
| Failed to delete party | Database error during party deletion |
| Failed to apply to party | Database error during application |
| Failed to delete message | Database error during message deletion |

---

## Authentication

Authentication is handled via user ID passed in the WebSocket connection query string:

```
ws://<server-address>/ws?uid=<user-id>
```

The server validates the user ID on connection and associates the WebSocket connection with the authenticated user. All requests are then processed in the context of that user.

---

## Technology Stack

- **Language**: Go (server), Dart/Flutter (client)
- **WebSocket**: gorilla/websocket (Go), web_socket_channel (Flutter)
- **Database**: PostgreSQL (jackc/pgx)
- **Geocoding**: Nominatim (OpenStreetMap)

---

*Generated from WaterParty server implementation*
