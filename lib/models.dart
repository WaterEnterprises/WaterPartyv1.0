// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

// ==========================================
// ENUMS & CONSTANTS (Synced with models.go)
// ==========================================

enum PartyStatus { OPEN, LOCKED, LIVE, COMPLETED, CANCELLED }

enum ApplicantStatus { PENDING, ACCEPTED, DECLINED, WAITLIST }

enum MessageType { TEXT, IMAGE, VIDEO, AUDIO, SYSTEM, AI, PAYMENT }

extension PartyStatusExt on PartyStatus {
  String get value => toString().split('.').last;
}

// ==========================================
// CORE ENTITIES
// ==========================================

@immutable
class WalletInfo {
  final String type;
  final String data;

  const WalletInfo({this.type = '', this.data = ''});

  factory WalletInfo.fromMap(Map<String, dynamic> map) {
    return WalletInfo(type: map['Type'] ?? '', data: map['Data'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {'Type': type, 'Data': data};
  }
}

@immutable
class User {
  final String id;
  final String realName;
  final String phoneNumber;
  final String email;
  final List<String> profilePhotos;
  final int age;
  final DateTime? dateOfBirth;
  final int heightCm;
  final String gender;
  final String drinkingPref;
  final String smokingPref;
  final String jobTitle;
  final String company;
  final String school;
  final String degree;
  final String instagramHandle;
  final String linkedinHandle;
  final String xHandle;
  final String tiktokHandle;
  final bool isVerified;
  final double trustScore;
  final double eloScore;
  final int partiesHosted;
  final int flakeCount;
  final WalletInfo walletData;
  final double locationLat;
  final double locationLon;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final String bio;
  final String thumbnail;

  const User({
    required this.id,
    required this.realName,
    required this.phoneNumber,
    required this.email,
    required this.profilePhotos,
    required this.age,
    this.dateOfBirth,
    required this.heightCm,
    required this.gender,
    required this.drinkingPref,
    required this.smokingPref,
    required this.jobTitle,
    required this.company,
    required this.school,
    required this.degree,
    required this.instagramHandle,
    required this.linkedinHandle,
    required this.xHandle,
    required this.tiktokHandle,
    required this.isVerified,
    required this.trustScore,
    required this.eloScore,
    required this.partiesHosted,
    required this.flakeCount,
    required this.walletData,
    required this.locationLat,
    required this.locationLon,
    this.lastActiveAt,
    this.createdAt,
    required this.bio,
    required this.thumbnail,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    try {
      // Helper function to safely parse DateTime
      DateTime? parseDateTime(dynamic value) {
        if (value == null) return null;
        if (value is DateTime) return value;
        try {
          return DateTime.parse(value.toString());
        } catch (e) {
          debugPrint('[User.fromMap] Error parsing date: $value - $e');
          return null;
        }
      }

      // Helper function to safely parse double
      double parseDouble(dynamic value, [double defaultValue = 0.0]) {
        if (value == null) return defaultValue;
        if (value is double) return value;
        if (value is int) return value.toDouble();
        try {
          return double.parse(value.toString());
        } catch (e) {
          return defaultValue;
        }
      }

      // Helper function to safely parse int
      int parseInt(dynamic value, [int defaultValue = 0]) {
        if (value == null) return defaultValue;
        if (value is int) return value;
        if (value is double) return value.toInt();
        try {
          return int.parse(value.toString());
        } catch (e) {
          return defaultValue;
        }
      }

      // Helper function to safely get string
      String parseString(dynamic value, [String defaultValue = '']) {
        if (value == null) return defaultValue;
        return value.toString();
      }

      // Helper function to safely parse list
      List<String> parseStringList(dynamic value) {
        if (value == null) return const [];
        if (value is List) {
          return value.whereType<String>().toList();
        }
        return const [];
      }

      // CRITICAL: Ensure ID is never empty - use fallback if necessary
      String userId = parseString(map['ID'] ?? map['id'], '');
      if (userId.isEmpty) {
        debugPrint('[User.fromMap] WARNING: User ID is empty in map: $map');
        // Try to find any field that might contain an ID
        for (final key in map.keys) {
          final value = map[key];
          if (value is String &&
              value.isNotEmpty &&
              (key.toLowerCase().contains('id') || key == 'user_id')) {
            debugPrint(
              '[User.fromMap] Found potential ID in field "$key": $value',
            );
            userId = value;
            break;
          }
        }
      }

      return User(
        id: userId,
        realName: parseString(map['RealName'] ?? map['real_name']),
        phoneNumber: parseString(map['PhoneNumber'] ?? map['phone_number']),
        email: parseString(map['Email'] ?? map['email']),
        profilePhotos: parseStringList(
          map['ProfilePhotos'] ?? map['profile_photos'],
        ),
        age: parseInt(map['Age'] ?? map['age']),
        dateOfBirth: parseDateTime(map['DateOfBirth'] ?? map['date_of_birth']),
        heightCm: parseInt(map['HeightCm'] ?? map['height_cm']),
        gender: parseString(map['Gender'] ?? map['gender']),
        drinkingPref: parseString(map['DrinkingPref'] ?? map['drinking_pref']),
        smokingPref: parseString(map['SmokingPref'] ?? map['smoking_pref']),
        jobTitle: parseString(map['JobTitle'] ?? map['job_title']),
        company: parseString(map['Company'] ?? map['company']),
        school: parseString(map['School'] ?? map['school']),
        degree: parseString(map['Degree'] ?? map['degree']),
        instagramHandle: parseString(
          map['InstagramHandle'] ?? map['instagram_handle'],
        ),
        linkedinHandle: parseString(
          map['LinkedinHandle'] ?? map['linkedin_handle'],
        ),
        xHandle: parseString(map['XHandle'] ?? map['x_handle']),
        tiktokHandle: parseString(map['TikTokHandle'] ?? map['tiktok_handle']),
        isVerified: map['IsVerified'] ?? map['is_verified'] ?? false,
        trustScore: parseDouble(map['TrustScore'] ?? map['trust_score']),
        eloScore: parseDouble(map['EloScore'] ?? map['elo_score']),
        partiesHosted: parseInt(map['PartiesHosted'] ?? map['parties_hosted']),
        flakeCount: parseInt(map['FlakeCount'] ?? map['flake_count']),
        walletData: (map['WalletData'] ?? map['wallet_data']) != null
            ? WalletInfo.fromMap(map['WalletData'] ?? map['wallet_data'])
            : const WalletInfo(),
        locationLat: parseDouble(map['LocationLat'] ?? map['location_lat']),
        locationLon: parseDouble(map['LocationLon'] ?? map['location_lon']),
        lastActiveAt: parseDateTime(
          map['LastActiveAt'] ?? map['last_active_at'],
        ),
        createdAt: parseDateTime(map['CreatedAt'] ?? map['created_at']),
        bio: parseString(map['Bio'] ?? map['bio']),
        thumbnail: parseString(map['Thumbnail'] ?? map['thumbnail']),
      );
    } catch (e, stackTrace) {
      debugPrint('[User.fromMap] CRITICAL ERROR: $e');
      debugPrint('[User.fromMap] Stack trace: $stackTrace');
      debugPrint('[User.fromMap] Input map: $map');

      // Return a safe default User object to prevent UI crashes
      return User(
        id: map['ID']?.toString() ?? map['id']?.toString() ?? 'unknown',
        realName: 'Unknown User',
        phoneNumber: '',
        email: '',
        profilePhotos: const [],
        age: 0,
        heightCm: 0,
        gender: '',
        drinkingPref: '',
        smokingPref: '',
        jobTitle: '',
        company: '',
        school: '',
        degree: '',
        instagramHandle: '',
        linkedinHandle: '',
        xHandle: '',
        tiktokHandle: '',
        isVerified: false,
        trustScore: 0.0,
        eloScore: 0.0,
        partiesHosted: 0,
        flakeCount: 0,
        walletData: const WalletInfo(),
        locationLat: 0.0,
        locationLon: 0.0,
        bio: '',
        thumbnail: '',
      );
    }
  }

  User copyWith({
    String? realName,
    String? bio,
    List<String>? profilePhotos,
    double? trustScore,
    String? instagramHandle,
    String? linkedinHandle,
    String? xHandle,
    String? tiktokHandle,
    String? phoneNumber,
    int? age,
    int? heightCm,
    String? gender,
    String? drinkingPref,
    String? smokingPref,
    String? jobTitle,
    String? company,
    String? school,
    String? degree,
    String? thumbnail,
  }) {
    return User(
      id: id,
      realName: realName ?? this.realName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email,
      profilePhotos: profilePhotos ?? this.profilePhotos,
      age: age ?? this.age,
      dateOfBirth: dateOfBirth,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
      drinkingPref: drinkingPref ?? this.drinkingPref,
      smokingPref: smokingPref ?? this.smokingPref,
      jobTitle: jobTitle ?? this.jobTitle,
      company: company ?? this.company,
      school: school ?? this.school,
      degree: degree ?? this.degree,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      linkedinHandle: linkedinHandle ?? this.linkedinHandle,
      xHandle: xHandle ?? this.xHandle,
      tiktokHandle: tiktokHandle ?? this.tiktokHandle,
      isVerified: isVerified,
      trustScore: trustScore ?? this.trustScore,
      eloScore: eloScore,
      partiesHosted: partiesHosted,
      flakeCount: flakeCount,
      walletData: walletData,
      locationLat: locationLat,
      locationLon: locationLon,
      lastActiveAt: lastActiveAt,
      createdAt: createdAt,
      bio: bio ?? this.bio,
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'RealName': realName,
      'PhoneNumber': phoneNumber,
      'Email': email,
      'ProfilePhotos': profilePhotos,
      'Age': age,
      'DateOfBirth': dateOfBirth?.toUtc().toIso8601String(),
      'HeightCm': heightCm,
      'Gender': gender,
      'DrinkingPref': drinkingPref,
      'SmokingPref': smokingPref,
      'JobTitle': jobTitle,
      'Company': company,
      'School': school,
      'Degree': degree,
      'InstagramHandle': instagramHandle,
      'LinkedinHandle': linkedinHandle,
      'XHandle': xHandle,
      'TikTokHandle': tiktokHandle,
      'IsVerified': isVerified,
      'TrustScore': trustScore,
      'EloScore': eloScore,
      'PartiesHosted': partiesHosted,
      'FlakeCount': flakeCount,
      'WalletData': walletData.toMap(),
      'LocationLat': locationLat,
      'LocationLon': locationLon,
      'Bio': bio,
      'Thumbnail': thumbnail,
    };
  }
}

@immutable
class Party {
  final String id;
  final String hostId;
  final String title;
  final String description;
  final List<String> partyPhotos;
  final DateTime startTime;
  final int durationHours;
  final PartyStatus status;
  final bool isLocationRevealed;
  final String address;
  final String city;
  final double geoLat;
  final double geoLon;
  final int maxCapacity;
  final int currentGuestCount;
  final bool autoLockOnFull;
  final List<String> vibeTags;
  final List<String> rules;
  final Crowdfunding? rotationPool;
  final String chatRoomId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String thumbnail;

  const Party({
    required this.id,
    required this.hostId,
    required this.title,
    required this.description,
    required this.partyPhotos,
    required this.startTime,
    required this.durationHours,
    required this.status,
    required this.isLocationRevealed,
    required this.address,
    required this.city,
    required this.geoLat,
    required this.geoLon,
    required this.maxCapacity,
    required this.currentGuestCount,
    required this.autoLockOnFull,
    required this.vibeTags,
    required this.rules,
    this.rotationPool,
    required this.chatRoomId,
    this.createdAt,
    this.updatedAt,
    required this.thumbnail,
  });

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      id: map['ID'] ?? map['id'] ?? '',
      hostId: map['HostID'] ?? map['host_id'] ?? '',
      title: map['Title'] ?? map['title'] ?? '',
      description: map['Description'] ?? map['description'] ?? '',
      partyPhotos: List<String>.from(
        map['PartyPhotos'] ?? map['party_photos'] ?? [],
      ),
      startTime: DateTime.parse(map['StartTime'] ?? map['start_time']),
      durationHours:
          (map['DurationHours'] ?? map['duration_hours'] as num?)?.toInt() ?? 2,
      status: PartyStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['Status'] ?? map['status']),
        orElse: () => PartyStatus.OPEN,
      ),
      isLocationRevealed:
          map['IsLocationRevealed'] ?? map['is_location_revealed'] ?? false,
      address: map['Address'] ?? map['address'] ?? '',
      city: map['City'] ?? map['city'] ?? '',
      geoLat: (map['GeoLat'] ?? map['geo_lat'] ?? 0.0).toDouble(),
      geoLon: (map['GeoLon'] ?? map['geo_lon'] ?? 0.0).toDouble(),
      maxCapacity: map['MaxCapacity'] ?? map['max_capacity'] ?? 0,
      currentGuestCount:
          map['CurrentGuestCount'] ?? map['current_guest_count'] ?? 0,
      autoLockOnFull:
          map['AutoLockOnFull'] ?? map['auto_lock_on_full'] ?? false,
      vibeTags: List<String>.from(map['VibeTags'] ?? map['vibe_tags'] ?? []),
      rules: List<String>.from(map['Rules'] ?? map['rules'] ?? []),
      rotationPool:
          (map['RotationPool'] ??
                  map['rotation_pool'] ??
                  map['RotationPool']) !=
              null
          ? Crowdfunding.fromMap(map['RotationPool'] ?? map['rotation_pool'])
          : null,
      chatRoomId: map['ChatRoomID'] ?? map['chat_room_id'] ?? '',
      createdAt: (map['CreatedAt'] ?? map['created_at']) != null
          ? DateTime.parse(map['CreatedAt'] ?? map['created_at'])
          : null,
      updatedAt: (map['UpdatedAt'] ?? map['updated_at']) != null
          ? DateTime.parse(map['UpdatedAt'] ?? map['updated_at'])
          : null,
      thumbnail: map['Thumbnail'] ?? map['thumbnail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'HostID': hostId,
      'Title': title,
      'Description': description,
      'PartyPhotos': partyPhotos,
      'StartTime': startTime.toUtc().toIso8601String(),
      'DurationHours': durationHours,
      'Status': status.toString().split('.').last,
      'IsLocationRevealed': isLocationRevealed,
      'Address': address,
      'City': city,
      'GeoLat': geoLat,
      'GeoLon': geoLon,
      'MaxCapacity': maxCapacity,
      'CurrentGuestCount': currentGuestCount,
      'AutoLockOnFull': autoLockOnFull,
      'VibeTags': vibeTags,
      'Rules': rules,
      'RotationPool': rotationPool?.toMap(),
      'ChatRoomID': chatRoomId,
      'Thumbnail': thumbnail,
    };
  }
}

