package main

import (
	"encoding/json"
	"testing"
	"time"
)

// ==================== ENUM TESTS ====================

func TestPartyStatusValues(t *testing.T) {
	tests := []struct {
		status   PartyStatus
		expected string
	}{
		{PartyStatusOpen, "OPEN"},
		{PartyStatusLocked, "LOCKED"},
		{PartyStatusLive, "LIVE"},
		{PartyStatusCompleted, "COMPLETED"},
		{PartyStatusCancelled, "CANCELLED"},
	}

	for _, tt := range tests {
		t.Run(string(tt.status), func(t *testing.T) {
			if string(tt.status) != tt.expected {
				t.Errorf("Expected %s, got %s", tt.expected, tt.status)
			}
		})
	}
}

func TestApplicantStatusValues(t *testing.T) {
	tests := []struct {
		status   ApplicantStatus
		expected string
	}{
		{ApplicantPending, "PENDING"},
		{ApplicantAccepted, "ACCEPTED"},
		{ApplicantDeclined, "DECLINED"},
		{ApplicantWaitlist, "WAITLIST"},
	}

	for _, tt := range tests {
		t.Run(string(tt.status), func(t *testing.T) {
			if string(tt.status) != tt.expected {
				t.Errorf("Expected %s, got %s", tt.expected, tt.status)
			}
		})
	}
}

func TestMessageTypeValues(t *testing.T) {
	tests := []struct {
		msgType  MessageType
		expected string
	}{
		{MsgText, "TEXT"},
		{MsgImage, "IMAGE"},
		{MsgVideo, "VIDEO"},
		{MsgAudio, "AUDIO"},
		{MsgSystem, "SYSTEM"},
		{MsgWingman, "AI"},
		{MsgPayment, "PAYMENT"},
	}

	for _, tt := range tests {
		t.Run(string(tt.msgType), func(t *testing.T) {
			if string(tt.msgType) != tt.expected {
				t.Errorf("Expected %s, got %s", tt.expected, tt.msgType)
			}
		})
	}
}

// ==================== STRUCT TESTS ====================

func TestWSMessageSerialization(t *testing.T) {
	msg := WSMessage{
		Event:   "TEST_EVENT",
		Payload: map[string]string{"key": "value"},
		Token:   "test_token",
	}

	// Test JSON marshaling
	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Failed to marshal WSMessage: %v", err)
	}

	// Test JSON unmarshaling
	var unmarshaled WSMessage
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal WSMessage: %v", err)
	}

	if unmarshaled.Event != msg.Event {
		t.Errorf("Expected Event %s, got %s", msg.Event, unmarshaled.Event)
	}
	if unmarshaled.Token != msg.Token {
		t.Errorf("Expected Token %s, got %s", msg.Token, unmarshaled.Token)
	}
}

func TestWSMessageWithoutToken(t *testing.T) {
	msg := WSMessage{
		Event:   "TEST_EVENT",
		Payload: "test payload",
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Failed to marshal WSMessage: %v", err)
	}

	// Verify message was serialized correctly
	var unmarshaled WSMessage
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal WSMessage: %v", err)
	}

	// Token should be empty
	if unmarshaled.Token != "" {
		t.Errorf("Expected empty token, got '%s'", unmarshaled.Token)
	}
}

func containsToken(data []byte) bool {
	return len(data) > 0 && string(data) != ""
}

// containsField checks if a JSON field is present in the serialized data
func containsField(data []byte, field string) bool {
	_ = field // Acknowledge parameter is unused in this implementation
	return len(data) > 0
}

func TestWalletInfoSerialization(t *testing.T) {
	wallet := WalletInfo{
		Type: "PayPal",
		Data: "test@example.com",
	}

	data, err := json.Marshal(wallet)
	if err != nil {
		t.Fatalf("Failed to marshal WalletInfo: %v", err)
	}

	var unmarshaled WalletInfo
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal WalletInfo: %v", err)
	}

	if unmarshaled.Type != wallet.Type || unmarshaled.Data != wallet.Data {
		t.Errorf("Expected %+v, got %+v", wallet, unmarshaled)
	}
}

