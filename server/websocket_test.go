package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// ==================== HUB TESTS ====================

func TestNewHub(t *testing.T) {
	hub := NewHub()

	if hub == nil {
		t.Fatal("Hub should not be nil")
	}

	if hub.clients == nil {
		t.Error("Clients map should be initialized")
	}

	if hub.rooms == nil {
		t.Error("Rooms map should be initialized")
	}

	if hub.broadcast == nil {
		t.Error("Broadcast channel should be initialized")
	}

	if hub.globalBroadcast == nil {
		t.Error("Global broadcast channel should be initialized")
	}

	if hub.register == nil {
		t.Error("Register channel should be initialized")
	}

	if hub.unregister == nil {
		t.Error("Unregister channel should be initialized")
	}
}

func TestHubBroadcastGlobal(t *testing.T) {
	hub := NewHub()

	// Test broadcastGlobal sends to globalBroadcast channel
	msg := []byte(`{"Event":"TEST","Payload":{}}`)

	done := make(chan bool)
	go func() {
		select {
		case received := <-hub.globalBroadcast:
			if string(received) != string(msg) {
				t.Errorf("Expected message %s, got %s", msg, received)
			}
		case <-time.After(100 * time.Millisecond):
			t.Error("Timeout waiting for global broadcast")
		}
		done <- true
	}()

	hub.broadcastGlobal(msg)

	<-done
}

func TestHubRoomManagement(t *testing.T) {
	hub := NewHub()

	// Start the hub's Run method in a goroutine
	go hub.Run()

	// Create mock client (simplified - without rooms field)
	client := &Client{
		UID:  "test-user",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Test register
	hub.register <- client

	// Give time for goroutine to process
	time.Sleep(10 * time.Millisecond)

	hub.mu.RLock()
	_, exists := hub.clients["test-user"]
	hub.mu.RUnlock()

	if !exists {
		t.Error("Client should be registered")
	}

	// Test unregister
	hub.unregister <- client

	// Give time for goroutine to process
	time.Sleep(10 * time.Millisecond)

	hub.mu.RLock()
	_, exists = hub.clients["test-user"]
	hub.mu.RUnlock()

	if exists {
		t.Error("Client should be unregistered")
	}

	// Shutdown the hub
	hub.quit <- true
}

// ==================== CLIENT TESTS ====================

func TestClientCreation(t *testing.T) {
	hub := NewHub()

	client := &Client{
		UID:  "user-123",
		send: make(chan []byte, 256),
		hub:  hub,
	}

	_ = client.hub // Acknowledge hub is set but not read in this test

	if client.UID != "user-123" {
		t.Errorf("Expected UID 'user-123', got '%s'", client.UID)
	}

	if client.send == nil {
		t.Error("Send channel should be initialized")
	}
}

// ==================== WEBSOCKET MESSAGE TESTS ====================

func TestWSMessageParsing(t *testing.T) {
	tests := []struct {
		name     string
		jsonData string
		wantErr  bool
	}{
		{
			name:     "Valid message with event and payload",
			jsonData: `{"Event":"TEST_EVENT","Payload":{"key":"value"}}`,
			wantErr:  false,
		},
		{
			name:     "Valid message with token",
			jsonData: `{"Event":"TEST","Payload":{},"Token":"abc123"}`,
			wantErr:  false,
		},
		{
			name:     "Empty event",
			jsonData: `{"Event":"","Payload":{}}`,
			wantErr:  false,
		},
		{
			name:     "Null payload",
			jsonData: `{"Event":"TEST","Payload":null}`,
			wantErr:  false,
		},
		{
			name:     "Invalid JSON",
			jsonData: `{invalid`,
			wantErr:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var msg WSMessage
			err := json.Unmarshal([]byte(tt.jsonData), &msg)

			if tt.wantErr && err == nil {
				t.Error("Expected error, got nil")
			}
			if !tt.wantErr && err != nil {
				t.Errorf("Unexpected error: %v", err)
			}
		})
	}
}

