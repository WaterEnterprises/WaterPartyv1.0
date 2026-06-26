import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'models.dart';
import 'constants.dart';

// ============================================
// WebSocket Event Constants
// ============================================

/// Client-to-Server WebSocket Events
class SocketEvents {
  SocketEvents._();

  // --- Authentication & User ---
  static const String getUser = 'GET_USER';
  static const String updateProfile = 'UPDATE_PROFILE';
  static const String deleteUser = 'DELETE_USER';

  // --- Geocoding ---
  static const String reverseGeocode = 'REVERSE_GEOCODE';

  // --- Party Management ---
  static const String createParty = 'CREATE_PARTY';
  static const String deleteParty = 'DELETE_PARTY';
  static const String getFeed = 'GET_FEED';
  static const String getMyParties = 'GET_MY_PARTIES';
  static const String getMatchedParties = 'GET_MATCHED_PARTIES';
  static const String getPartyDetails = 'GET_PARTY_DETAILS';
  static const String updateParty = 'UPDATE_PARTY';
  static const String updatePartyStatus = 'UPDATE_PARTY_STATUS';
  static const String getPartyAnalytics = 'GET_PARTY_ANALYTICS';

  // --- Swiping ---
  static const String swipe = 'SWIPE';
  static const String rejectParty = 'REJECT_PARTY';

  // --- Party Applications ---
  static const String applyToParty = 'APPLY_TO_PARTY';
  static const String cancelApplication = 'CANCEL_APPLICATION';
  static const String getPartyApplicants = 'GET_PARTY_APPLICANTS';
  static const String respondToApplication = 'UPDATE_APPLICATION';
  static const String leaveParty = 'LEAVE_PARTY';
  static const String getMatchedUsers = 'GET_MATCHED_USERS';
  static const String unmatchUser = 'UNMATCH_USER';

  // --- Chat & Messaging ---
  static const String getChats = 'GET_CHATS';
  static const String sendMessage = 'SEND_MESSAGE';
  static const String sendDM = 'SEND_DM';
  static const String joinRoom = 'JOIN_ROOM';
  static const String leaveRoom = 'LEAVE_ROOM';
  static const String getChatHistory = 'GET_CHAT_HISTORY';
  static const String deleteDMMessage = 'DELETE_DM_MESSAGE';

  // --- Direct Messages ---
  static const String getDMs = 'GET_DMS';
  static const String getDMMessages = 'GET_DM_MESSAGES';

  // --- Fundraising ---
  static const String addContribution = 'ADD_CONTRIBUTION';
  static const String getFundraiserState = 'GET_FUNDRAISER_STATE';

  // --- Notifications ---
  static const String getNotifications = 'GET_NOTIFICATIONS';
  static const String markNotificationRead = 'MARK_NOTIFICATION_READ';
  static const String markAllNotificationsRead = 'MARK_ALL_NOTIFICATIONS_READ';

  // --- User Management ---
  static const String searchUsers = 'SEARCH_USERS';
  static const String blockUser = 'BLOCK_USER';
  static const String unblockUser = 'UNBLOCK_USER';
  static const String getBlockedUsers = 'GET_BLOCKED_USERS';
  static const String reportUser = 'REPORT_USER';
  static const String reportParty = 'REPORT_PARTY';
}

/// Server-to-Client WebSocket Events (Responses)
class SocketServerEvents {
  SocketServerEvents._();

  // --- User & Profile ---
  static const String profileUpdated = 'PROFILE_UPDATED';
  static const String userDeleted = 'USER_DELETED';

  // --- Geocoding ---
  static const String geocodeResult = 'GEOCODE_RESULT';

  // --- Party Events ---
  static const String partyCreated = 'PARTY_CREATED';
  static const String partyDeleted = 'PARTY_DELETED';
  static const String deletePartyResponse = 'DELETE_PARTY_RESPONSE';
  static const String newParty = 'NEW_PARTY';
  static const String feedUpdate = 'FEED_UPDATE';
  static const String myParties = 'MY_PARTIES';
  static const String myPartiesResponse = 'MY_PARTIES_RESPONSE';
  static const String partyLocked = 'PARTY_LOCKED';
  static const String locationRevealed = 'LOCATION_REVEALED';
  static const String partyDetails = 'PARTY_DETAILS';
  static const String partyUpdated = 'PARTY_UPDATED';
  static const String partyStatusUpdated = 'PARTY_STATUS_UPDATED';
  static const String partyAnalytics = 'PARTY_ANALYTICS';

  // --- Party Applications ---
  static const String applicantsList = 'APPLICANTS_LIST';
  static const String applicationUpdated = 'APPLICATION_UPDATED';
  static const String applicationSubmitted = 'APPLICATION_SUBMITTED';
  static const String applicationRejected = 'APPLICATION_REJECTED';
  static const String partyLeft = 'PARTY_LEFT';
  static const String matchedUsers = 'MATCHED_USERS';
  static const String userUnmatched = 'USER_UNMATCHED';

  // --- Chat & Messaging ---
  static const String chatsList = 'CHATS_LIST';
  static const String newChatRoom = 'NEW_CHAT_ROOM';
  static const String newMessage = 'NEW_MESSAGE';
  static const String chatHistory = 'CHAT_HISTORY';

  // --- Direct Messages ---
  static const String dmsList = 'DMS_LIST';
  static const String dmMessages = 'DM_MESSAGES';
  static const String messageDeleted = 'MESSAGE_DELETED';

  // --- Fundraising ---
  static const String fundraiserUpdated = 'FUNDRAISER_UPDATED';
  static const String fundraiserState = 'FUNDRAISER_STATE';

  // --- Notifications ---
  static const String notificationsList = 'NOTIFICATIONS_LIST';
  static const String notificationMarkedRead = 'NOTIFICATION_MARKED_READ';
  static const String allNotificationsMarkedRead =
      'ALL_NOTIFICATIONS_MARKED_READ';

  // --- User Search & Management ---
  static const String usersSearchResults = 'USERS_SEARCH_RESULTS';
  static const String userBlocked = 'USER_BLOCKED';
  static const String userUnblocked = 'USER_UNBLOCKED';
  static const String blockedUsersList = 'BLOCKED_USERS_LIST';
  static const String userReported = 'USER_REPORTED';
  static const String partyReported = 'PARTY_REPORTED';

  // --- Errors ---
  static const String error = 'ERROR';
}

/// Swipe direction constants
class SwipeDirection {
  SwipeDirection._();