class ChatRoom {
  final String id;
  final String partyId;
  final String hostId;
  final String title;
  final String imageUrl;
  final bool isGroup;
  final List<String> participantIds;
  final bool isActive;
  final List<ChatMessage> recentMessages;
  final String lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatRoom({
    required this.id,
    required this.partyId,
    required this.hostId,
    this.title = '',
    this.imageUrl = '',
    this.isGroup = true,
    this.participantIds = const [],
    this.isActive = true,
    this.recentMessages = const [],
    this.lastMessageContent = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.startTime,
  });

  final DateTime? startTime;

  /// Generates a deterministic DM chat ID that matches the server's algorithm
  /// Server algorithm: sort u1, u2 lexicographically, join with "_"
  static String generateDMChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Creates a DM ChatRoom with proper ID generation
  factory ChatRoom.dmRoom({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    String otherUserThumbnail = '',
  }) {
    // CRITICAL: Validate that neither ID is empty
    if (currentUserId.isEmpty) {
      debugPrint('[ChatRoom.dmRoom] ERROR: currentUserId is empty!');
      throw ArgumentError('currentUserId cannot be empty');
    }
    if (otherUserId.isEmpty) {
      debugPrint('[ChatRoom.dmRoom] ERROR: otherUserId is empty!');
      throw ArgumentError('otherUserId cannot be empty');
    }

    final dmChatId = generateDMChatId(currentUserId, otherUserId);
    debugPrint('[ChatRoom.dmRoom] Creating DM room:');
    debugPrint('  - currentUserId: $currentUserId');
    debugPrint('  - otherUserId: $otherUserId');
    debugPrint('  - dmChatId: $dmChatId');
    debugPrint('  - participantIds: [$currentUserId, $otherUserId]');

    return ChatRoom(
      id: dmChatId,
      partyId: '',
      hostId: currentUserId,
      isGroup: false,
      participantIds: [currentUserId, otherUserId],
      title: otherUserName.isNotEmpty ? otherUserName : 'Unknown User',
      imageUrl: otherUserThumbnail,
    );
  }