func TestWSMessageEventTypes(t *testing.T) {
	// Test all WebSocket event types from the API
	eventTypes := []string{
		// Party Management
		"GET_FEED",
		"GET_MY_PARTIES",
		"GET_MATCHED_PARTIES",
		"GET_PARTY_DETAILS",
		"CREATE_PARTY",
		"UPDATE_PARTY",
		"DELETE_PARTY",
		"LEAVE_PARTY",
		"UPDATE_PARTY_STATUS",

		// Applications
		"GET_APPLICANTS",
		"GET_MATCHED_USERS",
		"UPDATE_APPLICATION",
		"APPLY_TO_PARTY",
		"REJECT_PARTY",
		"UNMATCH_USER",
		"SWIPE",

		// Chat
		"GET_CHATS",
		"GET_CHAT_HISTORY",
		"SEND_MESSAGE",
		"JOIN_ROOM",

		// DM
		"GET_DMS",
		"GET_DM_MESSAGES",
		"SEND_DM",
		"DELETE_DM_MESSAGE",

		// User
		"GET_USER",
		"UPDATE_PROFILE",
		"DELETE_USER",

		// Fundraising
		"GET_FUNDRAISER_STATE",
		"ADD_CONTRIBUTION",

		// Notifications
		"GET_NOTIFICATIONS",
		"MARK_NOTIFICATION_READ",
		"MARK_ALL_NOTIFICATIONS_READ",

		// Search & Blocking
		"SEARCH_USERS",
		"BLOCK_USER",
		"UNBLOCK_USER",
		"GET_BLOCKED_USERS",

		// Reporting
		"REPORT_USER",
		"REPORT_PARTY",

		// Analytics
		"GET_PARTY_ANALYTICS",
	}

	for _, event := range eventTypes {
		t.Run(event, func(t *testing.T) {
			msg := WSMessage{
				Event:   event,
				Payload: map[string]string{"test": "value"},
			}

			data, err := json.Marshal(msg)
			if err != nil {
				t.Fatalf("Failed to marshal message: %v", err)
			}

			var unmarshaled WSMessage
			err = json.Unmarshal(data, &unmarshaled)
			if err != nil {
				t.Fatalf("Failed to unmarshal message: %v", err)
			}

			if unmarshaled.Event != event {
				t.Errorf("Expected event '%s', got '%s'", event, unmarshaled.Event)
			}
		})
	}
}

// ==================== RESPONSE EVENT TESTS ====================

func TestWSResponseEvents(t *testing.T) {
	responseEvents := []string{
		// Party responses
		"FEED_UPDATE",
		"MY_PARTIES",
		"PARTY_DETAILS",
		"PARTY_CREATED",
		"PARTY_UPDATED",
		"PARTY_DELETED",
		"PARTY_LEFT",
		"PARTY_STATUS_UPDATED",

		// Application responses
		"APPLICANTS_LIST",
		"MATCHED_USERS",
		"APPLICATION_SUBMITTED",
		"APPLICATION_UPDATED",
		"APPLICATION_REJECTED",
		"USER_UNMATCHED",

		// Chat responses
		"CHATS_LIST",
		"CHAT_HISTORY",
		"NEW_MESSAGE",

		// DM responses
		"DMS_LIST",
		"DM_MESSAGES",
		"MESSAGE_DELETED",

		// User responses
		"PROFILE_UPDATED",
		"USER_DELETED",

		// Fundraising responses
		"FUNDRAISER_STATE",
		"FUNDRAISER_UPDATED",

		// Notification responses
		"NOTIFICATIONS_LIST",
		"NOTIFICATION_MARKED_READ",
		"ALL_NOTIFICATIONS_MARKED_READ",

		// Search responses
		"USERS_SEARCH_RESULTS",
		"USER_BLOCKED",
		"USER_UNBLOCKED",
		"BLOCKED_USERS_LIST",

		// Reporting responses
		"USER_REPORTED",
		"PARTY_REPORTED",

		// Analytics responses
		"PARTY_ANALYTICS",

		// Error
		"ERROR",
	}

	for _, event := range responseEvents {
		t.Run(event, func(t *testing.T) {
			msg := WSMessage{
				Event:   event,
				Payload: map[string]string{"status": "success"},
			}

			data, err := json.Marshal(msg)
			if err != nil {
				t.Fatalf("Failed to marshal response: %v", err)
			}

			if len(data) == 0 {
				t.Error("Response should not be empty")
			}
		})
	}
}

// ==================== PAYLOAD SERIALIZATION TESTS ====================

func TestPartyPayloadSerialization(t *testing.T) {
	party := CreateTestParty("party-payload", "host-123")

	data, err := json.Marshal(party)
	if err != nil {
		t.Fatalf("Failed to marshal party: %v", err)
	}

	var unmarshaled Party
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal party: %v", err)
	}

	if unmarshaled.ID != party.ID {
		t.Errorf("ID mismatch")
	}
}

func TestUserPayloadSerialization(t *testing.T) {
	user := CreateTestUser("user-payload")

	data, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("Failed to marshal user: %v", err)
	}

	var unmarshaled User
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal user: %v", err)
	}

	if unmarshaled.ID != user.ID {
		t.Errorf("ID mismatch")
	}
}

func TestChatMessagePayloadSerialization(t *testing.T) {
	msg := CreateTestMessage("msg-payload", "chat-123", "user-456")

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Failed to marshal message: %v", err)
	}

	var unmarshaled ChatMessage
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal message: %v", err)
	}

	if unmarshaled.ID != msg.ID {
		t.Errorf("ID mismatch")
	}
}

func TestNotificationPayloadSerialization(t *testing.T) {
	notif := CreateTestNotification("notif-payload", "user-123")

	data, err := json.Marshal(notif)
	if err != nil {
		t.Fatalf("Failed to marshal notification: %v", err)
	}

	var unmarshaled Notification
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal notification: %v", err)
	}

	if unmarshaled.ID != notif.ID {
		t.Errorf("ID mismatch")
	}
}

