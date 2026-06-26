import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'theme.dart';
import 'providers.dart';
import 'models.dart';
import 'api.dart';
import 'constants.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool isEditing = false;
  bool _isUploading = false;
  bool _fieldsInitialized =
      false; // Flag to track if fields have been initialized
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  // Global user variable - gets current user from Riverpod authProvider
  // Use ref.watch for reactivity - UI will rebuild when user data changes
  User? get user => ref.watch(authProvider).value;

  Future<void> _pickAndUploadPhoto() async {
    final currentUser = user!;

    int remaining = 12 - currentUser.profilePhotos.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maximum 12 profile photos allowed")),
      );
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);

    if (images.isEmpty) {
      debugPrint('[DEBUG] No images selected or user cancelled');
      return;
    }

    setState(() => _isUploading = true);
    try {
      // Limit to remaining capacity
      final toUpload = images.length > remaining
          ? images.sublist(0, remaining)
          : images;

      List<String> newHashes = [];
      String? firstThumbHash;
      for (int i = 0; i < toUpload.length; i++) {
        final bytes = await toUpload[i].readAsBytes();
        // Generate thumbnail only for the first photo if user doesn't have one yet
        bool shouldGenThumb = (i == 0 && currentUser.profilePhotos.isEmpty);
        final uploadResult = await ref
            .read(authProvider.notifier)
            .uploadImage(bytes, "image/jpeg", thumbnail: true);

        // Store only the hash, not the full URL
        final hash = uploadResult['hash']!;
        newHashes.add(hash);
        if (shouldGenThumb) {
          firstThumbHash = uploadResult['thumbnailHash'];
        }
      }

      final updatedPhotos = [...currentUser.profilePhotos, ...newHashes];
      final updatedUser = currentUser.copyWith(
        profilePhotos: updatedPhotos,
        thumbnail: firstThumbHash ?? currentUser.thumbnail,
      );

      // Send to server and wait for PROFILE_UPDATED event
      // Do NOT update local state here - let the server confirmation handle it
      final socketService = ref.read(socketServiceProvider);
      debugPrint('[Profile] Socket connected: ${socketService.isConnected}');
      debugPrint('[Profile] Sending UPDATE_PROFILE with pictures to server');
      socketService.sendMessage('UPDATE_PROFILE', updatedUser.toMap());

      // Wait for the server to send back PROFILE_UPDATED before completing
      // The api.dart handler will update local state upon receiving PROFILE_UPDATED
      debugPrint('[Profile] Waiting for PROFILE_UPDATED event...');
      await ref.read(socketServiceProvider).waitForEvent('PROFILE_UPDATED');
      debugPrint('[Profile] Received PROFILE_UPDATED event');

      // Check if there was a validation error
      final validationError = ref
          .read(socketServiceProvider)
          .getLastProfileValidationError();
      if (validationError != null) {
        ref.read(socketServiceProvider).clearLastProfileValidationError();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: $validationError")),
          );
        }
        return; // Don't proceed with further processing
      }

      if (mounted && images.length > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Only $remaining photos were added (max 12 reached)"),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[DEBUG] Upload error: $e');
      debugPrint('[DEBUG] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _deletePhoto(int index) async {
    final currentUser = user;
    if (currentUser == null) return;

    final updatedPhotos = List<String>.from(currentUser.profilePhotos);
    updatedPhotos.removeAt(index);

    final updatedUser = currentUser.copyWith(profilePhotos: updatedPhotos);
    await ref.read(authProvider.notifier).updateUserProfile(updatedUser);

    final socketService = ref.read(socketServiceProvider);
    debugPrint(
      '[Profile] _deletePhoto - Socket connected: ${socketService.isConnected}',
    );
    socketService.sendMessage('UPDATE_PROFILE', updatedUser.toMap());
    setState(() {});
  }

  // --- Controllers for Text Input ---
  late TextEditingController _realNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _jobCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _schoolCtrl;
  late TextEditingController _degreeCtrl;
  late TextEditingController _instaCtrl;
  late TextEditingController _linkedInCtrl;
  late TextEditingController _xCtrl;
  late TextEditingController _tiktokCtrl;
  late TextEditingController _heightCtrl;

  // --- Local State for Non-Text Fields ---
  int _age = 18;
  int _heightCm = 170;
  String _gender = "OTHER";
  String _drinking = "";
  String _smoking = "";

  // Options for Dropdowns - includes "Do not disclose" option
  final List<String> _habitOptions = ["", "No", "Social", "Yes"];
  final Map<String, String> _habitLabels = {
    "": "Do not disclose",
    "No": "No",
    "Social": "Social",
    "Yes": "Yes",
  };

  // Gender options with "Prefer not to say"
  final List<String> _genderOptions = ["", "MALE", "FEMALE", "OTHER"];
  final Map<String, String> _genderLabels = {
    "": "Prefer not to say",
    "MALE": "Male",
    "FEMALE": "Female",
    "OTHER": "Other",
  };

  @override
  void initState() {
    super.initState();
    // Note: Don't call _initializeFields() here - ref is not available yet
    // Initialization will happen in didChangeDependencies()
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize fields here - ref is now available
    // Use flag to prevent re-initialization on every dependency change
    if (!_fieldsInitialized) {
      _initializeFields();
      _fieldsInitialized = true;
    }
  }

  void _initializeFields() {
    final currentUser = user;
    if (currentUser == null) return;

    _realNameCtrl = TextEditingController(text: currentUser.realName);
    _phoneCtrl = TextEditingController(text: currentUser.phoneNumber);
    _bioCtrl = TextEditingController(text: currentUser.bio);
    _jobCtrl = TextEditingController(text: currentUser.jobTitle);
    _companyCtrl = TextEditingController(text: currentUser.company);
    _schoolCtrl = TextEditingController(text: currentUser.school);
    _degreeCtrl = TextEditingController(text: currentUser.degree);
    _instaCtrl = TextEditingController(text: currentUser.instagramHandle);
    _linkedInCtrl = TextEditingController(text: currentUser.linkedinHandle);
    _xCtrl = TextEditingController(text: currentUser.xHandle);
    _tiktokCtrl = TextEditingController(text: currentUser.tiktokHandle);
    _heightCtrl = TextEditingController(
      text: currentUser.heightCm > 0 ? currentUser.heightCm.toString() : '',
    );

    // Initialize fields - allow empty/undisclosed values
    _age = currentUser.age == 0 ? 18 : currentUser.age;
    _heightCm = currentUser.heightCm;
    _gender = currentUser.gender;
    _drinking = currentUser.drinkingPref;
    _smoking = currentUser.smokingPref;
  }

  @override
  void dispose() {
    _realNameCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    _jobCtrl.dispose();
    _companyCtrl.dispose();
    _schoolCtrl.dispose();
    _degreeCtrl.dispose();
    _instaCtrl.dispose();
    _linkedInCtrl.dispose();
    _xCtrl.dispose();
    _tiktokCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    if (isEditing) {
      // Validate all fields before saving
      if (!_validateFields()) {
        // Validation failed, don't exit edit mode
        return;
      }
      _saveChanges();
    }
    setState(() => isEditing = !isEditing);
  }

  /// Validates all required fields before saving profile
  /// Returns true if validation passes, false otherwise
  bool _validateFields() {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) return false;

    // Validate required fields
    final validations = <String, String>{'Name': _realNameCtrl.text.trim()};

    final errors = <String>[];
    validations.forEach((fieldName, value) {
      if (value.isEmpty) {
        errors.add('$fieldName is required');
      }
    });

    // Validate age (must be reasonable)
    if (_age < 13 || _age > 120) {
      errors.add('Age must be between 13 and 120');
    }

    // Validate height if provided (must be reasonable)
    if (_heightCm > 0 && (_heightCm < 50 || _heightCm > 300)) {
      errors.add('Height must be between 50cm and 300cm');
    }

    // Validate phone number if provided (must contain only digits and be valid length)
    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      // Remove common phone formatting characters for validation
      final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length < 8 || digitsOnly.length > 15) {
        errors.add('Phone number must be between 8 and 15 digits');
      }
      // Check if phone contains only allowed characters (digits, +, -, space, parentheses)
      if (!RegExp(r'^[\d\+\-\s\(\)]+$').hasMatch(phone)) {
        errors.add(
          'Phone number can only contain numbers, +, -, spaces, and parentheses',
        );
      }
    }

    if (errors.isNotEmpty) {
      // Show validation errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please fix the following:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...errors.map((e) => Text('• $e')),
              ],
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }

    return true;
  }

  void _saveChanges() async {
    final currentUser = ref.read(authProvider).value;
    if (currentUser == null) return;

    final updatedUser = currentUser.copyWith(
      realName: _realNameCtrl.text,
      bio: _bioCtrl.text,
      phoneNumber: _phoneCtrl.text,
      jobTitle: _jobCtrl.text,
      company: _companyCtrl.text,
      school: _schoolCtrl.text,
      degree: _degreeCtrl.text,
      instagramHandle: _instaCtrl.text,
      linkedinHandle: _linkedInCtrl.text,
      xHandle: _xCtrl.text,
      tiktokHandle: _tiktokCtrl.text,
      age: _age,
      heightCm: _heightCm,
      gender: _gender,
      drinkingPref: _drinking,
      smokingPref: _smoking,
    );

    // Send to server and wait for PROFILE_UPDATED event
    // Do NOT update local state here - let the server confirmation handle it
    final socketService = ref.read(socketServiceProvider);
    debugPrint(
      '[Profile] _saveChanges - Socket connected: ${socketService.isConnected}',
    );
    debugPrint('[Profile] _saveChanges - Sending UPDATE_PROFILE to server');
    socketService.sendMessage('UPDATE_PROFILE', updatedUser.toMap());

    // Wait for the server to send back PROFILE_UPDATED before completing
    // The api.dart handler will update local state upon receiving PROFILE_UPDATED
    await ref.read(socketServiceProvider).waitForEvent('PROFILE_UPDATED');

    // Check if there was a validation error
    final validationError = ref
        .read(socketServiceProvider)
        .getLastProfileValidationError();
    if (validationError != null) {
      ref.read(socketServiceProvider).clearLastProfileValidationError();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Update failed: $validationError")),
        );
      }
      return; // Don't proceed with further processing
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is loaded - return loading indicator if not
    final currentUser = user;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            if (currentUser.profilePhotos.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                color: Colors.redAccent.withValues(alpha: 0.8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "PLEASE UPLOAD AT LEAST ONE PHOTO TO ACCESS THE FEED",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isEditing
                        ? _buildPhotoGrid(currentUser)
                        : _buildTinderCarousel(currentUser),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIdentitySection(),
                          const SizedBox(height: 20),
                          _buildBioSection(),
                          const SizedBox(height: 20),
                          _buildLifestyleSection(),
                          const SizedBox(height: 20),
                          _buildWorkEducationSection(),
                          const SizedBox(height: 20),
                          _buildSocialHandlesSection(),
                          const SizedBox(height: 40),
                          _buildEditButton(),
                          const SizedBox(height: 30),
                          _buildDangerZone(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: _toggleEdit,
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: isEditing
                ? [
                    Colors.greenAccent.withValues(alpha: 0.8),
                    Colors.tealAccent.withValues(alpha: 0.8),
                  ]
                : [AppColors.textCyan, AppColors.electricPurple],
          ),
          boxShadow: [
            BoxShadow(
              color: (isEditing ? Colors.greenAccent : AppColors.textCyan)
                  .withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          isEditing ? "SAVE PROFILE" : "EDIT PROFILE",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildTinderCarousel(User user) {
    final photos = user.profilePhotos;
    if (photos.isEmpty) {
      return SizedBox(
        height: 400,
        child: CachedNetworkImage(
          imageUrl:
              "https://images.unsplash.com/photo-1511367461989-f85a21fda167?q=80&w=1000",
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.black12),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      );
    }

    return SizedBox(
      height: 500,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (idx) => setState(() => _currentPhotoIndex = idx),
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: AppConstants.assetUrl(photos[index]),
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              );
            },
          ),

          // Tinder-style Progress Indicators
          Positioned(
            top: 15,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(photos.length, (index) {
                return Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
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

          // Tap Areas for Navigation
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_currentPhotoIndex > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_currentPhotoIndex < photos.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Gradient Overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Trust Badge
          Positioned(
            bottom: 20,
            right: 20,
            child: WaterGlass(
              width: 100,
              height: 35,
              borderRadius: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield, color: AppColors.gold, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    "${user.trustScore} TRUST",
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(User user) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "PROFILE PHOTOS",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPink,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Text(
                "${user.profilePhotos.length}/12",
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              if (index < user.profilePhotos.length) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: CachedNetworkImage(
                        imageUrl: AppConstants.assetUrl(
                          user.profilePhotos[index],
                        ),
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
                        onTap: () => _deletePhoto(index),
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
              } else {
                bool isNext = index == user.profilePhotos.length;
                return GestureDetector(
                  onTap: isNext
                      ? (_isUploading ? null : _pickAndUploadPhoto)
                      : null,
                  child: WaterGlass(
                    borderRadius: 15,
                    child: (isNext && _isUploading)
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.textCyan,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.add_a_photo,
                            color: isNext
                                ? Colors.white24
                                : Colors.white.withValues(alpha: 0.02),
                          ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: isEditing
                  ? TextField(
                      controller: _realNameCtrl,
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(fontSize: 32),
                      decoration: const InputDecoration(
                        hintText: "Your Name",
                        border: InputBorder.none,
                      ),
                    )
                  : Text(
                      user!.realName,
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(fontSize: 32),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBioSection() {
    if (!isEditing && _bioCtrl.text.trim().isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ABOUT ME",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        isEditing
            ? WaterGlass(
                height: 100,
                child: TextField(
                  controller: _bioCtrl,
                  maxLines: 4,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                  ),
                ),
              )
            : Text(
                _bioCtrl.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: Colors.white70,
                ),
              ),
      ],
    );
  }

  Widget _buildLifestyleSection() {
    // Lifestyle fields can now be empty (undisclosed)
    // Show section if editing OR if there's any data to display
    bool hasData =
        _heightCm > 0 ||
        _gender.isNotEmpty ||
        _drinking.isNotEmpty ||
        _smoking.isNotEmpty;

    if (!isEditing && !hasData) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("LIFESTYLE"),
        if (isEditing) ...[
          Text(
            "GENDER",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildGenderDropdown(),
          const SizedBox(height: 20),
        ],
        // Show gender in view mode if set
        if (!isEditing && _gender.isNotEmpty) ...[
          _buildInfoTile(
            Icons.person_outline,
            "Gender",
            _genderLabels[_gender] ?? _gender,
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: isEditing
                  ? _buildHeightEditTile()
                  : _heightCm > 0
                  ? _buildInfoTile(Icons.straighten, "Height", "$_heightCm cm")
                  : const SizedBox(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdownTile(
                Icons.local_bar,
                "Drinks",
                _drinking,
                (v) => setState(() => _drinking = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildDropdownTile(
                Icons.smoking_rooms,
                "Smoke",
                _smoking,
                (v) => setState(() => _smoking = v),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return WaterGlass(
      height: 60,
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _genderOptions.contains(_gender) ? _gender : "",
            dropdownColor: Colors.grey[900],
            isExpanded: true,
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
            items: _genderOptions.map((opt) {
              return DropdownMenuItem(
                value: opt,
                child: Text(
                  _genderLabels[opt] ?? opt,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: _gender == opt
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _gender = v);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeightEditTile() {
    return WaterGlass(
      height: 60,
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Row(
          children: [
            const Icon(Icons.straighten, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  hintText: "Height (cm) - optional",
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (v) {
                  if (v.trim().isEmpty) {
                    _heightCm = 0; // 0 means not disclosed
                  } else {
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      _heightCm = parsed;
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile(
    IconData icon,
    String label,
    String value,
    Function(String) onChanged,
  ) {
    // In view mode, don't show tile if value is empty (undisclosed)
    if (!isEditing) {
      if (value.isEmpty) return const SizedBox();
      return _buildInfoTile(icon, label, _habitLabels[value] ?? value);
    }

    return WaterGlass(
      height: 60,
      borderRadius: 15,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white38),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _habitOptions.contains(value) ? value : "",
                  dropdownColor: Colors.grey[900],
                  isDense: true,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white54,
                    size: 20,
                  ),
                  items: _habitOptions.map((opt) {
                    return DropdownMenuItem(
                      value: opt,
                      child: Text(
                        _habitLabels[opt] ?? opt,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: value == opt
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return WaterGlass(
      height: 60,
      borderRadius: 15,
      child: Row(
        children: [
          const SizedBox(width: 15),
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkEducationSection() {
    bool hasData =
        _jobCtrl.text.trim().isNotEmpty ||
        _companyCtrl.text.trim().isNotEmpty ||
        _schoolCtrl.text.trim().isNotEmpty ||
        _degreeCtrl.text.trim().isNotEmpty ||
        _phoneCtrl.text.trim().isNotEmpty;

    if (!isEditing && !hasData) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("WORK & EDUCATION"),
        _buildListInput(_jobCtrl, Icons.work_outline, "Job Title", "Add Job"),
        const SizedBox(height: 10),
        _buildListInput(
          _companyCtrl,
          Icons.business_outlined,
          "Company",
          "Add Company",
        ),
        const SizedBox(height: 10),
        _buildListInput(
          _schoolCtrl,
          Icons.school_outlined,
          "School",
          "Add School",
        ),
        const SizedBox(height: 10),
        _buildListInput(
          _degreeCtrl,
          Icons.description_outlined,
          "Degree",
          "Add Degree",
        ),
        const SizedBox(height: 10),
        _buildPhoneInput(),
      ],
    );
  }

  Widget _buildSocialHandlesSection() {
    bool hasData =
        _instaCtrl.text.trim().isNotEmpty ||
        _xCtrl.text.trim().isNotEmpty ||
        _tiktokCtrl.text.trim().isNotEmpty ||
        _linkedInCtrl.text.trim().isNotEmpty;

    if (!isEditing && !hasData) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("SOCIAL ECOSYSTEM"),
        _buildListInput(
          _instaCtrl,
          FontAwesomeIcons.instagram,
          "Instagram",
          "Add Instagram",
        ),
        const SizedBox(height: 10),
        _buildListInput(
          _xCtrl,
          FontAwesomeIcons.xTwitter,
          "X (Twitter)",
          "Add X",
        ),
        const SizedBox(height: 10),
        _buildListInput(
          _tiktokCtrl,
          FontAwesomeIcons.tiktok,
          "TikTok",
          "Add TikTok",
        ),
        const SizedBox(height: 10),
        _buildListInput(
          _linkedInCtrl,
          FontAwesomeIcons.linkedin,
          "LinkedIn",
          "Add LinkedIn",
        ),
      ],
    );
  }

  Widget _buildListInput(
    TextEditingController ctrl,
    IconData icon,
    String hint,
    String emptyLabel,
  ) {
    if (!isEditing && ctrl.text.isEmpty) return const SizedBox();

    String cleanText = ctrl.text.trim();
    bool isSocial =
        (icon == FontAwesomeIcons.instagram ||
        icon == FontAwesomeIcons.xTwitter ||
        icon == FontAwesomeIcons.tiktok ||
        icon == FontAwesomeIcons.linkedin);

    bool isLinkable = !isEditing && cleanText.isNotEmpty && isSocial;

    return GestureDetector(
      onTap: isLinkable
          ? () async {
              String input = cleanText;
              String url = input;

              if (!input.startsWith('http')) {
                // It's likely a handle
                String handle = input.startsWith('@')
                    ? input.substring(1)
                    : input;

                if (icon == FontAwesomeIcons.instagram) {
                  url = 'https://instagram.com/$handle';
                } else if (icon == FontAwesomeIcons.xTwitter) {
                  url = 'https://twitter.com/$handle';
                } else if (icon == FontAwesomeIcons.tiktok) {
                  url = 'https://tiktok.com/@$handle';
                } else if (icon == FontAwesomeIcons.linkedin) {
                  if (!handle.contains('/')) {
                    url = 'https://linkedin.com/in/$handle';
                  } else {
                    url = 'https://linkedin.com/$handle';
                  }
                }
              }

              final uri = Uri.tryParse(url);
              if (uri != null) {
                try {
                  // Try with external application mode first (opens in browser/app)
                  final launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!launched) {
                    // Fallback: try platform default
                    await launchUrl(uri);
                  }
                } catch (e) {
                  // If all else fails, try with platform default
                  try {
                    await launchUrl(uri);
                  } catch (_) {
                    // Silently fail - don't show error to user
                  }
                }
              }
            }
          : null,
      child: WaterGlass(
        height: 55,
        borderRadius: 15,
        child: TextField(
          controller: ctrl,
          enabled: isEditing,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isLinkable ? AppColors.textCyan : Colors.white,
            decoration: isLinkable ? TextDecoration.underline : null,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: isLinkable
                  ? AppColors.textCyan
                  : AppColors.textCyan.withValues(alpha: 0.4),
              size: 18,
            ),
            hintText: hint,
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white24),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    if (!isEditing && _phoneCtrl.text.trim().isEmpty) {
      return const SizedBox();
    }

    return WaterGlass(
      height: 55,
      borderRadius: 15,
      child: TextField(
        controller: _phoneCtrl,
        enabled: isEditing,
        keyboardType: TextInputType.phone,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.phone_outlined,
            color: AppColors.textCyan.withValues(alpha: 0.4),
            size: 18,
          ),
          hintText: "Phone Number",
          hintStyle: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    if (!isEditing) return const SizedBox();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showLogoutConfirmation,
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "LOGOUT",
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: GestureDetector(
                onTap: _showDeleteConfirmation,
                child: Container(
                  height: 45,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "DELETE ACCOUNT",
                    style: TextStyle(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Logout", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              "LOGOUT",
              style: TextStyle(color: AppColors.textCyan),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    print('[Profile] _showDeleteConfirmation called');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Delete Account",
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          "This action is permanent and cannot be undone. All your data will be wiped.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              print('[Profile] Delete account confirmed by user');
              try {
                await ref.read(authProvider.notifier).deleteAccount();
                print(
                  '[Profile] deleteAccount completed successfully - app will navigate to login',
                );
              } catch (e) {
                print('[Profile] deleteAccount failed: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
              }
            },
            child: const Text(
              "DELETE",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPink,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }
}