  ChatRoom copyWith({
    String? lastMessageContent,
    DateTime? lastMessageAt,
    int? unreadCount,
    List<ChatMessage>? recentMessages,
  }) {
    return ChatRoom(
      id: id,
      partyId: partyId,
      hostId: hostId,
      title: title,
      imageUrl: imageUrl,
      isGroup: isGroup,
      participantIds: participantIds,
      isActive: isActive,
      recentMessages: recentMessages ?? this.recentMessages,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      startTime: startTime ?? this.startTime,
    );
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map) {
    return ChatRoom(
      id: map['ID'] ?? map['id'] ?? '',
      partyId: map['PartyID'] ?? map['party_id'] ?? '',
      hostId: map['HostID'] ?? map['host_id'] ?? '',
      title: map['Title'] ?? map['title'] ?? '',
      imageUrl: map['ImageUrl'] ?? map['image_url'] ?? '',
      isGroup: map['IsGroup'] ?? map['is_group'] ?? true,
      participantIds: List<String>.from(
        map['ParticipantIDs'] ?? map['participant_ids'] ?? [],
      ),
      isActive: map['IsActive'] ?? map['is_active'] ?? true,
      recentMessages: _parseRecentMessages(
        map['RecentMessages'] ?? map['recent_messages'],
      ),
      lastMessageContent:
          map['LastMessageContent'] ?? map['last_message_content'] ?? '',
      lastMessageAt: (map['LastMessageAt'] ?? map['last_message_at']) != null
          ? DateTime.parse(map['LastMessageAt'] ?? map['last_message_at'])
          : null,
      unreadCount: map['UnreadCount'] ?? map['unread_count'] ?? 0,
      startTime:
          (map['StartTime'] ??
                  map['start_time'] ??
                  map['PartyStartTime'] ??
                  map['party_start_time']) !=
              null
          ? DateTime.parse(
              map['StartTime'] ??
                  map['start_time'] ??
                  map['PartyStartTime'] ??
                  map['party_start_time'],
            )
          : null,
    );
  }

