import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:geolocator/geolocator.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'theme.dart';
import 'providers.dart';
import 'models.dart';
import 'api.dart';
import 'constants.dart';

class PartyFeedScreen extends ConsumerStatefulWidget {
  const PartyFeedScreen({super.key});

  @override
  ConsumerState<PartyFeedScreen> createState() => _PartyFeedScreenState();
}

class _PartyFeedScreenState extends ConsumerState<PartyFeedScreen> {
  final CardSwiperController controller = CardSwiperController();
  bool _isInitialLoading = true;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFetchLocation();
    });
  }

  Future<void> _checkAndFetchLocation() async {
    final existingLoc = ref.read(locationProvider).value;

    if (existingLoc != null) {
      // We have a location! Start loading feed immediately
      _fetchFeed(existingLoc.lat, existingLoc.lon);
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }

      // Still refresh location silently in background, but only if it's "old" (e.g. > 5 mins)
      if (DateTime.now().difference(existingLoc.timestamp).inMinutes > 5) {
        _determinePosition(silent: true);
      }
    } else {
      // No location yet, must fetch
      _determinePosition();
    }
  }

  Future<void> _fetchFeed(double lat, double lon) async {
    ref.read(socketServiceProvider).sendMessage('GET_FEED', {
      'Lat': lat,
      'Lon': lon,
      'RadiusKm': 50.0,
    });
  }

  Future<void> _determinePosition({bool silent = false}) async {
    bool serviceEnabled;
    LocationPermission permission;

    if (!silent) {
      setState(() {
        _isInitialLoading = true;
        _locationError = null;
      });
    }

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (silent) {
          return;
        }
        throw 'Location services are disabled.';
      }

      permission = await Geolocator.checkPermission();

      // If we already have permission, don't ask again
      if (permission == LocationPermission.denied) {
        if (silent) {
          return;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (silent) {
          return;
        }
        throw 'Location permissions are permanently denied.';
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      await ref
          .read(locationProvider.notifier)
          .updateLocation(position.latitude, position.longitude);
      _fetchFeed(position.latitude, position.longitude);

      if (mounted) setState(() => _isInitialLoading = false);
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _locationError = e.toString();
          _isInitialLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parties = ref.watch(partyFeedProvider);
    final locationAsync = ref.watch(locationProvider);
    final currentLoc = locationAsync.value;

    // Only show loading if we have absolutely no location and we are currently fetching
    if (_isInitialLoading && currentLoc == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.textCyan),
      );
    }

    if (_locationError != null && currentLoc == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: Colors.white24, size: 50),
            const SizedBox(height: 20),
            Text(
              _locationError!,
              style: const TextStyle(color: Colors.white54),
            ),
            TextButton(
              onPressed: _determinePosition,
              child: const Text(
                "RETRY",
                style: TextStyle(color: AppColors.textCyan),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: parties.isEmpty
                ? _buildEmptyState()
                : CardSwiper(
                    controller: controller,
                    cardsCount: parties.length,
                    numberOfCardsDisplayed: 1,
                    isDisabled: false,
                    padding: EdgeInsets.zero,
                    onSwipe: (previousIndex, currentIndex, direction) {
                      final party = parties[previousIndex];
                      // 1. Remove from local buffer immediately
                      ref
                          .read(partyFeedProvider.notifier)
                          .markAsSwiped(party.id);

                      // 2. Send Swipe to Backend
                      ref.read(socketServiceProvider).sendMessage('SWIPE', {
                        'PartyID': party.id,
                        'Direction': direction.name,
                      });
                      return true;
                    },
                    cardBuilder: (context, index, x, y) {
                      return _buildFeedCard(context, parties[index]);
                    },
                  ),
          ),

          // Layer 2: Action Buttons
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _roundActionButton(
                  FontAwesomeIcons.xmark,
                  AppColors.textPink,
                  () {
                    controller.swipe(CardSwiperDirection.left);
                  },
                ),
                _roundActionButton(
                  FontAwesomeIcons.check,
                  AppColors.textCyan,
                  () {
                    controller.swipe(CardSwiperDirection.right);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(BuildContext context, Party party) {
    final displayImage = party.partyPhotos.isNotEmpty
        ? AppConstants.assetUrl(party.partyPhotos.first)
        : "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?q=80&w=1000"; // Neutral Party Placeholder

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PartyDetailScreen(party: party),
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: displayImage,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black12),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.9),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 210,
            left: 25,
            right: 25,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  party.title.toUpperCase(),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 32,
                    height: 1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  party.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _chip(
                      context,
                      "${party.startTime.day}/${party.startTime.month}",
                      AppColors.textPink,
                    ),
                    const SizedBox(width: 10),
                    _chip(
                      context,
                      party.city.toUpperCase(),
                      AppColors.textCyan,
                    ),
                    const SizedBox(width: 10),
                    _chip(
                      context,
                      "${party.maxCapacity - party.currentGuestCount} SLOTS",
                      AppColors.gold,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  party.vibeTags.take(3).join(" • ").toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _roundActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: WaterGlass(
        width: 75,
        height: 75,
        borderRadius: 40,
        borderColor: color.withValues(alpha: 0.4),
        border: 2,
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            FontAwesomeIcons.water,
            color: AppColors.textCyan,
            size: 40,
          ),
          const SizedBox(height: 25),
          Text(
            "SILENCE",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white24,
              letterSpacing: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            "NO VIBES NEARBY",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// THE DETAILED "WHOLE CARD" VIEW
// ==========================================

class PartyDetailScreen extends StatefulWidget {
  final Party party;
  const PartyDetailScreen({required this.party, super.key});

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    final party = widget.party;
    final photos = party.partyPhotos.isNotEmpty
        ? party.partyPhotos
        : [
            "https://images.unsplash.com/photo-1492684223066-81342ee5ff30?q=80&w=1000",
          ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 550,
                pinned: true,
                backgroundColor: Colors.black,
                leading: const SizedBox(),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        itemCount: photos.length,
                        onPageChanged: (idx) =>
                            setState(() => _currentPhotoIndex = idx),
                        itemBuilder: (context, index) {
                          final url = photos[index].startsWith("http")
                              ? photos[index]
                              : AppConstants.assetUrl(photos[index]);
                          return CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.black12),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          );
                        },
                      ),
                      // Tinder-style indicators
                      Positioned(
                        top: 60,
                        left: 20,
                        right: 20,
                        child: Row(
                          children: List.generate(photos.length, (index) {
                            return Expanded(
                              child: Container(
                                height: 2,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentPhotoIndex == index
                                      ? Colors.white
                                      : Colors.white24,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      // Tap areas for navigation
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.ease,
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pageController.nextPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.ease,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.3),
                              Colors.transparent,
                              Colors.black,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party.title.toUpperCase(),
                        style: Theme.of(context).textTheme.displayLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 36,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 20),

                      // Primary Logistics Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _miniStat(
                              context,
                              FontAwesomeIcons.calendar,
                              "DATE",
                              "${party.startTime.day}/${party.startTime.month}",
                            ),
                            const SizedBox(width: 20),
                            _miniStat(
                              context,
                              FontAwesomeIcons.clock,
                              "START",
                              "${party.startTime.hour}:${party.startTime.minute.toString().padLeft(2, '0')}",
                            ),
                            const SizedBox(width: 20),
                            _miniStat(
                              context,
                              FontAwesomeIcons.locationDot,
                              "CITY",
                              party.city.toUpperCase(),
                            ),
                            const SizedBox(width: 20),
                            _miniStat(
                              context,
                              FontAwesomeIcons.users,
                              "LIMIT",
                              "${party.maxCapacity}",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 35),
                      _sectionLabel("THE VIBE"),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: party.vibeTags
                            .map((tag) => _smallChip(tag, AppColors.textCyan))
                            .toList(),
                      ),

                      const SizedBox(height: 30),
                      _sectionLabel("DESCRIPTION"),
                      const SizedBox(height: 10),
                      Text(
                        party.description,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),

                      if (party.rules.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        _sectionLabel("BASIC RULES"),
                        const SizedBox(height: 10),
                        ...party.rules.map(
                          (rule) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.circle,
                                  size: 4,
                                  color: AppColors.textPink,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    rule,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 30),
                      _sectionLabel("TECHNICAL LOGISTICS"),
                      const SizedBox(height: 15),
                      _infoLine(
                        "ADDRESS",
                        party.isLocationRevealed
                            ? party.address
                            : "HIDDEN UNTIL ACCEPTED",
                      ),
                      _infoLine(
                        "STATUS",
                        party.status.toString().split('.').last,
                      ),
                      _infoLine(
                        "CAPACITY",
                        "${party.currentGuestCount} / ${party.maxCapacity} GUESTS",
                      ),
                      _infoLine(
                        "AUTO-LOCK",
                        party.autoLockOnFull ? "ENABLED" : "DISABLED",
                      ),

                      if (party.rotationPool != null) ...[
                        const SizedBox(height: 40),
                        _sectionLabel("ROTATION POOL"),
                        const SizedBox(height: 15),
                        WaterGlass(
                          height: 60,
                          borderRadius: 15,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                FontAwesomeIcons.wallet,
                                color: AppColors.gold,
                                size: 14,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "\$${party.rotationPool!.currentAmount.toInt()} / \$${party.rotationPool!.targetAmount.toInt()} FUNDED",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 150),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Action Buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _decisionBtn(
                  context,
                  FontAwesomeIcons.xmark,
                  AppColors.textPink,
                  "SKIP",
                  () => Navigator.pop(context),
                ),
                _decisionBtn(
                  context,
                  FontAwesomeIcons.bolt,
                  AppColors.textCyan,
                  "REQUEST",
                  () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPink,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
      fontSize: 10,
    ),
  );

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 8, color: Colors.white38),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _decisionBtn(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          WaterGlass(
            width: 70,
            height: 70,
            borderRadius: 35,
            borderColor: color.withValues(alpha: 0.5),
            border: 2,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