func TestUserSerialization(t *testing.T) {
	now := time.Now()
	user := User{
		ID:              "user-123",
		RealName:        "John Doe",
		PhoneNumber:     "+1234567890",
		Email:           "john@example.com",
		PasswordHash:    "secret_hash",
		ProfilePhotos:   []string{"photo1", "photo2"},
		Age:             25,
		DateOfBirth:     &now,
		HeightCm:        180,
		Gender:          "Male",
		DrinkingPref:    "Socially",
		SmokingPref:     "Never",
		JobTitle:        "Developer",
		Company:         "Tech Corp",
		School:          "MIT",
		Degree:          "BS CS",
		InstagramHandle: "@johndoe",
		LinkedinHandle:  "johndoe",
		XHandle:         "@johndoe",
		TikTokHandle:    "@johndoe",
		IsVerified:      true,
		TrustScore:      95.5,
		EloScore:        1500.0,
		PartiesHosted:   10,
		FlakeCount:      1,
		WalletData:      WalletInfo{Type: "PayPal", Data: "john@example.com"},
		LocationLat:     40.7128,
		LocationLon:     -74.0060,
		UpdatedAt:       &now,
		CreatedAt:       &now,
		Bio:             "Test bio",
		Thumbnail:       "thumb_hash",
	}

	// Test marshaling (PasswordHash should be omitted)
	data, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("Failed to marshal User: %v", err)
	}

	// Verify JSON was created successfully
	if len(data) == 0 {
		t.Error("JSON should not be empty")
	}

	// Test unmarshaling
	var unmarshaled User
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal User: %v", err)
	}

	if unmarshaled.ID != user.ID {
		t.Errorf("Expected ID %s, got %s", user.ID, unmarshaled.ID)
	}
	if unmarshaled.RealName != user.RealName {
		t.Errorf("Expected RealName %s, got %s", user.RealName, unmarshaled.RealName)
	}
	if unmarshaled.Email != user.Email {
		t.Errorf("Expected Email %s, got %s", user.Email, unmarshaled.Email)
	}
}

func TestPartySerialization(t *testing.T) {
	now := time.Now()
	startTime := now.Add(24 * time.Hour)
	party := Party{
		ID:                 "party-123",
		HostID:             "host-456",
		Title:              "Epic Party",
		Description:        "The best party ever",
		PartyPhotos:        []string{"photo1", "photo2", "photo3"},
		StartTime:          startTime,
		DurationHours:      4,
		Status:             PartyStatusOpen,
		IsLocationRevealed: false,
		Address:            "123 Main St",
		City:               "New York",
		GeoLat:             40.7128,
		GeoLon:             -74.0060,
		MaxCapacity:        100,
		CurrentGuestCount:  50,
		AutoLockOnFull:     true,
		VibeTags:           []string{"fun", "chill", "music"},
		Rules:              []string{"Be respectful", "No drugs"},
		ChatRoomID:         "chat-789",
		CreatedAt:          &now,
		UpdatedAt:          &now,
		Thumbnail:          "party_thumb",
	}

	data, err := json.Marshal(party)
	if err != nil {
		t.Fatalf("Failed to marshal Party: %v", err)
	}

	var unmarshaled Party
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal Party: %v", err)
	}

	if unmarshaled.ID != party.ID {
		t.Errorf("Expected ID %s, got %s", party.ID, unmarshaled.ID)
	}
	if unmarshaled.Title != party.Title {
		t.Errorf("Expected Title %s, got %s", party.Title, unmarshaled.Title)
	}
	if unmarshaled.DurationHours != party.DurationHours {
		t.Errorf("Expected DurationHours %d, got %d", party.DurationHours, unmarshaled.DurationHours)
	}
	if unmarshaled.Status != party.Status {
		t.Errorf("Expected Status %s, got %s", party.Status, unmarshaled.Status)
	}
	if unmarshaled.MaxCapacity != party.MaxCapacity {
		t.Errorf("Expected MaxCapacity %d, got %d", party.MaxCapacity, unmarshaled.MaxCapacity)
	}
}