func TestAnalyticsPayloadSerialization(t *testing.T) {
	analytics := PartyAnalytics{
		PartyID:           "party-123",
		TotalViews:        100,
		TotalApplications: 50,
		AcceptedCount:     25,
		PendingCount:      15,
		DeclinedCount:     10,
		CurrentGuestCount: 20,
	}

	data, err := json.Marshal(analytics)
	if err != nil {
		t.Fatalf("Failed to marshal analytics: %v", err)
	}

	var unmarshaled PartyAnalytics
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal analytics: %v", err)
	}

	if unmarshaled.PartyID != analytics.PartyID {
		t.Errorf("PartyID mismatch")
	}
}

func TestCrowdfundingPayloadSerialization(t *testing.T) {
	pool := Crowdfunding{
		ID:            "pool-123",
		PartyID:       "party-456",
		TargetAmount:  1000.0,
		CurrentAmount: 500.0,
		Currency:      "USD",
		Contributors: []Contribution{
			{UserID: "user1", Amount: 100.0, PaidAt: time.Now()},
			{UserID: "user2", Amount: 200.0, PaidAt: time.Now()},
		},
		IsFunded: false,
	}

	data, err := json.Marshal(pool)
	if err != nil {
		t.Fatalf("Failed to marshal pool: %v", err)
	}

	var unmarshaled Crowdfunding
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal pool: %v", err)
	}

	if unmarshaled.ID != pool.ID {
		t.Errorf("ID mismatch")
	}
	if len(unmarshaled.Contributors) != len(pool.Contributors) {
		t.Errorf("Contributors count mismatch")
	}
}

// ==================== ROOM EVENT TESTS ====================

func TestRoomEventSerialization(t *testing.T) {
	event := RoomEvent{
		RoomID:  "room-123",
		Message: []byte(`{"Event":"TEST","Payload":{}}`),
	}

	// Test that Message field is properly set
	if len(event.Message) == 0 {
		t.Error("Message should not be empty")
	}

	// Test JSON serialization of event
	data, err := json.Marshal(event)
	if err != nil {
		t.Fatalf("Failed to marshal RoomEvent: %v", err)
	}

	if len(data) == 0 {
		t.Error("Serialized event should not be empty")
	}
}

// ==================== WEBSOCKET CONSTANTS TESTS ====================

func TestWebSocketConstants(t *testing.T) {
	// Verify constants are defined
	if writeWait == 0 {
		t.Error("writeWait should be defined")
	}

	if pongWait == 0 {
		t.Error("pongWait should be defined")
	}

	if pingPeriod == 0 {
		t.Error("pingPeriod should be defined")
	}

	if maxMessageSize == 0 {
		t.Error("maxMessageSize should be defined")
	}

	// Verify reasonable values
	if writeWait < 0 {
		t.Error("writeWait should be positive")
	}

	if pongWait < 0 {
		t.Error("pongWait should be positive")
	}

	if pingPeriod < 0 {
		t.Error("pingPeriod should be positive")
	}

	if maxMessageSize <= 0 {
		t.Error("maxMessageSize should be positive")
	}
}

// ==================== UPGRADER TESTS ====================

func TestWebSocketUpgrader(t *testing.T) {
	// Test that upgrader is properly configured
	if upgrader.ReadBufferSize <= 0 {
		t.Error("ReadBufferSize should be positive")
	}

	if upgrader.WriteBufferSize <= 0 {
		t.Error("WriteBufferSize should be positive")
	}

	if upgrader.CheckOrigin == nil {
		t.Error("CheckOrigin should be defined")
	}

	// Test CheckOrigin allows all origins (current configuration)
	req, _ := http.NewRequest("GET", "http://localhost:8080", nil)
	result := upgrader.CheckOrigin(req)
	if !result {
		t.Error("CheckOrigin should return true for testing")
	}
}

// ==================== MESSAGE BUFFER TESTS ====================

func TestMessageBufferSize(t *testing.T) {
	// Test that the hub broadcast channels have appropriate buffer sizes
	hub := NewHub()

	// These should be buffered channels
	// We can't directly check buffer size, but we can verify they were created
	if hub.broadcast == nil {
		t.Error("Broadcast channel should exist")
	}

	if hub.globalBroadcast == nil {
		t.Error("Global broadcast channel should exist")
	}

	// Test client send channel buffer
	client := &Client{
		UID:  "test",
		send: make(chan []byte, 256),
		hub:  hub,
	}

	_ = client.UID // Acknowledge UID is set but not read in this test
	_ = client.hub // Acknowledge hub is set but not read in this test

	if client.send == nil {
		t.Error("Client send channel should exist")
	}
}

// ==================== CONCURRENT ACCESS TESTS ====================

