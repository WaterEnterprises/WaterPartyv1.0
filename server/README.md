# WaterParty Server API Documentation

This document describes the WebSocket API coverage for the WaterParty server.

## WebSocket Connection

Connect to: `ws://<server-address>/ws`

The WebSocket uses a JSON envelope format:
```json
{
  "Event": "EVENT_NAME",
  "Payload": { ... }
}
```

---

## API Coverage

### 1. REVERSE_GEOCODE
**Description**: Convert latitude and longitude coordinates to city and address using reverse geocoding.

**Request**:
```json
{
  "Event": "REVERSE_GEOCODE",
  "Payload": {
    "Lat": 40.7128,
    "Lon": -74.0060
  }
}
```

**Response**:
```json
{
  "Event": "GEOCODE_RESULT",
  "Payload": {
    "Address": "New York, NY, United States",
    "City": "New York",
    "Lat": "40.712800",
    "Lon": "-74.006000"
  }
}
```

**Error Response**:
```json
{
  "Event": "ERROR",
  "Payload": {
    "message": "Invalid coordinates: latitude and longitude cannot be zero"
  }
}
```

**Notes**:
- Uses Nominatim (OpenStreetMap) API for reverse geocoding
- Returns full address (display_name) and city name
- Coordinates (0, 0) are rejected as invalid

---

### 2. CREATE_PARTY
**Description**: Create a new party event.

**Request**:
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
    "GeoLat": 40.7128,
    "GeoLon": -74.0060,
    "ChatRoomID": "uuid"
  }
}
```

**Special Address Handling**:
- If `Address` is "MY CURRENT LOCATION", the server will auto-detect the address from coordinates
- If `City` is "DETECTED ON PUBLISH", the server will auto-detect the city from coordinates

---

### 3. SEND_MESSAGE
**Description**: Send a chat message to a party room.

**Request**:
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

---

### 4. SEND_DM
**Description**: Send a direct message to another user.

**Request**:
```json
{
  "Event": "SEND_DM",
  "Payload": {
    "RecipientID": "user-uuid",
    "Content": "Hey!"
  }
}
```

---

### 5. JOIN_ROOM
**Description**: Join a chat room.

**Request**:
```json
{
  "Event": "JOIN_ROOM",
  "Payload": {
    "RoomID": "party-uuid"
  }
}
```

---

### 6. GET_CHATS
**Description**: Get all chat rooms for the current user.

**Request**:
```json
{
  "Event": "GET_CHATS"
}
```

---

### 7. GET_MY_PARTIES / GET_MATCHED_PARTIES
**Description**: Get parties created by or matched to the current user.

**Request**:
```json
{
  "Event": "GET_MY_PARTIES"
}
```

or

```json
{
  "Event": "GET_MATCHED_PARTIES"
}
```

---

### 8. UPDATE_PROFILE
**Description**: Update the current user's profile.

**Request**:
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

---

### 9. GET_USER
**Description**: Get the current user's profile.

**Request**:
```json
{
  "Event": "GET_USER"
}
```

---

### 10. SWIPE
**Description**: Swipe on a party (like or pass).

**Request**:
```json
{
  "Event": "SWIPE",
  "Payload": {
    "PartyID": "party-uuid",
    "Direction": "right"  // or "left"
  }
}
```

---

### 11. GET_FEED
**Description**: Get a feed of nearby parties.

**Request**:
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

---

## Server Events (Outgoing)

The server may send these events to clients:

- `NEW_MESSAGE` - New chat message received
- `NEW_PARTY` - New party created (global broadcast)
- `PARTY_CREATED` - Confirmation of party creation
- `NEW_CHAT_ROOM` - New chat room available
- `CHATS_LIST` - List of user's chat rooms
- `MY_PARTIES` - User's parties list
- `PROFILE_UPDATED` - Profile update confirmation
- `GEOCODE_RESULT` - Reverse geocoding result
- `ERROR` - Error message

---

## Technology Stack

- **Language**: Go
- **WebSocket**: gorilla/websocket
- **Database**: PostgreSQL (jackc/pgx)
- **Geocoding**: Nominatim (OpenStreetMap)
- **Authentication**: JWT tokens passed in WebSocket connection query string