  static List<ChatMessage> _parseRecentMessages(dynamic data) {
    if (data == null) return [];
    if (data is! List) return [];
    try {
      return data
          .map((m) => ChatMessage.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String content;
  final String mediaUrl;
  final String thumbnailUrl;
  final Map<String, dynamic> metadata;
  final String replyToId;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.content,
    this.mediaUrl = '',
    this.thumbnailUrl = '',
    this.metadata = const {},
    this.replyToId = '',
    required this.createdAt,
    this.senderName = '',
    this.senderThumbnail = '',
  });

  final String senderName;
  final String senderThumbnail;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['ID'] ?? map['id'] ?? '',
      chatId: map['ChatID'] ?? map['chat_id'] ?? '',
      senderId: map['SenderID'] ?? map['sender_id'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == (map['Type'] ?? map['type']),
        orElse: () => MessageType.TEXT,
      ),
      content: map['Content'] ?? map['content'] ?? '',
      mediaUrl: map['MediaURL'] ?? map['media_url'] ?? '',
      thumbnailUrl: map['ThumbnailURL'] ?? map['thumbnail_url'] ?? '',
      metadata: Map<String, dynamic>.from(
        map['Metadata'] ?? map['metadata'] ?? {},
      ),
      replyToId: map['ReplyToID'] ?? map['reply_to_id'] ?? '',
      createdAt: DateTime.parse(map['CreatedAt'] ?? map['created_at']),
      senderName: map['SenderName'] ?? map['sender_name'] ?? '',
      senderThumbnail: map['SenderThumbnail'] ?? map['sender_thumbnail'] ?? '',
    );
  }
}

