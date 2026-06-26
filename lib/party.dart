import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'theme.dart';
import 'providers.dart';
import 'models.dart';
import 'api.dart';
import 'constants.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class CreatePartyScreen extends ConsumerStatefulWidget {
  const CreatePartyScreen({super.key});

  @override
  ConsumerState<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends ConsumerState<CreatePartyScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _poolAmountController;
  late TextEditingController _ruleController;
  late TextEditingController _partyTypeController;

  double _capacity = 10;
  bool _autoLock = true;
  bool _hasPool = false;
  double? _geoLat;
  double? _geoLon;
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 22, minute: 0);

  List<String> _selectedTags = [];
  final List<String> _availableTags = [
    "HOUSE PARTY",
    "RAVE",
    "ROOFTOP",
    "DINNER",
    "ART",
    "POOL PARTY",
  ];

  List<String> _rules = [];

  List<String> _partyPhotos = [];
  String _partyThumbnail = "";
  bool _isUploading = false;
  bool _isGettingLocation = false;
  bool _isReverseGeocoding = false;
  double _durationHours = 6;

  /// Reverse geocoding result holder
  String? _detectedAddress;
  String? _detectedCity;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftPartyProvider);

    _titleController = TextEditingController(text: draft.title);
    _descController = TextEditingController(text: draft.description);
    _cityController = TextEditingController(text: draft.city);
    _addressController = TextEditingController(text: draft.address);
    _poolAmountController = TextEditingController(text: draft.poolAmount);
    _ruleController = TextEditingController();
    _partyTypeController = TextEditingController(text: draft.partyType);

    _capacity = draft.capacity;
    _autoLock = draft.autoLock;
    _hasPool = draft.hasPool;
    _geoLat = draft.geoLat;
    _geoLon = draft.geoLon;
    if (draft.date != null) _date = draft.date!;
    if (draft.hour != null && draft.minute != null) {
      _time = TimeOfDay(hour: draft.hour!, minute: draft.minute!);
    }
    _selectedTags = List.from(draft.selectedTags);
    _rules = List.from(draft.rules);
    _partyPhotos = List.from(draft.photos);
    _partyThumbnail = draft.thumbnail;
    _durationHours = draft.durationHours;

    _titleController.addListener(_updateDraft);
    _descController.addListener(_updateDraft);
    _cityController.addListener(_updateDraft);
    _addressController.addListener(_updateDraft);
    _poolAmountController.addListener(_updateDraft);
    _partyTypeController.addListener(_updateDraft);
  }

  void _updateDraft() {
    ref
        .read(draftPartyProvider.notifier)
        .update(
          DraftParty(
            title: _titleController.text,
            description: _descController.text,
            city: _cityController.text,
            address: _addressController.text,
            photos: _partyPhotos,
            capacity: _capacity,
            autoLock: _autoLock,
            hasPool: _hasPool,
            poolAmount: _poolAmountController.text,
            selectedTags: _selectedTags,
            partyType: _partyTypeController.text,
            rules: _rules,
            geoLat: _geoLat,
            geoLon: _geoLon,
            date: _date,
            hour: _time.hour,
            minute: _time.minute,
            durationHours: _durationHours,
            thumbnail: _partyThumbnail,
          ),
        );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _poolAmountController.dispose();
    _ruleController.dispose();
    _partyTypeController.dispose();
    super.dispose();
  }

  /// Request reverse geocoding via websocket
  void _requestReverseGeocode(double lat, double lon) {
    // Clear previous result
    ref.read(geocodeResultProvider.notifier).clear();

    // Send request to server
    ref.read(socketServiceProvider).sendMessage('REVERSE_GEOCODE', {
      'Lat': lat,
      'Lon': lon,
    });
  }

  /// Auto-fill address and city from GPS coordinates via websocket
  Future<void> _autoFillLocationFromCoords(double lat, double lon) async {
    setState(() => _isReverseGeocoding = true);

    // Send reverse geocode request via websocket
    _requestReverseGeocode(lat, lon);

    // Listen for the result
    ref.listen<GeocodeResult>(geocodeResultProvider, (previous, next) {
      if (next.address.isNotEmpty || next.city.isNotEmpty) {
        if (mounted) {
          setState(() {
            _detectedAddress = next.address;
            _detectedCity = next.city;

            if (_detectedAddress!.isNotEmpty) {
              _addressController.text = _detectedAddress!;
            } else {
              _addressController.text = 'PINNED ON MAP';
            }

            if (_detectedCity!.isNotEmpty) {
              _cityController.text = _detectedCity!;
            } else {
              _cityController.text = 'DETECTED ON PUBLISH';
            }
          });
          _updateDraft();
        }
      }

      // Stop listening after we get a result
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
      }
    });
  }

  /// Detect city from current pinned location (called on publish)
  Future<String> _detectCityFromPinnedLocation() async {
    if (_geoLat == null || _geoLon == null) return '';

    // If we already have a detected city, use it
    if (_detectedCity != null && _detectedCity!.isNotEmpty) {
      return _detectedCity!;
    }

    // Request reverse geocoding and wait for result
    _requestReverseGeocode(_geoLat!, _geoLon!);

    // Wait for result with timeout - check current provider value periodically
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final result = ref.read(geocodeResultProvider);
      if (result.city.isNotEmpty) {
        return result.city;
      }
    }

    return '';
  }

  Future<void> _useMyLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _geoLat = position.latitude;
        _geoLon = position.longitude;
      });

      // Auto-fill address and city from coordinates
      await _autoFillLocationFromCoords(position.latitude, position.longitude);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _openMapPicker() async {
    LatLng initial = LatLng(_geoLat ?? 0, _geoLon ?? 0);
    if (_geoLat == null || _geoLon == null) {
      // Default to current position if possible
      try {
        final pos = await Geolocator.getCurrentPosition();
        initial = LatLng(pos.latitude, pos.longitude);
      } catch (_) {}
    }

    if (!mounted) return;
    final LatLng? picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialLocation: initial),
      ),
    );

    if (picked != null) {
      setState(() {
        _geoLat = picked.latitude;
        _geoLon = picked.longitude;
      });

      // Auto-fill address and city from pinned coordinates
      await _autoFillLocationFromCoords(picked.latitude, picked.longitude);
    }
  }

  Future<void> _pickImage() async {
    int remaining = 16 - _partyPhotos.length;
    if (remaining <= 0) {
      _showError("Maximum 16 photos allowed");
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);

    if (images.isNotEmpty) {
      setState(() => _isUploading = true);
      try {
        // Limit to remaining capacity
        final toUpload = images.length > remaining
            ? images.sublist(0, remaining)
            : images;

        for (int i = 0; i < toUpload.length; i++) {
          final bytes = await toUpload[i].readAsBytes();
          // Generate thumbnail for the first photo of the party
          bool shouldGenThumb = (_partyPhotos.isEmpty && i == 0);
          final uploadResult = await ref
              .read(authProvider.notifier)
              .uploadImage(bytes, "image/jpeg", thumbnail: shouldGenThumb);

          final hash = uploadResult['hash']!;
          setState(() {
            _partyPhotos.add(hash);
            if (shouldGenThumb) {
              _partyThumbnail = uploadResult['thumbnailHash'] ?? "";
            }
          });
        }
        _updateDraft();

        if (images.length > remaining) {
          _showError("Only $remaining photos were added (max 16 reached)");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleCreateParty() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    if (_titleController.text.isEmpty) {
      _showError("Title is required");
      return;
    }
    if (_descController.text.isEmpty) {
      _showError("Description is required");
      return;
    }
    if (_addressController.text.isEmpty) {
      _showError("Address is required");
      return;
    }
    if (_partyPhotos.isEmpty) {
      _showError("At least one photo is required");
      return;
    }

    // Validate date/time is in the future
    final selectedDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (selectedDateTime.isBefore(DateTime.now())) {
      _showError("Date and time must be in the future");
      return;
    }

    // Validate at least one tag or party type is selected
    if (_selectedTags.isEmpty && _partyTypeController.text.isEmpty) {
      _showError("Select at least one party type or describe the party");
      return;
    }

    // If city is still a placeholder or empty, detect it from the pinned location
    String finalCity = _cityController.text;
    if (finalCity.isEmpty || finalCity == "DETECTED ON PUBLISH") {
      // Try to detect city from pinned location
      final detectedCity = await _detectCityFromPinnedLocation();
      if (detectedCity.isNotEmpty) {
        finalCity = detectedCity;
      } else {
        // If still can't detect, require manual input
        _showError("Please enter a city (could not detect from location)");
        return;
      }
    }

    ref.read(partyCreationProvider.notifier).setLoading();

    final String partyId = const Uuid().v4();
    final DateTime startDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    Crowdfunding? pool;
    if (_hasPool && _poolAmountController.text.isNotEmpty) {
      pool = Crowdfunding(
        id: const Uuid().v4(),
        partyId: partyId,
        targetAmount: double.tryParse(_poolAmountController.text) ?? 0.0,
        currentAmount: 0.0,
        currency: "USD",
        contributors: [],
        isFunded: false,
      );
    }

    // Combine manual tags and text input
    final List<String> finalTags = List.from(_selectedTags);
    if (_partyTypeController.text.isNotEmpty) {
      finalTags.add(_partyTypeController.text.toUpperCase());
    }

    final newParty = Party(
      id: partyId,
      hostId: user.id,
      title: _titleController.text.toUpperCase(),
      description: _descController.text,
      partyPhotos: _partyPhotos,
      startTime: startDateTime,
      durationHours: _durationHours.toInt(),
      status: PartyStatus.OPEN,
      isLocationRevealed: false,
      address: _addressController.text,
      city: finalCity,
      geoLat: _geoLat ?? 0.0,
      geoLon: _geoLon ?? 0.0,
      maxCapacity: _capacity.toInt(),
      currentGuestCount: 0,
      autoLockOnFull: _autoLock,
      vibeTags: finalTags,
      rules: _rules,
      rotationPool: pool,
      chatRoomId: const Uuid().v4(),
      thumbnail: _partyThumbnail,
    );

    ref
        .read(socketServiceProvider)
        .sendMessage('CREATE_PARTY', newParty.toMap());
    print('[CreateParty] Sent CREATE_PARTY with title: ${newParty.title}');
    print('[CreateParty] Party map keys: ${newParty.toMap().keys.toList()}');
  }

  void _showError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: AppColors.textCyan,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creationState = ref.watch(partyCreationProvider);

    ref.listen(partyCreationProvider, (previous, next) {
      if (next.status == CreationStatus.success &&
          next.createdPartyId != null) {
        _showSuccess("PARTY IGNITED SUCCESSFULLY!");
        ref.read(draftPartyProvider.notifier).clear();

        // Request feed first so party data is loaded before navigating to chats
        // This ensures party title is available when chat list renders
        ref.read(socketServiceProvider).sendMessage('GET_FEED', {});
        ref.read(socketServiceProvider).sendMessage('GET_CHATS', {});

        // Navigate to feed first to ensure data loads, then user can go to chats
        ref.read(navIndexProvider.notifier).setIndex(0);

        // Navigation is now handled by MatchesScreen listener to avoid race conditions
        ref.read(partyCreationProvider.notifier).reset();

        // Ensure new inputs are cleared as well
        setState(() {
          _titleController.clear();
          _descController.clear();
          _cityController.clear();
          _addressController.clear();
          _poolAmountController.clear();
          _partyTypeController.clear();
          _ruleController.clear();
          _partyPhotos.clear();
          _selectedTags.clear();
          _rules.clear();
        });
      } else if (next.status == CreationStatus.error) {
        _showError(next.errorMessage ?? "Failed to create party");
      }
    });

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildHeader()),
                  const SizedBox(height: 0),
                  _sectionHeader("DETAILS"),
                  WaterGlass(
                    height: 220,
                    borderRadius: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _compactInput(
                            _titleController,
                            "PARTY TITLE (REQUIRED)",
                            FontAwesomeIcons.bolt,
                            maxLines: 2,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: AppTypography.titleStyle.fontSize,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const Divider(color: Colors.white10, height: 20),
                          Expanded(
                            child: _compactInput(
                              _descController,
                              "DESCRIPTION (REQUIRED)",
                              Icons.notes,
                              maxLines: 5,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize:
                                    AppTypography.smallStyle.fontSize! + 1,
                                fontWeight: FontWeight.normal,
                              ),
                              hintStyle: TextStyle(
                                color: Colors.white10,
                                fontSize: AppTypography.smallStyle.fontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildPhotoGrid(),
                  const SizedBox(height: 10),
                  _sectionHeader("LOGISTICS"),
                  Row(
                    children: [
                      Expanded(
                        child: _actionTile(
                          FontAwesomeIcons.calendarDay,
                          "${_date.day}/${_date.month}",
                          _pickDate,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionTile(
                          FontAwesomeIcons.clock,
                          _time.format(context),
                          _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildDurationSlider(),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _inputField(
                          _cityController,
                          "CITY (REQUIRED)",
                          FontAwesomeIcons.locationDot,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isReverseGeocoding ? null : _openMapPicker,
                        child: WaterGlass(
                          width: 65,
                          height: 65,
                          borderRadius: 15,
                          child: _isReverseGeocoding
                              ? const CircularProgressIndicator(
                                  color: AppColors.textCyan,
                                  strokeWidth: 2,
                                )
                              : const Icon(
                                  FontAwesomeIcons.mapLocationDot,
                                  color: AppColors.textCyan,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _inputField(
                          _addressController,
                          "FULL ADDRESS (HIDDEN)",
                          FontAwesomeIcons.mapPin,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isGettingLocation ? null : _useMyLocation,
                        child: WaterGlass(
                          width: 65,
                          height: 65,
                          borderRadius: 15,
                          child: _isGettingLocation
                              ? const CircularProgressIndicator(
                                  color: AppColors.textCyan,
                                  strokeWidth: 2,
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: AppColors.textCyan,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _sectionHeader("ATMOSPHERE"),
                  _buildVibeExplainer(),
                  const SizedBox(height: 15),
                  _chipSelect("KIND OF PARTY", _availableTags, _selectedTags),
                  const SizedBox(height: 15),
                  _inputField(
                    _partyTypeController,
                    "OR DESCRIBE THE TYPE...",
                    Icons.edit_note,
                  ),
                  const SizedBox(height: 25),
                  _sectionHeader("BASIC RULES"),
                  _buildRuleInput(),
                  const SizedBox(height: 25),
                  _sectionHeader("CAPACITY & FUNDING"),
                  _buildCapacitySlider(),
                  const SizedBox(height: 15),
                  _buildPoolToggle(),
                  const SizedBox(height: 50),
                  _buildIgniteButton(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
        if (creationState.status == CreationStatus.loading)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: WaterGlass(
                  width: 100,
                  height: 100,
                  borderRadius: 20,
                  child: CircularProgressIndicator(color: AppColors.textCyan),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVibeExplainer() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.textCyan.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.textCyan.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textCyan, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              "Define the nature of your event. Is it a cozy house party, a wild rooftop rave, or a sophisticated dinner?",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSlider() {
    return WaterGlass(
      height: 70,
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Icon(
              FontAwesomeIcons.hourglassHalf,
              color: AppColors.textCyan,
              size: 16,
            ),
            const SizedBox(width: 15),
            Text(
              "DURATION: ${_durationHours.toInt()}H",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: AppTypography.smallStyle.fontSize! - 2,
              ),
            ),
            Expanded(
              child: Slider(
                value: _durationHours,
                min: 1,
                max: 6,
                activeColor: AppColors.textCyan,
                onChanged: (v) {
                  setState(() => _durationHours = v);
                  _updateDraft();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacitySlider() {
    return WaterGlass(
      height: 100,
      borderRadius: 20,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "GUEST LIMIT: ${_capacity.toInt()}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Slider(
            value: _capacity,
            min: 2,
            max: 1000,
            activeColor: AppColors.textCyan,
            inactiveColor: Colors.white10,
            onChanged: (v) {
              setState(() => _capacity = v);
              _updateDraft();
            },
          ),
          Text(
            _autoLock ? "AUTO-LOCK WHEN FULL" : "MANUAL LOCKING",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _autoLock ? AppColors.textCyan : Colors.white38,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasPool)
          Padding(
            padding: const EdgeInsets.only(left: 5, bottom: 10),
            child: Text(
              "HOW MUCH DO YOU NEED IN ADDITIONAL FUNDING?",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        GestureDetector(
          onTap: () {
            setState(() => _hasPool = !_hasPool);
            _updateDraft();
          },
          child: WaterGlass(
            height: 80,
            borderRadius: 20,
            borderColor: _hasPool ? AppColors.gold : Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FontAwesomeIcons.wallet,
                  color: _hasPool ? AppColors.gold : Colors.white24,
                  size: 20,
                ),
                const SizedBox(width: 15),
                if (_hasPool)
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _poolAmountController,
                      keyboardType: TextInputType.number,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      decoration: const InputDecoration(
                        hintText: "GOAL \$",
                        hintStyle: TextStyle(color: Colors.white10),
                        border: InputBorder.none,
                      ),
                    ),
                  )
                else
                  Text(
                    "ENABLE CROWD-FUND WITH WALLET",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIgniteButton() {
    return GestureDetector(
      onTap: _handleCreateParty,
      child: Container(
        height: 65,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [AppColors.textCyan, AppColors.electricPurple],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textCyan.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          "PUBLISH PARTY",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (d != null) {
      setState(() => _date = d);
      _updateDraft();
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) {
      setState(() => _time = t);
      _updateDraft();
    }
  }

  Widget _buildHeader() {
    return Text(
      "HOST A PARTY",
      style: AppTypography.titleStyle,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionHeader("GALLERY"),
            Text(
              "${_partyPhotos.length}/16",
              style: const TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: (_partyPhotos.length + 1).clamp(3, 16),
          itemBuilder: (context, index) {
            if (index < _partyPhotos.length) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: CachedNetworkImage(
                      imageUrl: AppConstants.assetUrl(_partyPhotos[index]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) =>
                          Container(color: Colors.black12),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.error),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _partyPhotos.removeAt(index));
                        _updateDraft();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else if (index == _partyPhotos.length) {
              return GestureDetector(
                onTap: _isUploading ? null : _pickImage,
                child: WaterGlass(
                  borderRadius: 15,
                  child: _isUploading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.textCyan,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.add_a_photo, color: Colors.white24),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        if (_partyPhotos.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "ADD AT LEAST ONE PHOTO TO DEFINE THE VIBE",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white10,
                fontSize: 9,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(left: 5, bottom: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textPink,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    ),
  );

  Widget _compactInput(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
    TextStyle? style,
    TextStyle? hintStyle,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style:
          style ??
          Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            hintStyle ??
            Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white10,
              fontSize: 14,
            ),
        border: InputBorder.none,
        prefixIcon: Icon(icon, color: AppColors.textCyan, size: 18),
        isDense: true,
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String hint, IconData icon) {
    return WaterGlass(
      height: 65,
      borderRadius: 15,
      child: _compactInput(
        ctrl,
        hint,
        icon,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        hintStyle: const TextStyle(color: Colors.white10, fontSize: 11),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: WaterGlass(
        height: 65,
        borderRadius: 15,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.textCyan),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: AppTypography.smallStyle.fontSize! - 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipSelect(
    String title,
    List<String> options,
    List<String> selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return GestureDetector(
              onTap: () {
                setState(
                  () => isSelected ? selected.remove(opt) : selected.add(opt),
                );
                _updateDraft();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.textCyan.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.textCyan : Colors.white10,
                  ),
                ),
                child: Text(
                  opt,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? Colors.white : Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRuleInput() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _inputField(
                _ruleController,
                "ADD PROTOCOL...",
                FontAwesomeIcons.shieldHalved,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                if (_ruleController.text.isNotEmpty) {
                  setState(() {
                    _rules.add(_ruleController.text.toUpperCase());
                    _ruleController.clear();
                  });
                  _updateDraft();
                }
              },
              child: WaterGlass(
                width: 65,
                height: 65,
                borderRadius: 15,
                child: const Icon(Icons.add, color: AppColors.textCyan),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 5,
          children: _rules
              .map(
                (r) => Chip(
                  label: Text(
                    r,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  backgroundColor: Colors.white10,
                  onDeleted: () {
                    setState(() => _rules.remove(r));
                    _updateDraft();
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  const MapPickerScreen({super.key, required this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "PINPOINT LOCATION",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textCyan,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedLocation),
            child: const Text(
              "CONFIRM",
              style: TextStyle(
                color: AppColors.textCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _selectedLocation,
          initialZoom: 15,
          onTap: (tapPosition, point) =>
              setState(() => _selectedLocation = point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.waterparty.app',
            tileBuilder: (context, tileWidget, tile) {
              return ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  -0.9,
                  0,
                  0,
                  0,
                  255,
                  0,
                  -0.9,
                  0,
                  0,
                  255,
                  0,
                  0,
                  -0.9,
                  0,
                  255,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: tileWidget,
              );
            },
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _selectedLocation,
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_on,
                  color: AppColors.textPink,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