  static const String right = 'right';
  static const String left = 'left';
}

/// Message type constants
class MessageTypeStrings {
  MessageTypeStrings._();

  static const String text = 'text';
  static const String image = 'image';
  static const String video = 'video';
  static const String audio = 'audio';
  static const String system = 'system';
  static const String ai = 'ai';
  static const String payment = 'payment';
}

/// Special address markers
class SpecialAddress {
  SpecialAddress._();

  static const String myCurrentLocation = 'MY CURRENT LOCATION';
  static const String detectedOnPublish = 'DETECTED ON PUBLISH';
}

// ============================================
// Socket Service
// ============================================

class SocketService {
  static const String serverUrl = AppConstants.host;
  final Ref ref;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _shouldReconnect = true;

  // Public getter for connection status
  bool get isConnected => _isConnected;

  // Map of event names to completers for waiting on specific events
  final Map<String, Completer<void>> _pendingEvents = {};

  // Store validation errors for profile updates
  String? _lastProfileValidationError;

  SocketService(this.ref);

  void connect(String uid) {
    print('[SocketService] connect() called with uid: $uid');
    if (_isConnected) {
      print('[SocketService] Already connected, skipping');
      return;
    }
    _shouldReconnect = true;

    final uri = Uri.parse('ws://$serverUrl/ws?uid=$uid');
    print('[WebSocket] Connecting to: ws://$serverUrl/ws?uid=$uid');

    _channel = WebSocketChannel.connect(uri);
    _isConnected = true;

    _channel!.stream.listen(
      (data) {
        print('[WebSocket] Received data: $data');
        _handleIncomingMessage(data);
      },
      onDone: () {
        print('[WebSocket] Connection closed');
        if (_shouldReconnect) {
          print('[WebSocket] Attempting reconnect');
          _reconnect(uid);
        } else {
          print('[WebSocket] Reconnect skipped (intentional disconnect)');
        }
      },
      onError: (err) {
        print('[WebSocket] Connection error: $err');
        if (_shouldReconnect) {
          _reconnect(uid);
        } else {
          print('[WebSocket] Reconnect skipped (intentional disconnect)');
        }
      },
    );

    // Request all user data from server immediately after connection
    // Note: getUser is NOT called here - user data comes from login response
    // PROFILE_UPDATED should only fire when user edits their profile
    sendMessage(SocketEvents.getChats, {});
    sendMessage(SocketEvents.getMyParties, {});
    sendMessage(SocketEvents.getNotifications, {});
    sendMessage(SocketEvents.getMatchedUsers, {});
    sendMessage(SocketEvents.getBlockedUsers, {});
    sendMessage(SocketEvents.getDMs, {});
  }