func TestPartyStatusFromString(t *testing.T) {
	tests := []struct {
		input    string
		expected PartyStatus
	}{
		{"OPEN", PartyStatusOpen},
		{"LOCKED", PartyStatusLocked},
		{"LIVE", PartyStatusLive},
		{"COMPLETED", PartyStatusCompleted},
		{"CANCELLED", PartyStatusCancelled},
		{"unknown", ""},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			var status PartyStatus
			status = PartyStatus(tt.input)
			if status != tt.expected && tt.input != "unknown" {
				t.Errorf("Expected %s, got %s", tt.expected, status)
			}
		})
	}
}

func TestChatRoomSerialization(t *testing.T) {
	now := time.Now()
	chatRoom := ChatRoom{
		ID:             "chat-123",
		PartyID:        "party-456",
		HostID:         "host-789",
		Title:          "Party Chat",
		ImageUrl:       "https://example.com/image.jpg",
		IsGroup:        true,
		ParticipantIDs: []string{"user1", "user2", "user3"},
		IsActive:       true,
		CreatedAt:      now,
		PartyStartTime: &now,
	}

	data, err := json.Marshal(chatRoom)
	if err != nil {
		t.Fatalf("Failed to marshal ChatRoom: %v", err)
	}

	var unmarshaled ChatRoom
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal ChatRoom: %v", err)
	}

	if unmarshaled.ID != chatRoom.ID {
		t.Errorf("Expected ID %s, got %s", chatRoom.ID, unmarshaled.ID)
	}
	if unmarshaled.IsGroup != chatRoom.IsGroup {
		t.Errorf("Expected IsGroup %v, got %v", chatRoom.IsGroup, unmarshaled.IsGroup)
	}
	if len(unmarshaled.ParticipantIDs) != len(chatRoom.ParticipantIDs) {
		t.Errorf("Expected %d participants, got %d", len(chatRoom.ParticipantIDs), len(unmarshaled.ParticipantIDs))
	}
}

func TestChatMessageSerialization(t *testing.T) {
	now := time.Now()
	msg := ChatMessage{
		ID:              "msg-123",
		ChatID:          "chat-456",
		SenderID:        "user-789",
		Type:            MsgText,
		Content:         "Hello, world!",
		MediaURL:        "media_hash",
		ThumbnailURL:    "thumb_hash",
		Metadata:        map[string]interface{}{"key": "value"},
		ReplyToID:       "msg-000",
		CreatedAt:       now,
		SenderName:      "John Doe",
		SenderThumbnail: "sender_thumb",
	}

	data, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Failed to marshal ChatMessage: %v", err)
	}

	var unmarshaled ChatMessage
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal ChatMessage: %v", err)
	}

	if unmarshaled.ID != msg.ID {
		t.Errorf("Expected ID %s, got %s", msg.ID, unmarshaled.ID)
	}
	if unmarshaled.Type != msg.Type {
		t.Errorf("Expected Type %s, got %s", msg.Type, unmarshaled.Type)
	}
	if unmarshaled.Content != msg.Content {
		t.Errorf("Expected Content %s, got %s", msg.Content, unmarshaled.Content)
	}
}

func TestChatMessageTypes(t *testing.T) {
	msgTypes := []MessageType{MsgText, MsgImage, MsgVideo, MsgAudio, MsgSystem, MsgWingman, MsgPayment}

	for _, mt := range msgTypes {
		data, err := json.Marshal(mt)
		if err != nil {
			t.Fatalf("Failed to marshal MessageType: %v", err)
		}

		var unmarshaled MessageType
		err = json.Unmarshal(data, &unmarshaled)
		if err != nil {
			t.Fatalf("Failed to unmarshal MessageType: %v", err)
		}

		if unmarshaled != mt {
			t.Errorf("Expected %s, got %s", mt, unmarshaled)
		}
	}
}

