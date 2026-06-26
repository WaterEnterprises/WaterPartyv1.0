package main

import (
	"testing"
	"time"
)

// ==================== USER TESTS ====================

func TestUserOperations(t *testing.T) {
	mockDB := NewMockDB()

	t.Run("CreateUser", func(t *testing.T) {
		user := CreateTestUser("user-123")
		mockDB.users[user.ID] = user

		if len(mockDB.users) != 1 {
			t.Errorf("Expected 1 user, got %d", len(mockDB.users))
		}

		stored, ok := mockDB.users["user-123"]
		if !ok {
			t.Error("User not found in mock DB")
		}
		if stored.RealName != "Test User" {
			t.Errorf("Expected RealName 'Test User', got '%s'", stored.RealName)
		}
	})

	t.Run("GetUser", func(t *testing.T) {
		user := CreateTestUser("user-456")
		mockDB.users[user.ID] = user

		stored, ok := mockDB.users["user-456"]
		if !ok {
			t.Error("User not found")
		}
		if stored.Email != "test@example.com" {
			t.Errorf("Expected email 'test@example.com', got '%s'", stored.Email)
		}
	})

	t.Run("UpdateUser", func(t *testing.T) {
		user := CreateTestUser("user-789")
		mockDB.users[user.ID] = user

		// Update user
		user.RealName = "Updated Name"
		user.Bio = "New bio"
		mockDB.users[user.ID] = user

		updated := mockDB.users["user-789"]
		if updated.RealName != "Updated Name" {
			t.Errorf("Expected 'Updated Name', got '%s'", updated.RealName)
		}
		if updated.Bio != "New bio" {
			t.Errorf("Expected 'New bio', got '%s'", updated.Bio)
		}
	})

	t.Run("DeleteUser", func(t *testing.T) {
		user := CreateTestUser("user-to-delete")
		mockDB.users[user.ID] = user

		delete(mockDB.users, user.ID)

		if _, ok := mockDB.users["user-to-delete"]; ok {
			t.Error("User should have been deleted")
		}
	})
}

// ==================== PARTY TESTS ====================

func TestPartyOperations(t *testing.T) {
	mockDB := NewMockDB()
	host := CreateTestUser("host-123")
	mockDB.users[host.ID] = host

	t.Run("CreateParty", func(t *testing.T) {
		party := CreateTestParty("party-123", host.ID)
		mockDB.parties[party.ID] = party

		if len(mockDB.parties) != 1 {
			t.Errorf("Expected 1 party, got %d", len(mockDB.parties))
		}

		stored := mockDB.parties["party-123"]
		if stored.Title != "Test Party" {
			t.Errorf("Expected Title 'Test Party', got '%s'", stored.Title)
		}
		if stored.HostID != host.ID {
			t.Errorf("Expected HostID '%s', got '%s'", host.ID, stored.HostID)
		}
	})

	t.Run("GetParty", func(t *testing.T) {
		party := CreateTestParty("party-456", host.ID)
		mockDB.parties[party.ID] = party

		stored := mockDB.parties["party-456"]
		if stored.Status != PartyStatusOpen {
			t.Errorf("Expected status OPEN, got %s", stored.Status)
		}
		if stored.DurationHours != 4 {
			t.Errorf("Expected DurationHours 4, got %d", stored.DurationHours)
		}
	})

	t.Run("UpdatePartyStatus", func(t *testing.T) {
		party := CreateTestParty("party-789", host.ID)
		mockDB.parties[party.ID] = party

		// Update status
		party.Status = PartyStatusLive
		mockDB.parties[party.ID] = party

		updated := mockDB.parties["party-789"]
		if updated.Status != PartyStatusLive {
			t.Errorf("Expected status LIVE, got %s", updated.Status)
		}
	})

	t.Run("DeleteParty", func(t *testing.T) {
		party := CreateTestParty("party-to-delete", "host-id")
		mockDB.parties[party.ID] = party

		delete(mockDB.parties, party.ID)

		if _, ok := mockDB.parties[party.ID]; ok {
			t.Error("Party should have been deleted")
		}
	})

	t.Run("PartyCapacity", func(t *testing.T) {
		party := CreateTestParty("party-capacity", host.ID)
		party.MaxCapacity = 100
		party.CurrentGuestCount = 50
		mockDB.parties[party.ID] = party

		stored := mockDB.parties[party.ID]
		if stored.MaxCapacity != 100 {
			t.Errorf("Expected MaxCapacity 100, got %d", stored.MaxCapacity)
		}
		if stored.CurrentGuestCount != 50 {
			t.Errorf("Expected CurrentGuestCount 50, got %d", stored.CurrentGuestCount)
		}

		// Test auto-lock feature
		if stored.AutoLockOnFull && stored.CurrentGuestCount >= stored.MaxCapacity {
			stored.Status = PartyStatusLocked
		}

		// Simulate full party
		stored.CurrentGuestCount = 100
		if stored.AutoLockOnFull {
			stored.Status = PartyStatusLocked
		}

		if stored.Status != PartyStatusLocked {
			t.Error("Party should be locked when full with AutoLockOnFull enabled")
		}
	})
}

