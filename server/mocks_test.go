package main

import (
	"context"
	"sync"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// MockDB implements a mock database for testing
type MockDB struct {
	mu            sync.RWMutex
	users         map[string]User
	parties       map[string]Party
	chatRooms     map[string]ChatRoom
	messages      map[string][]ChatMessage
	applications  map[string]map[string]string // partyID -> userID -> status
	notifications map[string][]Notification
	blocked       map[string]map[string]bool // blockerID -> blockedID -> true
	reports       []map[string]string
	analytics     map[string]PartyAnalytics
	rotationPools map[string]Crowdfunding
	assets        map[string][]byte
}

func NewMockDB() *MockDB {
	return &MockDB{
		users:         make(map[string]User),
		parties:       make(map[string]Party),
		chatRooms:     make(map[string]ChatRoom),
		messages:      make(map[string][]ChatMessage),
		applications:  make(map[string]map[string]string),
		notifications: make(map[string][]Notification),
		blocked:       make(map[string]map[string]bool),
		reports:       make([]map[string]string, 0),
		analytics:     make(map[string]PartyAnalytics),
		rotationPools: make(map[string]Crowdfunding),
		assets:        make(map[string][]byte),
	}
}

// MockPool implements a mock connection pool
type MockPool struct {
	db *MockDB
}

func (m *MockPool) Query(ctx context.Context, sql string, args ...interface{}) (MockRows, error) {
	m.db.mu.RLock()
	defer m.db.mu.RUnlock()
	return MockRows{db: m.db, sql: sql, args: args}, nil
}

func (m *MockPool) QueryRow(ctx context.Context, sql string, args ...interface{}) MockRow {
	m.db.mu.RLock()
	defer m.db.mu.RUnlock()
	return MockRow{db: m.db, sql: sql, args: args}
}

func (m *MockPool) Exec(ctx context.Context, sql string, args ...interface{}) (int64, error) {
	m.db.mu.Lock()
	defer m.db.mu.Unlock()
	return 1, nil
}

func (m *MockPool) Begin(ctx context.Context) (MockTx, error) {
	m.db.mu.Lock()
	defer m.db.mu.Unlock()
	return MockTx{db: m.db}, nil
}

// MockRows implements mock query rows
type MockRows struct {
	db   *MockDB
	sql  string
	args []interface{}
}

func (m MockRows) Next() bool {
	return false
}

func (m MockRows) Scan(dest ...interface{}) error {
	return nil
}

func (m MockRows) Close() error {
	return nil
}

func (m MockRows) Err() error {
	return nil
}

// MockRow implements a mock query row
type MockRow struct {
	db   *MockDB
	sql  string
	args []interface{}
}

func (m MockRow) Scan(dest ...interface{}) error {
	return nil
}

// MockTx implements a mock transaction
type MockTx struct {
	db *MockDB
}

func (m MockTx) Commit(ctx context.Context) error {
	return nil
}

func (m MockTx) Rollback(ctx context.Context) error {
	return nil
}

func (m MockTx) Query(ctx context.Context, sql string, args ...interface{}) (MockRows, error) {
	return MockRows{db: m.db}, nil
}

func (m MockTx) QueryRow(ctx context.Context, sql string, args ...interface{}) MockRow {
	return MockRow{db: m.db}
}

func (m MockTx) Exec(ctx context.Context, sql string, args ...interface{}) (int64, error) {
	return 1, nil
}

// SetMockDB sets the global mock database
func SetMockDB(mockPool *MockPool) {
	// This would replace the global db variable in tests
	_ = mockPool
	_ = pgxpool.NewWithConfig
}

// Helper functions for creating test data
func CreateTestUser(id string) User {
	return User{
		ID:              id,
		RealName:        "Test User",
		Email:           "test@example.com",
		PasswordHash:    "hashed_password",
		ProfilePhotos:   []string{"hash1", "hash2"},
		Age:             25,
		HeightCm:        175,
		Gender:          "Male",
		DrinkingPref:    "Socially",
		SmokingPref:     "Never",
		JobTitle:        "Engineer",
		Company:         "Test Corp",
		School:          "Test University",
		Degree:          "BS",
		InstagramHandle: "@testuser",
		XHandle:         "@testuser",
		TikTokHandle:    "@testuser",
		IsVerified:      true,
		TrustScore:      95.5,
		EloScore:        1200.0,
		PartiesHosted:   5,
		FlakeCount:      0,
		LocationLat:     40.7128,
		LocationLon:     -74.0060,
		Bio:             "Test bio",
		Thumbnail:       "thumb_hash",
		CreatedAt:       timePtr(time.Now()),
	}
}

func CreateTestParty(id, hostID string) Party {
	return Party{
		ID:                 id,
		HostID:             hostID,
		Title:              "Test Party",
		Description:        "A test party",
		PartyPhotos:        []string{"photo1", "photo2"},
		StartTime:          time.Now().Add(24 * time.Hour),
		DurationHours:      4,
		Status:             PartyStatusOpen,
		IsLocationRevealed: false,
		Address:            "123 Test St",
		City:               "New York",
		GeoLat:             40.7128,
		GeoLon:             -74.0060,
		MaxCapacity:        50,
		CurrentGuestCount:  10,
		AutoLockOnFull:     true,
		VibeTags:           []string{"fun", "chill"},
		Rules:              []string{"Be respectful"},
		ChatRoomID:         "chat_" + id,
		CreatedAt:          timePtr(time.Now()),
		Thumbnail:          "party_thumb",
	}
}

func CreateTestChatRoom(id, partyID, hostID string) ChatRoom {
	return ChatRoom{
		ID:             id,
		PartyID:        partyID,
		HostID:         hostID,
		Title:          "Party Chat",
		ImageUrl:       "image_url",
		IsGroup:        true,
		ParticipantIDs: []string{hostID, "user2", "user3"},
		IsActive:       true,
		CreatedAt:      time.Now(),
	}
}

func CreateTestMessage(id, chatID, senderID string) ChatMessage {
	return ChatMessage{
		ID:              id,
		ChatID:          chatID,
		SenderID:        senderID,
		Type:            MsgText,
		Content:         "Test message",
		MediaURL:        "",
		ThumbnailURL:    "",
		Metadata:        nil,
		ReplyToID:       "",
		CreatedAt:       time.Now(),
		SenderName:      "Test User",
		SenderThumbnail: "thumb",
	}
}

func CreateTestNotification(id, userID string) Notification {
	return Notification{
		ID:        id,
		UserID:    userID,
		Type:      "party_invite",
		Title:     "Party Invite",
		Body:      "You've been invited to a party",
		Data:      "{}",
		IsRead:    false,
		CreatedAt: time.Now(),
	}
}

func timePtr(t time.Time) *time.Time {
	return &t
}
