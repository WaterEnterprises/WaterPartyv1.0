package main

import (
	"time"
)

// ==========================================
// ENUMS & CONSTANTS
// ==========================================

type PartyStatus string
type ApplicantStatus string
type MessageType string

const (
	PartyStatusOpen      PartyStatus = "OPEN"
	PartyStatusLocked    PartyStatus = "LOCKED"
	PartyStatusLive      PartyStatus = "LIVE"
	PartyStatusCompleted PartyStatus = "COMPLETED"
	PartyStatusCancelled PartyStatus = "CANCELLED"

	ApplicantPending  ApplicantStatus = "PENDING"
	ApplicantAccepted ApplicantStatus = "ACCEPTED"
	ApplicantDeclined ApplicantStatus = "DECLINED"
	ApplicantWaitlist ApplicantStatus = "WAITLIST"

	MsgText    MessageType = "TEXT"
	MsgImage   MessageType = "IMAGE"
	MsgVideo   MessageType = "VIDEO"
	MsgAudio   MessageType = "AUDIO"
	MsgSystem  MessageType = "SYSTEM"
	MsgWingman MessageType = "AI"
	MsgPayment MessageType = "PAYMENT"
)

// ==========================================
// WEBSOCKET ENVELOPE
// ==========================================

type WSMessage struct {
	Event   string      `json:"Event" db:"event"`
	Payload interface{} `json:"Payload" db:"payload"`
	Token   string      `json:"Token,omitempty" db:"token"`
}

// ==========================================
// CORE ENTITIES
// ==========================================

type WalletInfo struct {
	Type string `json:"Type" db:"wallet_type"` // e.g., "PayPal", "Bank", "Crypto"
	Data string `json:"Data" db:"wallet_data"` // e.g., email, IBAN, address
}

type User struct {
	ID              string     `json:"ID" db:"id"`
	RealName        string     `json:"RealName" db:"real_name"`
	PhoneNumber     string     `json:"PhoneNumber" db:"phone_number"`
	Email           string     `json:"-" db:"email"` // Email excluded from JSON for privacy
	PasswordHash    string     `json:"-" db:"password_hash"`
	ProfilePhotos   []string   `json:"ProfilePhotos" db:"profile_photos"` // Stores hashes
	Age             int        `json:"Age" db:"age"`
	DateOfBirth     *time.Time `json:"DateOfBirth,omitempty" db:"date_of_birth"`
	HeightCm        int        `json:"HeightCm" db:"height_cm"`
	Gender          string     `json:"Gender" db:"gender"`
	DrinkingPref    string     `json:"DrinkingPref" db:"drinking_pref"`
	SmokingPref     string     `json:"SmokingPref" db:"smoking_pref"`
	JobTitle        string     `json:"JobTitle" db:"job_title"`
	Company         string     `json:"Company" db:"company"`
	School          string     `json:"School" db:"school"`
	Degree          string     `json:"Degree" db:"degree"`
	InstagramHandle string     `json:"InstagramHandle" db:"instagram_handle"`
	LinkedinHandle  string     `json:"LinkedinHandle" db:"linkedin_handle"`
	XHandle         string     `json:"XHandle" db:"x_handle"`
	TikTokHandle    string     `json:"TikTokHandle" db:"tiktok_handle"`
	IsVerified      bool       `json:"IsVerified" db:"is_verified"`
	TrustScore      float64    `json:"TrustScore" db:"trust_score"`
	EloScore        float64    `json:"EloScore" db:"elo_score"`
	PartiesHosted   int        `json:"PartiesHosted" db:"parties_hosted"`
	FlakeCount      int        `json:"FlakeCount" db:"flake_count"`
	WalletData      WalletInfo `json:"WalletData" db:"wallet_data"`
	LocationLat     float64    `json:"LocationLat" db:"location_lat"`
	LocationLon     float64    `json:"LocationLon" db:"location_lon"`
	UpdatedAt       *time.Time `json:"UpdatedAt,omitempty" db:"updated_at"`
	CreatedAt       *time.Time `json:"CreatedAt,omitempty" db:"created_at"`
	Bio             string     `json:"Bio" db:"bio"`
	Thumbnail       string     `json:"Thumbnail" db:"thumbnail"`
}