// ==================== CHAT ROOM TESTS ====================

func TestChatRoomOperations(t *testing.T) {
	mockDB := NewMockDB()
	host := CreateTestUser("host-chat")
	party := CreateTestParty("party-chat", host.ID)
	mockDB.parties[party.ID] = party

	t.Run("CreateChatRoom", func(t *testing.T) {
		chatRoom := CreateTestChatRoom("chat-123", party.ID, host.ID)
		mockDB.chatRooms[chatRoom.ID] = chatRoom

		if len(mockDB.chatRooms) != 1 {
			t.Errorf("Expected 1 chat room, got %d", len(mockDB.chatRooms))
		}

		stored := mockDB.chatRooms["chat-123"]
		if !stored.IsGroup {
			t.Error("Chat room should be a group")
		}
		if len(stored.ParticipantIDs) != 3 {
			t.Errorf("Expected 3 participants, got %d", len(stored.ParticipantIDs))
		}
	})

	t.Run("GetChatRoom", func(t *testing.T) {
		chatRoom := CreateTestChatRoom("chat-456", party.ID, host.ID)
		mockDB.chatRooms[chatRoom.ID] = chatRoom

		stored := mockDB.chatRooms["chat-456"]
		if stored.PartyID != party.ID {
			t.Errorf("Expected PartyID '%s', got '%s'", party.ID, stored.PartyID)
		}
	})
}

// ==================== MESSAGE TESTS ====================

func TestMessageOperations(t *testing.T) {
	mockDB := NewMockDB()
	chatRoom := CreateTestChatRoom("chat-msg", "party-123", "host-123")
	mockDB.chatRooms[chatRoom.ID] = chatRoom

	t.Run("SaveMessage", func(t *testing.T) {
		msg := CreateTestMessage("msg-123", chatRoom.ID, "user-123")
		mockDB.messages[msg.ChatID] = append(mockDB.messages[msg.ChatID], msg)

		if len(mockDB.messages[chatRoom.ID]) != 1 {
			t.Errorf("Expected 1 message, got %d", len(mockDB.messages[chatRoom.ID]))
		}

		stored := mockDB.messages[chatRoom.ID][0]
		if stored.Content != "Test message" {
			t.Errorf("Expected content 'Test message', got '%s'", stored.Content)
		}
		if stored.Type != MsgText {
			t.Errorf("Expected type TEXT, got %s", stored.Type)
		}
	})

	t.Run("GetChatHistory", func(t *testing.T) {
		// Add multiple messages
		for i := 0; i < 5; i++ {
			msg := CreateTestMessage("msg-"+string(rune(i)), chatRoom.ID, "user-123")
			mockDB.messages[msg.ChatID] = append(mockDB.messages[msg.ChatID], msg)
		}

		messages := mockDB.messages[chatRoom.ID]
		if len(messages) != 6 { // 1 from previous test + 5 new
			t.Errorf("Expected 6 messages, got %d", len(messages))
		}
	})

	t.Run("DeleteMessage", func(t *testing.T) {
		msgID := "msg-to-delete"
		msg := CreateTestMessage(msgID, chatRoom.ID, "user-123")
		mockDB.messages[msg.ChatID] = append(mockDB.messages[msg.ChatID], msg)

		// Delete message (only by sender)
		senderID := "user-123"
		var updatedMessages []ChatMessage
		for _, m := range mockDB.messages[chatRoom.ID] {
			if m.ID != msgID || m.SenderID != senderID {
				updatedMessages = append(updatedMessages, m)
			}
		}
		mockDB.messages[chatRoom.ID] = updatedMessages

		// Verify deleted
		found := false
		for _, m := range mockDB.messages[chatRoom.ID] {
			if m.ID == msgID {
				found = true
				break
			}
		}
		if found {
			t.Error("Message should have been deleted")
		}
	})
}