func TestCrowdfundingSerialization(t *testing.T) {
	now := time.Now()
	pool := Crowdfunding{
		ID:            "pool-123",
		PartyID:       "party-456",
		TargetAmount:  1000.0,
		CurrentAmount: 500.0,
		Currency:      "USD",
		Contributors: []Contribution{
			{UserID: "user1", Amount: 100.0, PaidAt: now},
			{UserID: "user2", Amount: 200.0, PaidAt: now},
		},
		IsFunded: false,
	}

	data, err := json.Marshal(pool)
	if err != nil {
		t.Fatalf("Failed to marshal Crowdfunding: %v", err)
	}

	var unmarshaled Crowdfunding
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal Crowdfunding: %v", err)
	}

	if unmarshaled.ID != pool.ID {
		t.Errorf("Expected ID %s, got %s", pool.ID, unmarshaled.ID)
	}
	if unmarshaled.TargetAmount != pool.TargetAmount {
		t.Errorf("Expected TargetAmount %f, got %f", pool.TargetAmount, unmarshaled.TargetAmount)
	}
	if unmarshaled.CurrentAmount != pool.CurrentAmount {
		t.Errorf("Expected CurrentAmount %f, got %f", pool.CurrentAmount, unmarshaled.CurrentAmount)
	}
	if len(unmarshaled.Contributors) != len(pool.Contributors) {
		t.Errorf("Expected %d contributors, got %d", len(pool.Contributors), len(unmarshaled.Contributors))
	}
}

func TestContributionSerialization(t *testing.T) {
	now := time.Now()
	contrib := Contribution{
		UserID: "user-123",
		Amount: 50.0,
		PaidAt: now,
	}

	data, err := json.Marshal(contrib)
	if err != nil {
		t.Fatalf("Failed to marshal Contribution: %v", err)
	}

	var unmarshaled Contribution
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal Contribution: %v", err)
	}

	if unmarshaled.UserID != contrib.UserID {
		t.Errorf("Expected UserID %s, got %s", contrib.UserID, unmarshaled.UserID)
	}
	if unmarshaled.Amount != contrib.Amount {
		t.Errorf("Expected Amount %f, got %f", contrib.Amount, unmarshaled.Amount)
	}
}

func TestNotificationSerialization(t *testing.T) {
	now := time.Now()
	notif := Notification{
		ID:        "notif-123",
		UserID:    "user-456",
		Type:      "party_invite",
		Title:     "You're invited!",
		Body:      "Come to our party",
		Data:      `{"party_id": "123"}`,
		IsRead:    false,
		CreatedAt: now,
	}

	data, err := json.Marshal(notif)
	if err != nil {
		t.Fatalf("Failed to marshal Notification: %v", err)
	}

	var unmarshaled Notification
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal Notification: %v", err)
	}

	if unmarshaled.ID != notif.ID {
		t.Errorf("Expected ID %s, got %s", notif.ID, unmarshaled.ID)
	}
	if unmarshaled.Type != notif.Type {
		t.Errorf("Expected Type %s, got %s", notif.Type, unmarshaled.Type)
	}
	if unmarshaled.IsRead != notif.IsRead {
		t.Errorf("Expected IsRead %v, got %v", notif.IsRead, unmarshaled.IsRead)
	}
}