type Party struct {
	ID                 string        `json:"ID" db:"id"`
	HostID             string        `json:"HostID" db:"host_id"`
	Title              string        `json:"Title" db:"title"`
	Description        string        `json:"Description" db:"description"`
	PartyPhotos        []string      `json:"PartyPhotos" db:"party_photos"` // Stores hashes
	StartTime          time.Time     `json:"StartTime" db:"start_time"`
	DurationHours      int           `json:"DurationHours" db:"duration_hours"`
	Status             PartyStatus   `json:"Status" db:"status"`
	IsLocationRevealed bool          `json:"IsLocationRevealed" db:"is_location_revealed"`
	Address            string        `json:"Address" db:"address"`
	City               string        `json:"City" db:"city"`
	GeoLat             float64       `json:"GeoLat" db:"geo_lat"`
	GeoLon             float64       `json:"GeoLon" db:"geo_lon"`
	MaxCapacity        int           `json:"MaxCapacity" db:"max_capacity"`
	CurrentGuestCount  int           `json:"CurrentGuestCount" db:"current_guest_count"`
	AutoLockOnFull     bool          `json:"AutoLockOnFull" db:"auto_lock_on_full"`
	VibeTags           []string      `json:"VibeTags" db:"vibe_tags"`
	Rules              []string      `json:"Rules" db:"rules"`
	RotationPool       *Crowdfunding `json:"RotationPool" db:"rotation_pool"` // Nested or separate table
	ChatRoomID         string        `json:"ChatRoomID" db:"chat_room_id"`
	CreatedAt          *time.Time    `json:"CreatedAt,omitempty" db:"created_at"`
	UpdatedAt          *time.Time    `json:"UpdatedAt,omitempty" db:"updated_at"`
	Thumbnail          string        `json:"Thumbnail" db:"thumbnail"`
}

type ChatRoom struct {
	ID             string     `json:"ID" db:"id"`
	PartyID        string     `json:"PartyID" db:"party_id"`
	HostID         string     `json:"HostID" db:"host_id"`
	Title          string     `json:"Title" db:"title"`
	ImageUrl       string     `json:"ImageUrl" db:"image_url"`
	IsGroup        bool       `json:"IsGroup" db:"is_group"`
	ParticipantIDs []string   `json:"ParticipantIDs" db:"participant_ids"`
	IsActive       bool       `json:"IsActive" db:"is_active"`
	CreatedAt      time.Time  `json:"CreatedAt" db:"created_at"`
	PartyStartTime *time.Time `json:"PartyStartTime,omitempty"`
}

type ChatMessage struct {
	ID              string                 `json:"ID" db:"id"`
	ChatID          string                 `json:"ChatID" db:"chat_id"`
	SenderID        string                 `json:"SenderID" db:"sender_id"`
	Type            MessageType            `json:"Type" db:"type"`
	Content         string                 `json:"Content" db:"content"`
	MediaURL        string                 `json:"MediaURL" db:"media_url"` // Computed hash URL
	ThumbnailURL    string                 `json:"ThumbnailURL" db:"thumbnail_url"`
	Metadata        map[string]interface{} `json:"Metadata" db:"metadata"` // Use JSONB in DB
	ReplyToID       string                 `json:"ReplyToID" db:"reply_to_id"`
	CreatedAt       time.Time              `json:"CreatedAt" db:"created_at"`
	SenderName      string                 `json:"SenderName" db:"sender_name"`
	SenderThumbnail string                 `json:"SenderThumbnail" db:"sender_thumbnail"`
}

type Crowdfunding struct {
	ID            string         `json:"ID" db:"id"`
	PartyID       string         `json:"PartyID" db:"party_id"`
	TargetAmount  float64        `json:"TargetAmount" db:"target_amount"`
	CurrentAmount float64        `json:"CurrentAmount" db:"current_amount"`
	Currency      string         `json:"Currency" db:"currency"`
	Contributors  []Contribution `json:"Contributors" db:"contributors"` // Use JSONB array or separate table
	IsFunded      bool           `json:"IsFunded" db:"is_funded"`
}

type Contribution struct {
	UserID string    `json:"UserID" db:"user_id"`
	Amount float64   `json:"Amount" db:"amount"`
	PaidAt time.Time `json:"PaidAt" db:"paid_at"`
}

// Notification represents a user notification
type Notification struct {
	ID        string    `json:"ID" db:"id"`
	UserID    string    `json:"UserID" db:"user_id"`
	Type      string    `json:"Type" db:"type"`
	Title     string    `json:"Title" db:"title"`
	Body      string    `json:"Body" db:"body"`
	Data      string    `json:"Data" db:"data"`
	IsRead    bool      `json:"IsRead" db:"is_read"`
	CreatedAt time.Time `json:"CreatedAt" db:"created_at"`
}

// PartyAnalytics holds party statistics
type PartyAnalytics struct {
	PartyID           string `json:"PartyID"`
	TotalViews        int    `json:"TotalViews"`
	TotalApplications int    `json:"TotalApplications"`
	AcceptedCount     int    `json:"AcceptedCount"`
	PendingCount      int    `json:"PendingCount"`
	DeclinedCount     int    `json:"DeclinedCount"`
	CurrentGuestCount int    `json:"CurrentGuestCount"`
}