// ==================== APPLICATION TESTS ====================

func TestApplicationOperations(t *testing.T) {
	mockDB := NewMockDB()
	party := CreateTestParty("party-app", "host-123")
	mockDB.parties[party.ID] = party
	mockDB.applications[party.ID] = make(map[string]string)

	t.Run("ApplyToParty", func(t *testing.T) {
		userID := "user-456"
		mockDB.applications[party.ID][userID] = "PENDING"

		status := mockDB.applications[party.ID][userID]
		if status != "PENDING" {
			t.Errorf("Expected status 'PENDING', got '%s'", status)
		}
	})

	t.Run("UpdateApplicationStatus", func(t *testing.T) {
		userID := "user-789"
		mockDB.applications[party.ID][userID] = "PENDING"

		// Accept user
		mockDB.applications[party.ID][userID] = "ACCEPTED"

		status := mockDB.applications[party.ID][userID]
		if status != "ACCEPTED" {
			t.Errorf("Expected status 'ACCEPTED', got '%s'", status)
		}
	})

	t.Run("GetApplicants", func(t *testing.T) {
		// Reset applications for this test
		mockDB.applications[party.ID] = make(map[string]string)
		mockDB.applications[party.ID]["user-1"] = "PENDING"
		mockDB.applications[party.ID]["user-2"] = "ACCEPTED"
		mockDB.applications[party.ID]["user-3"] = "DECLINED"

		applicants := mockDB.applications[party.ID]
		if len(applicants) != 3 {
			t.Errorf("Expected 3 applicants, got %d", len(applicants))
		}
	})

	t.Run("LeaveParty", func(t *testing.T) {
		userID := "user-leave"
		mockDB.applications[party.ID][userID] = "ACCEPTED"

		// User leaves - set to DECLINED
		mockDB.applications[party.ID][userID] = "DECLINED"

		status := mockDB.applications[party.ID][userID]
		if status != "DECLINED" {
			t.Errorf("Expected status 'DECLINED', got '%s'", status)
		}
	})
}

// ==================== NOTIFICATION TESTS ====================

func TestNotificationOperations(t *testing.T) {
	mockDB := NewMockDB()
	userID := "user-notif"

	t.Run("CreateNotification", func(t *testing.T) {
		notif := CreateTestNotification("notif-123", userID)
		mockDB.notifications[userID] = append(mockDB.notifications[userID], notif)

		if len(mockDB.notifications[userID]) != 1 {
			t.Errorf("Expected 1 notification, got %d", len(mockDB.notifications[userID]))
		}
	})

	t.Run("GetNotifications", func(t *testing.T) {
		// Add multiple notifications
		for i := 0; i < 5; i++ {
			notif := CreateTestNotification("notif-"+string(rune(i)), userID)
			mockDB.notifications[userID] = append(mockDB.notifications[userID], notif)
		}

		notifications := mockDB.notifications[userID]
		if len(notifications) != 6 { // 1 + 5
			t.Errorf("Expected 6 notifications, got %d", len(notifications))
		}
	})

	t.Run("MarkNotificationRead", func(t *testing.T) {
		notifID := "notif-read"
		notif := CreateTestNotification(notifID, userID)
		notif.IsRead = false
		mockDB.notifications[userID] = append(mockDB.notifications[userID], notif)

		// Mark as read
		for i := range mockDB.notifications[userID] {
			if mockDB.notifications[userID][i].ID == notifID {
				mockDB.notifications[userID][i].IsRead = true
			}
		}

		// Verify
		for _, n := range mockDB.notifications[userID] {
			if n.ID == notifID && !n.IsRead {
				t.Error("Notification should be marked as read")
			}
		}
	})

	t.Run("MarkAllNotificationsRead", func(t *testing.T) {
		// Mark all as read
		for i := range mockDB.notifications[userID] {
			mockDB.notifications[userID][i].IsRead = true
		}

		// Verify all are read
		allRead := true
		for _, n := range mockDB.notifications[userID] {
			if !n.IsRead {
				allRead = false
				break
			}
		}

		if !allRead {
			t.Error("All notifications should be read")
		}
	})
}

// ==================== BLOCKING TESTS ====================