  void _handleIncomingMessage(dynamic rawData) {
    print('[WebSocket] Raw message received: $rawData');
    final Map<String, dynamic> data = jsonDecode(rawData);

    final String event = data['Event'];
    final dynamic payload = data['Payload'];

    print('[WebSocket] Handling event: $event');

    // Complete any pending completer for this event
    if (_pendingEvents.containsKey(event)) {
      _pendingEvents[event]!.complete();
      _pendingEvents.remove(event);
    }

    switch (event) {
      case SocketServerEvents.profileUpdated:
        print('[WebSocket] Received PROFILE_UPDATED event');
        // Validate user structure from server
        _lastProfileValidationError = null;
        if (!_validateUserPayload(payload)) {
          _lastProfileValidationError =
              'Invalid profile data: photo URLs are invalid';
          print(
            '[WebSocket] PROFILE_UPDATED validation failed: invalid user structure',
          );
          // Complete the pending event even on validation failure so the UI can handle it
          if (_pendingEvents.containsKey(SocketServerEvents.profileUpdated)) {
            print(
              '[WebSocket] Completing PROFILE_UPDATED wait (validation failed)',
            );
            _pendingEvents[SocketServerEvents.profileUpdated]!.complete();
            _pendingEvents.remove(SocketServerEvents.profileUpdated);
          }
          break;
        }
        final user = User.fromMap(payload);
        print(
          '[WebSocket] PROFILE_UPDATED: UserID=${user.id}, Name=${user.realName}, Email=${user.email}',
        );
        ref.read(authProvider.notifier).updateUserProfile(user);
        print(
          '[WebSocket] PROFILE_UPDATED processed successfully, user profile updated',
        );
        break;
      case SocketServerEvents.chatsList:
        print('[WebSocket] CHATS_LIST received: $payload');
        if (payload == null) {
          print('[WebSocket] CHATS_LIST payload is null, setting empty list');
          ref.read(chatProvider.notifier).setRooms([]);
          break;
        }
        final List<dynamic> roomsRaw = payload;
        final rooms = roomsRaw.map((r) => ChatRoom.fromMap(r)).toList();
        print('[WebSocket] CHATS_LIST: Received ${rooms.length} rooms');
        for (final room in rooms) {
          print(
            '[WebSocket] CHATS_LIST: RoomID=${room.id}, Title=${room.title}, PartyID=${room.partyId}',
          );
        }
        ref.read(chatProvider.notifier).setRooms(rooms);
        print(
          '[WebSocket] CHATS_LIST: Stored ${rooms.length} rooms in provider',
        );
        break;
      case SocketServerEvents.newChatRoom:
        print('[WebSocket] Processing NEW_CHAT_ROOM: $payload');
        final room = ChatRoom.fromMap(payload);
        print(
          '[WebSocket] Parsed room: ${room.id}, partyId: ${room.partyId}, title: ${room.title}',
        );
        ref.read(chatProvider.notifier).addRoom(room);
        print('[WebSocket] Room added to provider');
        break;
      case SocketServerEvents.newMessage:
        final message = ChatMessage.fromMap(payload);
        ref.read(chatProvider.notifier).updateRoomWithNewMessage(message);
        break;
      case SocketServerEvents.newParty:
        final party = Party.fromMap(payload);
        ref.read(partyCacheProvider.notifier).updateParty(party);
        ref.read(partyFeedProvider.notifier).addParty(party);
        break;
      case SocketServerEvents.feedUpdate:
        print('[WebSocket] FEED_UPDATE payload: $payload');
        if (payload == null) {
          print('[WebSocket] FEED_UPDATE payload is null, skipping');
          break;
        }
        final List<dynamic> partiesRaw = payload;
        final parties = partiesRaw.map((p) => Party.fromMap(p)).toList();
        ref.read(partyCacheProvider.notifier).updateParties(parties);
        ref.read(partyFeedProvider.notifier).setParties(parties);
        break;
      case SocketServerEvents.partyLocked:
        // Logic for party locked
        break;
      case SocketServerEvents.locationRevealed:
        // Logic for location reveal
        break;
      case SocketServerEvents.applicantsList:
        print('[WebSocket] APPLICANTS_LIST received');
        print('[WebSocket] Payload type: ${payload.runtimeType}');

        final applicantsData = payload['Applicants'];
        if (applicantsData == null) {
          print('[WebSocket] Applicants is null, setting empty list');
          ref.read(partyApplicantsProvider.notifier).setApplicants([]);
          break;
        }

        print(
          '[WebSocket] Applicants count: ${(applicantsData as List).length}',
        );

        // Debug: Print first applicant structure if available
        if ((applicantsData).isNotEmpty) {
          final firstApp = applicantsData[0] as Map<String, dynamic>;
          print('[WebSocket] First applicant keys: ${firstApp.keys.toList()}');
          if (firstApp['User'] != null) {
            final userData = firstApp['User'] as Map<String, dynamic>;
            print(
              '[WebSocket] First applicant User keys: ${userData.keys.toList()}',
            );
            print('[WebSocket] First applicant User ID: ${userData['ID']}');
            print(
              '[WebSocket] First applicant ProfilePhotos: ${userData['ProfilePhotos']}',
            );
          }
        }

        final List<dynamic> appsRaw = applicantsData;
        final apps = appsRaw.map((a) {
          try {
            return PartyApplication.fromMap(a as Map<String, dynamic>);
          } catch (e, stackTrace) {
            print('[WebSocket] ERROR parsing PartyApplication: $e');
            print('[WebSocket] Stack trace: $stackTrace');
            print('[WebSocket] Problematic data: $a');
            // Return a placeholder to avoid crashing
            return PartyApplication(
              partyId: 'error',
              userId: 'error',
              status: ApplicantStatus.PENDING,
              appliedAt: DateTime.now(),
              user: null,
            );
          }
        }).toList();

        print('[WebSocket] Successfully parsed ${apps.length} applications');
        ref.read(partyApplicantsProvider.notifier).setApplicants(apps);
        break;
      case SocketServerEvents.applicationUpdated:
        final status = ApplicantStatus.values.firstWhere(
          (e) => e.toString().split('.').last == payload['Status'],
        );
        ref
            .read(partyApplicantsProvider.notifier)
            .updateStatus(payload['UserID'], status);
        break;
      case SocketServerEvents.partyCreated:
        print('[WebSocket] PARTY_CREATED raw payload: $payload');
        print(
          '[WebSocket] PARTY_CREATED payload keys: ${payload.keys.toList()}',
        );
        print('[WebSocket] PARTY_CREATED Title value: "${payload['Title']}"');
        final party = Party.fromMap(payload);
        print(
          '[WebSocket] Parsed party: id=${party.id}, title="${party.title}"',
        );
        ref.read(partyCacheProvider.notifier).updateParty(party);
        ref.read(partyFeedProvider.notifier).addParty(party);
        ref.read(myPartiesProvider.notifier).addParty(party);
        ref.read(partyCreationProvider.notifier).setSuccess(party.id);
        break;
      case SocketServerEvents.partyDeleted:
        print('[WebSocket] PARTY_DELETED payload: $payload');
        final partyId = payload['PartyID'] ?? payload['partyId'];
        final chatRoomId = payload['ChatRoomID'] ?? payload['chatRoomId'];
        print('[WebSocket] Removing party: $partyId, chatRoom: $chatRoomId');
        ref.read(partyCacheProvider.notifier).removeParty(partyId);
        ref.read(chatProvider.notifier).removeRoom(chatRoomId);
        ref.read(partyFeedProvider.notifier).removeParty(partyId);
        ref.read(myPartiesProvider.notifier).removeParty(partyId);
        // Set delete feedback to show SnackBar
        ref.read(deleteFeedbackProvider.notifier).setDeleted(partyId);
        print('[WebSocket] Party removed from providers');
        break;
      case SocketServerEvents.deletePartyResponse:
        print('[WebSocket] DELETE_PARTY_RESPONSE payload: $payload');
        final success = payload['success'] ?? payload['Success'] ?? true;
        if (success == true || success == 'true') {
          final partyId = payload['PartyID'] ?? payload['partyId'];
          final chatRoomId = payload['ChatRoomID'] ?? payload['chatRoomId'];
          ref.read(partyCacheProvider.notifier).removeParty(partyId);
          ref.read(chatProvider.notifier).removeRoom(chatRoomId);
          ref.read(partyFeedProvider.notifier).removeParty(partyId);
          ref.read(myPartiesProvider.notifier).removeParty(partyId);
          print('[WebSocket] Party deleted successfully');
        }
        break;
      case SocketServerEvents.error:
        final String message = payload['message'] ?? 'Unknown error';
        print('[WebSocket] ERROR received: $message');
        ref.read(partyCreationProvider.notifier).setError(message);
        break;
      case SocketServerEvents.myParties:
        print('[WebSocket] MY_PARTIES received: $payload');
        if (payload == null) {
          print('[WebSocket] MY_PARTIES payload is null, setting empty list');
          ref.read(myPartiesProvider.notifier).setParties([]);
          ref.read(partyCacheProvider.notifier).clear();
          break;
        }
        final List<dynamic> partiesRaw = payload as List<dynamic>;
        final parties = partiesRaw
            .map((p) => Party.fromMap(p as Map<String, dynamic>))
            .toList();
        print('[WebSocket] Parsed ${parties.length} my parties');
        // Update cache with all parties
        for (final party in parties) {
          print(
            '[WebSocket] My party: id=${party.id}, title=${party.title}, hostId=${party.hostId}',
          );
          ref.read(partyCacheProvider.notifier).updateParty(party);
        }
        // Update my parties provider
        ref.read(myPartiesProvider.notifier).setParties(parties);
        print(
          '[WebSocket] myPartiesProvider updated with ${parties.length} parties',
        );
        break;
      case SocketServerEvents.myPartiesResponse:
        // Alternative response format
        print('[WebSocket] MY_PARTIES_RESPONSE received: $payload');
        final List<dynamic> partiesRaw =
            payload['Parties'] ?? payload as List<dynamic>;
        final parties = partiesRaw
            .map((p) => Party.fromMap(p as Map<String, dynamic>))
            .toList();
        print('[WebSocket] Parsed ${parties.length} my parties from response');
        for (final party in parties) {
          print(
            '[WebSocket] My party: id=${party.id}, title=${party.title}, hostId=${party.hostId}',
          );
          ref.read(partyCacheProvider.notifier).updateParty(party);
        }
        ref.read(myPartiesProvider.notifier).setParties(parties);
        print(
          '[WebSocket] myPartiesProvider updated with ${parties.length} parties',
        );
        break;
      case SocketServerEvents.geocodeResult:
        print('[WebSocket] GEOCODE_RESULT received: $payload');
        // Extract address and city from the payload (server sends lowercase)
        final address =
            payload['address'] as String? ??
            payload['Address'] as String? ??
            '';
        final city =
            payload['city'] as String? ?? payload['City'] as String? ?? '';
        final lat =
            payload['lat'] as String? ?? payload['Lat'] as String? ?? '';
        final lon =
            payload['lon'] as String? ?? payload['Lon'] as String? ?? '';
        print(
          '[WebSocket] Geocode result - Address: $address, City: $city, Lat: $lat, Lon: $lon',
        );
        // Store the geocode result in a provider for the party screen to consume
        ref
            .read(geocodeResultProvider.notifier)
            .setGeocodeResult(
              GeocodeResult(address: address, city: city, lat: lat, lon: lon),
            );
        break;

      // ============================================
      // Party Details & Updates
      // ============================================

      case SocketServerEvents.partyDetails:
        print('[WebSocket] PARTY_DETAILS received: $payload');
        final party = Party.fromMap(payload);
        ref.read(partyCacheProvider.notifier).updateParty(party);
        break;

      case SocketServerEvents.partyUpdated:
        print('[WebSocket] PARTY_UPDATED received: $payload');
        final updatedParty = Party.fromMap(payload);
        ref.read(partyCacheProvider.notifier).updateParty(updatedParty);
        // Update in my parties if present, or add if it's a new party to the user
        final currentMyParties = ref.read(myPartiesProvider);
        if (currentMyParties.any((p) => p.id == updatedParty.id)) {
          ref.read(myPartiesProvider.notifier).addParty(updatedParty);
        }
        // Remove from feed as it's no longer available for swiping
        ref.read(partyFeedProvider.notifier).removeParty(updatedParty.id);
        break;

      case SocketServerEvents.partyStatusUpdated:
        print('[WebSocket] PARTY_STATUS_UPDATED received: $payload');
        final statusUpdatedParty = Party.fromMap(payload);
        ref.read(partyCacheProvider.notifier).updateParty(statusUpdatedParty);
        // Also update in my parties if present
        final currentMyParties = ref.read(myPartiesProvider);
        if (currentMyParties.any((p) => p.id == statusUpdatedParty.id)) {
          ref.read(myPartiesProvider.notifier).addParty(statusUpdatedParty);
        }
        break;

      case SocketServerEvents.partyAnalytics:
        print('[WebSocket] PARTY_ANALYTICS received: $payload');
        final analytics = PartyAnalytics.fromMap(payload);
        ref
            .read(partyAnalyticsProvider.notifier)
            .setAnalytics(analytics.partyId, analytics);
        break;

      // ============================================
      // Party Applications
      // ============================================

      case SocketServerEvents.applicationSubmitted:
        print('[WebSocket] APPLICATION_SUBMITTED received: $payload');
        final partyID = payload['PartyID'] as String? ?? '';
        final status = ApplicantStatus.values.firstWhere(
          (e) =>
              e.toString().split('.').last == (payload['Status'] ?? 'PENDING'),
          orElse: () => ApplicantStatus.PENDING,
        );
        // Update local state if needed
        print(
          '[WebSocket] Application submitted for party: $partyID, status: $status',
        );
        break;

      case SocketServerEvents.applicationRejected:
        print('[WebSocket] APPLICATION_REJECTED received: $payload');
        final rejectedPartyID = payload['PartyID'] as String? ?? '';
        print('[WebSocket] Application rejected for party: $rejectedPartyID');
        // Optionally remove from feed
        ref.read(partyFeedProvider.notifier).removeParty(rejectedPartyID);
        break;

      case SocketServerEvents.partyLeft:
        print('[WebSocket] PARTY_LEFT received: $payload');
        final leftPartyID = payload['PartyID'] as String? ?? '';
        ref.read(myPartiesProvider.notifier).removeParty(leftPartyID);
        print('[WebSocket] Left party: $leftPartyID');
        break;

      case SocketServerEvents.matchedUsers:
        print('[WebSocket] MATCHED_USERS received: $payload');
        final List<dynamic> usersRaw = payload as List<dynamic>;
        final matchedUsers = usersRaw
            .map((u) => MatchedUser.fromMap(u as Map<String, dynamic>))
            .toList();
        ref.read(matchedUsersProvider.notifier).setMatchedUsers(matchedUsers);
        print('[WebSocket] Parsed ${matchedUsers.length} matched users');
        break;

      case SocketServerEvents.userUnmatched:
        print('[WebSocket] USER_UNMATCHED received: $payload');
        final unmatchedPartyID = payload['PartyID'] as String? ?? '';
        final unmatchedUserID = payload['UserID'] as String? ?? '';
        ref.read(matchedUsersProvider.notifier).removeUser(unmatchedUserID);
        print(
          '[WebSocket] User $unmatchedUserID unmatched from party $unmatchedPartyID',
        );
        break;

      // ============================================
      // Chat History
      // ============================================

      case SocketServerEvents.chatHistory:
        print('[WebSocket] CHAT_HISTORY received: $payload');
        final List<dynamic> messagesRaw = payload as List<dynamic>;
        final messages = messagesRaw
            .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
            .toList();
        if (messages.isNotEmpty) {
          final chatID = messages.first.chatId;
          ref.read(chatHistoryProvider.notifier).setMessages(chatID, messages);
          print(
            '[WebSocket] Parsed ${messages.length} chat history messages for chat: $chatID',
          );
        }
        break;

      // ============================================
      // Direct Messages
      // ============================================

      case SocketServerEvents.dmsList:
        print('[WebSocket] DMS_LIST received: $payload');
        if (payload == null) {
          print('[WebSocket] DMS_LIST payload is null, setting empty list');
          ref.read(dmConversationsProvider.notifier).setConversations([]);
          break;
        }
        final List<dynamic> dmsRaw = payload as List<dynamic>;
        final dmConversations = dmsRaw
            .map((d) => DMConversation.fromMap(d as Map<String, dynamic>))
            .toList();
        ref
            .read(dmConversationsProvider.notifier)
            .setConversations(dmConversations);
        print('[WebSocket] Parsed ${dmConversations.length} DM conversations');
        break;

      case SocketServerEvents.dmMessages:
        print('[WebSocket] DM_MESSAGES received: $payload');
        final List<dynamic> dmMessagesRaw = payload as List<dynamic>;
        final dmMessages = dmMessagesRaw
            .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
            .toList();
        if (dmMessages.isNotEmpty) {
          // Use the other user's ID as key
          final otherUserID = dmMessages.first.senderId;
          ref
              .read(dmHistoryProvider.notifier)
              .setMessages(otherUserID, dmMessages);
          print('[WebSocket] Parsed ${dmMessages.length} DM messages');
        }
        break;

      case SocketServerEvents.messageDeleted:
        print('[WebSocket] MESSAGE_DELETED received: $payload');
        final deletedMessageID = payload['MessageID'] as String? ?? '';
        print('[WebSocket] Message deleted: $deletedMessageID');
        // Remove from local chat history if present
        for (final entry in ref.read(chatHistoryProvider).entries.toList()) {
          ref
              .read(chatHistoryProvider.notifier)
              .removeMessage(entry.key, deletedMessageID);
        }
        break;

      // ============================================
      // Fundraising
      // ============================================

      case SocketServerEvents.fundraiserUpdated:
        print('[WebSocket] FUNDRAISER_UPDATED received: $payload');
        final partyID = payload['PartyID'] as String? ?? '';
        // Update party with new crowdfunding state
        if (partyID.isNotEmpty && payload['RotationPool'] != null) {
          final crowdfunding = Crowdfunding.fromMap(payload['RotationPool']);
          final cachedParty = ref.read(partyCacheProvider)[partyID];
          if (cachedParty != null) {
            ref
                .read(partyCacheProvider.notifier)
                .updateParty(
                  Party(
                    id: cachedParty.id,
                    hostId: cachedParty.hostId,
                    title: cachedParty.title,
                    description: cachedParty.description,
                    partyPhotos: cachedParty.partyPhotos,
                    startTime: cachedParty.startTime,
                    durationHours: cachedParty.durationHours,
                    status: cachedParty.status,
                    isLocationRevealed: cachedParty.isLocationRevealed,
                    address: cachedParty.address,
                    city: cachedParty.city,
                    geoLat: cachedParty.geoLat,
                    geoLon: cachedParty.geoLon,
                    maxCapacity: cachedParty.maxCapacity,
                    currentGuestCount: cachedParty.currentGuestCount,
                    autoLockOnFull: cachedParty.autoLockOnFull,
                    vibeTags: cachedParty.vibeTags,
                    rules: cachedParty.rules,
                    rotationPool: crowdfunding,
                    chatRoomId: cachedParty.chatRoomId,
                    createdAt: cachedParty.createdAt,
                    updatedAt: cachedParty.updatedAt,
                    thumbnail: cachedParty.thumbnail,
                  ),
                );
          }
        }
        print('[WebSocket] Fundraiser updated for party: $partyID');
        break;

      case SocketServerEvents.fundraiserState:
        print('[WebSocket] FUNDRAISER_STATE received: $payload');
        // Similar to fundraiserUpdated but for initial fetch
        final fundraiserPartyID = payload['PartyID'] as String? ?? '';
        print('[WebSocket] Fundraiser state for party: $fundraiserPartyID');
        break;

      // ============================================
      // Notifications
      // ============================================

      case SocketServerEvents.notificationsList:
        print('[WebSocket] NOTIFICATIONS_LIST received: $payload');
        if (payload == null) {
          print(
            '[WebSocket] NOTIFICATIONS_LIST payload is null, setting empty list',
          );
          ref.read(notificationsProvider.notifier).setNotifications([]);
          break;
        }
        final List<dynamic> notificationsRaw = payload as List<dynamic>;
        final notifications = notificationsRaw
            .map((n) => Notification.fromMap(n as Map<String, dynamic>))
            .toList();
        ref
            .read(notificationsProvider.notifier)
            .setNotifications(notifications);
        print('[WebSocket] Parsed ${notifications.length} notifications');
        break;

      case SocketServerEvents.notificationMarkedRead:
        print('[WebSocket] NOTIFICATION_MARKED_READ received: $payload');
        final notificationID = payload['NotificationID'] as String? ?? '';
        ref.read(notificationsProvider.notifier).markAsRead(notificationID);
        print('[WebSocket] Notification marked as read: $notificationID');
        break;

      case SocketServerEvents.allNotificationsMarkedRead:
        print('[WebSocket] ALL_NOTIFICATIONS_MARKED_READ received: $payload');
        ref.read(notificationsProvider.notifier).markAllAsRead();
        print('[WebSocket] All notifications marked as read');
        break;

      // ============================================
      // User Search & Management
      // ============================================

      case SocketServerEvents.usersSearchResults:
        print('[WebSocket] USERS_SEARCH_RESULTS received: $payload');
        final List<dynamic> usersRaw = payload as List<dynamic>;
        final users = usersRaw
            .map((u) => User.fromMap(u as Map<String, dynamic>))
            .toList();
        ref.read(userSearchProvider.notifier).setResults(users);
        print('[WebSocket] Parsed ${users.length} search results');
        break;

      case SocketServerEvents.userBlocked:
        print('[WebSocket] USER_BLOCKED received: $payload');
        final blockedUserID = payload['UserID'] as String? ?? '';
        ref.read(blockedUsersProvider.notifier).addBlockedUser(blockedUserID);
        print('[WebSocket] User blocked: $blockedUserID');
        break;

      case SocketServerEvents.userUnblocked:
        print('[WebSocket] USER_UNBLOCKED received: $payload');
        final unblockedUserID = payload['UserID'] as String? ?? '';
        ref
            .read(blockedUsersProvider.notifier)
            .removeBlockedUser(unblockedUserID);
        print('[WebSocket] User unblocked: $unblockedUserID');
        break;

      case SocketServerEvents.blockedUsersList:
        print('[WebSocket] BLOCKED_USERS_LIST received: $payload');
        if (payload == null) {
          print(
            '[WebSocket] BLOCKED_USERS_LIST payload is null, setting empty list',
          );
          ref.read(blockedUsersProvider.notifier).setBlockedUsers([]);
          break;
        }
        final List<dynamic> blockedIDs = payload as List<dynamic>;
        final blockedUserIds = blockedIDs.map((id) => id.toString()).toList();
        ref.read(blockedUsersProvider.notifier).setBlockedUsers(blockedUserIds);
        print('[WebSocket] Parsed ${blockedUserIds.length} blocked users');
        break;

      case SocketServerEvents.userReported:
        print('[WebSocket] USER_REPORTED received: $payload');
        final reportedUserID = payload['UserID'] as String? ?? '';
        print('[WebSocket] User reported: $reportedUserID');
        break;

      case SocketServerEvents.partyReported:
        print('[WebSocket] PARTY_REPORTED received: $payload');
        final reportedPartyID = payload['PartyID'] as String? ?? '';
        print('[WebSocket] Party reported: $reportedPartyID');
        break;

      case SocketServerEvents.userDeleted:
        print('[WebSocket] USER_DELETED received: $payload');
        final deletedUserID = payload['UserID'] as String? ?? '';
        print('[WebSocket] User deleted: $deletedUserID');
        // Trigger logout
        ref.read(authProvider.notifier).logout();
        break;

      default:
        print('[WebSocket] Unhandled event: $event');
    }
  }

