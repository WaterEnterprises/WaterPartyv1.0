import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'providers.dart';
import 'models.dart';
import 'chat.dart';
import 'constants.dart';
import 'match.dart';
import 'api.dart';

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Fetch DM conversations when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(socketServiceProvider).getDMs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allChatRooms = ref.watch(chatProvider);
    final myParties = ref.watch(myPartiesProvider);
    final currentUser = ref.watch(authProvider).value;

    // Get parties where user is admin (host) or matched (guest)
    final userParties = myParties.where((party) {
      if (currentUser == null) return false;
      // User is admin/host of the party
      if (party.hostId == currentUser.id) {
        return true;
      }
      // User is matched on the party (not host but included)
      return true; // Show all parties from myPartiesProvider
    }).toList();

    final dmConversations = ref.watch(dmConversationsProvider);

    // Handle automatic navigation to newly created party chat
    ref.listen(partyCreationProvider, (previous, next) {
      if (next.status == CreationStatus.success &&
          next.createdPartyId != null) {
        try {
          final newRoom = allChatRooms.firstWhere(
            (r) => r.partyId == next.createdPartyId,
          );
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => ChatScreen(room: newRoom)),
          );
        } catch (_) {
          // Room hasn't arrived yet
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 60,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      "CHATS",
                      style: AppTypography.titleStyle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Tab Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _buildTabSelector(),
            ),
          ),

          // Content
          _selectedTab == 0
              ? _buildPartySliverList(userParties)
              : _buildDMSliverList(dmConversations),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildTabButton("PARTY CHATS", 0),
          _buildTabButton("DIRECT MESSAGES", 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.textCyan, AppColors.electricPurple],
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.xs + 2,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isSelected ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartySliverList(List<Party> parties) {
    if (parties.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          "No party chats yet",
          "Host or join a party to start chatting!",
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildMatchCard(parties[index]),
          childCount: parties.length,
        ),
      ),
    );
  }

  Widget _buildDMSliverList(List<DMConversation> conversations) {
    if (conversations.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(
          "No direct messages yet",
          "Visit someone's profile to start chatting!",
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildDMConversationCard(conversations[index]),
          childCount: conversations.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 48,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: AppFontSizes.lg,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: AppFontSizes.sm,
              color: Colors.white38,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================
  // MATCH CARD - Party Chat Display
  // ============================================
  Widget _buildMatchCard(Party party) {
    final currentUser = ref.watch(authProvider).value;
    final isHost = currentUser != null && party.hostId == currentUser.id;

    // Get thumbnail
    String? thumbnailUrl;
    if (party.thumbnail.isNotEmpty) {
      thumbnailUrl = party.thumbnail.startsWith("http")
          ? party.thumbnail
          : AppConstants.assetUrl(party.thumbnail);
    } else if (party.partyPhotos.isNotEmpty) {
      thumbnailUrl = party.partyPhotos.first.startsWith("http")
          ? party.partyPhotos.first
          : AppConstants.assetUrl(party.partyPhotos.first);
    }

    // Calculate ETA
    String etaLabel = _formatETA(party.startTime);

    // Status color
    Color statusColor = _getStatusColor(party.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        child: InkWell(
          onTap: () => _navigateToPartyChat(party),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                _buildThumbnail(
                  thumbnailUrl: thumbnailUrl,
                  isGroup: true,
                  statusColor: statusColor,
                  isHost: isHost,
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              party.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppFontSizes.md,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (isHost) _buildHostBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Description
                      Text(
                        party.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFontSizes.sm,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom row - guests, location, ETA
                      Row(
                        children: [
                          _buildInfoChip(
                            icon: Icons.people_outline,
                            text:
                                "${party.currentGuestCount}/${party.maxCapacity}",
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            icon: Icons.location_on_outlined,
                            text: party.city,
                          ),
                          const Spacer(),
                          _buildETABadge(etaLabel, statusColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // CHAT CARD - Direct Message Display
  // ============================================
  Widget _buildChatCard(ChatRoom room) {
    final partyCache = ref.watch(partyCacheProvider);
    final myParties = ref.watch(myPartiesProvider);
    final currentUser = ref.watch(authProvider).value;

    // Resolve dynamic title and party details if it's a party
    String displayTitle = room.title;
    String? partyThumbnail;
    DateTime? partyStartTime;

    if (room.isGroup && room.partyId.isNotEmpty) {
      final party =
          partyCache[room.partyId] ??
          myParties.where((p) => p.id == room.partyId).firstOrNull;

      if (party != null) {
        displayTitle = party.title;
        partyThumbnail = party.thumbnail.isNotEmpty
            ? party.thumbnail
            : (party.partyPhotos.isNotEmpty ? party.partyPhotos.first : null);
        partyStartTime = party.startTime;
      }
    }

    if (displayTitle.isEmpty || displayTitle == "PARTY CHAT") {
      displayTitle = room.isGroup ? "PARTY CHAT" : "DIRECT MESSAGE";
    }

    // Calculate ETA for party chats
    String? etaLabel;
    if (room.isGroup && partyStartTime != null) {
      etaLabel = _formatETA(partyStartTime);
    }

    // Check if last message is from current user
    bool isLastMessageFromMe =
        currentUser != null &&
        room.recentMessages.isNotEmpty &&
        room.recentMessages.last.senderId == currentUser.id;

    // Determine thumbnail URL
    String? thumbnailUrl;
    if (partyThumbnail != null) {
      thumbnailUrl = partyThumbnail.startsWith("http")
          ? partyThumbnail
          : AppConstants.assetUrl(partyThumbnail);
    } else if (room.imageUrl.isNotEmpty) {
      thumbnailUrl = room.imageUrl.startsWith("http")
          ? room.imageUrl
          : AppConstants.assetUrl(room.imageUrl);
    }

    // Format last message
    String lastMessageText = room.lastMessageContent.isEmpty
        ? "No messages yet"
        : room.lastMessageContent;
    if (isLastMessageFromMe) {
      lastMessageText = "You: $lastMessageText";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => ChatScreen(room: room)),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                _buildThumbnail(
                  thumbnailUrl: thumbnailUrl,
                  isGroup: room.isGroup,
                  isPartyChat: room.partyId.isNotEmpty,
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title row with time and ETA
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: AppFontSizes.md,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (etaLabel != null) ...[
                            const SizedBox(width: 8),
                            _buildETABadge(etaLabel, AppColors.textCyan),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(room.lastMessageAt),
                            style: TextStyle(
                              fontSize: AppFontSizes.xs,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Last message
                      Row(
                        children: [
                          if (isLastMessageFromMe) ...[
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: AppColors.textCyan.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              lastMessageText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSizes.sm,
                                color: isLastMessageFromMe
                                    ? AppColors.textCyan
                                    : Colors.white.withValues(alpha: 0.6),
                                fontStyle: room.lastMessageContent.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (room.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            _buildUnreadBadge(room.unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // DM CONVERSATION CARD
  // ============================================
  Widget _buildDMConversationCard(DMConversation conversation) {
    final currentUser = ref.watch(authProvider).value;

    // Format thumbnail URL
    String? thumbnailUrl;
    if (conversation.otherUserThumbnail.isNotEmpty) {
      thumbnailUrl = conversation.otherUserThumbnail.startsWith("http")
          ? conversation.otherUserThumbnail
          : AppConstants.assetUrl(conversation.otherUserThumbnail);
    }

    // Format last message time
    String timeText = "";
    if (conversation.lastMessageAt != null) {
      final now = DateTime.now();
      final diff = now.difference(conversation.lastMessageAt!);
      if (diff.inDays > 0) {
        timeText = "${diff.inDays}d ago";
      } else if (diff.inHours > 0) {
        timeText = "${diff.inHours}h ago";
      } else if (diff.inMinutes > 0) {
        timeText = "${diff.inMinutes}m ago";
      } else {
        timeText = "Just now";
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildGlassCard(
        child: InkWell(
          onTap: () {
            // CRITICAL FIX: Use deterministic DM room ID generation
            if (currentUser != null) {
              final dmRoom = ChatRoom.dmRoom(
                currentUserId: currentUser.id,
                otherUserId: conversation.otherUserId,
                otherUserName: conversation.otherUserName.isNotEmpty
                    ? conversation.otherUserName
                    : 'Unknown User',
                otherUserThumbnail: conversation.otherUserThumbnail,
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChatScreen(room: dmRoom),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.textCyan, AppColors.electricPurple],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.black26,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white54,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.black26,
                              child: const Icon(
                                Icons.person,
                                color: Colors.white54,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.black26,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white54,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.otherUserName.isEmpty
                                  ? "Unknown User"
                                  : conversation.otherUserName,
                              style: const TextStyle(
                                fontSize: AppFontSizes.md,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (timeText.isNotEmpty)
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: AppFontSizes.xs,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage.isEmpty
                                  ? "No messages yet"
                                  : conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppFontSizes.sm,
                                color: conversation.lastMessage.isEmpty
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.6),
                                fontStyle: conversation.lastMessage.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (conversation.unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            _buildUnreadBadge(conversation.unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // UI COMPONENTS
  // ============================================
  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildThumbnail({
    String? thumbnailUrl,
    required bool isGroup,
    Color? statusColor,
    bool isHost = false,
    bool isPartyChat = false,
  }) {
    return Stack(
      children: [
        // Image or placeholder
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isGroup ? 14 : 32),
            gradient: thumbnailUrl == null
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isGroup
                        ? [
                            AppColors.gold.withValues(alpha: 0.3),
                            AppColors.textCyan.withValues(alpha: 0.3),
                          ]
                        : [
                            AppColors.textCyan.withValues(alpha: 0.3),
                            Colors.purple.withValues(alpha: 0.3),
                          ],
                  )
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isGroup ? 14 : 32),
            child: thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.black12,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textCyan,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        _buildDefaultIcon(isGroup),
                  )
                : _buildDefaultIcon(isGroup),
          ),
        ),

        // Host badge
        if (isHost)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 10),
            ),
          ),

        // Status/Type indicator
        if ((isGroup || isPartyChat) && !isHost)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGroup ? Icons.celebration : Icons.person,
                color: statusColor ?? AppColors.gold,
                size: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultIcon(bool isGroup) {
    return Center(
      child: Icon(
        isGroup ? Icons.celebration : Icons.person,
        color: Colors.white54,
        size: 28,
      ),
    );
  }

  Widget _buildHostBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        "HOST",
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: AppColors.gold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildETABadge(String eta, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        eta,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: AppFontSizes.xs,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.textCyan,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? "99+" : count.toString(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  void _navigateToPartyChat(Party party) {
    final allChatRooms = ref.read(chatProvider);
    try {
      final room = allChatRooms.firstWhere((r) => r.partyId == party.id);
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => ChatScreen(room: room)));
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PartyDetailScreen(party: party),
        ),
      );
    }
  }

  Color _getStatusColor(PartyStatus status) {
    switch (status) {
      case PartyStatus.OPEN:
        return AppColors.textCyan;
      case PartyStatus.LOCKED:
        return Colors.orange;
      case PartyStatus.LIVE:
        return Colors.green;
      case PartyStatus.COMPLETED:
        return Colors.grey;
      case PartyStatus.CANCELLED:
        return Colors.red;
    }
  }

  String _formatETA(DateTime? startTime) {
    if (startTime == null) return "";
    final now = DateTime.now();
    final diff = startTime.difference(now);

    if (diff.isNegative) {
      if (diff.inMinutes.abs() < 60) return "NOW";
      if (diff.inHours.abs() < 24) return "${diff.inHours.abs()}h";
      return "${diff.inDays.abs()}d";
    }

    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    if (diff.inDays < 7) return "${diff.inDays}d";
    return "${(diff.inDays / 7).floor()}w";
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    if (diff.inDays < 7) return "${diff.inDays}d";
    return "${(diff.inDays / 7).floor()}w";
  }
}

// ============================================
// EXTERNAL PROFILE VIEW
// ============================================

class ExternalProfileScreen extends ConsumerWidget {
  final User user;
  const ExternalProfileScreen({required this.user, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Validate user data
    if (user.id.isEmpty) {
      return _buildErrorScreen(context, 'Invalid user data');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 500,
                pinned: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildPhotoCarousel(user),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Use null-safe string interpolation
                      Text(
                        _formatUserName(user),
                        style: const TextStyle(
                          fontSize: AppFontSizes.display,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildInfoPill(
                            Icons.badge_outlined,
                            "${user.trustScore.toStringAsFixed(0)}% Trust",
                          ),
                          const SizedBox(width: 10),
                          if (user.isVerified) _buildVerifiedBadge(),
                        ],
                      ),
                      const SizedBox(height: 25),
                      if (user.bio.isNotEmpty) ...[
                        Text(
                          "ABOUT",
                          style: TextStyle(
                            fontSize: AppFontSizes.xs,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.5),
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.bio,
                          style: const TextStyle(
                            fontSize: AppFontSizes.md,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                      _buildDetailSection("BASICS", [
                        _buildDetailRow("Gender", user.gender),
                        _buildDetailRow("Height", "${user.heightCm} cm"),
                        _buildDetailRow("Drinking", user.drinkingPref),
                        _buildDetailRow("Smoking", user.smokingPref),
                      ]),
                      const SizedBox(height: 20),
                      _buildDetailSection("LOCATION", [
                        if (user.locationLat != 0 && user.locationLon != 0)
                          _buildDetailRow(
                            "Coordinates",
                            "${user.locationLat.toStringAsFixed(4)}, ${user.locationLon.toStringAsFixed(4)}",
                          ),
                      ]),
                      const SizedBox(height: 20),
                      _buildDetailSection("CONTACT", [
                        // Email removed for privacy - only visible to hosts/matches
                        if (user.phoneNumber.isNotEmpty)
                          _buildDetailRow("Phone", user.phoneNumber),
                        if (user.instagramHandle.isNotEmpty)
                          _buildSocialLink(
                            "Instagram",
                            "@${user.instagramHandle}",
                            "https://instagram.com/${user.instagramHandle}",
                            FontAwesomeIcons.instagram,
                          ),
                        if (user.xHandle.isNotEmpty)
                          _buildSocialLink(
                            "X (Twitter)",
                            "@${user.xHandle}",
                            "https://x.com/${user.xHandle}",
                            FontAwesomeIcons.xTwitter,
                          ),
                        if (user.tiktokHandle.isNotEmpty)
                          _buildSocialLink(
                            "TikTok",
                            "@${user.tiktokHandle}",
                            "https://tiktok.com/@${user.tiktokHandle}",
                            FontAwesomeIcons.tiktok,
                          ),
                        if (user.linkedinHandle.isNotEmpty)
                          _buildSocialLink(
                            "LinkedIn",
                            user.linkedinHandle,
                            "https://linkedin.com/in/${user.linkedinHandle}",
                            FontAwesomeIcons.linkedin,
                          ),
                      ]),
                      const SizedBox(height: 20),
                      _buildDetailSection("WORK & EDUCATION", [
                        if (user.jobTitle.isNotEmpty)
                          _buildDetailRow(
                            "Job",
                            "${user.jobTitle} ${user.company.isNotEmpty ? "at ${user.company}" : ""}",
                          ),
                        if (user.school.isNotEmpty)
                          _buildDetailRow(
                            "School",
                            "${user.school} ${user.degree.isNotEmpty ? "- ${user.degree}" : ""}",
                          ),
                      ]),
                      const SizedBox(height: 20),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text("Close"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // CRITICAL FIX: Use deterministic DM room ID generation
                          // that matches the server's algorithm
                          final currentUser = ref.read(authProvider).value;
                          if (currentUser != null) {
                            // Validate user.id before creating DM room
                            if (user.id.isEmpty) {
                              debugPrint(
                                '[ExternalProfileScreen] ERROR: Cannot create DM - user.id is empty!',
                              );
                              debugPrint(
                                '[ExternalProfileScreen] User data: id=${user.id}, name=${user.realName}',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot start chat: Invalid user data',
                                  ),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }

                            final dmRoom = ChatRoom.dmRoom(
                              currentUserId: currentUser.id,
                              otherUserId: user.id,
                              otherUserName: user.realName.isNotEmpty
                                  ? user.realName
                                  : 'Unknown User',
                              otherUserThumbnail: user.thumbnail.isNotEmpty
                                  ? user.thumbnail
                                  : (user.profilePhotos.isNotEmpty
                                        ? user.profilePhotos.first
                                        : ''),
                            );

                            debugPrint(
                              '[ExternalProfileScreen] Creating DM room:',
                            );
                            debugPrint('  - Current User: ${currentUser.id}');
                            debugPrint('  - Other User: ${user.id}');
                            debugPrint('  - Chat ID: ${dmRoom.id}');
                            debugPrint(
                              '  - Participant IDs: ${dmRoom.participantIds}',
                            );

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(room: dmRoom),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text("Message"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCarousel(User user) {
    // Debug logging for photo loading
    debugPrint('[ExternalProfileScreen] Building photo carousel:');
    debugPrint('  - User: ${user.realName} (id: ${user.id})');
    debugPrint('  - Profile photos count: ${user.profilePhotos.length}');
    debugPrint('  - Profile photos: ${user.profilePhotos}');

    if (user.profilePhotos.isEmpty) {
      debugPrint('[ExternalProfileScreen] No profile photos available');
      return Container(
        color: Colors.grey[900],
        child: const Center(
          child: Icon(Icons.person, size: 100, color: Colors.white24),
        ),
      );
    }

    return PageView.builder(
      itemCount: user.profilePhotos.length,
      itemBuilder: (context, index) {
        final photoUrl = AppConstants.assetUrl(user.profilePhotos[index]);
        debugPrint('[ExternalProfileScreen] Loading photo $index: $photoUrl');

        return CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.textCyan),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('[ExternalProfileScreen] Error loading photo: $url');
            debugPrint('[ExternalProfileScreen] Error details: $error');
            return Container(
              color: Colors.grey[900],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.white24, size: 50),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textCyan),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: AppFontSizes.sm,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textCyan.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: AppColors.textCyan),
          SizedBox(width: 4),
          Text(
            "VERIFIED",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    final filteredChildren = children.where((c) => c is! SizedBox).toList();
    if (filteredChildren.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: AppFontSizes.xs,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...filteredChildren,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.md,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppFontSizes.md,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a tappable social media link that opens in native apps using universal links
  Widget _buildSocialLink(
    String label,
    String displayText,
    String url,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _launchSocialMediaUrl(label, displayText, url),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.md,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: AppFontSizes.md,
                    color: AppColors.textCyan,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: AppColors.textCyan),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new, size: 14, color: Colors.white54),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: AppFontSizes.sm,
          color: Colors.white70,
        ),
      ),
    );
  }

  /// Launches social media URLs with native app support using universal links
  /// Tries native app URL schemes first, then falls back to web URLs
  Future<void> _launchSocialMediaUrl(
    String label,
    String displayText,
    String webUrl,
  ) async {
    // Extract username/handle from the web URL
    String? username;
    final uri = Uri.parse(webUrl);

    if (webUrl.contains('instagram.com')) {
      username = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    } else if (webUrl.contains('x.com') || webUrl.contains('twitter.com')) {
      username = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    } else if (webUrl.contains('tiktok.com')) {
      username = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      if (username != null && username.startsWith('@')) {
        username = username.substring(1);
      }
    } else if (webUrl.contains('linkedin.com')) {
      username = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
    }

    // Build native app URL schemes
    List<String> urlsToTry = [];

    if (username != null) {
      if (webUrl.contains('instagram.com')) {
        // Instagram native app URLs
        urlsToTry.add('instagram://user?username=$username');
        urlsToTry.add('instagram://user?username=$username');
      } else if (webUrl.contains('x.com') || webUrl.contains('twitter.com')) {
        // X (Twitter) native app URLs
        urlsToTry.add('twitter://user?screen_name=$username');
        urlsToTry.add('x://user?screen_name=$username');
      } else if (webUrl.contains('tiktok.com')) {
        // TikTok native app URLs
        urlsToTry.add('tiktok://user?username=$username');
        urlsToTry.add('snssdk1233://user?username=$username');
      } else if (webUrl.contains('linkedin.com')) {
        // LinkedIn native app URLs
        urlsToTry.add('linkedin://profile/$username');
        urlsToTry.add('linkedin://in/$username');
      }
    }

    // Always add the web URL as fallback
    urlsToTry.add(webUrl);

    // Try each URL in order
    for (final urlString in urlsToTry) {
      try {
        final url = Uri.parse(urlString);
        final canLaunch = await canLaunchUrl(url);

        if (canLaunch) {
          final launched = await launchUrl(
            url,
            mode: LaunchMode.externalApplication,
          );
          if (launched) {
            debugPrint('[ExternalProfileScreen] Launched: $urlString');
            return; // Successfully launched
          }
        }
      } catch (e) {
        debugPrint('[ExternalProfileScreen] Error trying $urlString: $e');
      }
    }

    // Final fallback: try web URL with in-app web view
    try {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.inAppWebView);
    } catch (e) {
      debugPrint('[ExternalProfileScreen] Failed to launch web URL: $e');
    }
  }

  /// Formats user name with age, handling missing data gracefully
  String _formatUserName(User user) {
    final name = user.realName.isNotEmpty ? user.realName : 'Unknown User';
    final age = user.age > 0 ? ', ${user.age}' : '';
    return '$name$age';
  }

  /// Builds an error screen when user data is invalid
  Widget _buildErrorScreen(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 24),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: AppFontSizes.lg,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('GO BACK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textCyan,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
