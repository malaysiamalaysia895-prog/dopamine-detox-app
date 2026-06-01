import 'dart:async';
import 'dart:isolate';
import 'package:android_intent_plus/android_intent_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';
import 'home_screen.dart';

// ─── Background isolate helper (fast app loading) ─────────────────────────────
// Runs getInstalledApplications in a separate isolate so it never blocks UI.
Future<List<Application>> _loadAppsInBackground(bool withIcons) async {
  return DeviceApps.getInstalledApplications(
    includeAppIcons: withIcons,
    includeSystemApps: true,          // QUERY_ALL_PACKAGES in manifest covers this
    onlyAppsWithLaunchIntent: true,   // Only launchable apps
  );
}

class StudyFocusScreen extends StatefulWidget {
  const StudyFocusScreen({super.key});

  @override
  State<StudyFocusScreen> createState() => _StudyFocusScreenState();
}

class _StudyFocusScreenState extends State<StudyFocusScreen>
    with WidgetsBindingObserver {

  // ── App list state ─────────────────────────────────────────────────────────
  // Phase 1: names only (fast, no icons) → Phase 2: with icons (background)
  List<Application> _apps = [];
  bool _loadingPhase1 = true;  // initial load
  bool _loadingIcons = false;  // icon enrichment pass
  String? _loadError;

  final Set<String> _selectedPackages = {};
  Duration _selectedDuration = const Duration(hours: 1);

  // ── Permission state ───────────────────────────────────────────────────────
  bool _overlayGranted = false;
  bool _permChecked = false;

  // ── Starting state ─────────────────────────────────────────────────────────
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check overlay permission when user returns from Settings
    if (state == AppLifecycleState.resumed) {
      _checkOverlayPermission();
    }
  }

  Future<void> _init() async {
    await _checkOverlayPermission();
    // Load apps in two phases without blocking UI
    await _loadPhase1();
  }

  // ── Permission helpers ─────────────────────────────────────────────────────

  Future<void> _checkOverlayPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) {
      setState(() {
        _overlayGranted = granted;
        _permChecked = true;
      });
    }
  }

  Future<void> _requestOverlayPermission() async {
    // FlutterOverlayWindow.requestPermission() opens the system
    // "Display over other apps" settings screen automatically.
    await FlutterOverlayWindow.requestPermission();
    // Re-check after user returns (also handled by didChangeAppLifecycleState)
    await _checkOverlayPermission();
  }

  Future<void> _openUsageAccessSettings() async {
    // PACKAGE_USAGE_STATS is a special permission — must open Settings manually.
    const intent = AndroidIntent(
      action: 'android.settings.USAGE_ACCESS_SETTINGS',
    );
    try {
      await intent.launch();
    } catch (_) {
      // Fallback: open general app settings
      await openAppSettings();
    }
  }

  // ── App list — two-phase load ──────────────────────────────────────────────
  // Phase 1: no icons → renders list immediately (fast)
  // Phase 2: icons    → enriches in background, updates UI

  Future<void> _loadPhase1() async {
    setState(() {
      _loadingPhase1 = true;
      _loadError = null;
    });
    try {
      // Use compute() so platform-channel heavy call doesn't block the UI thread
      final apps = await compute(_loadAppsInBackground, false);
      _sortApps(apps);
      if (mounted) {
        setState(() {
          _apps = apps;
          _loadingPhase1 = false;
          _loadingIcons = true;
        });
      }
      // Phase 2: load icons in background (non-blocking)
      _loadPhase2();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPhase1 = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _loadPhase2() async {
    try {
      final apps = await compute(_loadAppsInBackground, true);
      _sortApps(apps);
      if (mounted) {
        setState(() {
          _apps = apps;
          _loadingIcons = false;
        });
      }
    } catch (_) {
      // Icons failed — no problem, we still show the name-only list
      if (mounted) setState(() => _loadingIcons = false);
    }
  }

  void _sortApps(List<Application> apps) {
    apps.sort((a, b) {
      // User-installed apps first, then system apps, both alphabetical
      if (a.systemApp != b.systemApp) return a.systemApp ? 1 : -1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
  }

  // ── Start focus ────────────────────────────────────────────────────────────

  Future<void> _startFocus() async {
    final provider = context.read<AppStateProvider>();

    // ── Bug fix #4: guard against starting a second challenge ──────────────
    if (provider.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ A challenge is already active!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedPackages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one app to lock.')),
      );
      return;
    }

    if (!_overlayGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚠️ "Display over other apps" permission required.')),
      );
      await _requestOverlayPermission();
      return;
    }

    setState(() => _starting = true);

    // ── Bug fix #5: wire billing callback before challenge starts ──────────
    final billing = context.read<BillingService>();
    billing.onPurchaseSuccess = () {
      provider.unlockAll();
    };

    // Start challenge in provider (persists to disk immediately)
    provider.startStudyFocus(
      packages: _selectedPackages.toList(),
      duration: _selectedDuration,
    );

    // ── Bug fix #3: show overlay THEN navigate — don't block on overlay ───
    // Fire-and-forget: overlay display is async and can take a moment.
    // Navigate to home immediately so the challenge banner is visible.
    _launchOverlay();

    if (mounted) {
      setState(() => _starting = false);
      // Navigate back to home (not pop, push replacement so back stack is clean)
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    }
  }

  Future<void> _launchOverlay() async {
    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: 'Study Focus Active',
        overlayContent: 'Kripya apna challenge complete karein.',
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.center,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: WindowSize.fullCover,
        width: WindowSize.fullCover,
      );
    } catch (e) {
      debugPrint('[StudyFocus] Overlay launch failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final alreadyLocked = provider.isLocked;

    // Determine button state
    final bool canStart =
        _overlayGranted && !alreadyLocked && !_starting && _selectedPackages.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppTheme.bg,
            pinned: true,
            expandedHeight: 160,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Study Focus',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF0D0D1A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                    child: Text('📚', style: TextStyle(fontSize: 60))),
              ),
            ),
          ),

          // ── Already locked banner ──────────────────────────────────────
          if (alreadyLocked)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B9D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFFF6B9D).withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A challenge is already active. Complete or pay penalty to start a new one.',
                        style: TextStyle(
                            color: Color(0xFFFF6B9D),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Permission banners (only if checked and not granted) ───────
          if (_permChecked && !_overlayGranted)
            SliverToBoxAdapter(
              child: _PermBanner(
                icon: '🪟',
                title: 'Display Over Other Apps Required',
                subtitle:
                    'Without this, the lock screen cannot appear over blocked apps.',
                color: const Color(0xFFFF6B9D),
                onTap: _requestOverlayPermission,
              ),
            ),

          // ── Duration picker ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DurationSection(
              selected: _selectedDuration,
              enabled: !alreadyLocked,
              onChanged: alreadyLocked
                  ? null
                  : (d) => setState(() => _selectedDuration = d),
            ),
          ),

          // ── App list header ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  const Text('Apps to Lock',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_loadingIcons)
                    const _SmallLoadingBadge(
                        label: 'Loading icons…', color: Color(0xFF00E5FF)),
                  if (_selectedPackages.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _CountBadge(count: _selectedPackages.length),
                  ],
                ],
              ),
            ),
          ),

          // ── App list body ──────────────────────────────────────────────
          if (_loadingPhase1)
            const SliverFillRemaining(child: _AppLoadingState())
          else if (_loadError != null)
            SliverToBoxAdapter(
              child: _AppErrorState(
                error: _loadError!,
                onRetry: _loadPhase1,
                onOpenSettings: _openUsageAccessSettings,
              ),
            )
          else if (_apps.isEmpty)
            SliverToBoxAdapter(
              child: _AppEmptyState(onOpenSettings: _openUsageAccessSettings),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final app = _apps[index];
                    final isSelected =
                        _selectedPackages.contains(app.packageName);
                    return _AppTile(
                      app: app,
                      isSelected: isSelected,
                      disabled: alreadyLocked,
                      onTap: alreadyLocked
                          ? null
                          : () => setState(() {
                                if (isSelected) {
                                  _selectedPackages.remove(app.packageName);
                                } else {
                                  _selectedPackages.add(app.packageName);
                                }
                              }),
                    );
                  },
                  childCount: _apps.length,
                ),
              ),
            ),
        ],
      ),

      // ── Start / locked button ──────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: GestureDetector(
            onTap: (canStart && !_starting) ? _startFocus : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: canStart
                      ? [const Color(0xFF7C4DFF), const Color(0xFF5C6BC0)]
                      : alreadyLocked
                          ? [const Color(0xFFFF6B9D), const Color(0xFFFF8E53)]
                          : [Colors.grey.shade800, Colors.grey.shade700],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: canStart
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: _starting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      alreadyLocked
                          ? '🔒 Challenge Already Active'
                          : !_overlayGranted
                              ? '⚠️ Grant Overlay Permission First'
                              : _selectedPackages.isEmpty
                                  ? 'Select Apps to Continue'
                                  : '🔒 Start Study Focus',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Permission Banner ────────────────────────────────────────────────────────