class Crowdfunding {
  final String id;
  final String partyId;
  final double targetAmount;
  final double currentAmount;
  final String currency;
  final List<Contribution> contributors;
  final bool isFunded;

  const Crowdfunding({
    required this.id,
    this.partyId = '',
    required this.targetAmount,
    required this.currentAmount,
    this.currency = 'USD',
    this.contributors = const [],
    this.isFunded = false,
  });

  factory Crowdfunding.fromMap(Map<String, dynamic> map) {
    return Crowdfunding(
      id: map['ID'] ?? '',
      partyId: map['PartyID'] ?? '',
      targetAmount: (map['TargetAmount'] ?? 0.0).toDouble(),
      currentAmount: (map['CurrentAmount'] ?? 0.0).toDouble(),
      currency: map['Currency'] ?? 'USD',
      contributors: (map['Contributors'] as List? ?? [])
          .map((c) => Contribution.fromMap(c))
          .toList(),
      isFunded: map['IsFunded'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'PartyID': partyId,
      'TargetAmount': targetAmount,
      'CurrentAmount': currentAmount,
      'Currency': currency,
      'IsFunded': isFunded,
    };
  }
}

class Contribution {
  final String userId;
  final double amount;
  final DateTime paidAt;

  const Contribution({
    required this.userId,
    required this.amount,
    required this.paidAt,
  });