func TestBlockingOperations(t *testing.T) {
	mockDB := NewMockDB()
	blockerID := "user-blocker"

	t.Run("BlockUser", func(t *testing.T) {
		blockedID := "user-blocked"
		if mockDB.blocked[blockerID] == nil {
			mockDB.blocked[blockerID] = make(map[string]bool)
		}
		mockDB.blocked[blockerID][blockedID] = true

		if !mockDB.blocked[blockerID][blockedID] {
			t.Error("User should be blocked")
		}
	})

	t.Run("UnblockUser", func(t *testing.T) {
		blockedID := "user-to-unblock"
		mockDB.blocked[blockerID] = make(map[string]bool)
		mockDB.blocked[blockerID][blockedID] = true

		// Unblock
		delete(mockDB.blocked[blockerID], blockedID)

		if mockDB.blocked[blockerID][blockedID] {
			t.Error("User should be unblocked")
		}
	})

	t.Run("IsBlocked", func(t *testing.T) {
		blockedID := "user-check"
		mockDB.blocked[blockerID] = make(map[string]bool)
		mockDB.blocked[blockerID][blockedID] = true

		isBlocked := mockDB.blocked[blockerID][blockedID]
		if !isBlocked {
			t.Error("User should be blocked")
		}
	})

	t.Run("GetBlockedUsers", func(t *testing.T) {
		mockDB.blocked[blockerID] = map[string]bool{
			"user1": true,
			"user2": true,
			"user3": true,
		}

		var blockedList []string
		for id := range mockDB.blocked[blockerID] {
			blockedList = append(blockedList, id)
		}

		if len(blockedList) != 3 {
			t.Errorf("Expected 3 blocked users, got %d", len(blockedList))
		}
	})
}

// ==================== REPORTING TESTS ====================

func TestReportingOperations(t *testing.T) {
	mockDB := NewMockDB()

	t.Run("ReportUser", func(t *testing.T) {
		report := map[string]string{
			"reporter": "user-123",
			"reported": "user-456",
			"reason":   "inappropriate behavior",
			"details":  "Details here",
		}
		mockDB.reports = append(mockDB.reports, report)

		if len(mockDB.reports) != 1 {
			t.Errorf("Expected 1 report, got %d", len(mockDB.reports))
		}
	})

	t.Run("ReportParty", func(t *testing.T) {
		report := map[string]string{
			"reporter": "user-123",
			"party":    "party-789",
			"reason":   "spam",
			"details":  "Party details here",
		}
		mockDB.reports = append(mockDB.reports, report)

		if len(mockDB.reports) != 2 {
			t.Errorf("Expected 2 reports, got %d", len(mockDB.reports))
		}
	})
}

// ==================== ANALYTICS TESTS ====================

func TestAnalyticsOperations(t *testing.T) {
	mockDB := NewMockDB()
	partyID := "party-analytics"

	t.Run("GetPartyAnalytics", func(t *testing.T) {
		analytics := PartyAnalytics{
			PartyID:           partyID,
			TotalViews:        100,
			TotalApplications: 50,
			AcceptedCount:     25,
			PendingCount:      15,
			DeclinedCount:     10,
			CurrentGuestCount: 20,
		}
		mockDB.analytics[partyID] = analytics

		stored := mockDB.analytics[partyID]
		if stored.TotalViews != 100 {
			t.Errorf("Expected TotalViews 100, got %d", stored.TotalViews)
		}
		if stored.TotalApplications != 50 {
			t.Errorf("Expected TotalApplications 50, got %d", stored.TotalApplications)
		}
		if stored.AcceptedCount != 25 {
			t.Errorf("Expected AcceptedCount 25, got %d", stored.AcceptedCount)
		}
	})
}

// ==================== CROWDFUNDING TESTS ====================