class _PermBanner extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PermBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Grant',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Duration Section ─────────────────────────────────────────────────────────
class _DurationSection extends StatelessWidget {
  final Duration selected;
  final bool enabled;
  final ValueChanged<Duration>? onChanged;

  const _DurationSection({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final durations = [
      const Duration(minutes: 25),
      const Duration(minutes: 45),
      const Duration(hours: 1),
      const Duration(hours: 2),
      const Duration(hours: 3),
      const Duration(hours: 4),
    ];
    String label(Duration d) =>
        d.inMinutes < 60 ? '${d.inMinutes}m' : '${d.inHours}h';

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lock Duration',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: durations
                  .map((d) => GestureDetector(
                        onTap: enabled ? () => onChanged?.call(d) : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: selected == d
                                ? AppTheme.primary
                                : AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.primary.withOpacity(0.4)),
                          ),
                          child: Text(
                            label(d),
                            style: TextStyle(
                              color: selected == d
                                  ? Colors.white
                                  : AppTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading / Error / Empty states ──────────────────────────────────────────
class _AppLoadingState extends StatelessWidget {
  const _AppLoadingState();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text('Loading installed apps…',
              style: TextStyle(color: Colors.white54, fontSize: 14)),
          SizedBox(height: 6),
          Text('This takes a few seconds.',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}

class _AppErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  const _AppErrorState(
      {required this.error,
      required this.onRetry,
      required this.onOpenSettings});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Could not load apps:\n$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                  onPressed: onRetry, child: const Text('Retry')),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onOpenSettings,
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFFB74D),
                    side: const BorderSide(color: Color(0xFFFFB74D))),
                child: const Text('Usage Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppEmptyState extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _AppEmptyState({required this.onOpenSettings});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'No apps found.\n\nIf this device has apps, please grant\n"Usage Access" permission.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onOpenSettings,
            child: const Text('Open Usage Access Settings'),
          ),
        ],
      ),
    );
  }
}

class _SmallLoadingBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallLoadingBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: color),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count selected',
          style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─── App Tile ─────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final Application app;
  final bool isSelected;
  final bool disabled;
  final VoidCallback? onTap;

  const _AppTile({
    required this.app,
    required this.isSelected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appWithIcon =
        app is ApplicationWithIcon ? app as ApplicationWithIcon : null;

    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.15)
                : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary.withOpacity(0.5)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              // Icon
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: appWithIcon != null
                    ? Image.memory(appWithIcon.icon,
                        width: 44, height: 44, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultIcon())
                    : _defaultIcon(),
              ),
              const SizedBox(width: 14),
              // Name + package
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.appName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    Text(app.packageName,
                        style: const TextStyle(
                            color: Color(0xFF6666AA), fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Checkbox
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.android, color: Colors.white54, size: 24),
    );
  }
}