  factory Contribution.fromMap(Map<String, dynamic> map) {
    return Contribution(
      userId: map['UserID'] ?? '',
      amount: (map['Amount'] ?? 0.0).toDouble(),
      paidAt: DateTime.parse(map['PaidAt']),
    );
  }
}

class PartyApplication {
  final String partyId;
  final String userId;
  final ApplicantStatus status;
  final DateTime appliedAt;
  final User? user; // Optional: include user details for UI

  const PartyApplication({
    required this.partyId,
    required this.userId,
    required this.status,
    required this.appliedAt,
    this.user,
  });

  factory PartyApplication.fromMap(Map<String, dynamic> map) {
    try {
      // Extract User data from nested structure (as returned by server)
      User? user;
      if (map['User'] != null && map['User'] is Map<String, dynamic>) {
        try {
          final userMap = map['User'] as Map<String, dynamic>;
          debugPrint(
            '[PartyApplication.fromMap] Parsing User from map with keys: ${userMap.keys.toList()}',
          );
          user = User.fromMap(userMap);
          debugPrint(
            '[PartyApplication.fromMap] Successfully parsed User: id=${user.id}, name=${user.realName}',
          );
        } catch (e, stackTrace) {
          debugPrint('[PartyApplication.fromMap] Error parsing User: $e');
          debugPrint('[PartyApplication.fromMap] Stack trace: $stackTrace');
          user = null;
        }
      } else {
        debugPrint(
          '[PartyApplication.fromMap] No User data found in map. Keys: ${map.keys.toList()}',
        );
      }

      // Parse AppliedAt with error handling
      DateTime appliedAt;
      try {
        appliedAt = DateTime.parse(
          map['AppliedAt'] ?? DateTime.now().toIso8601String(),
        );
      } catch (e) {
        debugPrint('[PartyApplication.fromMap] Error parsing AppliedAt: $e');
        appliedAt = DateTime.now();
      }

      return PartyApplication(
        partyId:
            map['PartyID']?.toString() ?? map['party_id']?.toString() ?? '',
        userId: map['UserID']?.toString() ?? map['user_id']?.toString() ?? '',
        status: _parseApplicantStatus(map['Status'] ?? map['status']),
        appliedAt: appliedAt,
        user: user,
      );
    } catch (e, stackTrace) {
      debugPrint('[PartyApplication.fromMap] CRITICAL ERROR: $e');
      debugPrint('[PartyApplication.fromMap] Stack trace: $stackTrace');
      debugPrint('[PartyApplication.fromMap] Input map: $map');

      // Return a safe default object to prevent UI crashes
      return PartyApplication(
        partyId: map['PartyID']?.toString() ?? 'unknown',
        userId: map['UserID']?.toString() ?? 'unknown',
        status: ApplicantStatus.PENDING,
        appliedAt: DateTime.now(),
        user: null,
      );
    }
  }

  static ApplicantStatus _parseApplicantStatus(dynamic status) {
    if (status == null) return ApplicantStatus.PENDING;
    final statusStr = status.toString().toUpperCase();
    return ApplicantStatus.values.firstWhere(
      (e) => e.toString().split('.').last.toUpperCase() == statusStr,
      orElse: () => ApplicantStatus.PENDING,
    );
  }
}

@immutable
class DraftParty {
  final String title;
  final String description;
  final String city;
  final String address;
  final List<String> photos;
  final double capacity;
  final bool autoLock;
  final bool hasPool;
  final String poolAmount;
  final List<String> selectedTags;
  final String partyType;
  final List<String> rules;
  final double? geoLat;
  final double? geoLon;
  final DateTime? date;
  final int? hour;
  final int? minute;
  final double durationHours;