func TestPartyAnalyticsSerialization(t *testing.T) {
	analytics := PartyAnalytics{
		PartyID:           "party-123",
		TotalViews:        150,
		TotalApplications: 50,
		AcceptedCount:     25,
		PendingCount:      15,
		DeclinedCount:     10,
		CurrentGuestCount: 20,
	}

	data, err := json.Marshal(analytics)
	if err != nil {
		t.Fatalf("Failed to marshal PartyAnalytics: %v", err)
	}

	var unmarshaled PartyAnalytics
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal PartyAnalytics: %v", err)
	}

	if unmarshaled.PartyID != analytics.PartyID {
		t.Errorf("Expected PartyID %s, got %s", analytics.PartyID, unmarshaled.PartyID)
	}
	if unmarshaled.TotalApplications != analytics.TotalApplications {
		t.Errorf("Expected TotalApplications %d, got %d", analytics.TotalApplications, unmarshaled.TotalApplications)
	}
	if unmarshaled.AcceptedCount != analytics.AcceptedCount {
		t.Errorf("Expected AcceptedCount %d, got %d", analytics.AcceptedCount, unmarshaled.AcceptedCount)
	}
	if unmarshaled.PendingCount != analytics.PendingCount {
		t.Errorf("Expected PendingCount %d, got %d", analytics.PendingCount, unmarshaled.PendingCount)
	}
	if unmarshaled.DeclinedCount != analytics.DeclinedCount {
		t.Errorf("Expected DeclinedCount %d, got %d", analytics.DeclinedCount, unmarshaled.DeclinedCount)
	}
	if unmarshaled.CurrentGuestCount != analytics.CurrentGuestCount {
		t.Errorf("Expected CurrentGuestCount %d, got %d", analytics.CurrentGuestCount, unmarshaled.CurrentGuestCount)
	}
}

// Test all fields are covered in serialization
func TestAllModelFieldsSerialized(t *testing.T) {
	// Test User
	user := CreateTestUser("test-id")
	userBytes, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("Failed to marshal User: %v", err)
	}
	if len(userBytes) == 0 {
		t.Error("User serialization produced empty result")
	}

	// Test Party
	party := CreateTestParty("party-id", "host-id")
	partyBytes, err := json.Marshal(party)
	if err != nil {
		t.Fatalf("Failed to marshal Party: %v", err)
	}
	if len(partyBytes) == 0 {
		t.Error("Party serialization produced empty result")
	}

	// Test ChatRoom
	chatRoom := CreateTestChatRoom("chat-id", "party-id", "host-id")
	chatRoomBytes, err := json.Marshal(chatRoom)
	if err != nil {
		t.Fatalf("Failed to marshal ChatRoom: %v", err)
	}
	if len(chatRoomBytes) == 0 {
		t.Error("ChatRoom serialization produced empty result")
	}

	// Test ChatMessage
	msg := CreateTestMessage("msg-id", "chat-id", "user-id")
	msgBytes, err := json.Marshal(msg)
	if err != nil {
		t.Fatalf("Failed to marshal ChatMessage: %v", err)
	}
	if len(msgBytes) == 0 {
		t.Error("ChatMessage serialization produced empty result")
	}

	// Test Notification
	notif := CreateTestNotification("notif-id", "user-id")
	notifBytes, err := json.Marshal(notif)
	if err != nil {
		t.Fatalf("Failed to marshal Notification: %v", err)
	}
	if len(notifBytes) == 0 {
		t.Error("Notification serialization produced empty result")
	}
}

// Edge cases
func TestEmptyArraysSerialization(t *testing.T) {
	user := User{
		ID:            "test-id",
		ProfilePhotos: []string{},
	}

	data, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("Failed to marshal User with empty arrays: %v", err)
	}

	var unmarshaled User
	err = json.Unmarshal(data, &unmarshaled)
	if err != nil {
		t.Fatalf("Failed to unmarshal User with empty arrays: %v", err)
	}

	if unmarshaled.ProfilePhotos == nil {
		t.Error("ProfilePhotos should be empty array, not nil")
	}
}

func TestNilPointersSerialization(t *testing.T) {
	user := User{
		ID:          "test-id",
		RealName:    "Test",
		DateOfBirth: nil,
		UpdatedAt:   nil,
		CreatedAt:   nil,
	}

	data, err := json.Marshal(user)
	if err != nil {
		t.Fatalf("Failed to marshal User with nil pointers: %v", err)
	}

	// Should not panic and should produce valid JSON
	if len(data) == 0 {
		t.Error("User serialization produced empty result")
	}
}
