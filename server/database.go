package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"image"

	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"log"
	"strings"
	"time"

	_ "golang.org/x/image/bmp"
	_ "golang.org/x/image/webp"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nfnt/resize"
)

var db *pgxpool.Pool

// InitDB initializes the connection pool
func InitDB(connString string) {
	var err error
	config, err := pgxpool.ParseConfig(connString)
	if err != nil {
		log.Fatalf("Unable to parse connection string: %v", err)
	}

	db, err = pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}

	// Run the schema setup
	if err := Migrate(); err != nil {
		log.Fatalf("❌ Database migration failed: %v", err)
	}

	fmt.Println("✅ Database initialized and schema verified.")
}

// ==========================================
// ASSET / FILE METHODS
// ==========================================

// SaveAsset stores binary data, returns the SHA256 hash.
func SaveAsset(data []byte, mimeType string) (string, error) {
	hashBytes := sha256.Sum256(data)
	hashStr := hex.EncodeToString(hashBytes[:])

	_, err := db.Exec(context.Background(),
		"INSERT INTO assets (hash, data, mime_type) VALUES ($1, $2, $3) ON CONFLICT (hash) DO NOTHING",
		hashStr, data, mimeType)
	return hashStr, err
}

// GetAsset retrieves binary data and mime type by hash.
func GetAsset(hash string) ([]byte, string, error) {
	var data []byte
	var mimeType string
	err := db.QueryRow(context.Background(),
		"SELECT data, mime_type FROM assets WHERE hash = $1", hash).Scan(&data, &mimeType)
	return data, mimeType, err
}

// DeleteAsset removes an asset from the database by hash.
func DeleteAsset(hash string) error {
	_, err := db.Exec(context.Background(),
		"DELETE FROM assets WHERE hash = $1", hash)
	return err
}

// CreateThumbnail generates a 150x150 thumbnail from image data.
func CreateThumbnail(data []byte) ([]byte, error) {
	img, _, err := image.Decode(bytes.NewReader(data))
	if err != nil {
		return nil, err
	}
	// Resize to 300p
	m := resize.Resize(300, 0, img, resize.Lanczos3)
	buf := new(bytes.Buffer)
	err = jpeg.Encode(buf, m, nil)
	return buf.Bytes(), err
}

// ==========================================
// USER CRUD
// ==========================================

func CreateUser(u User) (string, error) {
	walletJSON, _ := json.Marshal(u.WalletData)
	query := `INSERT INTO users (
		real_name, phone_number, email, profile_photos, age, 
		date_of_birth,height_cm, gender, drinking_pref, smoking_pref,job_title, company, school, degree,
		instagram_handle, linkedin_handle, x_handle, tiktok_handle,is_verified, 
		trust_score, elo_score, parties_hosted, flake_count,wallet_data, 
		location_lat, location_lon, bio, updated_at, thumbnail
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, 
		$13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30) 
	RETURNING id`

	var id string
	now := time.Now()
	err := db.QueryRow(context.Background(), query,
		u.RealName, u.PhoneNumber, u.Email, u.ProfilePhotos, u.Age,
		u.DateOfBirth, u.HeightCm, u.Gender, u.DrinkingPref, u.SmokingPref, u.JobTitle, u.Company, u.School, u.Degree,
		u.InstagramHandle, u.LinkedinHandle, u.XHandle, u.TikTokHandle, u.IsVerified,
		u.TrustScore, u.EloScore, u.PartiesHosted, u.FlakeCount, walletJSON,
		u.LocationLat, u.LocationLon, u.Bio, &now, u.Thumbnail,
	).Scan(&id)
	return id, err
}

func GetUser(id string) (User, error) {
	var u User
	var passwordHash string
	var walletJSON []byte
	var profilePhotos []string
	query := `SELECT id, real_name, COALESCE(phone_number, ''), email, password_hash, COALESCE(profile_photos, '{}'), age, 
		date_of_birth, height_cm, gender, COALESCE(drinking_pref, ''), COALESCE(smoking_pref, ''), 
		COALESCE(job_title, ''), COALESCE(company, ''), COALESCE(school, ''), COALESCE(degree, ''), COALESCE(instagram_handle, ''), 
		COALESCE(linkedin_handle, ''), COALESCE(x_handle, ''), COALESCE(tiktok_handle, ''), is_verified, trust_score, 
		elo_score, parties_hosted, flake_count, COALESCE(wallet_data::text, '{}'), location_lat, location_lon, 
		updated_at, created_at, COALESCE(bio, ''), COALESCE(thumbnail, '') 
		FROM users WHERE id = $1`

	err := db.QueryRow(context.Background(), query, id).Scan(
		&u.ID, &u.RealName, &u.PhoneNumber, &u.Email, &passwordHash, &profilePhotos, &u.Age,
		&u.DateOfBirth, &u.HeightCm, &u.Gender, &u.DrinkingPref, &u.SmokingPref,
		&u.JobTitle, &u.Company, &u.School, &u.Degree, &u.InstagramHandle,
		&u.LinkedinHandle, &u.XHandle, &u.TikTokHandle, &u.IsVerified, &u.TrustScore,
		&u.EloScore, &u.PartiesHosted, &u.FlakeCount, &walletJSON, &u.LocationLat, &u.LocationLon,
		&u.UpdatedAt, &u.CreatedAt, &u.Bio, &u.Thumbnail,
	)
	if err == nil {
		json.Unmarshal(walletJSON, &u.WalletData)
		u.ProfilePhotos = profilePhotos
	}
	return u, err
}

