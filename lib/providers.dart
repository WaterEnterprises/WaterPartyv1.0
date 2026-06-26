import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'constants.dart';
import 'api.dart';

// ============================================
// AUTHENTICATION SYSTEM - Only SharedPreferences usage
// ============================================

class AuthNotifier extends AsyncNotifier<User?> {
  static const String apiBase = AppConstants.apiBase;
  static const String _sessionKey = 'auth_user_session';

  @override
  Future<User?> build() async {
    try {
      return await _loadSession();
    } catch (e, st) {
      debugPrint('[AuthNotifier] Build error: $e');
      debugPrint('[AuthNotifier] Stack trace: $st');
      // Return null to show auth screen on error
      return null;
    }
  }

  Future<User?> _loadSession() async {
    // Only SharedPreferences usage: auth session
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_sessionKey);

    if (userJson != null) {
      try {
        final cachedUser = User.fromMap(jsonDecode(userJson));
        // Trigger background refresh from server
        Future.microtask(() => refreshProfile(cachedUser.id));
        return cachedUser;
      } catch (e) {
        // Invalid cached data, clear it
        debugPrint('[AuthNotifier] Invalid session data: $e');
        await prefs.remove(_sessionKey);
      }
    }
    return null;
  }

  Future<void> refreshProfile(String id) async {
    try {
      final response = await http.get(Uri.parse("$apiBase/profile?id=$id"));
      if (response.statusCode == 200) {
        final serverUser = User.fromMap(jsonDecode(response.body));
        state = AsyncValue.data(serverUser);
        await _saveSession(serverUser);
      }
    } catch (e) {
      debugPrint("Profile refresh failed: $e");
    }
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(user.toMap()));
  }

  Future<void> register(User user, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$apiBase/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"password": password, "user": user.toMap()}),
      );

      if (response.statusCode == 200) {
        final loggedInUser = User.fromMap(jsonDecode(response.body));
        state = AsyncValue.data(loggedInUser);
        await _saveSession(loggedInUser);
      } else {
        String errorMsg = "Registration failed";
        try {
          if (response.headers['content-type']?.contains('application/json') ??
              false) {
            final error = jsonDecode(response.body);
            errorMsg = error['error'] ?? errorMsg;
          } else {
            errorMsg = response.body;
          }
        } catch (_) {
          errorMsg = "Server error (${response.statusCode})";
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      debugPrint('[AuthNotifier] Login: Calling $apiBase/login');
      debugPrint('[AuthNotifier] Login: Email=$email');

      final response = await http.post(
        Uri.parse("$apiBase/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      debugPrint(
        '[AuthNotifier] Login: Response status=${response.statusCode}',
      );
      debugPrint('[AuthNotifier] Login: Response body=${response.body}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        debugPrint('[AuthNotifier] Login: Parsed JSON=$responseBody');
        final loggedInUser = User.fromMap(responseBody);
        debugPrint('[AuthNotifier] Login: User parsed successfully');
        debugPrint('[AuthNotifier] Login: User ID=${loggedInUser.id}');
        debugPrint('[AuthNotifier] Login: User Name=${loggedInUser.realName}');
        debugPrint('[AuthNotifier] Login: User Email=${loggedInUser.email}');
        debugPrint(
          '[AuthNotifier] Login: User Photos=${loggedInUser.profilePhotos.length}',
        );
        debugPrint(
          '[AuthNotifier] Login: User Verified=${loggedInUser.isVerified}',
        );
        state = AsyncValue.data(loggedInUser);
        await _saveSession(loggedInUser);
        debugPrint('[AuthNotifier] Login: Session saved');
      } else {
        String errorMsg = "Invalid credentials";
        try {
          if (response.headers['content-type']?.contains('application/json') ??
              false) {
            final error = jsonDecode(response.body);
            errorMsg = error['error'] ?? errorMsg;
          } else {
            errorMsg = response.body;
          }
        } catch (_) {
          errorMsg = "Login failed (${response.statusCode})";
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('[AuthNotifier] Login: ERROR=$e');
      rethrow;
    }
  }

  void _clearAllProviders() {
    debugPrint('[AuthNotifier] Clearing all providers');
    try {
      ref.read(myPartiesProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing myParties: $e');
    }
    try {
      ref.read(chatProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing chat: $e');
    }
    try {
      ref.read(chatHistoryProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing chatHistory: $e');
    }
    try {
      ref.read(dmHistoryProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing dmHistory: $e');
    }
    try {
      ref.read(dmConversationsProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing dmConversations: $e');
    }
    try {
      ref.read(notificationsProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing notifications: $e');
    }
    try {
      ref.read(partyFeedProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing partyFeed: $e');
    }
    try {
      ref.read(partiesAroundProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing partiesAround: $e');
    }
    try {
      ref.read(matchedUsersProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing matchedUsers: $e');
    }
    try {
      ref.read(blockedUsersProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing blockedUsers: $e');
    }
    try {
      ref.read(partyCacheProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing partyCache: $e');
    }
    try {
      ref.read(draftPartyProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing draftParty: $e');
    }
    try {
      ref.read(partyApplicantsProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing partyApplicants: $e');
    }
    try {
      ref.read(partyAnalyticsProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing partyAnalytics: $e');
    }
    try {
      ref.read(userSearchProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing userSearch: $e');
    }
    try {
      ref.read(deleteFeedbackProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing deleteFeedback: $e');
    }
    try {
      ref.read(geocodeResultProvider.notifier).clear();
    } catch (e) {
      debugPrint('[clearProviders] Error clearing geocodeResult: $e');
    }
    try {
      ref.read(navIndexProvider.notifier).setIndex(0);
    } catch (e) {
      debugPrint('[clearProviders] Error resetting navIndex: $e');
    }
    debugPrint('[AuthNotifier] All providers cleared');
  }

  Future<void> logout() async {
    debugPrint('[logout] Starting logout process');

    // Disconnect WebSocket first to prevent "Already connected" on next login
    ref.read(socketServiceProvider).disconnect();
    debugPrint('[logout] WebSocket disconnected');

    final prefs = await SharedPreferences.getInstance();

    // Remove auth session
    await prefs.remove(_sessionKey);
    debugPrint('[logout] Session deleted from SharedPreferences');

    // Clear registration draft data
    final regKeys = prefs.getKeys().where((k) => k.startsWith('reg_'));
    for (var k in regKeys) {
      await prefs.remove(k);
    }
    debugPrint('[logout] Registration draft cleared from SharedPreferences');

    _clearAllProviders();

    state = const AsyncValue.data(null);
    debugPrint('[logout] Auth state set to null');
  }

  Future<void> deleteAccount() async {
    final user = state.value;
    if (user == null) return;

    try {
      debugPrint('[deleteAccount] Attempting to delete user: ${user.id}');
      final response = await http.delete(
        Uri.parse("$apiBase/profile?id=${user.id}"),
      );

      debugPrint('[deleteAccount] Response status: ${response.statusCode}');
      debugPrint('[deleteAccount] Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('[deleteAccount] Deletion successful, calling logout');
        await logout();
      } else {
        debugPrint(
          '[deleteAccount] Deletion failed with status: ${response.statusCode}',
        );
        throw Exception("Failed to delete account: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint('[deleteAccount] Exception: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> uploadImage(
    List<int> bytes,
    String mime, {
    bool thumbnail = false,
  }) async {
    final uri = Uri.parse(
      "$apiBase/upload${thumbnail ? '?thumbnail=true' : ''}",
    );
    final request = http.MultipartRequest("POST", uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          "file",
          bytes,
          contentType: MediaType.parse(mime),
          filename: "upload.jpg",
        ),
      );

    final response = await request.send();
    if (response.statusCode == 200) {
      final data = jsonDecode(await response.stream.bytesToString());
      final hash = data['hash'] as String;
      final thumbnailHash = data['thumbnailHash'] as String?;

      final imageUrl = "$apiBase/assets/$hash";
      final result = <String, String>{'hash': hash, 'url': imageUrl};

      if (thumbnailHash != null) {
        result['thumbnailHash'] = thumbnailHash;
        result['thumbnailUrl'] = "$apiBase/assets/$thumbnailHash";
      }

      return result;
    }
    throw Exception("Upload failed");
  }

  Future<void> updateUserProfile(User updatedUser) async {
    debugPrint(
      '[AuthNotifier] updateUserProfile: Updating user ${updatedUser.id}',
    );
    debugPrint(
      '[AuthNotifier] updateUserProfile: Name=${updatedUser.realName}, Photos=${updatedUser.profilePhotos.length}',
    );
    state = AsyncValue.data(updatedUser);
    await _saveSession(updatedUser);
    debugPrint(
      '[AuthNotifier] updateUserProfile: User updated and session saved',
    );
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

// ============================================
// CHAT SYSTEM - Riverpod state only
// ============================================

class ChatNotifier extends Notifier<List<ChatRoom>> {
  @override
  List<ChatRoom> build() => [];

  void setRooms(List<ChatRoom> rooms) {
    debugPrint('[ChatNotifier] setRooms: Setting ${rooms.length} rooms');
    for (final room in rooms) {
      debugPrint('[ChatNotifier] setRooms: Room ${room.id} - ${room.title}');
    }
    state = rooms;
    debugPrint(
      '[ChatNotifier] setRooms: State updated with ${state.length} rooms',
    );
  }

  void addRoom(ChatRoom room) {
    if (!state.any((r) => r.id == room.id)) {
      state = [room, ...state];
    }
  }

  void updateRoomWithNewMessage(ChatMessage msg) {
    state = [
      for (final room in state)
        if (room.id == msg.chatId)
          room.copyWith(
            lastMessageContent: msg.content,
            lastMessageAt: msg.createdAt,
            recentMessages: [...room.recentMessages, msg],
          )
        else
          room,
    ];
    // Sort by latest message
    state.sort((a, b) {
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
  }

  void removeRoom(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatRoom>>(
  ChatNotifier.new,
);

// ============================================
// LOCATION SYSTEM - Riverpod state only
// ============================================

class UserLocation {
  final double lat;
  final double lon;
  final DateTime timestamp;
  const UserLocation({
    required this.lat,
    required this.lon,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lon': lon,
    'ts': timestamp.toIso8601String(),
  };

  factory UserLocation.fromMap(Map<String, dynamic> map) => UserLocation(
    lat: map['lat'],
    lon: map['lon'],
    timestamp: DateTime.parse(map['ts']),
  );
}

class LocationNotifier extends AsyncNotifier<UserLocation?> {
  @override
  Future<UserLocation?> build() async {
    return null;
  }

  Future<void> updateLocation(double lat, double lon) async {
    final loc = UserLocation(lat: lat, lon: lon, timestamp: DateTime.now());
    state = AsyncValue.data(loc);
  }
}

final locationProvider = AsyncNotifierProvider<LocationNotifier, UserLocation?>(
  LocationNotifier.new,
);

// ============================================
// NAVIGATION SYSTEM
// ============================================

class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void setIndex(int index) => state = index;
}

final navIndexProvider = NotifierProvider<NavIndexNotifier, int>(
  NavIndexNotifier.new,
);

// ============================================
// PARTY FEED SYSTEM - Riverpod state only
// ============================================

class PartyFeedNotifier extends Notifier<List<Party>> {
  final Set<String> _swipedIds = {};

  @override
  List<Party> build() => [];

  void setParties(List<Party> parties) {
    state = parties.where((p) => !_swipedIds.contains(p.id)).toList();
  }

  void addParty(Party party) {
    if (!_swipedIds.contains(party.id) && !state.any((p) => p.id == party.id)) {
      state = [...state, party];
    }
  }

  void markAsSwiped(String id) {
    _swipedIds.add(id);
    state = state.where((p) => p.id != id).toList();
  }

  void removeParty(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void clear() {
    state = [];
    _swipedIds.clear();
  }
}

final partyFeedProvider = NotifierProvider<PartyFeedNotifier, List<Party>>(
  PartyFeedNotifier.new,
);

// ============================================
// PARTY APPLICANTS SYSTEM - Riverpod state only
// ============================================

class PartyApplicantsNotifier extends Notifier<List<PartyApplication>> {
  @override
  List<PartyApplication> build() => [];

  void setApplicants(List<PartyApplication> apps) => state = apps;

  void updateStatus(String userId, ApplicantStatus status) {
    state = [
      for (final app in state)
        if (app.userId == userId)
          PartyApplication(
            partyId: app.partyId,
            userId: app.userId,
            status: status,
            appliedAt: app.appliedAt,
            user: app.user,
          )
        else
          app,
    ];
  }

  void clear() {
    state = [];
  }
}

final partyApplicantsProvider =
    NotifierProvider<PartyApplicantsNotifier, List<PartyApplication>>(
      PartyApplicantsNotifier.new,
    );

// ============================================
// DRAFT PARTY SYSTEM - Riverpod state only
// ============================================

class DraftPartyNotifier extends Notifier<DraftParty> {
  @override
  DraftParty build() => const DraftParty();

  void update(DraftParty draft) {
    state = draft;
  }

  void clear() {
    state = const DraftParty();
  }
}

final draftPartyProvider = NotifierProvider<DraftPartyNotifier, DraftParty>(
  DraftPartyNotifier.new,
);

// ============================================
// PARTY CREATION STATUS
// ============================================

enum CreationStatus { idle, loading, success, error }

class PartyCreationState {
  final CreationStatus status;
  final String? errorMessage;
  final String? createdPartyId;

  const PartyCreationState({
    this.status = CreationStatus.idle,
    this.errorMessage,
    this.createdPartyId,
  });
}

class PartyCreationNotifier extends Notifier<PartyCreationState> {
  @override
  PartyCreationState build() => const PartyCreationState();

  void setLoading() =>
      state = const PartyCreationState(status: CreationStatus.loading);

  void setSuccess(String id) => state = PartyCreationState(
    status: CreationStatus.success,
    createdPartyId: id,
  );

  void setError(String message) => state = PartyCreationState(
    status: CreationStatus.error,
    errorMessage: message,
  );

  void reset() => state = const PartyCreationState();
}

final partyCreationProvider =
    NotifierProvider<PartyCreationNotifier, PartyCreationState>(
      PartyCreationNotifier.new,
    );

// ============================================
// PARTY CACHE SYSTEM - Riverpod state only
// ============================================

class PartyCacheNotifier extends Notifier<Map<String, Party>> {
  @override
  Map<String, Party> build() => {};

  void updateParty(Party party) {
    state = {...state, party.id: party};
  }

  void updateParties(List<Party> parties) {
    state = {...state, for (final p in parties) p.id: p};
  }

  void removeParty(String id) {
    if (state.containsKey(id)) {
      final newState = Map<String, Party>.from(state);
      newState.remove(id);
      state = newState;
    }
  }

  Party? getParty(String id) => state[id];

  void clear() {
    state = {};
  }
}

final partyCacheProvider =
    NotifierProvider<PartyCacheNotifier, Map<String, Party>>(
      PartyCacheNotifier.new,
    );

// ============================================
// MY PARTIES SYSTEM - Riverpod state only
// ============================================

class MyPartiesNotifier extends Notifier<List<Party>> {
  @override
  List<Party> build() => [];

  void setParties(List<Party> parties) {
    debugPrint(
      '[MyPartiesNotifier] setParties: Setting ${parties.length} parties',
    );
    for (final party in parties) {
      debugPrint(
        '[MyPartiesNotifier] setParties: Party ${party.id} - ${party.title} (Host: ${party.hostId})',
      );
    }
    state = parties;
    debugPrint(
      '[MyPartiesNotifier] setParties: State updated with ${state.length} parties',
    );
  }

  void addParty(Party party) {
    final existingIndex = state.indexWhere((p) => p.id == party.id);
    if (existingIndex >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex) party else state[i],
      ];
    } else {
      state = [...state, party];
    }
  }

  void removeParty(String partyId) {
    state = state.where((p) => p.id != partyId).toList();
  }

  void updateParty(Party party) {
    final index = state.indexWhere((p) => p.id == party.id);
    if (index >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index) party else state[i],
      ];
    }
  }

  void clear() {
    state = [];
  }
}

final myPartiesProvider = NotifierProvider<MyPartiesNotifier, List<Party>>(
  MyPartiesNotifier.new,
);

// ============================================
// PARTIES AROUND SYSTEM - Riverpod state only
// ============================================

class PartiesAroundNotifier extends Notifier<List<Party>> {
  @override
  List<Party> build() => [];

  void setParties(List<Party> parties) {
    state = parties;
  }

  void addParty(Party party) {
    if (!state.any((p) => p.id == party.id)) {
      state = [...state, party];
    }
  }

  void removeParty(String partyId) {
    state = state.where((p) => p.id != partyId).toList();
  }

  void clear() {
    state = [];
  }
}

final partiesAroundProvider =
    NotifierProvider<PartiesAroundNotifier, List<Party>>(
      PartiesAroundNotifier.new,
    );

// ============================================
// DELETE FEEDBACK SYSTEM
// ============================================

class DeleteFeedbackNotifier extends Notifier<DeleteFeedbackState> {
  @override
  DeleteFeedbackState build() => DeleteFeedbackState();

  void setDeleting(String partyId) {
    state = DeleteFeedbackState(
      status: DeleteStatus.deleting,
      partyId: partyId,
    );
  }

  void setDeleted(String partyId) {
    state = DeleteFeedbackState(status: DeleteStatus.deleted, partyId: partyId);
    Future.delayed(const Duration(seconds: 2), () {
      if (state.partyId == partyId) {
        state = DeleteFeedbackState();
      }
    });
  }

  void clear() {
    state = DeleteFeedbackState();
  }
}

enum DeleteStatus { idle, deleting, deleted }

class DeleteFeedbackState {
  final DeleteStatus status;
  final String? partyId;

  DeleteFeedbackState({this.status = DeleteStatus.idle, this.partyId});
}

final deleteFeedbackProvider =
    NotifierProvider<DeleteFeedbackNotifier, DeleteFeedbackState>(
      DeleteFeedbackNotifier.new,
    );

// ============================================
// GEOCODE SYSTEM
// ============================================

class GeocodeResult {
  final String address;
  final String city;
  final String lat;
  final String lon;

  GeocodeResult({
    this.address = '',
    this.city = '',
    this.lat = '',
    this.lon = '',
  });
}

class GeocodeResultNotifier extends Notifier<GeocodeResult> {
  @override
  GeocodeResult build() => GeocodeResult();

  void setGeocodeResult(GeocodeResult result) {
    state = result;
  }

  void clear() {
    state = GeocodeResult();
  }
}

final geocodeResultProvider =
    NotifierProvider<GeocodeResultNotifier, GeocodeResult>(
      GeocodeResultNotifier.new,
    );

// ============================================
// NOTIFICATION SYSTEM - Riverpod state only
// ============================================

class NotificationsNotifier extends Notifier<List<Notification>> {
  @override
  List<Notification> build() => [];

  void setNotifications(List<Notification> notifications) {
    state = notifications;
  }

  void addNotification(Notification notification) {
    if (!state.any((n) => n.id == notification.id)) {
      state = [notification, ...state];
    }
  }

  void markAsRead(String notificationId) {
    state = [
      for (final n in state)
        if (n.id == notificationId) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllAsRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
  }

  void clear() {
    state = [];
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<Notification>>(
      NotificationsNotifier.new,
    );

// ============================================
// DM CONVERSATIONS SYSTEM - Riverpod state only
// ============================================

class DMConversationsNotifier extends Notifier<List<DMConversation>> {
  @override
  List<DMConversation> build() => [];

  void setConversations(List<DMConversation> conversations) {
    state = conversations;
  }

  void addConversation(DMConversation conversation) {
    if (!state.any((c) => c.chatId == conversation.chatId)) {
      state = [conversation, ...state];
    }
  }

  void updateConversation(DMConversation conversation) {
    state = [
      for (final c in state)
        if (c.chatId == conversation.chatId) conversation else c,
    ];
  }

  void removeConversation(String chatId) {
    state = state.where((c) => c.chatId != chatId).toList();
  }

  void clear() {
    state = [];
  }
}

final dmConversationsProvider =
    NotifierProvider<DMConversationsNotifier, List<DMConversation>>(
      DMConversationsNotifier.new,
    );

// ============================================
// PARTY ANALYTICS SYSTEM
// ============================================

class PartyAnalyticsNotifier extends Notifier<Map<String, PartyAnalytics>> {
  @override
  Map<String, PartyAnalytics> build() => {};

  void setAnalytics(String partyId, PartyAnalytics analytics) {
    state = {...state, partyId: analytics};
  }

  void clear() {
    state = {};
  }
}

final partyAnalyticsProvider =
    NotifierProvider<PartyAnalyticsNotifier, Map<String, PartyAnalytics>>(
      PartyAnalyticsNotifier.new,
    );

// ============================================
// MATCHED USERS SYSTEM - Riverpod state only
// ============================================

class MatchedUsersNotifier extends Notifier<List<MatchedUser>> {
  @override
  List<MatchedUser> build() => [];

  void setMatchedUsers(List<MatchedUser> users) {
    state = users;
  }

  void removeUser(String userId) {
    state = state.where((u) => u.userId != userId).toList();
  }

  void clear() {
    state = [];
  }
}

final matchedUsersProvider =
    NotifierProvider<MatchedUsersNotifier, List<MatchedUser>>(
      MatchedUsersNotifier.new,
    );

// ============================================
// BLOCKED USERS SYSTEM - Riverpod state only
// ============================================

class BlockedUsersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void setBlockedUsers(List<String> userIds) {
    state = userIds;
  }

  void addBlockedUser(String userId) {
    if (!state.contains(userId)) {
      state = [...state, userId];
    }
  }

  void removeBlockedUser(String userId) {
    state = state.where((id) => id != userId).toList();
  }

  bool isBlocked(String userId) => state.contains(userId);

  void clear() {
    state = [];
  }
}

final blockedUsersProvider =
    NotifierProvider<BlockedUsersNotifier, List<String>>(
      BlockedUsersNotifier.new,
    );

// ============================================
// SEARCH RESULTS SYSTEM
// ============================================

class UserSearchNotifier extends Notifier<List<User>> {
  @override
  List<User> build() => [];

  void setResults(List<User> users) {
    state = users;
  }

  void clear() {
    state = [];
  }
}

final userSearchProvider = NotifierProvider<UserSearchNotifier, List<User>>(
  UserSearchNotifier.new,
);

// ============================================
// CHAT HISTORY SYSTEM - Riverpod state only
// ============================================

class ChatHistoryNotifier extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> build() => {};

  void setMessages(String chatId, List<ChatMessage> messages) {
    state = {...state, chatId: messages};
  }

  void addMessage(String chatId, ChatMessage message) {
    final currentMessages = state[chatId] ?? [];
    state = {
      ...state,
      chatId: [...currentMessages, message],
    };
  }

  void removeMessage(String chatId, String messageId) {
    final currentMessages = state[chatId] ?? [];
    state = {
      ...state,
      chatId: currentMessages.where((m) => m.id != messageId).toList(),
    };
  }

  void clear() {
    state = {};
  }
}

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, Map<String, List<ChatMessage>>>(
      ChatHistoryNotifier.new,
    );

// ============================================
// DM HISTORY SYSTEM - Riverpod state only
// ============================================

class DMHistoryNotifier extends Notifier<Map<String, List<ChatMessage>>> {
  @override
  Map<String, List<ChatMessage>> build() => {};

  void setMessages(String otherUserId, List<ChatMessage> messages) {
    state = {...state, otherUserId: messages};
  }

  void addMessage(String otherUserId, ChatMessage message) {
    final currentMessages = state[otherUserId] ?? [];
    state = {
      ...state,
      otherUserId: [...currentMessages, message],
    };
  }

  void clear() {
    state = {};
  }
}

final dmHistoryProvider =
    NotifierProvider<DMHistoryNotifier, Map<String, List<ChatMessage>>>(
      DMHistoryNotifier.new,
    );

// ============================================
// EXTENSION METHODS FOR MODELS
// ============================================

extension ChatRoomSerialization on ChatRoom {
  Map<String, dynamic> toMap() => {
    'ID': id,
    'PartyID': partyId,
    'HostID': hostId,
    'Title': title,
    'ImageUrl': imageUrl,
    'IsGroup': isGroup,
    'ParticipantIDs': participantIds,
    'IsActive': isActive,
    'RecentMessages': recentMessages.map((m) => m.toMap()).toList(),
    'LastMessageContent': lastMessageContent,
    'LastMessageAt': lastMessageAt?.toIso8601String(),
    'UnreadCount': unreadCount,
    'StartTime': startTime?.toIso8601String(),
  };
}

extension ChatMessageSerialization on ChatMessage {
  Map<String, dynamic> toMap() => {
    'ID': id,
    'ChatID': chatId,
    'SenderID': senderId,
    'SenderName': senderName,
    'SenderThumbnail': senderThumbnail,
    'Type': type.toString().split('.').last,
    'Content': content,
    'MediaURL': mediaUrl,
    'ThumbnailURL': thumbnailUrl,
    'Metadata': metadata,
    'ReplyToID': replyToId,
    'CreatedAt': createdAt.toIso8601String(),
  };
}
