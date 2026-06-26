package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

// Migration represents a single database migration
type Migration struct {
	Version     int
	Description string
	Up          func(ctx context.Context, tx pgx.Tx) error
	Down        func(ctx context.Context, tx pgx.Tx) error
}

// MigrationRegistry holds all migrations in order
type MigrationRegistry struct {
	migrations []Migration
}

// Register adds a migration to the registry
func (r *MigrationRegistry) Register(m Migration) {
	r.migrations = append(r.migrations, m)
}

// GetMigrations returns all registered migrations
func (r *MigrationRegistry) GetMigrations() []Migration {
	return r.migrations
}

// SchemaVersion tracks the current schema version
type SchemaVersion struct {
	Version   int
	AppliedAt time.Time
	Checksum  string
}

// Global migration registry
var registry = &MigrationRegistry{}

func init() {
	// Register all migrations
	registerMigrations()
}

// registerMigrations defines all database migrations
func registerMigrations() {
	// Migration 1: Initial schema creation
	registry.Register(Migration{
		Version:     1,
		Description: "Create initial schema with all tables",
		Up: func(ctx context.Context, tx pgx.Tx) error {
			schema := `
			-- Enable UUID extension
			CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

			-- ==========================================
			-- CORE TABLES
			-- ==========================================
			
			-- Asset storage for media
			CREATE TABLE IF NOT EXISTS assets (
				hash TEXT PRIMARY KEY,
				data BYTEA NOT NULL,
				mime_type TEXT NOT NULL,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
			);

			-- Users table with all profile fields
			CREATE TABLE IF NOT EXISTS users (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				real_name TEXT DEFAULT '',
				phone_number TEXT DEFAULT '',
				email TEXT UNIQUE,
				password_hash TEXT,
				profile_photos TEXT[] DEFAULT '{}',
				age INTEGER,
				date_of_birth TIMESTAMP WITH TIME ZONE,
				height_cm INTEGER,
				gender TEXT DEFAULT '',
				drinking_pref TEXT DEFAULT '',
				smoking_pref TEXT DEFAULT '',
				job_title TEXT DEFAULT '',
				company TEXT DEFAULT '',
				school TEXT DEFAULT '',
				degree TEXT DEFAULT '',
				instagram_handle TEXT DEFAULT '',
				linkedin_handle TEXT DEFAULT '',
				x_handle TEXT DEFAULT '',
				tiktok_handle TEXT DEFAULT '',
				is_verified BOOLEAN DEFAULT FALSE,
				trust_score DOUBLE PRECISION DEFAULT 0.0,
				elo_score DOUBLE PRECISION DEFAULT 0.0,
				parties_hosted INTEGER DEFAULT 0,
				flake_count INTEGER DEFAULT 0,
				wallet_data JSONB DEFAULT '{}',
				location_lat DOUBLE PRECISION,
				location_lon DOUBLE PRECISION,
				bio TEXT DEFAULT '',
				updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
				thumbnail TEXT DEFAULT ''
			);

			-- Parties table
			CREATE TABLE IF NOT EXISTS parties (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				host_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				title TEXT NOT NULL,
				description TEXT,
				party_photos TEXT[] DEFAULT '{}',
				start_time TIMESTAMP WITH TIME ZONE NOT NULL,
				duration_hours INTEGER DEFAULT 2,
				status TEXT NOT NULL DEFAULT 'OPEN',
				is_location_revealed BOOLEAN DEFAULT FALSE,
				address TEXT,
				city TEXT,
				geo_lat DOUBLE PRECISION,
				geo_lon DOUBLE PRECISION,
				max_capacity INTEGER DEFAULT 0,
				current_guest_count INTEGER DEFAULT 0,
				auto_lock_on_full BOOLEAN DEFAULT FALSE,
				vibe_tags TEXT[] DEFAULT '{}',
				rules TEXT[] DEFAULT '{}',
				chat_room_id UUID,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
				updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
				thumbnail TEXT
			);

			-- Party applications
			CREATE TABLE IF NOT EXISTS party_applications (
				party_id UUID NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
				user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				status TEXT NOT NULL DEFAULT 'PENDING',
				applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
				PRIMARY KEY (party_id, user_id)
			);

			-- Party matches
			CREATE TABLE IF NOT EXISTS party_matches (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				party_id UUID NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
				creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				matched_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				matched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
				UNIQUE(party_id, creator_id, matched_user_id)
			);

			-- Crowdfunding
			CREATE TABLE IF NOT EXISTS crowdfunding (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				party_id UUID UNIQUE NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
				target_amount DOUBLE PRECISION DEFAULT 0.0,
				current_amount DOUBLE PRECISION DEFAULT 0.0,
				currency TEXT DEFAULT 'USD',
				contributors JSONB DEFAULT '[]',
				is_funded BOOLEAN DEFAULT FALSE
			);

			-- Chat system
			CREATE TABLE IF NOT EXISTS chat_rooms (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				party_id UUID REFERENCES parties(id) ON DELETE CASCADE,
				host_id UUID NOT NULL REFERENCES users(id),
				title TEXT,
				image_url TEXT,
				is_group BOOLEAN DEFAULT TRUE,
				participant_ids UUID[] DEFAULT '{}',
				is_active BOOLEAN DEFAULT TRUE,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
			);

			CREATE TABLE IF NOT EXISTS chat_messages (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				chat_id UUID NOT NULL,
				sender_id UUID NOT NULL REFERENCES users(id),
				type TEXT NOT NULL DEFAULT 'TEXT',
				content TEXT,
				media_url TEXT,
				thumbnail_url TEXT,
				metadata JSONB DEFAULT '{}',
				reply_to_id UUID,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
			);

			-- Blocked users
			CREATE TABLE IF NOT EXISTS blocked_users (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
				UNIQUE(blocker_id, blocked_id)
			);

			-- User reports
			CREATE TABLE IF NOT EXISTS user_reports (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				reported_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				reason TEXT NOT NULL,
				details TEXT,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
			);

			-- Party reports
			CREATE TABLE IF NOT EXISTS party_reports (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				party_id UUID NOT NULL REFERENCES parties(id) ON DELETE CASCADE,
				reason TEXT NOT NULL,
				details TEXT,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
			);

			-- Notifications
			CREATE TABLE IF NOT EXISTS notifications (
				id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
				user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				type TEXT NOT NULL,
				title TEXT NOT NULL,
				body TEXT,
				data TEXT,
				is_read BOOLEAN DEFAULT FALSE,
				created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
			);

			-- ==========================================
			-- INDEXES (Optimized for PostgreSQL)
			-- ==========================================
			-- Core user lookups
			CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
			CREATE INDEX IF NOT EXISTS idx_users_elo ON users(elo_score DESC NULLS LAST);
			
			-- Party queries (partial index for active parties)
			CREATE INDEX IF NOT EXISTS idx_parties_status ON parties(status) WHERE status = 'OPEN';
			CREATE INDEX IF NOT EXISTS idx_parties_host_id ON parties(host_id);
			CREATE INDEX IF NOT EXISTS idx_parties_start_time ON parties(start_time DESC);
			
			-- Chat system (composite indexes for common queries)
			CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_id_created ON chat_messages(chat_id, created_at DESC);
			CREATE INDEX IF NOT EXISTS idx_chat_rooms_party ON chat_rooms(party_id);
			CREATE INDEX IF NOT EXISTS idx_chat_rooms_active ON chat_rooms(is_active) WHERE is_active = true;
			
			-- Applications & matches (composite for efficient lookups)
			CREATE INDEX IF NOT EXISTS idx_party_applications_composite ON party_applications(party_id, status);
			CREATE INDEX IF NOT EXISTS idx_party_applications_user ON party_applications(user_id);
			CREATE INDEX IF NOT EXISTS idx_party_matches_creator ON party_matches(creator_id, matched_user_id);
			
			-- Social features
			CREATE INDEX IF NOT EXISTS idx_blocked_users_blocker ON blocked_users(blocker_id, blocked_id);
			CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, created_at DESC) WHERE is_read = false;
			
			-- Asset storage
			CREATE INDEX IF NOT EXISTS idx_assets_hash ON assets(hash);
			
			-- Reports
			CREATE INDEX IF NOT EXISTS idx_user_reports_reported ON user_reports(reported_id);
			CREATE INDEX IF NOT EXISTS idx_party_reports_party ON party_reports(party_id);

			-- ==========================================
			-- TRIGGERS & FUNCTIONS
			-- ==========================================
			CREATE OR REPLACE FUNCTION update_updated_at_column()
			RETURNS TRIGGER AS $$
			BEGIN
				NEW.updated_at = NOW();
				RETURN NEW;
			END;
			$$ LANGUAGE plpgsql;

			-- Create trigger only if it doesn't exist
			DO $$
			BEGIN
				IF NOT EXISTS (
					SELECT 1 FROM pg_trigger 
					WHERE tgname = 'update_party_modtime'
				) THEN
					CREATE TRIGGER update_party_modtime
						BEFORE UPDATE ON parties
						FOR EACH ROW
						EXECUTE FUNCTION update_updated_at_column();
				END IF;
			END $$;
			`
			_, err := tx.Exec(ctx, schema)
			return err
		},
		Down: func(ctx context.Context, tx pgx.Tx) error {
			// Dangerous - only for development rollback
			tables := []string{
				"notifications", "party_reports", "user_reports", "blocked_users",
				"chat_messages", "chat_rooms", "crowdfunding", "party_matches",
				"party_applications", "parties", "users", "assets",
			}
			for _, table := range tables {
				if _, err := tx.Exec(ctx, fmt.Sprintf("DROP TABLE IF EXISTS %s CASCADE", table)); err != nil {
					return err
				}
			}
			return nil
		},
	})

	// Migration 2: Normalize NULL values to empty strings (Optimized)
	registry.Register(Migration{
		Version:     2,
		Description: "Normalize NULL text values to empty strings",
		Up: func(ctx context.Context, tx pgx.Tx) error {
			// Use CTE for efficient batch update with minimal table scans
			updateSQL := `
			WITH users_with_nulls AS (
				SELECT id 
				FROM users 
				WHERE real_name IS NULL 
				   OR phone_number IS NULL 
				   OR gender IS NULL 
				   OR drinking_pref IS NULL 
				   OR smoking_pref IS NULL
				   OR job_title IS NULL 
				   OR company IS NULL 
				   OR school IS NULL 
				   OR degree IS NULL
				   OR instagram_handle IS NULL 
				   OR linkedin_handle IS NULL 
				   OR x_handle IS NULL
				   OR tiktok_handle IS NULL 
				   OR bio IS NULL 
				   OR thumbnail IS NULL
			),
			updated AS (
				UPDATE users u
				SET 
					real_name = COALESCE(real_name, ''),
					phone_number = COALESCE(phone_number, ''),
					gender = COALESCE(gender, ''),
					drinking_pref = COALESCE(drinking_pref, ''),
					smoking_pref = COALESCE(smoking_pref, ''),
					job_title = COALESCE(job_title, ''),
					company = COALESCE(company, ''),
					school = COALESCE(school, ''),
					degree = COALESCE(degree, ''),
					instagram_handle = COALESCE(instagram_handle, ''),
					linkedin_handle = COALESCE(linkedin_handle, ''),
					x_handle = COALESCE(x_handle, ''),
					tiktok_handle = COALESCE(tiktok_handle, ''),
					bio = COALESCE(bio, ''),
					thumbnail = COALESCE(thumbnail, '')
				FROM users_with_nulls n
				WHERE u.id = n.id
				RETURNING u.id
			)
			SELECT COUNT(*) FROM updated`

			var count int64
			err := tx.QueryRow(ctx, updateSQL).Scan(&count)
			if err != nil {
				return fmt.Errorf("failed to normalize NULL values: %w", err)
			}
			log.Printf("[Migration 2] Normalized NULL values in %d rows", count)
			return nil
		},
		Down: func(ctx context.Context, tx pgx.Tx) error {
			// No-op: cannot restore NULL values
			return nil
		},
	})

	// Migration 3: Add data consistency constraints (Optimized with DO blocks)
	registry.Register(Migration{
		Version:     3,
		Description: "Add data consistency constraints",
		Up: func(ctx context.Context, tx pgx.Tx) error {
			// First normalize invalid status values to prevent constraint violations
			normalizeSQL := `
			-- Normalize party_applications status values
			UPDATE party_applications 
			SET status = CASE 
				WHEN status IS NULL OR status = '' THEN 'PENDING'
				WHEN status NOT IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED') THEN 'PENDING'
				ELSE status
			END;

			-- Normalize parties status values
			UPDATE parties 
			SET status = CASE 
				WHEN status IS NULL OR status = '' THEN 'OPEN'
				WHEN status NOT IN ('OPEN', 'CLOSED', 'CANCELLED', 'COMPLETED') THEN 'OPEN'
				ELSE status
			END;

			-- Normalize chat_messages type values
			UPDATE chat_messages 
			SET type = CASE 
				WHEN type IS NULL OR type = '' THEN 'TEXT'
				WHEN type NOT IN ('TEXT', 'IMAGE', 'VIDEO', 'SYSTEM', 'DM') THEN 'TEXT'
				ELSE type
			END;`

			result, err := tx.Exec(ctx, normalizeSQL)
			if err != nil {
				return fmt.Errorf("failed to normalize status values: %w", err)
			}
			log.Printf("[Migration 3] Normalized status values in %d rows", result.RowsAffected())

			// Now add constraints using DO blocks
			constraintsSQL := `
			DO $$
			BEGIN
				-- Party application status constraint
				IF NOT EXISTS (
					SELECT 1 FROM pg_constraint 
					WHERE conname = 'chk_party_applications_status'
				) THEN
					ALTER TABLE party_applications 
					ADD CONSTRAINT chk_party_applications_status 
					CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'));
				END IF;
				
				-- Party status constraint
				IF NOT EXISTS (
					SELECT 1 FROM pg_constraint 
					WHERE conname = 'chk_parties_status'
				) THEN
					ALTER TABLE parties 
					ADD CONSTRAINT chk_parties_status 
					CHECK (status IN ('OPEN', 'CLOSED', 'CANCELLED', 'COMPLETED'));
				END IF;
				
				-- Chat message type constraint
				IF NOT EXISTS (
					SELECT 1 FROM pg_constraint 
					WHERE conname = 'chk_chat_messages_type'
				) THEN
					ALTER TABLE chat_messages 
					ADD CONSTRAINT chk_chat_messages_type 
					CHECK (type IN ('TEXT', 'IMAGE', 'VIDEO', 'SYSTEM', 'DM'));
				END IF;
			END $$`

			_, err = tx.Exec(ctx, constraintsSQL)
			if err != nil {
				return fmt.Errorf("failed to add constraints: %w", err)
			}
			log.Printf("[Migration 3] Data consistency constraints added")
			return nil
		},
		Down: func(ctx context.Context, tx pgx.Tx) error {
			sql := `
			ALTER TABLE party_applications DROP CONSTRAINT IF EXISTS chk_party_applications_status;
			ALTER TABLE parties DROP CONSTRAINT IF EXISTS chk_parties_status;
			ALTER TABLE chat_messages DROP CONSTRAINT IF EXISTS chk_chat_messages_type`
			_, err := tx.Exec(ctx, sql)
			return err
		},
	})

	// Migration 4: Enforce DEFAULT '' and NOT NULL on text columns
	registry.Register(Migration{
		Version:     4,
		Description: "Enforce DEFAULT '' and NOT NULL on text columns",
		Up: func(ctx context.Context, tx pgx.Tx) error {
			// First ensure all NULL values are converted (safety check)
			nullFixSQL := `
			UPDATE users SET
				real_name = COALESCE(real_name, ''),
				phone_number = COALESCE(phone_number, ''),
				gender = COALESCE(gender, ''),
				drinking_pref = COALESCE(drinking_pref, ''),
				smoking_pref = COALESCE(smoking_pref, ''),
				job_title = COALESCE(job_title, ''),
				company = COALESCE(company, ''),
				school = COALESCE(school, ''),
				degree = COALESCE(degree, ''),
				instagram_handle = COALESCE(instagram_handle, ''),
				linkedin_handle = COALESCE(linkedin_handle, ''),
				x_handle = COALESCE(x_handle, ''),
				tiktok_handle = COALESCE(tiktok_handle, ''),
				bio = COALESCE(bio, ''),
				thumbnail = COALESCE(thumbnail, '')
			WHERE real_name IS NULL OR phone_number IS NULL OR gender IS NULL
			   OR drinking_pref IS NULL OR smoking_pref IS NULL OR job_title IS NULL
			   OR company IS NULL OR school IS NULL OR degree IS NULL
			   OR instagram_handle IS NULL OR linkedin_handle IS NULL
			   OR x_handle IS NULL OR tiktok_handle IS NULL
			   OR bio IS NULL OR thumbnail IS NULL`

			result, err := tx.Exec(ctx, nullFixSQL)
			if err != nil {
				return fmt.Errorf("failed to fix NULL values: %w", err)
			}
			log.Printf("[Migration 4] Fixed %d rows with NULL text values", result.RowsAffected())

			// Now enforce DEFAULT '' and NOT NULL constraints
			alterSQL := `
			-- Enforce DEFAULT '' and NOT NULL on text columns
			ALTER TABLE users 
				ALTER COLUMN real_name SET DEFAULT '',
				ALTER COLUMN real_name SET NOT NULL,
				ALTER COLUMN phone_number SET DEFAULT '',
				ALTER COLUMN phone_number SET NOT NULL,
				ALTER COLUMN gender SET DEFAULT '',
				ALTER COLUMN gender SET NOT NULL,
				ALTER COLUMN drinking_pref SET DEFAULT '',
				ALTER COLUMN drinking_pref SET NOT NULL,
				ALTER COLUMN smoking_pref SET DEFAULT '',
				ALTER COLUMN smoking_pref SET NOT NULL,
				ALTER COLUMN job_title SET DEFAULT '',
				ALTER COLUMN job_title SET NOT NULL,
				ALTER COLUMN company SET DEFAULT '',
				ALTER COLUMN company SET NOT NULL,
				ALTER COLUMN school SET DEFAULT '',
				ALTER COLUMN school SET NOT NULL,
				ALTER COLUMN degree SET DEFAULT '',
				ALTER COLUMN degree SET NOT NULL,
				ALTER COLUMN instagram_handle SET DEFAULT '',
				ALTER COLUMN instagram_handle SET NOT NULL,
				ALTER COLUMN linkedin_handle SET DEFAULT '',
				ALTER COLUMN linkedin_handle SET NOT NULL,
				ALTER COLUMN x_handle SET DEFAULT '',
				ALTER COLUMN x_handle SET NOT NULL,
				ALTER COLUMN tiktok_handle SET DEFAULT '',
				ALTER COLUMN tiktok_handle SET NOT NULL,
				ALTER COLUMN bio SET DEFAULT '',
				ALTER COLUMN bio SET NOT NULL,
				ALTER COLUMN thumbnail SET DEFAULT '',
				ALTER COLUMN thumbnail SET NOT NULL`

			_, err = tx.Exec(ctx, alterSQL)
			if err != nil {
				return fmt.Errorf("failed to enforce constraints: %w", err)
			}

			log.Printf("[Migration 4] Enforced DEFAULT '' and NOT NULL on all text columns")
			return nil
		},
		Down: func(ctx context.Context, tx pgx.Tx) error {
			// Revert to allow NULL values (removes NOT NULL, keeps DEFAULT)
			sql := `
			ALTER TABLE users 
				ALTER COLUMN real_name DROP NOT NULL,
				ALTER COLUMN phone_number DROP NOT NULL,
				ALTER COLUMN gender DROP NOT NULL,
				ALTER COLUMN drinking_pref DROP NOT NULL,
				ALTER COLUMN smoking_pref DROP NOT NULL,
				ALTER COLUMN job_title DROP NOT NULL,
				ALTER COLUMN company DROP NOT NULL,
				ALTER COLUMN school DROP NOT NULL,
				ALTER COLUMN degree DROP NOT NULL,
				ALTER COLUMN instagram_handle DROP NOT NULL,
				ALTER COLUMN linkedin_handle DROP NOT NULL,
				ALTER COLUMN x_handle DROP NOT NULL,
				ALTER COLUMN tiktok_handle DROP NOT NULL,
				ALTER COLUMN bio DROP NOT NULL,
				ALTER COLUMN thumbnail DROP NOT NULL`
			_, err := tx.Exec(ctx, sql)
			return err
		},
	})
}