  // Send message to Go Backend
  void sendMessage(String event, dynamic payload) {
    print('[WebSocket] Sending message: $event with payload: $payload');
    if (_channel != null) {
      final user = ref.read(authProvider).value;
      final msg = jsonEncode({
        'Event': event,
        'Payload': payload,
        'Token': user?.id ?? 'anonymous',
      });
      _channel!.sink.add(msg);
    }
  }

  /// Wait for a specific WebSocket event to be received.
  /// Returns a Future that completes when the event is received.
  Future<void> waitForEvent(String eventName) {
    print('[WebSocket] waitForEvent: Starting to wait for $eventName');
    final completer = Completer<void>();
    _pendingEvents[eventName] = completer;
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        print('[WebSocket] waitForEvent: TIMEOUT waiting for $eventName');
        _pendingEvents.remove(eventName);
        throw Exception('Timeout waiting for $eventName');
      },
    );
  }

  /// Get the last profile validation error if any
  String? getLastProfileValidationError() {
    return _lastProfileValidationError;
  }

  /// Clear the last profile validation error
  void clearLastProfileValidationError() {
    _lastProfileValidationError = null;
  }

  /// Validate user payload from server
  /// Checks that profilePhotos and thumbnail are valid URLs or base64
  /// Validates that thumbnail corresponds to one of the profile photos if both exist
  bool _validateUserPayload(Map<String, dynamic> payload) {
    final profilePhotos = payload['ProfilePhotos'] ?? payload['profile_photos'];
    final thumbnail = payload['Thumbnail'] ?? payload['thumbnail'];

    // Validate profilePhotos - must be a list of strings
    if (profilePhotos != null) {
      if (profilePhotos is! List) {
        print('[Validation] profilePhotos is not a list');
        return false;
      }

      for (final photo in profilePhotos) {
        if (photo is! String) {
          print('[Validation] profilePhotos contains non-string value');
          return false;
        }
        if (!_isValidUrlOrBase64(photo)) {
          print(
            '[Validation] profilePhotos contains invalid URL or base64: $photo',
          );
          return false;
        }
      }
    }

    // Validate thumbnail - must be a valid URL or base64 if not empty
    if (thumbnail != null && thumbnail is! String) {
      print('[Validation] thumbnail is not a string');
      return false;
    }

    if (thumbnail != null && thumbnail.isNotEmpty) {
      if (!_isValidUrlOrBase64(thumbnail)) {
        print('[Validation] thumbnail is invalid URL or base64: $thumbnail');
        return false;
      }

      // Validate that thumbnail corresponds to one of the profile photos if both exist
      if (profilePhotos != null && profilePhotos.isNotEmpty) {
        bool thumbnailFound = profilePhotos.contains(thumbnail);
        if (!thumbnailFound) {
          // Also check if thumbnail could be a variation (e.g., same hash but different path)
          // For now, just check exact match
          print('[Validation] thumbnail does not match any profile photo');
          // We'll still allow this but log a warning - the server might use different URL format
        }
      }
    }

    return true;
  }

  /// Check if a string is a valid URL or base64
  bool _isValidUrlOrBase64(String value) {
    // Check if it's a valid URL
    if (value.startsWith('http://') || value.startsWith('https://')) {
      try {
        final uri = Uri.parse(value);
        return uri.hasScheme && uri.host.isNotEmpty;
      } catch (e) {
        return false;
      }
    }

    // Check if it's base64 (simple check - must be at least 4 chars and only valid base64 chars)
    if (value.length >= 4) {
      // Simple base64 validation - check if all chars are valid base64 characters
      // Base64 uses A-Z, a-z, 0-9, +, / and = for padding
      final base64Chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
      bool isBase64 = value.split('').every((c) => base64Chars.contains(c));
      if (isBase64 && value.length % 4 == 0) {
        return true;
      }
    }

    return false;
  }

  /// REVERSE_GEOCODE: Convert latitude and longitude coordinates to city and address
  void reverseGeocode(double lat, double lon) {
    sendMessage(SocketEvents.reverseGeocode, {'Lat': lat, 'Lon': lon});
  }

  /// CREATE_PARTY: Create a new party event using DraftParty model
  void createPartyFromDraft(DraftParty draft, String chatRoomID) {
    sendMessage(SocketEvents.createParty, {
      'Title': draft.title,
      'Description': draft.description,
      'StartTime':
          draft.date?.toUtc().toIso8601String() ??
          DateTime.now()
              .add(const Duration(hours: 24))
              .toUtc()
              .toIso8601String(),
      'DurationHours': draft.durationHours,
      'Address': draft.address,
      'City': draft.city,
      'MaxCapacity': draft.capacity.toInt(),
      'PartyPhotos': draft.photos,
      'VibeTags': draft.selectedTags,
      'GeoLat': draft.geoLat ?? 0.0,
      'GeoLon': draft.geoLon ?? 0.0,
      'ChatRoomID': chatRoomID,
    });
  }

  /// CREATE_PARTY: Create a new party event (explicit parameters)
  void createParty({
    required String title,
    required String description,
    required String startTime,
    required int durationHours,
    required String address,
    required String city,
    required int maxCapacity,
    List<String>? partyPhotos,
    List<String>? vibeTags,
    required double geoLat,
    required double geoLon,
    required String chatRoomID,
  }) {
    sendMessage(SocketEvents.createParty, {
      'Title': title,
      'Description': description,
      'StartTime': startTime,
      'DurationHours': durationHours,
      'Address': address,
      'City': city,
      'MaxCapacity': maxCapacity,
      'PartyPhotos': partyPhotos ?? [],
      'VibeTags': vibeTags ?? [],
      'GeoLat': geoLat,
      'GeoLon': geoLon,
      'ChatRoomID': chatRoomID,
    });
  }

  /// SEND_MESSAGE: Send a chat message to a party room
  void sendChatMessage({
    required String chatID,
    required String content,
    String type = MessageTypeStrings.text,
  }) {
    sendMessage(SocketEvents.sendMessage, {
      'ChatID': chatID,
      'Content': content,
      'Type': type,
    });
  }

  /// SEND_DM: Send a direct message to another user
  void sendDM({required String recipientID, required String content}) {
    sendMessage(SocketEvents.sendDM, {
      'RecipientID': recipientID,
      'Content': content,
    });
  }

  /// JOIN_ROOM: Join a chat room
  void joinRoom(String roomID) {
    sendMessage(SocketEvents.joinRoom, {'RoomID': roomID});
  }

  /// LEAVE_ROOM: Leave a chat room
  void leaveRoom(String roomID) {
    sendMessage(SocketEvents.leaveRoom, {'RoomID': roomID});
  }

  /// GET_CHATS: Get all chat rooms for the current user
  void getChats() {
    sendMessage(SocketEvents.getChats, {});
  }

  /// GET_MY_PARTIES: Get parties created by the current user
  void getMyParties() {
    sendMessage(SocketEvents.getMyParties, {});
  }

  /// GET_MATCHED_PARTIES: Get parties matched to the current user
  void getMatchedParties() {
    sendMessage(SocketEvents.getMatchedParties, {});
  }

  /// UPDATE_PROFILE: Update the current user's profile using User model
  void updateProfileFromUser(User user) {
    sendMessage(SocketEvents.updateProfile, {
      'RealName': user.realName,
      'Bio': user.bio,
      'Thumbnail': user.thumbnail,
    });
  }

  /// UPDATE_PROFILE: Update the current user's profile (explicit parameters)
  void updateProfile({String? realName, String? bio, String? thumbnail}) {
    final Map<String, dynamic> payload = {};
    if (realName != null) payload['RealName'] = realName;
    if (bio != null) payload['Bio'] = bio;
    if (thumbnail != null) payload['Thumbnail'] = thumbnail;
    sendMessage(SocketEvents.updateProfile, payload);
  }

  /// GET_USER: Get the current user's profile
  void getUser() {
    sendMessage(SocketEvents.getUser, {});
  }

  /// SWIPE: Swipe on a party (like or pass)
  /// Direction should be SwipeDirection.right for like, SwipeDirection.left for pass
  void swipe({required String partyID, required String direction}) {
    sendMessage(SocketEvents.swipe, {
      'PartyID': partyID,
      'Direction': direction,
    });
  }

  /// LIKE_PARTY: Swipe right on a party (like)
  void likeParty(String partyID) {
    swipe(partyID: partyID, direction: SwipeDirection.right);
  }

  /// PASS_PARTY: Swipe left on a party (pass)
  void passParty(String partyID) {
    swipe(partyID: partyID, direction: SwipeDirection.left);
  }

  /// GET_FEED: Get a feed of nearby parties
  void getFeed({
    required double lat,
    required double lon,
    double radiusKm = 50,
  }) {
    sendMessage(SocketEvents.getFeed, {
      'Lat': lat,
      'Lon': lon,
      'RadiusKm': radiusKm,
    });
  }

  /// DELETE_PARTY: Delete a party (host only)
  void deleteParty({required String partyID, required String chatRoomID}) {
    sendMessage(SocketEvents.deleteParty, {
      'PartyID': partyID,
      'ChatRoomID': chatRoomID,
    });
  }

  /// GET_PARTY_APPLICANTS: Get list of applicants for a party (host only)
  void getPartyApplicants(String partyID) {
    sendMessage(SocketEvents.getPartyApplicants, {'PartyID': partyID});
  }

  /// RESPOND_TO_APPLICATION: Accept or reject a party application (host only)
  void respondToApplication({
    required String userID,
    required String partyID,
    required bool accept,
  }) {
    sendMessage(SocketEvents.respondToApplication, {
      'UserID': userID,
      'PartyID': partyID,
      'Accept': accept,
    });
  }

  /// ACCEPT_APPLICATION: Accept a party application (convenience method)
  void acceptApplication({required String userID, required String partyID}) {
    respondToApplication(userID: userID, partyID: partyID, accept: true);
  }

  /// REJECT_APPLICATION: Reject a party application (convenience method)
  void rejectApplication({required String userID, required String partyID}) {
    respondToApplication(userID: userID, partyID: partyID, accept: false);
  }

  /// APPLY_TO_PARTY: Apply to join a party
  void applyToParty({required String partyID, String? message}) {
    sendMessage(SocketEvents.applyToParty, {
      'PartyID': partyID,
      'Message': message ?? '',
    });
  }

  /// CANCEL_APPLICATION: Cancel a pending party application
  void cancelApplication(String partyID) {
    sendMessage(SocketEvents.cancelApplication, {'PartyID': partyID});
  }

  /// LEAVE_PARTY: Leave a party (for non-hosts)
  void leaveParty(String partyID) {
    sendMessage(SocketEvents.leaveParty, {'PartyID': partyID});
  }

  // ============================================
  // Party Details & Updates
  // ============================================

  /// GET_PARTY_DETAILS: Get detailed information about a party
  void getPartyDetails(String partyID) {
    sendMessage(SocketEvents.getPartyDetails, {'PartyID': partyID});
  }

  /// UPDATE_PARTY: Update an existing party (host only)
  void updateParty({
    required String id,
    String? title,
    String? description,
    String? startTime,
    int? durationHours,
    String? address,
    String? city,
    int? maxCapacity,
    List<String>? partyPhotos,
    List<String>? vibeTags,
    List<String>? rules,
    double? geoLat,
    double? geoLon,
    bool? autoLockOnFull,
    bool? isLocationRevealed,
    String? thumbnail,
  }) {
    final Map<String, dynamic> payload = {'ID': id};
    if (title != null) payload['Title'] = title;
    if (description != null) payload['Description'] = description;
    if (startTime != null) payload['StartTime'] = startTime;
    if (durationHours != null) payload['DurationHours'] = durationHours;
    if (address != null) payload['Address'] = address;
    if (city != null) payload['City'] = city;
    if (maxCapacity != null) payload['MaxCapacity'] = maxCapacity;
    if (partyPhotos != null) payload['PartyPhotos'] = partyPhotos;
    if (vibeTags != null) payload['VibeTags'] = vibeTags;
    if (rules != null) payload['Rules'] = rules;
    if (geoLat != null) payload['GeoLat'] = geoLat;
    if (geoLon != null) payload['GeoLon'] = geoLon;
    if (autoLockOnFull != null) payload['AutoLockOnFull'] = autoLockOnFull;
    if (isLocationRevealed != null) {
      payload['IsLocationRevealed'] = isLocationRevealed;
    }
    if (thumbnail != null) payload['Thumbnail'] = thumbnail;
    sendMessage(SocketEvents.updateParty, payload);
  }

  /// UPDATE_PARTY_STATUS: Update party status (host only)
  void updatePartyStatus({required String partyID, required String status}) {
    sendMessage(SocketEvents.updatePartyStatus, {
      'PartyID': partyID,
      'Status': status,
    });
  }

  /// GET_PARTY_ANALYTICS: Get analytics for a party (host only)
  void getPartyAnalytics(String partyID) {
    sendMessage(SocketEvents.getPartyAnalytics, {'PartyID': partyID});
  }

  // ============================================
  // Matched Users
  // ============================================

  /// GET_MATCHED_USERS: Get list of matched users for a party (host only)
  void getMatchedUsers(String partyID) {
    sendMessage(SocketEvents.getMatchedUsers, {'PartyID': partyID});
  }

  /// UNMATCH_USER: Remove a matched user from a party (host only)
  void unmatchUser({required String partyID, required String userID}) {
    sendMessage(SocketEvents.unmatchUser, {
      'PartyID': partyID,
      'UserID': userID,
    });
  }

  // ============================================
  // Chat History
  // ============================================

  /// GET_CHAT_HISTORY: Get chat history for a party room
  void getChatHistory({required String chatID, int limit = 50}) {
    sendMessage(SocketEvents.getChatHistory, {
      'ChatID': chatID,
      'Limit': limit,
    });
  }

  /// DELETE_DM_MESSAGE: Delete a direct message
  void deleteDMMessage(String messageID) {
    sendMessage(SocketEvents.deleteDMMessage, {'MessageID': messageID});
  }

  // ============================================
  // Direct Messages
  // ============================================

  /// GET_DMS: Get all direct message conversations
  void getDMs() {
    sendMessage(SocketEvents.getDMs, {});
  }

  /// GET_DM_MESSAGES: Get DM history with another user
  void getDMMessages({required String otherUserID, int limit = 50}) {
    sendMessage(SocketEvents.getDMMessages, {
      'OtherUserID': otherUserID,
      'Limit': limit,
    });
  }

  // ============================================
  // Fundraising
  // ============================================

  /// ADD_CONTRIBUTION: Add a monetary contribution to a party's fundraiser
  void addContribution({required String partyID, required double amount}) {
    sendMessage(SocketEvents.addContribution, {
      'PartyID': partyID,
      'Amount': amount,
    });
  }

  /// GET_FUNDRAISER_STATE: Get the current state of a party's fundraiser
  void getFundraiserState(String partyID) {
    sendMessage(SocketEvents.getFundraiserState, {'PartyID': partyID});
  }

  // ============================================
  // Notifications
  // ============================================

  /// GET_NOTIFICATIONS: Get notifications for the current user
  void getNotifications() {
    sendMessage(SocketEvents.getNotifications, {});
  }

  /// MARK_NOTIFICATION_READ: Mark a notification as read
  void markNotificationRead(String notificationID) {
    sendMessage(SocketEvents.markNotificationRead, {
      'NotificationID': notificationID,
    });
  }

  /// MARK_ALL_NOTIFICATIONS_READ: Mark all notifications as read
  void markAllNotificationsRead() {
    sendMessage(SocketEvents.markAllNotificationsRead, {});
  }

  // ============================================
  // User Search & Management
  // ============================================

  /// SEARCH_USERS: Search for users by name
  void searchUsers({required String query, int limit = 20}) {
    sendMessage(SocketEvents.searchUsers, {'Query': query, 'Limit': limit});
  }

  /// BLOCK_USER: Block a user
  void blockUser(String userID) {
    sendMessage(SocketEvents.blockUser, {'UserID': userID});
  }

  /// UNBLOCK_USER: Unblock a user
  void unblockUser(String userID) {
    sendMessage(SocketEvents.unblockUser, {'UserID': userID});
  }

  /// GET_BLOCKED_USERS: Get list of blocked user IDs
  void getBlockedUsers() {
    sendMessage(SocketEvents.getBlockedUsers, {});
  }

  /// REPORT_USER: Report a user for violations
  void reportUser({
    required String userID,
    required String reason,
    String? details,
  }) {
    sendMessage(SocketEvents.reportUser, {
      'UserID': userID,
      'Reason': reason,
      'Details': details ?? '',
    });
  }

  /// REPORT_PARTY: Report a party for violations
  void reportParty({
    required String partyID,
    required String reason,
    String? details,
  }) {
    sendMessage(SocketEvents.reportParty, {
      'PartyID': partyID,
      'Reason': reason,
      'Details': details ?? '',
    });
  }

  /// DELETE_USER: Delete the current user's account
  void deleteUser(String userID) {
    sendMessage(SocketEvents.deleteUser, {'UserID': userID});
  }

  /// REJECT_PARTY: Reject/ignore a party
  void rejectParty(String partyID) {
    sendMessage(SocketEvents.rejectParty, {'PartyID': partyID});
  }

  // ============================================
  // End of Full WebSocket API Implementation
  // ============================================

  void _reconnect(String token) {
    _isConnected = false;
    Future.delayed(const Duration(seconds: 3), () => connect(token));
  }

  void disconnect() {
    _shouldReconnect = false;
    _channel?.sink.close();
    _isConnected = false;
    print('[SocketService] Disconnected (reconnect disabled)');
  }
}

// Provider to access the socket anywhere
final socketServiceProvider = Provider((ref) => SocketService(ref));