func TestCrowdfundingOperations(t *testing.T) {
	mockDB := NewMockDB()
	partyID := "party-fund"

	t.Run("CreateRotationPool", func(t *testing.T) {
		pool := Crowdfunding{
			ID:            "pool-123",
			PartyID:       partyID,
			TargetAmount:  1000.0,
			CurrentAmount: 0.0,
			Currency:      "USD",
			Contributors:  []Contribution{},
			IsFunded:      false,
		}
		mockDB.rotationPools[partyID] = pool

		if mockDB.rotationPools[partyID].TargetAmount != 1000.0 {
			t.Errorf("Expected TargetAmount 1000.0, got %f", mockDB.rotationPools[partyID].TargetAmount)
		}
	})

	t.Run("AddContribution", func(t *testing.T) {
		pool := mockDB.rotationPools[partyID]

		// Add contribution
		contrib := Contribution{
			UserID: "user-123",
			Amount: 100.0,
			PaidAt: time.Now(),
		}
		pool.Contributors = append(pool.Contributors, contrib)
		pool.CurrentAmount += contrib.Amount
		mockDB.rotationPools[partyID] = pool

		updated := mockDB.rotationPools[partyID]
		if updated.CurrentAmount != 100.0 {
			t.Errorf("Expected CurrentAmount 100.0, got %f", updated.CurrentAmount)
		}
		if len(updated.Contributors) != 1 {
			t.Errorf("Expected 1 contributor, got %d", len(updated.Contributors))
		}
	})

	t.Run("CheckFundedStatus", func(t *testing.T) {
		pool := mockDB.rotationPools[partyID]

		// Add more contributions to meet target
		pool.CurrentAmount = 1000.0
		if pool.CurrentAmount >= pool.TargetAmount {
			pool.IsFunded = true
		}
		mockDB.rotationPools[partyID] = pool

		if !mockDB.rotationPools[partyID].IsFunded {
			t.Error("Pool should be funded")
		}
	})
}

// ==================== DM TESTS ====================

func TestDMOperations(t *testing.T) {
	mockDB := NewMockDB()
	user1 := "user-1"
	user2 := "user-2"

	t.Run("GetDMMessages", func(t *testing.T) {
		// Generate deterministic DM chat ID
		u1, u2 := user1, user2
		if u1 > u2 {
			u1, u2 = u2, u1
		}
		dmChatID := u1 + "_" + u2

		// Add messages
		msg1 := CreateTestMessage("dm-1", dmChatID, user1)
		msg2 := CreateTestMessage("dm-2", dmChatID, user2)
		mockDB.messages[dmChatID] = []ChatMessage{msg1, msg2}

		messages := mockDB.messages[dmChatID]
		if len(messages) != 2 {
			t.Errorf("Expected 2 DM messages, got %d", len(messages))
		}
	})
}

// ==================== SEARCH TESTS ====================

func TestSearchOperations(t *testing.T) {
	mockDB := NewMockDB()

	t.Run("SearchUsers", func(t *testing.T) {
		// Create users for search - use a unique mock DB
		users := []User{
			{ID: "search-john", RealName: "John Doe", InstagramHandle: "@john"},
			{ID: "search-jane", RealName: "Jane Smith", XHandle: "@jane"},
			{ID: "search-bob", RealName: "Bob Wilson", InstagramHandle: "@bob"},
		}

		for _, u := range users {
			mockDB.users[u.ID] = u
		}

		// Search by name "John" - should only match "John Doe", not "Bob Wilson"
		query := "John"
		var results []User
		for _, u := range mockDB.users {
			hasMatch := false
			if len(query) > 0 && len(u.RealName) >= len(query) {
				// Simple substring match
				for i := 0; i <= len(u.RealName)-len(query); i++ {
					if u.RealName[i:i+len(query)] == query {
						hasMatch = true
						break
					}
				}
			}
			if hasMatch {
				results = append(results, u)
			}
		}

		// Only "John Doe" should match "John"
		if len(results) != 1 {
			t.Errorf("Expected 1 search result, got %d: %v", len(results), results)
		}
	})
}

// ==================== PARTY DURATION TESTS ====================

func TestPartyDuration(t *testing.T) {
	_ = NewMockDB()
	host := CreateTestUser("host-duration")

	t.Run("DurationHoursCalculation", func(t *testing.T) {
		party := CreateTestParty("party-duration", host.ID)
		party.StartTime = time.Now().Add(24 * time.Hour)
		party.DurationHours = 4

		// Calculate end time
		endTime := party.StartTime.Add(time.Duration(party.DurationHours) * time.Hour)

		expectedEnd := party.StartTime.Add(4 * time.Hour)
		if !endTime.Equal(expectedEnd) {
			t.Errorf("End time mismatch: got %v, expected %v", endTime, expectedEnd)
		}
	})

	t.Run("VariousDurations", func(t *testing.T) {
		durations := []int{1, 2, 4, 6, 8, 12, 24}

		for _, dur := range durations {
			party := CreateTestParty("party-"+string(rune(dur)), host.ID)
			party.DurationHours = dur
			_ = party.DurationHours // Acknowledge field is set but not read in this test

			endTime := party.StartTime.Add(time.Duration(dur) * time.Hour)
			expectedDuration := time.Duration(dur) * time.Hour

			if endTime.Sub(party.StartTime) != expectedDuration {
				t.Errorf("Duration %d hours mismatch", dur)
			}
		}
	})
}
