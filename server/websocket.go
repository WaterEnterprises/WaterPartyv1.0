package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sort"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/jackc/pgx/v5"
)

// generateDMChatId creates a deterministic DM chat ID using lexicographic sorting
// This must match the Flutter client's ChatRoom.generateDMChatId exactly
func generateDMChatId(userId1, userId2 string) string {
	ids := []string{userId1, userId2}
	sort.Strings(ids)
	return ids[0] + "_" + ids[1]
}

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4096 // Adjust based on your average ChatMessage size
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  2048,
	WriteBufferSize: 2048,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

// Hub maintains the set of active clients and broadcasts messages to rooms.
type Hub struct {
	// Registered clients mapped by UserID
	clients map[string]*Client

	// Room mapping: RoomID -> Set of Clients in that room
	rooms map[string]map[*Client]bool

	// Inbound messages from the clients.
	broadcast       chan RoomEvent
	globalBroadcast chan []byte

	register   chan *Client
	unregister chan *Client

	// Channel to signal hub shutdown
	quit chan bool

	mu sync.RWMutex
}

// RoomEvent wraps a message with its target room
type RoomEvent struct {
	RoomID  string
	Message []byte
}

func NewHub() *Hub {
	return &Hub{
		broadcast:       make(chan RoomEvent, 1024),
		globalBroadcast: make(chan []byte, 1024),
		register:        make(chan *Client),
		unregister:      make(chan *Client),
		quit:            make(chan bool),
		clients:         make(map[string]*Client),
		rooms:           make(map[string]map[*Client]bool),
	}
}

func (h *Hub) broadcastGlobal(msg []byte) {
	h.globalBroadcast <- msg
}