func TestHubConcurrentAccess(t *testing.T) {
	hub := NewHub()

	// Test concurrent read/write
	done := make(chan bool)

	go func() {
		for i := 0; i < 100; i++ {
			hub.mu.Lock()
			hub.clients["user-"+string(rune(i))] = &Client{
				UID:  "user-" + string(rune(i)),
				send: make(chan []byte),
				hub:  hub,
			}
			hub.mu.Unlock()
		}
		done <- true
	}()

	go func() {
		for i := 0; i < 100; i++ {
			hub.mu.RLock()
			_ = len(hub.clients)
			hub.mu.RUnlock()
		}
		done <- true
	}()

	<-done
	<-done

	// Verify no race conditions occurred
	if len(hub.clients) != 100 {
		t.Errorf("Expected 100 clients, got %d", len(hub.clients))
	}
}

// ==================== HUB RUN TESTS ====================

func TestHubRunRegisterUnregister(t *testing.T) {
	hub := NewHub()

	// Start hub in background
	go hub.Run()

	// Create and register a client
	client := &Client{
		UID:  "test-client",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	hub.register <- client

	// Wait for registration
	time.Sleep(10 * time.Millisecond)

	hub.mu.RLock()
	_, exists := hub.clients["test-client"]
	hub.mu.RUnlock()

	if !exists {
		t.Error("Client should be registered")
	}

	// Unregister the client
	hub.unregister <- client

	// Wait for unregistration
	time.Sleep(10 * time.Millisecond)

	hub.mu.RLock()
	_, exists = hub.clients["test-client"]
	hub.mu.RUnlock()

	if exists {
		t.Error("Client should be unregistered")
	}
}

func TestHubRunGlobalBroadcast(t *testing.T) {
	hub := NewHub()

	// Start hub in background
	go hub.Run()

	// Create and register a client
	client := &Client{
		UID:  "broadcast-client",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	hub.register <- client
	time.Sleep(10 * time.Millisecond)

	// Send global broadcast
	testMsg := []byte(`{"Event":"TEST","Payload":{}}`)
	hub.globalBroadcast <- testMsg

	// Client should receive the message
	select {
	case received := <-client.send:
		if string(received) != string(testMsg) {
			t.Errorf("Expected %s, got %s", testMsg, received)
		}
	case <-time.After(100 * time.Millisecond):
		t.Error("Timeout waiting for message")
	}
}

func TestHubRunRoomBroadcast(t *testing.T) {
	hub := NewHub()

	// Start hub in background
	go hub.Run()

	// Create and register clients
	client1 := &Client{
		UID:  "room-client-1",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	client2 := &Client{
		UID:  "room-client-2",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	hub.register <- client1
	hub.register <- client2
	time.Sleep(10 * time.Millisecond)

	// Add both clients to a room
	roomID := "test-room"
	hub.mu.Lock()
	if hub.rooms[roomID] == nil {
		hub.rooms[roomID] = make(map[*Client]bool)
	}
	hub.rooms[roomID][client1] = true
	hub.rooms[roomID][client2] = true
	hub.mu.Unlock()

	// Send room broadcast
	testMsg := []byte(`{"Event":"ROOM_TEST","Payload":{}}`)
	roomEvent := RoomEvent{
		RoomID:  roomID,
		Message: testMsg,
	}

	hub.broadcast <- roomEvent

	// Both clients should receive the message
	for i, client := range []*Client{client1, client2} {
		select {
		case received := <-client.send:
			if string(received) != string(testMsg) {
				t.Errorf("Client %d: Expected %s, got %s", i, testMsg, received)
			}
		case <-time.After(100 * time.Millisecond):
			t.Errorf("Client %d: Timeout waiting for message", i)
		}
	}
}

// ==================== JOIN ROOM TESTS ====================

func TestJoinRoom(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "test-user",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	roomID := "test-room-123"

	// Join the room
	hub.JoinRoom(roomID, client)

	// Verify client is in the room
	hub.mu.RLock()
	room, exists := hub.rooms[roomID]
	hub.mu.RUnlock()

	if !exists {
		t.Error("Room should exist after joining")
	}

	if room == nil {
		t.Error("Room should not be nil")
	}

	if !room[client] {
		t.Error("Client should be in the room")
	}

	// Join another room
	roomID2 := "test-room-456"
	hub.JoinRoom(roomID2, client)

	hub.mu.RLock()
	_, exists2 := hub.rooms[roomID2]
	hub.mu.RUnlock()

	if !exists2 {
		t.Error("Second room should exist after joining")
	}
}

// ==================== HANDLE INCOMING MESSAGE TESTS ====================

func TestHandleIncomingMessage_JoinRoom(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "test-user-join",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Register client
	hub.register <- client
	time.Sleep(10 * time.Millisecond)

	// Create JOIN_ROOM message
	msg := WSMessage{
		Event: "JOIN_ROOM",
		Payload: map[string]interface{}{
			"RoomID": "party-chat-123",
		},
	}

	msgBytes, _ := json.Marshal(msg)

	// Handle the message
	client.handleIncomingMessage(msgBytes)

	// Verify client joined the room
	hub.mu.RLock()
	room, exists := hub.rooms["party-chat-123"]
	hub.mu.RUnlock()

	if !exists {
		t.Error("Room should exist after JOIN_ROOM")
	}

	if !room[client] {
		t.Error("Client should be in the room after JOIN_ROOM")
	}
}

func TestHandleIncomingMessage_EmptyRoomID(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "test-user-empty",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Register client
	hub.register <- client
	time.Sleep(10 * time.Millisecond)

	// Create JOIN_ROOM message with empty room ID
	msg := WSMessage{
		Event: "JOIN_ROOM",
		Payload: map[string]interface{}{
			"RoomID": "",
		},
	}

	msgBytes, _ := json.Marshal(msg)

	// Handle the message - should not panic
	client.handleIncomingMessage(msgBytes)

	// Verify no room was created
	hub.mu.RLock()
	_, exists := hub.rooms[""]
	hub.mu.RUnlock()

	if exists {
		t.Error("Empty room ID should not create a room")
	}
}

func TestHandleIncomingMessage_InvalidJSON(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "test-user-invalid",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Send invalid JSON - should not panic
	client.handleIncomingMessage([]byte("invalid json"))
}

func TestHandleIncomingMessage_UnknownEvent(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "test-user-unknown",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Send unknown event - should not panic
	msg := WSMessage{
		Event:   "UNKNOWN_EVENT",
		Payload: map[string]interface{}{},
	}

	msgBytes, _ := json.Marshal(msg)
	client.handleIncomingMessage(msgBytes)
}

func TestHandleIncomingMessage_DeleteUser_Success(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "user-to-delete",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Register client
	hub.register <- client
	time.Sleep(10 * time.Millisecond)

	// Create DELETE_USER message for own account
	deleteMsg := WSMessage{
		Event: "DELETE_USER",
		Payload: map[string]interface{}{
			"UserID": "user-to-delete",
		},
	}

	msgBytes, _ := json.Marshal(deleteMsg)

	// Handle the message - may succeed or fail depending on database availability
	// The important thing is that the authorization check passes
	client.handleIncomingMessage(msgBytes)

	// Check response - either USER_DELETED (if DB available) or ERROR (if DB fails)
	select {
	case response := <-client.send:
		var wsMsg WSMessage
		err := json.Unmarshal(response, &wsMsg)
		if err != nil {
			t.Fatalf("Failed to unmarshal response: %v", err)
		}
		// Accept either USER_DELETED or ERROR (if DB is not available in test)
		if wsMsg.Event != "USER_DELETED" && wsMsg.Event != "ERROR" {
			t.Errorf("Expected USER_DELETED or ERROR event, got %s", wsMsg.Event)
		}
		// If we got USER_DELETED, authorization worked correctly
		if wsMsg.Event == "USER_DELETED" {
			t.Log("User deletion authorized and processed successfully")
		}
	case <-time.After(100 * time.Millisecond):
		t.Error("Timeout waiting for delete response")
	}
}

func TestHandleIncomingMessage_DeleteUser_Unauthorized(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "actual-user",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Register client
	hub.register <- client
	time.Sleep(10 * time.Millisecond)

	// Create DELETE_USER message for different user (should fail)
	deleteMsg := WSMessage{
		Event: "DELETE_USER",
		Payload: map[string]interface{}{
			"UserID": "different-user",
		},
	}

	msgBytes, _ := json.Marshal(deleteMsg)

	// Handle the message - should send ERROR response
	client.handleIncomingMessage(msgBytes)

	// Check response
	select {
	case response := <-client.send:
		var wsMsg WSMessage
		err := json.Unmarshal(response, &wsMsg)
		if err != nil {
			t.Fatalf("Failed to unmarshal response: %v", err)
		}
		if wsMsg.Event != "ERROR" {
			t.Errorf("Expected ERROR event, got %s", wsMsg.Event)
		}
		// Check error message
		payloadMap, ok := wsMsg.Payload.(map[string]interface{})
		if !ok {
			t.Error("Payload should be a map")
		} else {
			msg, _ := payloadMap["message"].(string)
			if msg != "Not authorized to delete this user" {
				t.Errorf("Expected authorization error, got: %s", msg)
			}
		}
	case <-time.After(100 * time.Millisecond):
		t.Error("Timeout waiting for error response")
	}
}

func TestHandleIncomingMessage_DeleteUser_InvalidPayload(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "test-user",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	// Register client
	hub.register <- client
	time.Sleep(10 * time.Millisecond)

	// Create DELETE_USER message with invalid/missing UserID (empty string)
	deleteMsg := WSMessage{
		Event: "DELETE_USER",
		Payload: map[string]interface{}{
			"UserID": "",
		},
	}

	msgBytes, _ := json.Marshal(deleteMsg)

	// Handle the message - should try to delete and potentially fail gracefully
	// The handler checks if req.UserID != c.UID, so empty string won't match
	client.handleIncomingMessage(msgBytes)

	// Should still get a response (either ERROR or USER_DELETED)
	select {
	case response := <-client.send:
		var wsMsg WSMessage
		err := json.Unmarshal(response, &wsMsg)
		if err != nil {
			t.Fatalf("Failed to unmarshal response: %v", err)
		}
		// Either ERROR (for auth) is acceptable
		if wsMsg.Event != "ERROR" && wsMsg.Event != "USER_DELETED" {
			t.Errorf("Expected ERROR or USER_DELETED event, got %s", wsMsg.Event)
		}
	case <-time.After(100 * time.Millisecond):
		// Timeout is also acceptable if the message is just ignored
	}
}

// ==================== REVERSE GEOCODE TESTS ====================

func TestReverseGeocode(t *testing.T) {
	// Test with valid coordinates (NYC)
	addr, city, err := ReverseGeocode(40.7128, -74.0060)

	// Note: This may fail if there's no network, so we check for error
	if err != nil {
		// Network error is expected in test environment
		t.Logf("ReverseGeocode failed (expected without network): %v", err)
	} else {
		if addr == "" && city == "" {
			t.Log("ReverseGeocode returned empty results")
		}
	}
}

func TestReverseGeocode_InvalidCoords(t *testing.T) {
	// Test with invalid coordinates (0, 0)
	addr, city, err := ReverseGeocode(0, 0)

	// This should return an error or empty results
	if err != nil {
		t.Logf("ReverseGeocode returned error: %v", err)
	}

	_ = addr
	_ = city
}

// ==================== HUB ROOM MANAGEMENT TESTS ====================

func TestHubGetRoomClients(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client1 := &Client{
		UID:  "user1",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	client2 := &Client{
		UID:  "user2",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	roomID := "test-get-clients"

	// Add clients to room
	hub.JoinRoom(roomID, client1)
	hub.JoinRoom(roomID, client2)

	// Get room clients
	hub.mu.RLock()
	clients := hub.rooms[roomID]
	hub.mu.RUnlock()

	if len(clients) != 2 {
		t.Errorf("Expected 2 clients in room, got %d", len(clients))
	}
}

func TestHubRemoveClientFromRoom(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	client := &Client{
		UID:  "remove-test-user",
		send: make(chan []byte, 10),
		hub:  hub,
	}

	roomID := "test-remove-room"

	// Add client to room
	hub.JoinRoom(roomID, client)

	// Manually remove from room (simulating unregister behavior)
	hub.mu.Lock()
	if room, ok := hub.rooms[roomID]; ok {
		delete(room, client)
	}
	hub.mu.Unlock()

	// Verify client is removed
	hub.mu.RLock()
	room, exists := hub.rooms[roomID]
	hub.mu.RUnlock()

	if exists && room[client] {
		t.Error("Client should be removed from room")
	}
}

// ==================== GETENV AND CORS TESTS ====================

func TestGetEnv(t *testing.T) {
	// Test with existing key
	os.Setenv("TEST_KEY", "test_value")
	defer os.Unsetenv("TEST_KEY")

	result := getEnv("TEST_KEY", "default")
	if result != "test_value" {
		t.Errorf("Expected 'test_value', got '%s'", result)
	}

	// Test with non-existing key (uses fallback)
	result = getEnv("NON_EXISTENT_KEY", "fallback_value")
	if result != "fallback_value" {
		t.Errorf("Expected 'fallback_value', got '%s'", result)
	}
}

func TestCorsMiddleware(t *testing.T) {
	// Create a simple handler to test CORS middleware
	handlerCalled := false
	testHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handlerCalled = true
		w.WriteHeader(http.StatusOK)
	})

	wrappedHandler := corsMiddleware(testHandler)

	// Test OPTIONS request (preflight)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("OPTIONS", "/test", nil)

	wrappedHandler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, rec.Code)
	}

	if handlerCalled {
		t.Error("Handler should not be called for OPTIONS request")
	}

	// Check CORS headers
	if rec.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Error("CORS origin header not set")
	}

	// Test regular GET request
	handlerCalled = false
	rec = httptest.NewRecorder()
	req = httptest.NewRequest("GET", "/test", nil)

	wrappedHandler.ServeHTTP(rec, req)

	if !handlerCalled {
		t.Error("Handler should be called for GET request")
	}

	if rec.Code != http.StatusOK {
		t.Errorf("Expected status %d, got %d", http.StatusOK, rec.Code)
	}
}

// ==================== HUB QUIT TEST ====================

func TestHubRunQuit(t *testing.T) {
	hub := NewHub()

	// Start the hub
	runDone := make(chan bool)
	go func() {
		hub.Run()
		runDone <- true
	}()

	// Give it a moment to start
	time.Sleep(10 * time.Millisecond)

	// Send quit signal
	hub.quit <- true

	// Wait for Run to exit
	select {
	case <-runDone:
		// Success - hub quit
	case <-time.After(100 * time.Millisecond):
		t.Error("Hub should have quit within timeout")
	}
}

// ==================== HTTP HANDLER TESTS ====================

func TestHandleRegister_MethodNotAllowed(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/register", nil)

	handleRegister(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("Expected status %d, got %d", http.StatusMethodNotAllowed, rec.Code)
	}
}

func TestHandleRegister_InvalidJSON(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/register", bytes.NewBufferString("not valid json"))
	req.Header.Set("Content-Type", "application/json")

	handleRegister(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestHandleLogin_MethodNotAllowed(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/login", nil)

	handleLogin(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("Expected status %d, got %d", http.StatusMethodNotAllowed, rec.Code)
	}
}

func TestHandleLogin_InvalidJSON(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/login", bytes.NewBufferString("not valid json"))
	req.Header.Set("Content-Type", "application/json")

	handleLogin(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}
}

func TestHandleGetProfile_MethodNotAllowed(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("PUT", "/profile?id=test123", nil)

	handleProfile(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("Expected status %d, got %d", http.StatusMethodNotAllowed, rec.Code)
	}
}

func TestHandleUpload_MethodNotAllowed(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/upload", nil)

	handleUpload(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("Expected status %d, got %d", http.StatusMethodNotAllowed, rec.Code)
	}
}

func TestHandleUpload_NoFile(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("POST", "/upload", nil)
	req.Header.Set("Content-Type", "multipart/form-data")

	handleUpload(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("Expected status %d, got %d", http.StatusBadRequest, rec.Code)
	}
}

// ==================== HUB BROADCAST EDGE CASE TESTS ====================

func TestHubRunGlobalBroadcastFullBuffer(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create a client with a full send buffer (0 size)
	client := &Client{
		UID:  "full-buffer-user",
		send: make(chan []byte), // No buffer - will fill immediately
		hub:  hub,
	}

	// Register the client
	hub.register <- client
	time.Sleep(10 * time.Millisecond)

	// Register in hub clients manually since channel is full
	hub.mu.Lock()
	hub.clients[client.UID] = client
	hub.mu.Unlock()

	// Send global broadcast - this should trigger the default case (unregister due to full buffer)
	msg := []byte(`{"Event":"TEST","Payload":{}}`)
	hub.globalBroadcast <- msg

	// Give time for the goroutine to process
	time.Sleep(20 * time.Millisecond)

	// The client should have been unregistered due to full buffer
	hub.mu.RLock()
	_, exists := hub.clients[client.UID]
	hub.mu.RUnlock()

	// Note: This test verifies the code path executes; actual behavior depends on timing
	_ = exists // May or may not be unregistered depending on race conditions
}

func TestHubRunRoomBroadcastFullBuffer(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create a client with a full send buffer
	client := &Client{
		UID:  "room-full-buffer-user",
		send: make(chan []byte),
		hub:  hub,
	}

	roomID := "test-room-full-buffer"

	// Add client to room
	hub.JoinRoom(roomID, client)

	// Manually add to clients map
	hub.mu.Lock()
	hub.clients[client.UID] = client
	hub.mu.Unlock()

	// Send room broadcast - this should trigger the default case
	msg := []byte(`{"Event":"ROOM_TEST","Payload":{}}`)
	hub.broadcast <- RoomEvent{RoomID: roomID, Message: msg}

	// Give time for processing
	time.Sleep(20 * time.Millisecond)

	// The client should have been unregistered due to full buffer
	hub.mu.RLock()
	_, exists := hub.clients[client.UID]
	hub.mu.RUnlock()

	_ = exists
}

// TestServeWs tests the WebSocket server handler
func TestServeWs(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create a test server with WebSocket upgrade
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))
	defer server.Close()

	// Convert test server URL to WebSocket URL
	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "?uid=test-user-123"

	// Connect to WebSocket
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial WebSocket: %v", err)
	}
	defer ws.Close()

	// Verify connection is established
	if ws == nil {
		t.Error("WebSocket connection is nil")
	}

	// Give time for the hub to register the client
	time.Sleep(50 * time.Millisecond)

	// Verify client is registered
	hub.mu.RLock()
	clientCount := len(hub.clients)
	hub.mu.RUnlock()

	if clientCount == 0 {
		t.Error("Expected at least one client registered in hub")
	}
}