  const DraftParty({
    this.title = '',
    this.description = '',
    this.city = '',
    this.address = '',
    this.photos = const [],
    this.capacity = 10,
    this.autoLock = true,
    this.hasPool = false,
    this.poolAmount = '',
    this.selectedTags = const [],
    this.partyType = '',
    this.rules = const [],
    this.geoLat,
    this.geoLon,
    this.date,
    this.hour,
    this.minute,
    this.durationHours = 6,
    this.thumbnail = '',
  });

  final String thumbnail;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'city': city,
      'address': address,
      'photos': photos,
      'capacity': capacity,
      'autoLock': autoLock,
      'hasPool': hasPool,
      'poolAmount': poolAmount,
      'selectedTags': selectedTags,
      'partyType': partyType,
      'rules': rules,
      'geoLat': geoLat,
      'geoLon': geoLon,
      'date': date?.toIso8601String(),
      'hour': hour,
      'minute': minute,
      'durationHours': durationHours,
      'thumbnail': thumbnail,
    };
  }

  factory DraftParty.fromMap(Map<String, dynamic> map) {
    return DraftParty(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      city: map['city'] ?? '',
      address: map['address'] ?? '',
      photos: List<String>.from(map['photos'] ?? []),
      capacity: (map['capacity'] ?? 10.0).toDouble(),
      autoLock: map['autoLock'] ?? true,
      hasPool: map['hasPool'] ?? false,
      poolAmount: map['poolAmount'] ?? '',
      selectedTags: List<String>.from(map['selectedTags'] ?? []),
      partyType: map['partyType'] ?? '',
      rules: List<String>.from(map['rules'] ?? []),
      geoLat: map['geoLat'],
      geoLon: map['geoLon'],
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      hour: map['hour'],
      minute: map['minute'],
      durationHours: (map['durationHours'] ?? 6.0).toDouble(),
      thumbnail: map['thumbnail'] ?? '',
    );
  }

  DraftParty copyWith({
    String? title,
    String? description,
    String? city,
    String? address,
    List<String>? photos,
    double? capacity,
    bool? autoLock,
    bool? hasPool,
    String? poolAmount,
    List<String>? selectedTags,
    String? partyType,
    List<String>? rules,
    double? geoLat,
    double? geoLon,
    DateTime? date,
    int? hour,
    int? minute,
    double? durationHours,
    String? thumbnail,
  }) {
    return DraftParty(
      title: title ?? this.title,
      description: description ?? this.description,
      city: city ?? this.city,
      address: address ?? this.address,
      photos: photos ?? this.photos,
      capacity: capacity ?? this.capacity,
      autoLock: autoLock ?? this.autoLock,
      hasPool: hasPool ?? this.hasPool,
      poolAmount: poolAmount ?? this.poolAmount,
      selectedTags: selectedTags ?? this.selectedTags,
      partyType: partyType ?? this.partyType,
      rules: rules ?? this.rules,
      geoLat: geoLat ?? this.geoLat,
      geoLon: geoLon ?? this.geoLon,
      date: date ?? this.date,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      durationHours: durationHours ?? this.durationHours,
    );
  }
}

// ============================================
// Notification Model
// ============================================

enum NotificationType {
  applicationAccepted,
  applicationRejected,
  newApplication,
  newMessage,
  partyDeleted,
  partyUpdated,
  partyStarting,
  reminder,
  system,
}

extension NotificationTypeExt on NotificationType {
  String get value => toString().split('.').last;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => NotificationType.system,
    );
  }
}

