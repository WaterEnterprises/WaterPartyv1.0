// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart' show AppTheme, AppColors;
import 'providers.dart';
import 'match.dart'; // Feed
import 'matches.dart'; // Chat
import 'party.dart'; // Create
import 'profile.dart'; // Profile
import 'auth.dart'; // Auth Screen
import 'api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const ProviderScope(child: WaterPartyApp()));
}

class WaterPartyApp extends ConsumerWidget {
  const WaterPartyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authProvider);

    return MaterialApp(
      title: 'Water Party',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: userAsync.when(
        data: (user) {
          if (user == null) return const AuthScreen();
          if (user.profilePhotos.isEmpty) {
            return const MainScaffold(initialIndex: 3);
          }
          return const MainScaffold();
        },
        loading: () {
          // Check if we already have a user in the previous state (not likely on first load)
          // or just show the splash if it's the very first load.
          // If we want to avoid unmounting AuthScreen during login,
          // we need to return AuthScreen if we are in the process of logging in.
          // Since userAsync.value is null initially, we return AuthScreen.
          if (userAsync.value == null) return const AuthScreen();
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.textCyan),
            ),
          );
        },
        error: (e, st) {
          debugPrint('[AuthProvider] Error: $e');
          debugPrint('[AuthProvider] Stack trace: $st');
          return const AuthScreen();
        },
      ),
    );
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  final int initialIndex;
  const MainScaffold({this.initialIndex = 0, super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialIndex != 0) {
        ref.read(navIndexProvider.notifier).setIndex(widget.initialIndex);
      }
      final user = ref.read(authProvider).value;
      if (user != null) {
        ref.read(socketServiceProvider).connect(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navIndexProvider);

    final List<Widget> screens = [
      const PartyFeedScreen(),
      const MatchesScreen(),
      const CreatePartyScreen(),
      const ProfileScreen(),
    ];

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.oceanGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: currentIndex, children: screens),

        bottomNavigationBar: Container(
          height: 75,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navItem(Icons.style_rounded, "Feed", 0),
                _navItem(Icons.forum_rounded, "Chats", 1),
                _navItem(Icons.celebration_rounded, "Host", 2),
                _navItem(Icons.person_rounded, "Profile", 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final currentIndex = ref.watch(navIndexProvider);
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(navIndexProvider.notifier).setIndex(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white38,
                size: 22,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