func GetUserByEmail(email string) (User, string, error) {
	var u User
	var passwordHash string
	var walletJSON []byte
	var profilePhotos []string
	query := `SELECT id, real_name, COALESCE(phone_number, ''), email, password_hash, COALESCE(profile_photos, '{}'), age, 
		date_of_birth, height_cm, gender, COALESCE(drinking_pref, ''), COALESCE(smoking_pref, ''), 
		 COALESCE(job_title, ''), COALESCE(company, ''), COALESCE(school, ''), COALESCE(degree, ''), COALESCE(instagram_handle, ''), 
		COALESCE(linkedin_handle, ''), COALESCE(x_handle, ''), COALESCE(tiktok_handle, ''), is_verified, trust_score, 
		elo_score, parties_hosted, flake_count, COALESCE(wallet_data::text, '{}'), location_lat, location_lon, 
		updated_at, created_at, COALESCE(bio, ''), COALESCE(thumbnail, '') 
		FROM users WHERE email = $1`

	err := db.QueryRow(context.Background(), query, email).Scan(
		&u.ID, &u.RealName, &u.PhoneNumber, &u.Email, &passwordHash, &profilePhotos, &u.Age,
		&u.DateOfBirth, &u.HeightCm, &u.Gender, &u.DrinkingPref, &u.SmokingPref,
		&u.JobTitle, &u.Company, &u.School, &u.Degree, &u.InstagramHandle,
		&u.LinkedinHandle, &u.XHandle, &u.TikTokHandle, &u.IsVerified, &u.TrustScore,
		&u.EloScore, &u.PartiesHosted, &u.FlakeCount, &walletJSON, &u.LocationLat, &u.LocationLon,
		&u.UpdatedAt, &u.CreatedAt, &u.Bio, &u.Thumbnail,
	)
	if err == nil {
		json.Unmarshal(walletJSON, &u.WalletData)
		u.ProfilePhotos = profilePhotos
	}
	return u, passwordHash, err
}

func UpdateUser(u User) error {
	walletJSON, _ := json.Marshal(u.WalletData)

	// Debug logging to diagnose parameter type issues
	log.Printf("DEBUG UpdateUser: RealName=%q, PhoneNumber=%q, ProfilePhotos=%v, Thumbnail=%q",
		u.RealName, u.PhoneNumber, u.ProfilePhotos, u.Thumbnail)
	log.Printf("DEBUG UpdateUser: DrinkingPref=%q, SmokingPref=%q, JobTitle=%q",
		u.DrinkingPref, u.SmokingPref, u.JobTitle)

	// Auto-generate thumbnail from first profile photo if needed
	_thumb := u.Thumbnail
	// Get current user to check if we need to regenerate thumbnail
	// Only auto-generate if first photo changed and no explicit thumbnail provided
	if len(u.ProfilePhotos) > 0 {
		url := u.ProfilePhotos[0]
		// Strip /assets/ prefix if present (some clients send full URL)
		parts := strings.Split(url, "/")

		// 2. Grab the last item in that slice
		hash := parts[len(parts)-1]
		log.Printf("DEBUG UpdateUser: Auto-generating thumbnail from first photo: %s", hash)

		// Get the original image data from assets table
		imageData, mimeType, err := GetAsset(hash)
		if err != nil {
			log.Printf("DEBUG UpdateUser: Could not get original image: %v", err)
		} else {
			// Create thumbnail from image data
			thumbData, err := CreateThumbnail(imageData)
			if err != nil {
				log.Printf("DEBUG UpdateUser: Could not create thumbnail: %v", err)
			} else {
				// Save thumbnail as new asset and get its hash
				thumbHash, err := SaveAsset(thumbData, mimeType)
				if err != nil {
					log.Printf("DEBUG UpdateUser: Could not save thumbnail: %v", err)
				} else {
					_thumb = thumbHash
					log.Printf("DEBUG UpdateUser: Auto-generated thumbnail: %s", thumbHash)
				}
			}
		}
	}

	// Handle empty strings by using NULL for TEXT columns when empty
	// This fixes "could not determine data type of parameter" error
	phoneNumber := nullString(u.PhoneNumber)
	drinkingPref := nullString(u.DrinkingPref)
	smokingPref := nullString(u.SmokingPref)
	jobTitle := nullString(u.JobTitle)
	company := nullString(u.Company)
	school := nullString(u.School)
	degree := nullString(u.Degree)
	instagramHandle := nullString(u.InstagramHandle)
	linkedinHandle := nullString(u.LinkedinHandle)
	xHandle := nullString(u.XHandle)
	tiktokHandle := nullString(u.TikTokHandle)
	thumbnail := nullString(_thumb)
	bio := nullString(u.Bio)

	query := `UPDATE users SET 
		real_name=CAST($1 AS TEXT), 
		phone_number=CAST($2 AS TEXT), 
		profile_photos=CAST($3 AS TEXT[]), 
		bio=CAST($4 AS TEXT),
		location_lat=$5, 
		location_lon=$6, 
		updated_at=$7,
		instagram_handle=CAST($8 AS TEXT), 
		linkedin_handle=CAST($9 AS TEXT), 
		x_handle=CAST($10 AS TEXT), 
		tiktok_handle=CAST($11 AS TEXT), 
		wallet_data=$12,
		job_title=CAST($13 AS TEXT), 
		company=CAST($14 AS TEXT), 
		school=CAST($15 AS TEXT), 
		degree=CAST($16 AS TEXT), 
		age=$17,
		height_cm=$18, 
		gender=CAST($19 AS TEXT), 
		drinking_pref=CAST($20 AS TEXT), 
		smoking_pref=CAST($21 AS TEXT), 
		thumbnail=CAST($22 AS TEXT)
		WHERE id=$23`
	_, err := db.Exec(context.Background(), query,
		u.RealName, phoneNumber, u.ProfilePhotos, bio,
		u.LocationLat, u.LocationLon, time.Now(),
		instagramHandle, linkedinHandle, xHandle,
		tiktokHandle, walletJSON, jobTitle, company, school,
		degree, u.Age, u.HeightCm, u.Gender, drinkingPref,
		smokingPref, thumbnail, u.ID)
	return err
}