func (h *Hub) Run() {
	for {
		select {
		case <-h.quit:
			return

		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.UID] = client
			h.mu.Unlock()

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.UID]; ok {
				delete(h.clients, client.UID)
				// Remove client from all rooms they were in
				for roomID := range h.rooms {
					delete(h.rooms[roomID], client)
				}
				close(client.send)
			}
			h.mu.Unlock()

		case msg := <-h.globalBroadcast:
			h.mu.RLock()
			for _, client := range h.clients {
				select {
				case client.send <- msg:
				default:
					go func(c *Client) { h.unregister <- c }(client)
				}
			}
			h.mu.RUnlock()

		case ev := <-h.broadcast:
			h.mu.RLock()
			// Ultra-efficient routing: only iterate over clients in the specific room
			if clients, ok := h.rooms[ev.RoomID]; ok {
				for client := range clients {
					select {
					case client.send <- ev.Message:
					default:
						// If client buffer is full, drop them to prevent hub lag
						go func(c *Client) { h.unregister <- c }(client)
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

// JoinRoom adds a client to a specific room map
func (h *Hub) JoinRoom(roomID string, client *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.rooms[roomID] == nil {
		h.rooms[roomID] = make(map[*Client]bool)
	}
	h.rooms[roomID][client] = true
}

type Client struct {
	hub  *Hub
	conn *websocket.Conn
	send chan []byte // Buffered channel for outbound messages
	UID  string
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
				errorMsg, _ := json.Marshal(WSMessage{
					Event: "ERROR",
					Payload: map[string]string{
						"message": "Failed" + err.Error(),
					},
				})
				c.send <- errorMsg
			}
			break
		}

		// Handle the message efficiently
		c.handleIncomingMessage(message)
	}
}

func (c *Client) handleIncomingMessage(raw []byte) {
	var wsMsg WSMessage
	if err := json.Unmarshal(raw, &wsMsg); err != nil {
		return
	}

	switch wsMsg.Event {
	case "JOIN_ROOM":
		// Payload: {"RoomID": "uuid"}
		roomID, _ := wsMsg.Payload.(map[string]interface{})["RoomID"].(string)
		if roomID != "" {
			c.hub.JoinRoom(roomID, c)
		}

	case "LEAVE_ROOM":
		// Payload: {"RoomID": "uuid"}
		roomID, _ := wsMsg.Payload.(map[string]interface{})["RoomID"].(string)
		if roomID != "" {
			c.hub.mu.Lock()
			if clients, ok := c.hub.rooms[roomID]; ok {
				delete(clients, c)
			}
			c.hub.mu.Unlock()
		}

	case "SEND_MESSAGE":
		// 1. Convert payload to ChatMessage struct
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		var chatMsg ChatMessage
		json.Unmarshal(payloadBytes, &chatMsg)

		chatMsg.SenderID = c.UID
		chatMsg.CreatedAt = time.Now()

		// Fetch sender info for real-time broadcast
		sender, err := GetUser(c.UID)
		if err == nil {
			chatMsg.SenderName = sender.RealName
			chatMsg.SenderThumbnail = sender.Thumbnail
		}

		// 2. Save to Postgres (database.go) asynchronously to not block WS
		go func(m ChatMessage) {
			_, err := SaveMessage(m)
			if err != nil {
				log.Printf("DB Save Error: %v", err)
				errorMsg, _ := json.Marshal(WSMessage{
					Event: "ERROR",
					Payload: map[string]string{
						"message": "Failed" + err.Error(),
					},
				})
				c.send <- errorMsg
			}
		}(chatMsg)

		// 3. Broadcast to Room
		outgoing, _ := json.Marshal(WSMessage{
			Event:   "NEW_MESSAGE",
			Payload: chatMsg,
		})
		c.hub.broadcast <- RoomEvent{RoomID: chatMsg.ChatID, Message: outgoing}

	case "SEND_DM":
		// Payload: {"RecipientID": "uuid", "Content": "text"}
		var dmReq struct {
			RecipientID string `json:"RecipientID"`
			Content     string `json:"Content"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &dmReq)

		// Check if either user has blocked the other
		blocked1, _ := IsBlocked(c.UID, dmReq.RecipientID)
		blocked2, _ := IsBlocked(dmReq.RecipientID, c.UID)
		if blocked1 || blocked2 {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Cannot send message to this user",
				},
			})
			c.send <- errorMsg
			return
		}

		// Create a synthetic ChatID for the DM (deterministic pair-wise ID)
		// Use lexicographic sorting to match Flutter client's generateDMChatId
		dmChatID := generateDMChatId(c.UID, dmReq.RecipientID)

		msg := ChatMessage{
			ChatID:    dmChatID,
			SenderID:  c.UID,
			Content:   dmReq.Content,
			Type:      MsgText,
			CreatedAt: time.Now(),
		}

		// Fetch sender info for real-time broadcast
		sender, err := GetUser(c.UID)
		if err == nil {
			msg.SenderName = sender.RealName
			msg.SenderThumbnail = sender.Thumbnail
		}

		// 1. Save to DB
		SaveMessage(msg)

		// 2. Broadcast to Recipient and Sender (Private)
		outgoingDM, _ := json.Marshal(WSMessage{
			Event:   "NEW_MESSAGE",
			Payload: msg,
		})

		c.hub.mu.RLock()
		if recipient, ok := c.hub.clients[dmReq.RecipientID]; ok {
			recipient.send <- outgoingDM
		}
		c.send <- outgoingDM // Send back to self for sync
		c.hub.mu.RUnlock()

	case "CREATE_PARTY":
		// Directly access payload as map to avoid marshal/unmarshal issues
		payloadMap, ok := wsMsg.Payload.(map[string]interface{})
		if !ok {
			log.Printf("CREATE_PARTY: Failed to cast payload to map")
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + "CREATE_PARTY: Failed to cast payload to map",
				},
			})
			c.send <- errorMsg
			return
		}

		// Extract fields manually
		var p Party
		p.ID = ""
		if id, ok := payloadMap["ID"].(string); ok {
			p.ID = id
		}
		if title, ok := payloadMap["Title"].(string); ok {
			p.Title = title
		}
		if desc, ok := payloadMap["Description"].(string); ok {
			p.Description = desc
		}
		if startTime, ok := payloadMap["StartTime"].(string); ok && startTime != "" {
			// Try multiple formats
			if t, err := time.Parse(time.RFC3339, startTime); err == nil {
				p.StartTime = t
			} else if t, err := time.Parse("2006-01-02T15:04:05.000Z", startTime); err == nil {
				p.StartTime = t
			} else if t, err := time.Parse("2006-01-02T15:04:05Z", startTime); err == nil {
				p.StartTime = t
			} else if t, err := time.Parse("2006-01-02 15:04:05", startTime); err == nil {
				p.StartTime = t
			}
		}
		// Calculate end time from duration if provided
		durationHours := 2 // default 2 hours
		if dh, ok := payloadMap["DurationHours"].(float64); ok {
			durationHours = int(dh)
		}
		if !p.StartTime.IsZero() {
			p.DurationHours = durationHours
		}
		if status, ok := payloadMap["Status"].(string); ok {
			p.Status = PartyStatus(status)
		}
		if addr, ok := payloadMap["Address"].(string); ok {
			p.Address = addr
		}
		if city, ok := payloadMap["City"].(string); ok {
			p.City = city
		}
		if photos, ok := payloadMap["PartyPhotos"].([]interface{}); ok {
			for _, photo := range photos {
				if s, ok := photo.(string); ok {
					p.PartyPhotos = append(p.PartyPhotos, s)
				}
			}
		}
		if tags, ok := payloadMap["VibeTags"].([]interface{}); ok {
			for _, tag := range tags {
				if s, ok := tag.(string); ok {
					p.VibeTags = append(p.VibeTags, s)
				}
			}
		}
		if rules, ok := payloadMap["Rules"].([]interface{}); ok {
			for _, rule := range rules {
				if s, ok := rule.(string); ok {
					p.Rules = append(p.Rules, s)
				}
			}
		}
		if chatRoomID, ok := payloadMap["ChatRoomID"].(string); ok {
			p.ChatRoomID = chatRoomID
		}
		if thumbnail, ok := payloadMap["Thumbnail"].(string); ok {
			p.Thumbnail = thumbnail
		}
		if geoLat, ok := payloadMap["GeoLat"].(float64); ok {
			p.GeoLat = geoLat
		}
		if geoLon, ok := payloadMap["GeoLon"].(float64); ok {
			p.GeoLon = geoLon
		}
		if maxCap, ok := payloadMap["MaxCapacity"].(float64); ok {
			p.MaxCapacity = int(maxCap)
		}
		if autoLock, ok := payloadMap["AutoLockOnFull"].(bool); ok {
			p.AutoLockOnFull = autoLock
		}
		if isLocRevealed, ok := payloadMap["IsLocationRevealed"].(bool); ok {
			p.IsLocationRevealed = isLocRevealed
		}

		// DEBUG: Log what was received
		log.Printf("CREATE_PARTY received - Title: %q, Description: %q, StartTime: %q, ChatRoomID: %q, MaxCapacity: %v",
			p.Title, p.Description, p.StartTime, p.ChatRoomID, p.MaxCapacity)
		log.Printf("CREATE_PARTY raw payload: %+v", payloadMap)

		// Validate required fields
		errors := []string{}

		if p.Title == "" {
			errors = append(errors, "Title is required")
		}
		if p.StartTime.IsZero() {
			errors = append(errors, "Start time is required")
		}
		if p.ChatRoomID == "" {
			errors = append(errors, "Chat room ID is required")
		}
		if len(p.PartyPhotos) == 0 {
			errors = append(errors, "At least one photo is required")
		}
		if p.Address == "" {
			errors = append(errors, "Address is required")
		}
		if p.City == "" {
			errors = append(errors, "City is required")
		}
		if p.MaxCapacity <= 0 {
			errors = append(errors, "Max capacity must be greater than 0")
		}

		if len(errors) > 0 {
			log.Printf("CREATE_PARTY validation errors: %v", errors)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]interface{}{
					"message": "Validation failed",
					"errors":  errors,
				},
			})
			c.send <- errorMsg
			return
		}

		p.HostID = c.UID
		now := time.Now()
		p.CreatedAt = &now
		p.UpdatedAt = &now

		// Auto-extrapolate address/city from coordinates if using "My Location"
		if p.GeoLat != 0 && p.GeoLon != 0 && (p.Address == "MY CURRENT LOCATION" || p.City == "DETECTED ON PUBLISH") {
			addr, city, err := ReverseGeocode(p.GeoLat, p.GeoLon)
			if err == nil {
				if p.Address == "MY CURRENT LOCATION" {
					p.Address = addr
				}
				if p.City == "DETECTED ON PUBLISH" {
					p.City = city
				}
			}
		}

		id, err := CreateParty(p)
		if err != nil {
			log.Printf("CREATE_PARTY DB Error: %v", err)
			log.Printf("Create Party DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		p.ID = id

		// DEBUG: Log what was saved and is being sent back
		log.Printf("After CreateParty - ID: %s, Title: %q", p.ID, p.Title)

		// Send confirmation back to creator
		confirmationMsg, _ := json.Marshal(WSMessage{
			Event:   "PARTY_CREATED",
			Payload: p,
		})
		c.send <- confirmationMsg

		// Also send the new ChatRoom to the creator immediately
		newRoom, err := GetChatRoom(p.ChatRoomID)
		if err == nil {
			newRoomMsg, _ := json.Marshal(WSMessage{
				Event:   "NEW_CHAT_ROOM",
				Payload: newRoom,
			})
			c.send <- newRoomMsg
		}

		broadcastMsg, _ := json.Marshal(WSMessage{
			Event:   "NEW_PARTY",
			Payload: p,
		})
		c.hub.broadcastGlobal(broadcastMsg)

	case "GET_CHATS":
		log.Printf("GET_CHATS received from user: %s", c.UID)
		rooms, err := GetChatRoomsForUser(c.UID)
		if err != nil {
			log.Printf("Get Chats DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "CHATS_LIST",
			Payload: rooms,
		})
		c.send <- response

	case "GET_MY_PARTIES", "GET_MATCHED_PARTIES":
		log.Printf("GET_MY_PARTIES received from user: %s", c.UID)
		parties, err := GetMyParties(c.UID)
		if err != nil {
			log.Printf("GetMyParties DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to get your parties",
				},
			})
			c.send <- errorMsg
			return
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "MY_PARTIES",
			Payload: parties,
		})
		log.Printf("GET_MY_PARTIES: returning %d parties", len(parties))
		c.send <- response

	case "UPDATE_PROFILE":
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		var u User
		json.Unmarshal(payloadBytes, &u)

		// Ensure the user is updating their own profile
		u.ID = c.UID

		err := UpdateUser(u)
		if err != nil {
			log.Printf("Update Profile DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg

			return
		}
		log.Printf("Update Profile DB: %v", u)

		// Optional: broadcast update or send confirmation back to client
		response, _ := json.Marshal(WSMessage{
			Event:   "PROFILE_UPDATED",
			Payload: u,
		})
		c.send <- response

	case "GET_USER":
		log.Printf("GET_USER received from user: %s", c.UID)
		u, err := GetUser(c.UID)
		if err != nil {
			log.Printf("Get User DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "PROFILE_UPDATED",
			Payload: u,
		})
		c.send <- response
		log.Printf("GET_USER: returning user %v", u)

	case "REVERSE_GEOCODE":
		// Payload: {"lat": 40.7128, "lon": -74.0060}
		var coords struct {
			Lat float64 `json:"lat"`
			Lon float64 `json:"lon"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &coords)

		if coords.Lat == 0 && coords.Lon == 0 {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Invalid coordinates: latitude and longitude cannot be zero",
				},
			})
			c.send <- errorMsg
			return
		}

		log.Printf("REVERSE_GEOCODE request from user %s: Lat=%f, Lon=%f", c.UID, coords.Lat, coords.Lon)

		address, city, err := ReverseGeocode(coords.Lat, coords.Lon)
		if err != nil {
			log.Printf("ReverseGeocode Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to reverse geocode: " + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event: "GEOCODE_RESULT",
			Payload: map[string]string{
				"address": address,
				"city":    city,
				"lat":     fmt.Sprintf("%f", coords.Lat),
				"lon":     fmt.Sprintf("%f", coords.Lon),
			},
		})
		c.send <- response

	case "SWIPE":
		// Payload: {"PartyID": "uuid", "Direction": "right/left"}
		var swipe struct {
			PartyID   string `json:"PartyID"`
			Direction string `json:"Direction"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &swipe)

		status := "PENDING"
		if swipe.Direction == "left" {
			status = "DECLINED"
		}

		// Save swipe to party_applications table
		query := `INSERT INTO party_applications (party_id, user_id, status) 
				  VALUES ($1, $2, $3) ON CONFLICT (party_id, user_id) 
				  DO UPDATE SET status = $3`
		_, err := db.Exec(context.Background(), query, swipe.PartyID, c.UID, status)
		if err != nil {
			log.Printf("Swipe Save Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to swipe: " + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

	case "GET_FEED":
		// Payload: {"Lat": 0.0, "Lon": 0.0, "RadiusKm": 50}
		log.Printf("GET_FEED received from user: %s", c.UID)
		var loc struct {
			Lat      float64 `json:"Lat"`
			Lon      float64 `json:"Lon"`
			RadiusKm float64 `json:"RadiusKm"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &loc)

		if loc.RadiusKm <= 0 {
			loc.RadiusKm = 50.0
		}

		// Simple bounding box calculation
		// 1 degree lat ~= 111km
		latDelta := loc.RadiusKm / 111.0
		// 1 degree lon ~= 111km * cos(lat)
		lonDelta := loc.RadiusKm / (111.0 * 0.7) // Roughly estimate for mid-latitudes

		query := `
			SELECT id, host_id, title, description, party_photos, start_time, duration_hours, status, 
			       is_location_revealed, address, city, geo_lat, geo_lon, max_capacity, 
			       current_guest_count, auto_lock_on_full, vibe_tags, rules, chat_room_id, 
			       created_at, updated_at, thumbnail
			FROM parties 
			WHERE status = 'OPEN' 
			  AND host_id != $1
			  AND id NOT IN (SELECT party_id FROM party_applications WHERE user_id = $1)
			  AND host_id NOT IN (SELECT blocked_id FROM blocked_users WHERE blocker_id = $1)
			  AND host_id NOT IN (SELECT blocker_id FROM blocked_users WHERE blocked_id = $1)
		`

		var rows pgx.Rows
		var err error

		if loc.Lat != 0 || loc.Lon != 0 {
			query += ` AND geo_lat BETWEEN $2 AND $3 AND geo_lon BETWEEN $4 AND $5`
			query += ` ORDER BY created_at DESC LIMIT 50`
			rows, err = db.Query(context.Background(), query,
				c.UID,
				loc.Lat-latDelta, loc.Lat+latDelta,
				loc.Lon-lonDelta, loc.Lon+lonDelta)
		} else {
			query += ` ORDER BY created_at DESC LIMIT 50`
			rows, err = db.Query(context.Background(), query, c.UID)
		}

		if err != nil {
			log.Printf("Feed Query Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to get feed: " + err.Error(),
				},
			})
			c.send <- errorMsg
			return
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
				log.Printf("Feed Scan Error: %v", err)
				errorMsg, _ := json.Marshal(WSMessage{
					Event: "ERROR",
					Payload: map[string]string{
						"message": "Failed" + err.Error(),
					},
				})
				c.send <- errorMsg
				continue
			}
			parties = append(parties, p)
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "FEED_UPDATE",
			Payload: parties,
		})
		c.send <- response

	case "GET_APPLICANTS", "GET_PARTY_APPLICANTS":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		apps, err := GetApplicantsForParty(partyID)
		if err != nil {
			log.Printf("Get Applicants DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event: "APPLICANTS_LIST",
			Payload: map[string]interface{}{
				"PartyID":    partyID,
				"Applicants": apps,
			},
		})
		c.send <- response

	case "UPDATE_APPLICATION":
		// Payload: {"PartyID": "uuid", "UserID": "uuid", "Status": "ACCEPTED/DECLINED"}
		var req struct {
			PartyID string `json:"PartyID"`
			UserID  string `json:"UserID"`
			Status  string `json:"Status"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		err := UpdateApplicationStatus(req.PartyID, req.UserID, req.Status)
		if err != nil {
			log.Printf("Update Application DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		// Broadcast update to the host (self)
		response, _ := json.Marshal(WSMessage{
			Event:   "APPLICATION_UPDATED",
			Payload: req,
		})
		c.send <- response

		// Notify the specific user if they are connected
		if req.Status == "ACCEPTED" {
			c.hub.mu.RLock()
			if recipient, ok := c.hub.clients[req.UserID]; ok {
				// 1. Send the application update notification
				recipient.send <- response

				// 2. Fetch and send the chat room details so it appears in their list immediately
				room, err := GetChatRoomByParty(req.PartyID)
				if err == nil {
					roomMsg, _ := json.Marshal(WSMessage{
						Event:   "NEW_CHAT_ROOM",
						Payload: room,
					})
					recipient.send <- roomMsg
				}
			}
			c.hub.mu.RUnlock()
		}

	case "GET_PARTY_DETAILS":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		p, err := GetParty(partyID)
		if err != nil {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Party not found",
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "PARTY_DETAILS",
			Payload: p,
		})
		c.send <- response

	case "GET_CHAT_HISTORY":
		// Payload: {"ChatID": "uuid", "Limit": 50}
		var req struct {
			ChatID string `json:"ChatID"`
			Limit  int    `json:"Limit"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.ChatID == "" {
			return
		}
		if req.Limit <= 0 {
			req.Limit = 50
		}

		messages, err := GetChatHistory(req.ChatID, req.Limit)
		if err != nil {
			log.Printf("GetChatHistory DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "CHAT_HISTORY",
			Payload: messages,
		})
		c.send <- response

	case "LEAVE_PARTY":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		// Verify party exists
		p, err := GetParty(partyID)
		if err != nil {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Party not found",
				},
			})
			c.send <- errorMsg
			return
		}

		// If user is the host, they can't leave - they can only delete
		if p.HostID == c.UID {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Host cannot leave party, please delete instead",
				},
			})
			c.send <- errorMsg
			return
		}

		// Remove user from party applications (set to DECLINED)
		err = UpdateApplicationStatus(partyID, c.UID, "DECLINED")
		if err != nil {
			log.Printf("LeaveParty DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to leave party",
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event: "PARTY_LEFT",
			Payload: map[string]string{
				"PartyID": partyID,
			},
		})
		c.send <- response

	case "DELETE_PARTY":
		// Payload: {"PartyID": "uuid"}
		log.Printf("DELETE_PARTY received - PartyID: %s", wsMsg.Payload)

		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			log.Printf("DELETE_PARTY: No PartyID provided")
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + "DELETE_PARTY: No PartyID provided",
				},
			})
			c.send <- errorMsg
			return
		}

		// 1. Verify Host
		p, err := GetParty(partyID)
		if err != nil {
			log.Printf("DELETE_PARTY: Failed to get party: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to swipe: " + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		if p.HostID != c.UID {
			// Permission denied
			log.Printf("DELETE_PARTY: Permission denied - user %s is not host %s", c.UID, p.HostID)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to swipe: " + fmt.Sprintf("DELETE_PARTY: Permission denied - user %s is not host %s", c.UID, p.HostID),
				},
			})
			c.send <- errorMsg
			return
		}

		// 2. Delete from DB
		err = DeleteParty(partyID)
		if err != nil {
			log.Printf("DELETE_PARTY: DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to swipe: " + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		log.Printf("DELETE_PARTY: Party %s deleted successfully", partyID)

		// 3. Broadcast deletion to the room so people are kicked out
		deletionMsg, _ := json.Marshal(WSMessage{
			Event: "PARTY_DELETED",
			Payload: map[string]string{
				"PartyID":    partyID,
				"ChatRoomID": p.ChatRoomID,
			},
		})
		c.hub.broadcast <- RoomEvent{RoomID: p.ChatRoomID, Message: deletionMsg}

		// 4. Also broadcast global notification to remove from feeds
		c.hub.broadcastGlobal(deletionMsg)

		// 5. Send direct response to the client that requested the deletion
		c.send <- deletionMsg

	case "GET_MATCHED_USERS":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		// Verify the user is the host
		p, err := GetParty(partyID)
		if err != nil || p.HostID != c.UID {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Not authorized to view matched users",
				},
			})
			c.send <- errorMsg
			return
		}

		// Get accepted applicants (matched users)
		apps, err := GetAcceptedApplicants(partyID)
		if err != nil {
			log.Printf("GetMatchedUsers DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "MATCHED_USERS",
			Payload: apps,
		})
		c.send <- response

	case "UPDATE_PARTY":
		// Payload: Party object with ID
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		var p Party
		json.Unmarshal(payloadBytes, &p)

		// Verify the user is the host
		existing, err := GetParty(p.ID)
		if err != nil || existing.HostID != c.UID {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Not authorized to edit this party",
				},
			})
			c.send <- errorMsg
			return
		}

		// Preserve host ID and created time
		p.HostID = existing.HostID
		p.CreatedAt = existing.CreatedAt
		now := time.Now()
		p.UpdatedAt = &now

		err = UpdateParty(p)
		if err != nil {
			log.Printf("UpdateParty DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		// Get updated party and send back
		updated, _ := GetParty(p.ID)
		response, _ := json.Marshal(WSMessage{
			Event:   "PARTY_UPDATED",
			Payload: updated,
		})
		c.send <- response

	case "UNMATCH_USER":
		// Payload: {"PartyID": "uuid", "UserID": "uuid"}
		var req struct {
			PartyID string `json:"PartyID"`
			UserID  string `json:"UserID"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.PartyID == "" || req.UserID == "" {
			return
		}

		// Verify the user is the host
		p, err := GetParty(req.PartyID)
		if err != nil || p.HostID != c.UID {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Not authorized to unmatch users",
				},
			})
			c.send <- errorMsg
			return
		}

		// Update application status to DECLINED
		err = UpdateApplicationStatus(req.PartyID, req.UserID, "DECLINED")
		if err != nil {
			log.Printf("UnmatchUser DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event: "USER_UNMATCHED",
			Payload: map[string]string{
				"PartyID": req.PartyID,
				"UserID":  req.UserID,
			},
		})
		c.send <- response

	case "DELETE_USER":
		// Payload: {"UserID": "uuid"}
		var req struct {
			UserID string `json:"UserID"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		// Only allow users to delete their own account
		if req.UserID != c.UID {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Not authorized to delete this user",
				},
			})
			c.send <- errorMsg
			return
		}

		err := DeleteUser(req.UserID)
		if err != nil {
			log.Printf("DeleteUser DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "USER_DELETED",
			Payload: map[string]string{"UserID": req.UserID},
		})
		c.send <- response

	case "APPLY_TO_PARTY":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		// Check if party exists and is open
		p, err := GetParty(partyID)
		if err != nil {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Party not found",
				},
			})
			c.send <- errorMsg
			return
		}

		if p.Status != "OPEN" {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Party is not accepting applications",
				},
			})
			c.send <- errorMsg
			return
		}

		// Save application to party_applications table
		query := `INSERT INTO party_applications (party_id, user_id, status) 
			  VALUES ($1, $2, 'PENDING') ON CONFLICT (party_id, user_id) 
			  DO UPDATE SET status = 'PENDING', applied_at = NOW()`
		_, err = db.Exec(context.Background(), query, partyID, c.UID)
		if err != nil {
			log.Printf("ApplyToParty Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event: "APPLICATION_SUBMITTED",
			Payload: map[string]string{
				"PartyID": partyID,
				"Status":  "PENDING",
			},
		})
		c.send <- response

	case "REJECT_PARTY":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		// Save rejection to party_applications table
		query := `INSERT INTO party_applications (party_id, user_id, status) 
			  VALUES ($1, $2, 'DECLINED') ON CONFLICT (party_id, user_id) 
			  DO UPDATE SET status = 'DECLINED', applied_at = NOW()`
		_, err := db.Exec(context.Background(), query, partyID, c.UID)
		if err != nil {
			log.Printf("RejectParty Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event: "APPLICATION_REJECTED",
			Payload: map[string]string{
				"PartyID": partyID,
				"Status":  "DECLINED",
			},
		})
		c.send <- response

	case "CANCEL_APPLICATION":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		// Set the application status to DECLINED
		err := UpdateApplicationStatus(partyID, c.UID, "DECLINED")
		if err != nil {
			log.Printf("CancelApplication Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to cancel application",
				},
			})
			c.send <- errorMsg
			return
		}

		cancelResponse, _ := json.Marshal(WSMessage{
			Event: "APPLICATION_REJECTED",
			Payload: map[string]string{
				"PartyID": partyID,
				"Status":  "DECLINED",
			},
		})
		c.send <- cancelResponse

	case "GET_DMS":
		// Get direct message chats for the current user
		log.Printf("GET_DMS received from user: %s", c.UID)
		dms, err := GetDMsForUser(c.UID)
		if err != nil {
			log.Printf("GetDMsForUser DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to get DMs",
				},
			})
			c.send <- errorMsg
			return
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "DMS_LIST",
			Payload: dms,
		})
		c.send <- response

	case "GET_DM_MESSAGES":
		// Payload: {"OtherUserID": "uuid", "Limit": 50}
		var req struct {
			OtherUserID string `json:"OtherUserID"`
			Limit       int    `json:"Limit"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.OtherUserID == "" {
			return
		}
		if req.Limit <= 0 {
			req.Limit = 50
		}

		log.Printf("GET_DM_MESSAGES: %s <-> %s", c.UID, req.OtherUserID)
		messages, err := GetDMMessages(c.UID, req.OtherUserID, req.Limit)
		if err != nil {
			log.Printf("GetDMMessages DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "DM_MESSAGES",
			Payload: messages,
		})
		c.send <- response

	case "DELETE_DM_MESSAGE":
		// Payload: {"MessageID": "uuid"}
		var req struct {
			MessageID string `json:"MessageID"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.MessageID == "" {
			return
		}

		err := DeleteMessage(req.MessageID, c.UID)
		if err != nil {
			log.Printf("DeleteMessage DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event: "MESSAGE_DELETED",
			Payload: map[string]string{
				"MessageID": req.MessageID,
			},
		})
		c.send <- response

	case "ADD_CONTRIBUTION":
		// Payload: {"PartyID": "uuid", "Amount": 10.00}
		var req struct {
			PartyID string  `json:"PartyID"`
			Amount  float64 `json:"Amount"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.PartyID == "" || req.Amount <= 0 {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Invalid contribution amount",
				},
			})
			c.send <- errorMsg
			return
		}

		contrib := Contribution{
			UserID: c.UID,
			Amount: req.Amount,
			PaidAt: time.Now(),
		}

		err := AddContribution(req.PartyID, contrib)
		if err != nil {
			log.Printf("AddContribution DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to add contribution",
				},
			})
			c.send <- errorMsg
			return
		}

		// Get updated pool state
		pool, err := GetRotationPool(req.PartyID)
		if err == nil {
			response, _ := json.Marshal(WSMessage{
				Event:   "FUNDRAISER_UPDATED",
				Payload: pool,
			})
			c.send <- response

			// Also broadcast to the party room
			p, _ := GetParty(req.PartyID)
			if p.ChatRoomID != "" {
				c.hub.broadcast <- RoomEvent{RoomID: p.ChatRoomID, Message: response}
			}
		}

	case "GET_FUNDRAISER_STATE":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		pool, err := GetRotationPool(partyID)
		if err != nil {
			// Return empty pool if not found
			pool = Crowdfunding{
				PartyID:  partyID,
				Currency: "USD",
				IsFunded: false,
			}
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "FUNDRAISER_STATE",
			Payload: pool,
		})
		c.send <- response

	case "GET_NOTIFICATIONS":
		// Get user's notifications
		notifs, err := GetNotifications(c.UID, 20)
		if err != nil {
			log.Printf("GetNotifications DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "NOTIFICATIONS_LIST",
			Payload: notifs,
		})
		c.send <- response

	case "MARK_NOTIFICATION_READ":
		// Payload: {"NotificationID": "uuid"}
		var req struct {
			NotificationID string `json:"NotificationID"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.NotificationID != "" {
			err := MarkNotificationRead(req.NotificationID, c.UID)
			if err != nil {
				log.Printf("MarkNotificationRead Error: %v", err)
				errorMsg, _ := json.Marshal(WSMessage{
					Event: "ERROR",
					Payload: map[string]string{
						"message": "Failed" + err.Error(),
					},
				})
				c.send <- errorMsg
			}
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "NOTIFICATION_MARKED_READ",
			Payload: map[string]string{"NotificationID": req.NotificationID},
		})
		c.send <- response

	case "MARK_ALL_NOTIFICATIONS_READ":
		err := MarkAllNotificationsRead(c.UID)
		if err != nil {
			log.Printf("MarkAllNotificationsRead Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "ALL_NOTIFICATIONS_MARKED_READ",
			Payload: map[string]string{"status": "success"},
		})
		c.send <- response

	case "SEARCH_USERS":
		// Payload: {"Query": "search term", "Limit": 20}
		var req struct {
			Query string `json:"Query"`
			Limit int    `json:"Limit"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.Query == "" {
			return
		}

		users, err := SearchUsers(req.Query, req.Limit)
		if err != nil {
			log.Printf("SearchUsers DB Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "USERS_SEARCH_RESULTS",
			Payload: users,
		})
		c.send <- response

	case "BLOCK_USER":
		// Payload: {"UserID": "uuid"}
		var req struct {
			UserID string `json:"UserID"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.UserID == "" || req.UserID == c.UID {
			return
		}

		err := BlockUser(c.UID, req.UserID)
		if err != nil {
			log.Printf("BlockUser Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event:   "ERROR",
				Payload: map[string]string{"message": "Failed to block user"},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "USER_BLOCKED",
			Payload: map[string]string{"UserID": req.UserID},
		})
		c.send <- response

	case "UNBLOCK_USER":
		// Payload: {"UserID": "uuid"}
		var req struct {
			UserID string `json:"UserID"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.UserID == "" {
			return
		}

		err := UnblockUser(c.UID, req.UserID)
		if err != nil {
			log.Printf("UnblockUser Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "USER_UNBLOCKED",
			Payload: map[string]string{"UserID": req.UserID},
		})
		c.send <- response

	case "GET_BLOCKED_USERS":
		blockedIDs, err := GetBlockedUsers(c.UID)
		if err != nil {
			log.Printf("GetBlockedUsers Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}
		response, _ := json.Marshal(WSMessage{
			Event:   "BLOCKED_USERS_LIST",
			Payload: blockedIDs,
		})
		c.send <- response

	case "REPORT_USER":
		// Payload: {"UserID": "uuid", "Reason": "...", "Details": "..."}
		var req struct {
			UserID  string `json:"UserID"`
			Reason  string `json:"Reason"`
			Details string `json:"Details"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.UserID == "" || req.Reason == "" {
			return
		}

		err := ReportUser(c.UID, req.UserID, req.Reason, req.Details)
		if err != nil {
			log.Printf("ReportUser Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event:   "ERROR",
				Payload: map[string]string{"message": "Failed to submit report"},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "USER_REPORTED",
			Payload: map[string]string{"UserID": req.UserID},
		})
		c.send <- response

	case "REPORT_PARTY":
		// Payload: {"PartyID": "uuid", "Reason": "...", "Details": "..."}
		var req struct {
			PartyID string `json:"PartyID"`
			Reason  string `json:"Reason"`
			Details string `json:"Details"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.PartyID == "" || req.Reason == "" {
			return
		}

		err := ReportParty(c.UID, req.PartyID, req.Reason, req.Details)
		if err != nil {
			log.Printf("ReportParty Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event:   "ERROR",
				Payload: map[string]string{"message": "Failed to submit report"},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "PARTY_REPORTED",
			Payload: map[string]string{"PartyID": req.PartyID},
		})
		c.send <- response

	case "GET_PARTY_ANALYTICS":
		// Payload: {"PartyID": "uuid"}
		partyID, _ := wsMsg.Payload.(map[string]interface{})["PartyID"].(string)
		if partyID == "" {
			return
		}

		// Verify user is host
		p, err := GetParty(partyID)
		if err != nil || p.HostID != c.UID {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Not authorized to view analytics",
				},
			})
			c.send <- errorMsg
			return
		}

		analytics, err := GetPartyAnalytics(partyID)
		if err != nil {
			log.Printf("GetPartyAnalytics Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed" + err.Error(),
				},
			})
			c.send <- errorMsg
			return
		}

		response, _ := json.Marshal(WSMessage{
			Event:   "PARTY_ANALYTICS",
			Payload: analytics,
		})
		c.send <- response

	case "UPDATE_PARTY_STATUS":
		// Payload: {"PartyID": "uuid", "Status": "LIVE|COMPLETED|CANCELLED"}
		var req struct {
			PartyID string `json:"PartyID"`
			Status  string `json:"Status"`
		}
		payloadBytes, _ := json.Marshal(wsMsg.Payload)
		json.Unmarshal(payloadBytes, &req)

		if req.PartyID == "" || req.Status == "" {
			return
		}

		// Verify user is host
		p, err := GetParty(req.PartyID)
		if err != nil || p.HostID != c.UID {
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Not authorized to update status",
				},
			})
			c.send <- errorMsg
			return
		}

		err = UpdatePartyStatus(req.PartyID, PartyStatus(req.Status))
		if err != nil {
			log.Printf("UpdatePartyStatus Error: %v", err)
			errorMsg, _ := json.Marshal(WSMessage{
				Event: "ERROR",
				Payload: map[string]string{
					"message": "Failed to update status",
				},
			})
			c.send <- errorMsg
			return
		}

		// Get updated party
		updated, _ := GetParty(req.PartyID)
		response, _ := json.Marshal(WSMessage{
			Event:   "PARTY_STATUS_UPDATED",
			Payload: updated,
		})
		c.send <- response

		// Broadcast status change to party room
		if updated.ChatRoomID != "" {
			c.hub.broadcast <- RoomEvent{RoomID: updated.ChatRoomID, Message: response}
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			// Add queued chat messages to the current websocket message to reduce overhead
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ServeWs handles websocket requests from the peer.
func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	// Extract UID from context or query parameter
	uid, ok := r.Context().Value("uid").(string)
	if !ok || uid == "" {
		// Fallback to query parameter for non-firebase auth
		uid = r.URL.Query().Get("uid")
	}

	if uid == "" {
		// For now, allow anonymous or handle as needed for Render deployment
		uid = "anonymous_" + time.Now().Format("150405")
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println(err)
		return
	}

	client := &Client{
		hub:  hub,
		conn: conn,
		send: make(chan []byte, 256), // Buffered to handle spikes
		UID:  uid,
	}
	client.hub.register <- client

	// Start goroutines for high-performance concurrent I/O
	go client.writePump()
	go client.readPump()
}

// ReverseGeocode uses Nominatim (OpenStreetMap) to convert coordinates to an address and city.
func ReverseGeocode(lat, lon float64) (string, string, error) {
	url := fmt.Sprintf("https://nominatim.openstreetmap.org/reverse?format=json&lat=%f&lon=%f", lat, lon)

	client := &http.Client{Timeout: 5 * time.Second}
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", "WaterParty-App") // Required by Nominatim policy

	resp, err := client.Do(req)
	if err != nil {
		return "", "", err
	}
	defer resp.Body.Close()

	var result struct {
		DisplayName string `json:"display_name"`
		Address     struct {
			City    string `json:"city"`
			Town    string `json:"town"`
			Village string `json:"village"`
			Suburb  string `json:"suburb"`
		} `json:"address"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", "", err
	}

	city := result.Address.City
	if city == "" {
		city = result.Address.Town
	}
	if city == "" {
		city = result.Address.Village
	}
	if city == "" {
		city = result.Address.Suburb
	}
	log.Printf("ReverseGeocode result: %s, %s", result.DisplayName, city)

	return result.DisplayName, city, nil
}