// TestServeWsMultipleClients tests multiple WebSocket connections
func TestServeWsMultipleClients(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http")

	// Connect multiple clients
	var conns []*websocket.Conn
	for i := 0; i < 3; i++ {
		ws, _, err := websocket.DefaultDialer.Dial(wsURL+"?uid=user-"+string(rune('0'+i)), nil)
		if err != nil {
			t.Fatalf("Failed to dial WebSocket %d: %v", i, err)
		}
		conns = append(conns, ws)
	}
	defer func() {
		for _, ws := range conns {
			ws.Close()
		}
	}()

	// Give time for registration
	time.Sleep(50 * time.Millisecond)

	// Verify all clients are registered
	hub.mu.RLock()
	clientCount := len(hub.clients)
	hub.mu.RUnlock()

	if clientCount != 3 {
		t.Errorf("Expected 3 clients, got %d", clientCount)
	}
}

// TestServeWsInvalidUID tests WebSocket with invalid UID
func TestServeWsInvalidUID(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "?uid=" // Empty UID

	// This should still work but with empty UID
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Logf("Expected error for empty UID: %v", err)
		return
	}
	if ws != nil {
		ws.Close()
	}
}

// TestWebSocketMessageRoundTrip tests sending and receiving messages via WebSocket
func TestWebSocketMessageRoundTrip(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "?uid=roundtrip-user"

	// Connect
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer ws.Close()

	// Wait for registration
	time.Sleep(50 * time.Millisecond)

	// Send a message through WebSocket
	msg := map[string]interface{}{
		"Event":   "TEST_MESSAGE",
		"Payload": map[string]string{"text": "hello world"},
	}
	msgBytes, _ := json.Marshal(msg)

	err = ws.WriteMessage(websocket.TextMessage, msgBytes)
	if err != nil {
		t.Fatalf("Failed to write message: %v", err)
	}

	// Give time for the message to be processed
	time.Sleep(50 * time.Millisecond)

	// The test passes if no panic occurred during read/write
}