class Notification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final String? partyId;
  final String? senderId;
  final bool isRead;
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.partyId,
    this.senderId,
    this.isRead = false,
    required this.createdAt,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['ID'] ?? map['id'] ?? '',
      userId: map['UserID'] ?? map['user_id'] ?? '',
      type: NotificationTypeExt.fromString(
        map['Type'] ?? map['type'] ?? 'system',
      ),
      title: map['Title'] ?? map['title'] ?? '',
      message: map['Message'] ?? map['message'] ?? '',
      partyId: map['PartyID'] ?? map['party_id'],
      senderId: map['SenderID'] ?? map['sender_id'],
      isRead: map['IsRead'] ?? map['is_read'] ?? false,
      createdAt: map['CreatedAt'] != null
          ? DateTime.parse(map['CreatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ID': id,
      'UserID': userId,
      'Type': type.value,
      'Title': title,
      'Message': message,
      'PartyID': partyId,
      'SenderID': senderId,
      'IsRead': isRead,
      'CreatedAt': createdAt.toUtc().toIso8601String(),
    };
  }

  Notification copyWith({bool? isRead}) {
    return Notification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      partyId: partyId,
      senderId: senderId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

// ============================================
// DM Conversation Model
// ============================================

class DMConversation {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserThumbnail;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const DMConversation({
    required this.chatId,
    required this.otherUserId,
    this.otherUserName = '',
    this.otherUserThumbnail = '',
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory DMConversation.fromMap(Map<String, dynamic> map) {
    return DMConversation(
      chatId: map['ChatID'] ?? map['chat_id'] ?? '',
      otherUserId: map['OtherUserID'] ?? map['other_user_id'] ?? '',
      otherUserName: map['OtherUserName'] ?? map['other_user_name'] ?? '',
      otherUserThumbnail:
          map['OtherUserThumbnail'] ?? map['other_user_thumbnail'] ?? '',
      lastMessage: map['LastMessage'] ?? map['last_message'] ?? '',
      lastMessageAt: map['LastMessageAt'] != null
          ? DateTime.parse(map['LastMessageAt'])
          : null,
      unreadCount: map['UnreadCount'] ?? map['unread_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ChatID': chatId,
      'OtherUserID': otherUserId,
      'OtherUserName': otherUserName,
      'OtherUserThumbnail': otherUserThumbnail,
      'LastMessage': lastMessage,
      'LastMessageAt': lastMessageAt?.toUtc().toIso8601String(),
      'UnreadCount': unreadCount,
    };
  }
}

// ============================================
// Party Analytics Model
// ============================================

class PartyAnalytics {
  final String partyId;
  final int totalViews;
  final int totalApplications;
  final int acceptedCount;
  final int rejectedCount;
  final int pendingCount;
  final int messagesCount;
  final int uniqueChatters;

  const PartyAnalytics({
    required this.partyId,
    this.totalViews = 0,
    this.totalApplications = 0,
    this.acceptedCount = 0,
    this.rejectedCount = 0,
    this.pendingCount = 0,
    this.messagesCount = 0,
    this.uniqueChatters = 0,
  });

  factory PartyAnalytics.fromMap(Map<String, dynamic> map) {
    return PartyAnalytics(
      partyId: map['PartyID'] ?? map['party_id'] ?? '',
      totalViews: map['TotalViews'] ?? map['total_views'] ?? 0,
      totalApplications:
          map['TotalApplications'] ?? map['total_applications'] ?? 0,
      acceptedCount: map['AcceptedCount'] ?? map['accepted_count'] ?? 0,
      rejectedCount: map['RejectedCount'] ?? map['rejected_count'] ?? 0,
      pendingCount: map['PendingCount'] ?? map['pending_count'] ?? 0,
      messagesCount: map['MessagesCount'] ?? map['messages_count'] ?? 0,
      uniqueChatters: map['UniqueChatters'] ?? map['unique_chatters'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'PartyID': partyId,
      'TotalViews': totalViews,
      'TotalApplications': totalApplications,
      'AcceptedCount': acceptedCount,
      'RejectedCount': rejectedCount,
      'PendingCount': pendingCount,
      'MessagesCount': messagesCount,
      'UniqueChatters': uniqueChatters,
    };
  }
}

// ============================================
// Matched User Model
// ============================================

class MatchedUser {
  final String userId;
  final String userName;
  final String userThumbnail;
  final ApplicantStatus status;

  const MatchedUser({
    required this.userId,
    this.userName = '',
    this.userThumbnail = '',
    this.status = ApplicantStatus.ACCEPTED,
  });

  factory MatchedUser.fromMap(Map<String, dynamic> map) {
    return MatchedUser(
      userId: map['UserID'] ?? map['user_id'] ?? '',
      userName: map['UserName'] ?? map['user_name'] ?? '',
      userThumbnail: map['UserThumbnail'] ?? map['user_thumbnail'] ?? '',
      status: ApplicantStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (map['Status'] ?? map['status']),
        orElse: () => ApplicantStatus.ACCEPTED,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'UserID': userId,
      'UserName': userName,
      'UserThumbnail': userThumbnail,
      'Status': status.toString().split('.').last,
    };
  }
}