// nullString converts empty string to nil for proper NULL handling in PostgreSQL
func nullString(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

func DeleteUser(id string) error {
	if db == nil {
		return fmt.Errorf("database not initialized")
	}

	// Delete related records first to avoid foreign key constraint violations
	// Delete blocked user relationships
	_, err := db.Exec(context.Background(),
		"DELETE FROM blocked_users WHERE blocker_id = $1 OR blocked_id = $1", id)
	if err != nil {
		return err
	}

	// Delete user reports
	_, err = db.Exec(context.Background(),
		"DELETE FROM user_reports WHERE reporter_id = $1 OR reported_id = $1", id)
	if err != nil {
		return err
	}

	// Delete party reports by this user
	_, err = db.Exec(context.Background(),
		"DELETE FROM party_reports WHERE reporter_id = $1", id)
	if err != nil {
		return err
	}

	// Delete notifications
	_, err = db.Exec(context.Background(),
		"DELETE FROM notifications WHERE user_id = $1", id)
	if err != nil {
		return err
	}

	// Delete chat messages where user is sender
	_, err = db.Exec(context.Background(),
		"DELETE FROM chat_messages WHERE sender_id = $1", id)
	if err != nil {
		return err
	}

	// Delete party applications
	_, err = db.Exec(context.Background(),
		"DELETE FROM party_applications WHERE user_id = $1", id)
	if err != nil {
		return err
	}

	// Delete chat rooms where user is host
	_, err = db.Exec(context.Background(),
		"DELETE FROM chat_rooms WHERE host_id = $1", id)
	if err != nil {
		return err
	}

	// Delete parties hosted by user
	_, err = db.Exec(context.Background(),
		"DELETE FROM parties WHERE host_id = $1", id)
	if err != nil {
		return err
	}

	// Finally delete the user
	_, err = db.Exec(context.Background(), "DELETE FROM users WHERE id = $1", id)
	return err
}

// ==========================================
// PARTY CRUD
// ==========================================

func CreateParty(p Party) (string, error) {
	// Use atomic transaction to ensure party and chat room are created together
	tx, err := db.Begin(context.Background())
	if err != nil {
		return "", fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(context.Background())

	// Insert party
	partyQuery := `INSERT INTO parties (
		host_id, title, description, party_photos, start_time, duration_hours, status,
		is_location_revealed, address, city, geo_lat, geo_lon, max_capacity, current_guest_count,
		vibe_tags, rules, chat_room_id, thumbnail, created_at, updated_at
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20) 
	RETURNING id`

	var partyID string
	now := time.Now()
	err = tx.QueryRow(context.Background(), partyQuery,
		p.HostID, p.Title, p.Description, p.PartyPhotos, p.StartTime, p.DurationHours, p.Status,
		p.IsLocationRevealed, p.Address, p.City, p.GeoLat, p.GeoLon, p.MaxCapacity, 1, // current_guest_count = 1 (creator)
		p.VibeTags, p.Rules, p.ChatRoomID, p.Thumbnail, now, now,
	).Scan(&partyID)

	if err != nil {
		return "", fmt.Errorf("failed to insert party: %w", err)
	}

	// Insert chat room with creator as participant (for authorization filtering)
	chatRoomQuery := `INSERT INTO chat_rooms (
		id, party_id, host_id, title, is_group, participant_ids, is_active, created_at
	) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`

	var chatRoomID string
	err = tx.QueryRow(context.Background(), chatRoomQuery,
		p.ChatRoomID, partyID, p.HostID, p.Title, true, []string{p.HostID}, true, now,
	).Scan(&chatRoomID)

	if err != nil {
		return "", fmt.Errorf("failed to create chat room: %w", err)
	}

	// Create crowdfunding/rotation pool if specified
	if p.RotationPool != nil {
		contribs, _ := json.Marshal(p.RotationPool.Contributors)
		rotationQuery := `INSERT INTO crowdfunding (
			party_id, target_amount, current_amount, currency, contributors, is_funded
		) VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`

		var rotationID string
		err = tx.QueryRow(context.Background(), rotationQuery,
			partyID, p.RotationPool.TargetAmount, p.RotationPool.CurrentAmount,
			p.RotationPool.Currency, contribs, p.RotationPool.IsFunded,
		).Scan(&rotationID)
		if err != nil {
			return "", fmt.Errorf("failed to create rotation pool: %w", err)
		}
	}

	// Commit transaction
	if err := tx.Commit(context.Background()); err != nil {
		return "", fmt.Errorf("failed to commit transaction: %w", err)
	}

	log.Printf("CreateParty: Successfully created party %s with chat room %s and participant record", partyID, chatRoomID)
	return partyID, nil
}

func GetParty(id string) (Party, error) {
	var p Party
	query := `SELECT id, host_id, title, description, party_photos, start_time, duration_hours, status,
		is_location_revealed, address, city, geo_lat, geo_lon, max_capacity, current_guest_count,
		auto_lock_on_full, vibe_tags, rules, chat_room_id,
		created_at, updated_at, thumbnail FROM parties WHERE id = $1`

	err := db.QueryRow(context.Background(), query, id).Scan(
		&p.ID, &p.HostID, &p.Title, &p.Description, &p.PartyPhotos, &p.StartTime, &p.DurationHours,
		&p.Status, &p.IsLocationRevealed, &p.Address, &p.City, &p.GeoLat, &p.GeoLon,
		&p.MaxCapacity, &p.CurrentGuestCount, &p.AutoLockOnFull, &p.VibeTags,
		&p.Rules, &p.ChatRoomID, &p.CreatedAt, &p.UpdatedAt, &p.Thumbnail,
	)
	return p, err
}

func UpdateParty(p Party) error {
	query := `UPDATE parties SET 
		title=$1, description=$2, status=$3, is_location_revealed=$4, address=$5,
		city=$6, max_capacity=$7, thumbnail=$8, updated_at=NOW()
		WHERE id=$9`
	_, err := db.Exec(context.Background(), query, p.Title, p.Description, p.Status,
		p.IsLocationRevealed, p.Address, p.City, p.MaxCapacity, p.Thumbnail, p.ID)
	return err
}

func UpdatePartyStatus(partyID string, status PartyStatus) error {
	_, err := db.Exec(context.Background(), "UPDATE parties SET status = $1, updated_at = NOW() WHERE id = $2", status, partyID)
	return err
}

func DeleteParty(id string) error {
	_, err := db.Exec(context.Background(), "DELETE FROM parties WHERE id = $1", id)
	return err
}

func GetApplicantsForParty(partyID string) ([]map[string]interface{}, error) {
	// CRITICAL FIX: Select ALL User fields to prevent data truncation in UI
	// Previously only selected 11 fields, now selecting all 33 fields
	query := `SELECT 
		pa.party_id, pa.user_id, pa.status, pa.applied_at,
		-- Complete User object fields (all 33 fields)
		u.id, u.real_name, u.phone_number, u.email, u.profile_photos, u.age, 
		u.date_of_birth, u.height_cm, u.gender, u.drinking_pref, u.smoking_pref,
		u.job_title, u.company, u.school, u.degree, u.instagram_handle, 
		u.linkedin_handle, u.x_handle, u.tiktok_handle, u.is_verified, 
		u.trust_score, u.elo_score, u.parties_hosted, u.flake_count, 
		u.wallet_data, u.location_lat, u.location_lon, u.last_active_at,
		u.created_at, u.bio, u.thumbnail
		FROM party_applications pa
		JOIN users u ON pa.user_id = u.id
		WHERE pa.party_id = $1
		ORDER BY u.elo_score DESC`

	rows, err := db.Query(context.Background(), query, partyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var apps []map[string]interface{}
	for rows.Next() {
		// Application fields
		var partyID, userID, status string
		var appliedAt time.Time

		// Complete User fields (all 33 fields) - NOT NULL enforced by schema
		var id, realName, phoneNumber, email string
		var bio, thumbnail string
		var profilePhotos []string
		var age int
		var dateOfBirth *time.Time
		var heightCm int
		var gender, drinkingPref, smokingPref string
		var jobTitle, company, school, degree string
		var instagramHandle, linkedinHandle, xHandle, tiktokHandle string
		var isVerified bool
		var trustScore, eloScore float64
		var partiesHosted, flakeCount int
		var walletDataJSON []byte
		var locationLat, locationLon float64
		var lastActiveAt, createdAt *time.Time

		// Scan all 33 User fields - no COALESCE needed due to schema constraints
		err := rows.Scan(
			// Application fields (4)
			&partyID, &userID, &status, &appliedAt,
			// User fields (29) - all text columns have NOT NULL DEFAULT ''
			&id, &realName, &phoneNumber, &email, &profilePhotos, &age,
			&dateOfBirth, &heightCm, &gender, &drinkingPref, &smokingPref,
			&jobTitle, &company, &school, &degree, &instagramHandle,
			&linkedinHandle, &xHandle, &tiktokHandle, &isVerified,
			&trustScore, &eloScore, &partiesHosted, &flakeCount,
			&walletDataJSON, &locationLat, &locationLon, &lastActiveAt,
			&createdAt, &bio, &thumbnail,
		)
		if err != nil {
			log.Printf("[ERROR] GetApplicantsForParty: Failed to scan row: %v", err)
			return nil, err
		}

		// Parse wallet data JSON
		var walletData map[string]interface{}
		if len(walletDataJSON) > 0 {
			json.Unmarshal(walletDataJSON, &walletData)
		}

		// Build complete User object with all fields (no NULL handling needed)
		// Email is excluded from public API responses for privacy
		userMap := map[string]interface{}{
			"ID":              id,
			"RealName":        realName,
			"PhoneNumber":     phoneNumber,
			"ProfilePhotos":   profilePhotos,
			"Age":             age,
			"DateOfBirth":     dateOfBirth,
			"HeightCm":        heightCm,
			"Gender":          gender,
			"DrinkingPref":    drinkingPref,
			"SmokingPref":     smokingPref,
			"JobTitle":        jobTitle,
			"Company":         company,
			"School":          school,
			"Degree":          degree,
			"InstagramHandle": instagramHandle,
			"LinkedinHandle":  linkedinHandle,
			"XHandle":         xHandle,
			"TikTokHandle":    tiktokHandle,
			"IsVerified":      isVerified,
			"TrustScore":      trustScore,
			"EloScore":        eloScore,
			"PartiesHosted":   partiesHosted,
			"FlakeCount":      flakeCount,
			"WalletData":      walletData,
			"LocationLat":     locationLat,
			"LocationLon":     locationLon,
			"LastActiveAt":    lastActiveAt,
			"CreatedAt":       createdAt,
			"Bio":             bio,
			"Thumbnail":       thumbnail,
		}

		apps = append(apps, map[string]interface{}{
			"PartyID":   partyID,
			"UserID":    userID,
			"Status":    status,
			"AppliedAt": appliedAt,
			"User":      userMap,
		})
	}

	if err = rows.Err(); err != nil {
		log.Printf("[ERROR] GetApplicantsForParty: Row iteration error: %v", err)
		return nil, err
	}

	log.Printf("[DEBUG] GetApplicantsForParty: Retrieved %d applicants with complete User data for party %s", len(apps), partyID)
	return apps, nil
}

// GetAcceptedApplicants returns users who have been accepted to a party
// Includes all profile fields for complete UI display
func GetAcceptedApplicants(partyID string) ([]map[string]interface{}, error) {
	query := `SELECT pa.party_id, pa.user_id, pa.status, pa.applied_at,
		-- Complete User profile fields
		u.id, u.real_name, u.profile_photos, u.age, u.height_cm, u.gender,
		u.drinking_pref, u.smoking_pref, u.job_title, u.company, u.school, u.degree,
		u.instagram_handle, u.linkedin_handle, u.x_handle, u.tiktok_handle,
		u.is_verified, u.trust_score, u.elo_score, u.bio, u.thumbnail
		FROM party_applications pa
		JOIN users u ON pa.user_id = u.id
		WHERE pa.party_id = $1 AND pa.status = 'ACCEPTED'
		ORDER BY u.elo_score DESC`

	rows, err := db.Query(context.Background(), query, partyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var apps []map[string]interface{}
	for rows.Next() {
		// Application fields
		var partyID, userID, status string
		var appliedAt time.Time

		// User fields
		var id, realName string
		var profilePhotos []string
		var age, heightCm int
		var gender, drinkingPref, smokingPref string
		var jobTitle, company, school, degree string
		var instagramHandle, linkedinHandle, xHandle, tiktokHandle string
		var isVerified bool
		var trustScore, eloScore float64
		var bio, thumbnail string

		err := rows.Scan(
			&partyID, &userID, &status, &appliedAt,
			&id, &realName, &profilePhotos, &age, &heightCm, &gender,
			&drinkingPref, &smokingPref, &jobTitle, &company, &school, &degree,
			&instagramHandle, &linkedinHandle, &xHandle, &tiktokHandle,
			&isVerified, &trustScore, &eloScore, &bio, &thumbnail,
		)
		if err != nil {
			return nil, err
		}

		apps = append(apps, map[string]interface{}{
			"PartyID":   partyID,
			"UserID":    userID,
			"Status":    status,
			"AppliedAt": appliedAt,
			"User": map[string]interface{}{
				"ID":              id,
				"RealName":        realName,
				"ProfilePhotos":   profilePhotos,
				"Age":             age,
				"HeightCm":        heightCm,
				"Gender":          gender,
				"DrinkingPref":    drinkingPref,
				"SmokingPref":     smokingPref,
				"JobTitle":        jobTitle,
				"Company":         company,
				"School":          school,
				"Degree":          degree,
				"InstagramHandle": instagramHandle,
				"LinkedinHandle":  linkedinHandle,
				"XHandle":         xHandle,
				"TikTokHandle":    tiktokHandle,
				"IsVerified":      isVerified,
				"TrustScore":      trustScore,
				"EloScore":        eloScore,
				"Bio":             bio,
				"Thumbnail":       thumbnail,
			},
		})
	}
	return apps, nil
}

func UpdateApplicationStatus(partyID, userID, status string) error {
	tx, err := db.Begin(context.Background())
	if err != nil {
		return err
	}
	defer tx.Rollback(context.Background())

	_, err = tx.Exec(context.Background(),
		"UPDATE party_applications SET status = $1 WHERE party_id = $2 AND user_id = $3",
		status, partyID, userID)
	if err != nil {
		return err
	}

	if status == "ACCEPTED" {
		// Also add the user to the chat room participants
		_, err = tx.Exec(context.Background(),
			"UPDATE chat_rooms SET participant_ids = array_append(participant_ids, $1) WHERE party_id = $2 AND NOT ($1 = ANY(participant_ids))",
			userID, partyID)
		if err != nil {
			return err
		}
	}

	return tx.Commit(context.Background())
}

func CreateChatRoom(cr ChatRoom) (string, error) {
	query := `INSERT INTO chat_rooms (id, party_id, host_id, title, image_url, is_group, participant_ids) 
	          VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id`

	var id string
	err := db.QueryRow(context.Background(), query, cr.ID, cr.PartyID, cr.HostID, cr.Title, cr.ImageUrl, cr.IsGroup, cr.ParticipantIDs).Scan(&id)
	return id, err
}

func GetChatRoom(id string) (ChatRoom, error) {
	var cr ChatRoom
	var partyID, title, imageURL *string
	var partyStartTime *time.Time
	query := `
		SELECT cr.id, cr.party_id, cr.host_id, COALESCE(cr.title, p.title, '') as title, cr.image_url, cr.is_group, cr.participant_ids, cr.is_active, cr.created_at, p.start_time
		FROM chat_rooms cr
		LEFT JOIN parties p ON cr.party_id = p.id
		WHERE cr.id = $1`
	err := db.QueryRow(context.Background(), query, id).Scan(
		&cr.ID, &partyID, &cr.HostID, &title, &imageURL, &cr.IsGroup, &cr.ParticipantIDs, &cr.IsActive, &cr.CreatedAt, &partyStartTime,
	)
	if err == nil {
		if partyID != nil {
			cr.PartyID = *partyID
		}
		if title != nil {
			cr.Title = *title
		}
		if imageURL != nil {
			cr.ImageUrl = *imageURL
		}
		cr.PartyStartTime = partyStartTime
	}
	return cr, err
}

func GetChatRoomByParty(partyID string) (ChatRoom, error) {
	var cr ChatRoom
	var pID, title, imageURL *string
	var partyStartTime *time.Time
	query := `
		SELECT cr.id, cr.party_id, cr.host_id, COALESCE(cr.title, p.title, '') as title, cr.image_url, cr.is_group, cr.participant_ids, cr.is_active, cr.created_at, p.start_time
		FROM chat_rooms cr
		LEFT JOIN parties p ON cr.party_id = p.id
		WHERE cr.party_id = $1`
	err := db.QueryRow(context.Background(), query, partyID).Scan(
		&cr.ID, &pID, &cr.HostID, &title, &imageURL, &cr.IsGroup, &cr.ParticipantIDs, &cr.IsActive, &cr.CreatedAt, &partyStartTime,
	)
	if err == nil {
		if pID != nil {
			cr.PartyID = *pID
		}
		if title != nil {
			cr.Title = *title
		}
		if imageURL != nil {
			cr.ImageUrl = *imageURL
		}
		cr.PartyStartTime = partyStartTime
	}
	return cr, err
}

func GetChatRoomsForUser(userID string) ([]map[string]interface{}, error) {
	query := `
		SELECT cr.id, cr.party_id, cr.host_id, COALESCE(cr.title, p.title, '') as room_title, cr.image_url, cr.is_group, cr.participant_ids, cr.is_active, cr.created_at,
		       (SELECT content FROM chat_messages WHERE chat_id = cr.id ORDER BY created_at DESC LIMIT 1) as last_message_content,
		       (SELECT created_at FROM chat_messages WHERE chat_id = cr.id ORDER BY created_at DESC LIMIT 1) as last_message_at,
		       p.thumbnail as party_thumbnail,
		       (SELECT u.thumbnail FROM users u WHERE u.id = ANY(cr.participant_ids) AND u.id != $1 LIMIT 1) as dm_thumbnail,
		       p.title as p_title,
		       p.start_time as party_start_time
		FROM chat_rooms cr
		LEFT JOIN parties p ON cr.party_id = p.id
		WHERE $1::UUID = ANY(cr.participant_ids)
		  AND (
			  p.host_id = $1
			  OR EXISTS (SELECT 1 FROM party_applications WHERE party_id = p.id AND user_id = $1 AND status = 'ACCEPTED')
			  OR EXISTS (SELECT 1 FROM party_matches WHERE party_id = p.id AND (creator_id = $1 OR matched_user_id = $1))
		  )
		ORDER BY last_message_at DESC NULLS LAST, cr.created_at DESC`

	rows, err := db.Query(context.Background(), query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rooms []map[string]interface{}
	for rows.Next() {
		var id, hostID string
		var partyID, title, imageURL *string
		var isGroup, isActive bool
		var participantIDs []string
		var createdAt time.Time
		var lastMsgContent *string
		var lastMsgAt *time.Time
		var partyThumbnail, dmThumbnail *string
		var pTitle *string
		var partySTime *time.Time

		err := rows.Scan(&id, &partyID, &hostID, &title, &imageURL, &isGroup, &participantIDs, &isActive, &createdAt,
			&lastMsgContent, &lastMsgAt, &partyThumbnail, &dmThumbnail, &pTitle, &partySTime)
		if err != nil {
			return nil, err
		}

		room := map[string]interface{}{
			"ID":             id,
			"PartyID":        "",
			"HostID":         hostID,
			"Title":          "",
			"ImageUrl":       "",
			"IsGroup":        isGroup,
			"ParticipantIDs": participantIDs,
			"IsActive":       isActive,
			"CreatedAt":      createdAt,
			"RecentMessages": []interface{}{}, // Initial list empty
			"UnreadCount":    0,               // Placeholder
		}

		if partyID != nil {
			room["PartyID"] = *partyID
		}
		if title != nil {
			room["Title"] = *title
		}

		finalImageUrl := ""
		if imageURL != nil {
			finalImageUrl = *imageURL
		}

		// Prioritise thumbnails
		if isGroup && partyThumbnail != nil && *partyThumbnail != "" {
			finalImageUrl = *partyThumbnail
		} else if !isGroup && dmThumbnail != nil && *dmThumbnail != "" {
			finalImageUrl = *dmThumbnail
		}
		room["ImageUrl"] = finalImageUrl

		// Prioritize party title for group chats
		if isGroup && pTitle != nil && *pTitle != "" {
			room["Title"] = *pTitle
		}

		if partySTime != nil {
			room["StartTime"] = *partySTime
		}

		if lastMsgContent != nil {
			room["LastMessageContent"] = *lastMsgContent
		} else {
			room["LastMessageContent"] = "No messages yet"
		}
		if lastMsgAt != nil {
			room["LastMessageAt"] = *lastMsgAt
		}

		rooms = append(rooms, room)
	}
	return rooms, nil
}

// ==========================================
// CHANNEL / CHAT METHODS
// ==========================================

func SaveMessage(m ChatMessage) (string, error) {
	meta, _ := json.Marshal(m.Metadata)
	query := `INSERT INTO chat_messages (chat_id, sender_id, type, content, media_url, 
		thumbnail_url, metadata, reply_to_id) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`

	var id string
	var replyID interface{} = nil
	if m.ReplyToID != "" {
		replyID = m.ReplyToID
	}

	err := db.QueryRow(context.Background(), query, m.ChatID, m.SenderID, m.Type, m.Content,
		m.MediaURL, m.ThumbnailURL, meta, replyID).Scan(&id)
	return id, err
}

func GetChatHistory(chatID string, limit int) ([]ChatMessage, error) {
	query := `SELECT m.id, m.sender_id, m.type, m.content, m.media_url, m.thumbnail_url, m.metadata, m.reply_to_id, m.created_at,
		u.real_name as sender_name, COALESCE(u.thumbnail, '') as sender_thumbnail
		FROM chat_messages m
		JOIN users u ON m.sender_id = u.id
		WHERE m.chat_id = $1 ORDER BY m.created_at DESC LIMIT $2`

	rows, err := db.Query(context.Background(), query, chatID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var msgs []ChatMessage
	for rows.Next() {
		var m ChatMessage
		var meta []byte
		var replyID *string // Handle potential nulls
		err := rows.Scan(&m.ID, &m.SenderID, &m.Type, &m.Content, &m.MediaURL, &m.ThumbnailURL, &meta, &replyID, &m.CreatedAt, &m.SenderName, &m.SenderThumbnail)
		if err != nil {
			return nil, err
		}
		m.ChatID = chatID
		json.Unmarshal(meta, &m.Metadata)
		if replyID != nil {
			m.ReplyToID = *replyID
		}
		msgs = append(msgs, m)
	}
	return msgs, nil
}

// GetDMsForUser returns direct message chats for a user (pair-wise DMs)
func GetDMsForUser(userID string) ([]map[string]interface{}, error) {
	query := `
		SELECT DISTINCT
			CASE WHEN c.participant_ids[1] = $1 THEN c.participant_ids[2] ELSE c.participant_ids[1] END as other_user_id,
			u.real_name as other_user_name, COALESCE(u.thumbnail, '') as other_user_thumbnail,
			(
				SELECT content FROM chat_messages 
				WHERE chat_id = c.id 
				ORDER BY created_at DESC LIMIT 1
			) as last_message,
			(
				SELECT created_at FROM chat_messages 
				WHERE chat_id = c.id 
				ORDER BY created_at DESC LIMIT 1
			) as last_message_at
		FROM chat_rooms c
		JOIN users u ON u.id = CASE WHEN c.participant_ids[1] = $1 THEN c.participant_ids[2] ELSE c.participant_ids[1] END
		WHERE c.is_group = false 
		  AND $1 = ANY(c.participant_ids)
		ORDER BY last_message_at DESC
	`

	rows, err := db.Query(context.Background(), query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var dms []map[string]interface{}
	for rows.Next() {
		var otherUserID, otherUserName, otherUserThumbnail, lastMessage string
		var lastMessageAt *time.Time

		err := rows.Scan(&otherUserID, &otherUserName, &otherUserThumbnail, &lastMessage, &lastMessageAt)
		if err != nil {
			return nil, err
		}

		dms = append(dms, map[string]interface{}{
			"OtherUserID":        otherUserID,
			"OtherUserName":      otherUserName,
			"OtherUserThumbnail": otherUserThumbnail,
			"LastMessage":        lastMessage,
			"LastMessageAt":      lastMessageAt,
		})
	}
	return dms, nil
}

// GetDMMessages returns messages between two users
func GetDMMessages(userID, otherUserID string, limit int) ([]ChatMessage, error) {
	// Generate the deterministic DM chat ID
	u1, u2 := userID, otherUserID
	if u1 > u2 {
		u1, u2 = u2, u1
	}
	dmChatID := u1 + "_" + u2

	return GetChatHistory(dmChatID, limit)
}

// DeleteMessage deletes a chat message
func DeleteMessage(messageID, userID string) error {
	// Only allow the sender to delete their own message
	_, err := db.Exec(context.Background(),
		"DELETE FROM chat_messages WHERE id = $1 AND sender_id = $2",
		messageID, userID)
	return err
}

// ==========================================
// NOTIFICATIONS
// ==========================================

// CreateNotification creates a new notification
func CreateNotification(n Notification) (string, error) {
	query := `INSERT INTO notifications (user_id, type, title, body, data) 
			  VALUES ($1, $2, $3, $4, $5) RETURNING id`
	var id string
	err := db.QueryRow(context.Background(), query, n.UserID, n.Type, n.Title, n.Body, n.Data).Scan(&id)
	return id, err
}

// GetNotifications returns notifications for a user
func GetNotifications(userID string, limit int) ([]Notification, error) {
	if limit <= 0 {
		limit = 20
	}
	query := `SELECT id, user_id, type, title, body, data, is_read, created_at 
			  FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`

	rows, err := db.Query(context.Background(), query, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifs []Notification
	for rows.Next() {
		var n Notification
		err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.CreatedAt)
		if err != nil {
			return nil, err
		}
		notifs = append(notifs, n)
	}
	return notifs, nil
}

// MarkNotificationRead marks a notification as read
func MarkNotificationRead(notifID, userID string) error {
	_, err := db.Exec(context.Background(),
		"UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2",
		notifID, userID)
	return err
}

// MarkAllNotificationsRead marks all notifications as read for a user
func MarkAllNotificationsRead(userID string) error {
	_, err := db.Exec(context.Background(),
		"UPDATE notifications SET is_read = true WHERE user_id = $1",
		userID)
	return err
}

// ==========================================
// USER SEARCH & BLOCKING
// ==========================================

// SearchUsers searches for users by name or handle
func SearchUsers(query string, limit int) ([]User, error) {
	if limit <= 0 {
		limit = 20
	}
	searchQuery := `%` + query + `%`
	sqlQuery := `SELECT id, real_name, profile_photos, age, bio, elo_score, trust_score, thumbnail
				FROM users 
				WHERE real_name ILIKE $1 OR instagram_handle ILIKE $1 OR x_handle ILIKE $1
				ORDER BY elo_score DESC LIMIT $2`

	rows, err := db.Query(context.Background(), sqlQuery, searchQuery, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var u User
		err := rows.Scan(&u.ID, &u.RealName, &u.ProfilePhotos, &u.Age, &u.Bio, &u.EloScore, &u.TrustScore, &u.Thumbnail)
		if err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, nil
}

// BlockUser blocks a user
func BlockUser(blockerID, blockedID string) error {
	query := `INSERT INTO blocked_users (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`
	_, err := db.Exec(context.Background(), query, blockerID, blockedID)
	return err
}

// UnblockUser unblocks a user
func UnblockUser(blockerID, blockedID string) error {
	query := `DELETE FROM blocked_users WHERE blocker_id = $1 AND blocked_id = $2`
	_, err := db.Exec(context.Background(), query, blockerID, blockedID)
	return err
}

// IsBlocked checks if user is blocked
func IsBlocked(blockerID, checkedID string) (bool, error) {
	var exists bool
	query := `SELECT EXISTS(SELECT 1 FROM blocked_users WHERE blocker_id = $1 AND blocked_id = $2)`
	err := db.QueryRow(context.Background(), query, blockerID, checkedID).Scan(&exists)
	return exists, err
}

// GetBlockedUsers returns list of blocked user IDs
func GetBlockedUsers(userID string) ([]string, error) {
	query := `SELECT blocked_id FROM blocked_users WHERE blocker_id = $1`
	rows, err := db.Query(context.Background(), query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blockedIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		blockedIDs = append(blockedIDs, id)
	}
	return blockedIDs, nil
}

// ==========================================
// REPORTING
// ==========================================

// ReportUser creates a user report
func ReportUser(reporterID, reportedID, reason, details string) error {
	query := `INSERT INTO user_reports (reporter_id, reported_id, reason, details) VALUES ($1, $2, $3, $4)`
	_, err := db.Exec(context.Background(), query, reporterID, reportedID, reason, details)
	return err
}

// ReportParty creates a party report
func ReportParty(reporterID, partyID, reason, details string) error {
	query := `INSERT INTO party_reports (reporter_id, party_id, reason, details) VALUES ($1, $2, $3, $4)`
	_, err := db.Exec(context.Background(), query, reporterID, partyID, reason, details)
	return err
}

// ==========================================
// PARTY ANALYTICS
// ==========================================

// GetPartyAnalytics returns analytics for a party
func GetPartyAnalytics(partyID string) (PartyAnalytics, error) {
	var analytics PartyAnalytics
	analytics.PartyID = partyID

	// Get application counts
	appQuery := `SELECT 
			COUNT(*) as total,
			SUM(CASE WHEN status = 'ACCEPTED' THEN 1 ELSE 0 END) as accepted,
			SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) as pending,
			SUM(CASE WHEN status = 'DECLINED' THEN 1 ELSE 0 END) as declined
			FROM party_applications WHERE party_id = $1`

	err := db.QueryRow(context.Background(), appQuery, partyID).Scan(
		&analytics.TotalApplications, &analytics.AcceptedCount,
		&analytics.PendingCount, &analytics.DeclinedCount)
	if err != nil {
		return analytics, err
	}

	// Get current guest count from party
	partyQuery := `SELECT current_guest_count FROM parties WHERE id = $1`
	err = db.QueryRow(context.Background(), partyQuery, partyID).Scan(&analytics.CurrentGuestCount)
	if err != nil {
		return analytics, err
	}

	return analytics, nil
}

// ==========================================
// CROWDFUNDING / ROTATION POOL
// ==========================================

func CreateRotationPool(pool Crowdfunding) (string, error) {
	contribs, _ := json.Marshal(pool.Contributors)
	query := `INSERT INTO crowdfunding (party_id, target_amount, current_amount, currency, contributors, is_funded) 
	          VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`

	var id string
	err := db.QueryRow(context.Background(), query, pool.PartyID, pool.TargetAmount,
		pool.CurrentAmount, pool.Currency, contribs, pool.IsFunded).Scan(&id)
	return id, err
}

func GetRotationPool(partyID string) (Crowdfunding, error) {
	var c Crowdfunding
	var contribs []byte
	query := `SELECT id, party_id, target_amount, current_amount, currency, contributors, is_funded 
		FROM crowdfunding WHERE party_id = $1`

	err := db.QueryRow(context.Background(), query, partyID).Scan(
		&c.ID, &c.PartyID, &c.TargetAmount, &c.CurrentAmount, &c.Currency, &contribs, &c.IsFunded,
	)
	if err == nil {
		json.Unmarshal(contribs, &c.Contributors)
	}
	return c, err
}

func AddContribution(partyID string, contrib Contribution) error {
	// 1. Atomically update Amount, 2. Append to Contributors JSONB array using Postgres concat operator ||
	query := `UPDATE crowdfunding SET 
		current_amount = current_amount + $1,
		contributors = contributors || $2::jsonb
		WHERE party_id = $3`

	contribJSON, _ := json.Marshal(contrib)
	result, err := db.Exec(context.Background(), query, contrib.Amount, contribJSON, partyID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return errors.New("no rotation pool found for this party")
	}
	return nil
}

// GetMyParties returns parties where user is creator, participant, or matched
func GetMyParties(userID string) ([]Party, error) {
	query := `
		SELECT id, host_id, title, description, party_photos, start_time, duration_hours, status,
		       is_location_revealed, address, city, geo_lat, geo_lon, max_capacity, current_guest_count,
		       auto_lock_on_full, vibe_tags, rules, chat_room_id, created_at, updated_at, thumbnail
		FROM parties
		WHERE host_id = $1
		   OR EXISTS (SELECT 1 FROM party_applications WHERE party_id = parties.id AND user_id = $1 AND status = 'ACCEPTED')
		   OR EXISTS (SELECT 1 FROM party_matches WHERE party_id = parties.id AND (host_id = $1 OR matched_user_id = $1))
		ORDER BY created_at DESC
	`

	rows, err := db.Query(context.Background(), query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var parties []Party
	for rows.Next() {
		var p Party
		err := rows.Scan(
			&p.ID, &p.HostID, &p.Title, &p.Description, &p.PartyPhotos, &p.StartTime, &p.DurationHours,
			&p.Status, &p.IsLocationRevealed, &p.Address, &p.City, &p.GeoLat, &p.GeoLon,
			&p.MaxCapacity, &p.CurrentGuestCount, &p.AutoLockOnFull, &p.VibeTags,
			&p.Rules, &p.ChatRoomID, &p.CreatedAt, &p.UpdatedAt, &p.Thumbnail,
		)
		if err != nil {
			log.Printf("GetMyParties Scan Error: %v", err)
			continue
		}
		parties = append(parties, p)
	}
	return parties, nil
}