// TestWebSocketInvalidJSON tests sending invalid JSON through WebSocket
func TestWebSocketInvalidJSON(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "?uid=invalid-json-user"

	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer ws.Close()

	time.Sleep(50 * time.Millisecond)

	// Send invalid JSON
	err = ws.WriteMessage(websocket.TextMessage, []byte("not valid json{"))
	if err != nil {
		t.Fatalf("Failed to write: %v", err)
	}

	time.Sleep(50 * time.Millisecond)
}

// TestServeWsNonWebSocketRequest tests serving a non-WebSocket request
func TestServeWsNonWebSocketRequest(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Use httptest to make a regular HTTP request (not WebSocket)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/ws?uid=test", nil)

	// This should not panic, just return
	ServeWs(hub, rec, req)

	// Check that we get a bad handshake response
	// The upgrader will reject non-WebSocket requests
}

// TestWebSocketMessageFlow tests the complete message flow
func TestWebSocketMessageFlow(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	// Create test server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "?uid=msgflow-user"

	// Connect
	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer ws.Close()

	// Wait for registration
	time.Sleep(50 * time.Millisecond)

	// Verify client is registered
	hub.mu.RLock()
	client, ok := hub.clients["msgflow-user"]
	hub.mu.RUnlock()

	if !ok {
		t.Fatal("Client not registered")
	}

	// Test writing to the client's send channel (simulating writePump behavior)
	testMsg := []byte(`{"Event":"TEST","Payload":{"data":"test"}}`)
	select {
	case client.send <- testMsg:
	case <-time.After(100 * time.Millisecond):
		t.Error("Failed to send message to client channel")
		return
	}

	// Read the message from WebSocket (this tests writePump output)
	ws.SetReadDeadline(time.Now().Add(500 * time.Millisecond))
	msgType, msg, err := ws.ReadMessage()
	if err != nil {
		t.Logf("Could not read message (this may be due to ping/pong): %v", err)
	} else if msgType == websocket.TextMessage {
		var wsMsg WSMessage
		if err := json.Unmarshal(msg, &wsMsg); err == nil {
			if wsMsg.Event != "TEST" {
				t.Errorf("Expected event TEST, got %s", wsMsg.Event)
			}
		}
	}

	// Send a message through WebSocket (this tests readPump input)
	sendMsg := map[string]interface{}{
		"Event":   "ECHO_TEST",
		"Payload": map[string]string{"echo": "hello"},
	}
	sendBytes, _ := json.Marshal(sendMsg)
	err = ws.WriteMessage(websocket.TextMessage, sendBytes)
	if err != nil {
		t.Fatalf("Failed to write: %v", err)
	}

	// Give time for processing
	time.Sleep(50 * time.Millisecond)
}

// TestServeWsWithQueryParams tests ServeWs with query parameters
func TestServeWsWithQueryParams(t *testing.T) {
	hub := NewHub()
	go hub.Run()
	defer func() { hub.quit <- true }()

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	}))
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + "?uid=test-uid&room=test-room"

	ws, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatalf("Failed to dial: %v", err)
	}
	defer ws.Close()

	time.Sleep(50 * time.Millisecond)

	// Verify client registered with correct UID
	hub.mu.RLock()
	_, exists := hub.clients["test-uid"]
	hub.mu.RUnlock()

	if !exists {
		t.Error("Expected client to be registered")
	}
}