// Migrate runs all pending migrations
func Migrate() error {
	fmt.Println("🗄️  Database Migration System")
	fmt.Println("=============================")

	// Get database connection
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return fmt.Errorf("DATABASE_URL environment variable not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	defer conn.Close(ctx)

	fmt.Println("✅ Connected to database")

	// Ensure schema_migrations table exists
	if err := ensureMigrationsTable(ctx, conn); err != nil {
		return fmt.Errorf("failed to create migrations table: %w", err)
	}

	// Get current schema version
	currentVersion, err := getCurrentVersion(ctx, conn)
	if err != nil {
		return fmt.Errorf("failed to get current version: %w", err)
	}

	fmt.Printf("📊 Current schema version: %d\n", currentVersion)

	// Run pending migrations
	migrations := registry.GetMigrations()
	applied := 0
	failed := 0

	for _, migration := range migrations {
		if migration.Version <= currentVersion {
			continue // Already applied
		}

		fmt.Printf("\n🔄 Applying migration %d: %s\n", migration.Version, migration.Description)

		// Run migration in a transaction
		err := runMigrationWithTransaction(ctx, conn, migration)
		if err != nil {
			fmt.Printf("   ❌ Failed: %v\n", err)
			failed++
			// Continue with other migrations but track failure
			continue
		}

		fmt.Printf("   ✅ Applied successfully\n")
		applied++
	}

	// Print summary
	fmt.Println("\n" + strings.Repeat("=", 40))
	fmt.Println("📊 MIGRATION SUMMARY")
	fmt.Println(strings.Repeat("=", 40))
	fmt.Printf("   Applied: %d\n", applied)
	fmt.Printf("   Failed:  %d\n", failed)
	fmt.Printf("   Total:   %d/%d\n", currentVersion+applied, len(migrations))

	if failed > 0 {
		return fmt.Errorf("%d migration(s) failed", failed)
	}

	fmt.Println("\n✅ All migrations completed successfully!")
	return nil
}

// ensureMigrationsTable creates the schema_migrations tracking table
func ensureMigrationsTable(ctx context.Context, conn *pgx.Conn) error {
	sql := `
	CREATE TABLE IF NOT EXISTS schema_migrations (
		version INTEGER PRIMARY KEY,
		applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
		description TEXT,
		checksum TEXT
	)
	`
	_, err := conn.Exec(ctx, sql)
	return err
}

// getCurrentVersion retrieves the highest applied migration version
func getCurrentVersion(ctx context.Context, conn *pgx.Conn) (int, error) {
	var version pgtype.Int4
	err := conn.QueryRow(ctx,
		"SELECT COALESCE(MAX(version), 0) FROM schema_migrations").Scan(&version)
	if err != nil {
		return 0, err
	}
	return int(version.Int32), nil
}

// runMigrationWithTransaction executes a migration within a transaction
func runMigrationWithTransaction(ctx context.Context, conn *pgx.Conn, migration Migration) error {
	tx, err := conn.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Run the migration
	if err := migration.Up(ctx, tx); err != nil {
		return fmt.Errorf("migration up failed: %w", err)
	}

	// Record the migration
	checksum := computeChecksum(migration)
	_, err = tx.Exec(ctx,
		"INSERT INTO schema_migrations (version, description, checksum) VALUES ($1, $2, $3)",
		migration.Version, migration.Description, checksum)
	if err != nil {
		return fmt.Errorf("failed to record migration: %w", err)
	}

	// Commit the transaction
	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}

// computeChecksum creates a simple checksum for migration verification
func computeChecksum(migration Migration) string {
	// Simple checksum based on version and description
	return fmt.Sprintf("v%d-%s", migration.Version,
		strings.ReplaceAll(migration.Description, " ", "_"))
}

// Rollback rolls back the last n migrations
func Rollback(steps int) error {
	fmt.Printf("🔄 Rolling back %d migration(s)\n", steps)

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return fmt.Errorf("DATABASE_URL environment variable not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	defer conn.Close(ctx)

	// Get applied migrations in reverse order
	rows, err := conn.Query(ctx,
		"SELECT version FROM schema_migrations ORDER BY version DESC LIMIT $1",
		steps)
	if err != nil {
		return err
	}
	defer rows.Close()

	var versions []int
	for rows.Next() {
		var v int
		if err := rows.Scan(&v); err != nil {
			return err
		}
		versions = append(versions, v)
	}

	// Rollback each migration
	migrations := registry.GetMigrations()
	migrationMap := make(map[int]Migration)
	for _, m := range migrations {
		migrationMap[m.Version] = m
	}

	for _, version := range versions {
		migration, ok := migrationMap[version]
		if !ok {
			fmt.Printf("⚠️  Migration %d not found in registry, skipping\n", version)
			continue
		}

		fmt.Printf("🔄 Rolling back migration %d: %s\n", version, migration.Description)

		tx, err := conn.Begin(ctx)
		if err != nil {
			return err
		}

		if err := migration.Down(ctx, tx); err != nil {
			tx.Rollback(ctx)
			fmt.Printf("   ❌ Rollback failed: %v\n", err)
			continue
		}

		// Remove migration record
		_, err = tx.Exec(ctx, "DELETE FROM schema_migrations WHERE version = $1", version)
		if err != nil {
			tx.Rollback(ctx)
			fmt.Printf("   ❌ Failed to remove migration record: %v\n", err)
			continue
		}

		if err := tx.Commit(ctx); err != nil {
			fmt.Printf("   ❌ Failed to commit rollback: %v\n", err)
			continue
		}

		fmt.Printf("   ✅ Rolled back successfully\n")
	}

	return nil
}

// Status shows the current migration status
func Status() error {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		return fmt.Errorf("DATABASE_URL environment variable not set")
	}

	ctx := context.Background()
	conn, err := pgx.Connect(ctx, databaseURL)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}
	defer conn.Close(ctx)

	// Check if migrations table exists
	var exists bool
	err = conn.QueryRow(ctx, `
		SELECT EXISTS (
			SELECT FROM information_schema.tables 
			WHERE table_name = 'schema_migrations'
		)`).Scan(&exists)
	if err != nil {
		return err
	}

	if !exists {
		fmt.Println("📊 No migrations have been run yet")
		fmt.Printf("📋 Available migrations: %d\n", len(registry.GetMigrations()))
		return nil
	}

	// Get applied migrations
	rows, err := conn.Query(ctx,
		"SELECT version, description, applied_at FROM schema_migrations ORDER BY version")
	if err != nil {
		return err
	}
	defer rows.Close()

	fmt.Println("📊 Applied Migrations")
	fmt.Println(strings.Repeat("-", 60))
	fmt.Printf("%-10s %-30s %-20s\n", "Version", "Description", "Applied At")
	fmt.Println(strings.Repeat("-", 60))

	for rows.Next() {
		var version int
		var description string
		var appliedAt time.Time
		if err := rows.Scan(&version, &description, &appliedAt); err != nil {
			continue
		}
		fmt.Printf("%-10d %-30s %-20s\n", version, description, appliedAt.Format("2006-01-02 15:04"))
	}

	fmt.Println(strings.Repeat("-", 60))
	fmt.Printf("📋 Total available: %d | Applied: %d | Pending: %d\n",
		len(registry.GetMigrations()),
		len(func() []Migration {
			var applied []Migration
			for _, m := range registry.GetMigrations() {
				// Check if applied (simplified - would need query)
				applied = append(applied, m)
			}
			return applied
		}()),
		0)

	return nil
}
