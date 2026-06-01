import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:android_intent_plus/android_intent.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';

class StudyFocusScreen extends StatefulWidget {
  const StudyFocusScreen({super.key});

  @override
  State<StudyFocusScreen> createState() => _StudyFocusScreenState();
}

class _StudyFocusScreenState extends State<StudyFocusScreen> {
  // ── App list ───────────────────────────────────────────────────────────────
  List<AppInfo> _installedApps = [];

  // Icons stored separately — loaded in a second pass so the list appears fast.
  // Key: packageName → icon bytes.
  Map<String, Uint8List> _appIcons = {};

  final Set<String> _selectedPackages = {};
  Duration _selectedDuration = const Duration(hours: 1);
  bool _loadingApps = true;

  // ── Search ─────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) return _installedApps;
    final q = _searchQuery.toLowerCase();
    return _installedApps
        .where((a) =>
            a.name.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q))
        .toList();
  }

  // ── Permissions ────────────────────────────────────────────────────────────
  bool _overlayGranted = false;
  bool _usageGranted = false;
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Permission flow ────────────────────────────────────────────────────────

  Future<void> _requestAllPermissions() async {
    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) await FlutterOverlayWindow.requestPermission();
    final overlayNow = await FlutterOverlayWindow.isPermissionGranted();

    // Check PACKAGE_USAGE_STATS — Android-specific special permission.
    // We probe it by attempting to load apps; no runtime dialog exists for it.
    final usageNow = await _checkUsageStatsGranted();

    setState(() {
      _overlayGranted = overlayNow;
      _usageGranted = usageNow;
      _permissionsChecked = true;
    });

    await _loadApps();
  }

  Future<bool> _checkUsageStatsGranted() async {
    try {
      final apps = await InstalledApps.getInstalledApps(false, true);
      return apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openUsageAccessSettings() async {
    if (Platform.isAndroid) {
      const intent = AndroidIntent(
        action: 'android.settings.USAGE_ACCESS_SETTINGS',
      );
      await intent.launch();
    }
  }

  // ── App loading (two-phase) ────────────────────────────────────────────────
  //
  // Phase 1 — fast: load package names + app names WITHOUT icons.
  //   The list appears instantly with an Android icon fallback.
  //
  // Phase 2 — background: load the same list WITH icons and populate
  //   _appIcons. The list updates smoothly as icons arrive.

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);

    // Give the UI one frame to render the loading spinner before the
    // heavy platform channel call starts. Without this, the spinner never
    // appears and the screen looks frozen.
    await Future.delayed(const Duration(milliseconds: 32));

    try {
      // Phase 1: No icons — fast (~200–400 ms vs 3–8 s with icons)
      final apps = await InstalledApps.getInstalledApps(false, true);
      apps.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _loadingApps = false;
        });
      }

      // Phase 2: Load icons in the background — does NOT block the UI.
      _loadIconsInBackground();
    } catch (e) {
      if (mounted) setState(() => _loadingApps = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps: $e')),
        );
      }
    }
  }

  Future<void> _loadIconsInBackground() async {
    try {
      final withIcons = await InstalledApps.getInstalledApps(true, true);
      if (!mounted) return;
      final map = <String, Uint8List>{};
      for (final a in withIcons) {
        if (a.icon != null) map[a.packageName] = a.icon!;
      }
      setState(() => _appIcons = map);
    } catch (_) {
      // Icons are cosmetic — silently ignore failures.
    }
  }

  // ── Start focus ────────────────────────────────────────────────────────────

  Future<void> _startFocus() async {
    final provider = context.read<AppStateProvider>();

    // ── State lock guard ─────────────────────────────────────────────────────
    // Prevents starting a second session while one is already running.
    if (provider.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A session is already active. Wait for it to end.')),
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
            content: Text(
                '⚠️ "Display over other apps" permission is required.')),
      );
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    final billing = context.read<BillingService>();
    billing.onPurchaseSuccess = () {
      provider.unlockAll();
      if (mounted) {
        Navigator.popUntil(context, (r) => r.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Penalty paid — lock removed.')),
        );
      }
    };

    provider.startStudyFocus(
      packages: _selectedPackages.toList(),
      duration: _selectedDuration,
    );

    // The background AppMonitorService (started by main.dart's provider
    // listener) will show the overlay whenever a locked app is opened.
    // We just navigate back — no overlay shown here.
    if (mounted) Navigator.pop(context);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final isStudyActive =
        provider.activeChallenge == ChallengeType.studyFocus;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
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
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 20)),
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

          // ── Active session banner (state lock) ────────────────────────
          if (isStudyActive)
            SliverToBoxAdapter(
              child: _ActiveSessionBanner(provider: provider),
            ),

          // ── Permission banners (only when no session is active) ───────
          if (!isStudyActive && _permissionsChecked)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (!_overlayGranted)
                    _PermBanner(
                      icon: '🪟',
                      title: 'Display Over Other Apps Required',
                      subtitle:
                          'Needed to show the lock screen over blocked apps.',
                      color: const Color(0xFFFF6B9D),
                      onTap: () async {
                        await FlutterOverlayWindow.requestPermission();
                        final g =
                            await FlutterOverlayWindow.isPermissionGranted();
                        setState(() => _overlayGranted = g);
                      },
                    ),
                  if (!_usageGranted)
                    _PermBanner(
                      icon: '📊',
                      title: 'Usage Access Required',
                      subtitle:
                          'Allows the app to detect which app is open and lock it.',
                      color: const Color(0xFFFFB74D),
                      onTap: () async {
                        await _openUsageAccessSettings();
                        final g = await _checkUsageStatsGranted();
                        setState(() => _usageGranted = g);
                      },
                    ),
                ],
              ),
            ),

          // ── Duration picker (hidden when session active) ───────────────
          if (!isStudyActive)
            SliverToBoxAdapter(
              child: _DurationSection(
                selected: _selectedDuration,
                onChanged: (d) => setState(() => _selectedDuration = d),
              ),
            ),

          // ── App list header (hidden when session active) ───────────────
          if (!isStudyActive)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    const Text('Select Apps to Lock',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (_selectedPackages.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_selectedPackages.length} selected',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // ── Search bar ────────────────────────────────────────────────
          if (!isStudyActive && !_loadingApps && _installedApps.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search,
                        color: Colors.white38, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(Icons.close,
                                color: Colors.white38, size: 18),
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.cardBg,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppTheme.primary.withOpacity(0.5),
                          width: 1.5),
                    ),
                  ),
                ),
              ),
            ),

          // ── App list ──────────────────────────────────────────────────
          if (!isStudyActive)
            _loadingApps
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                              color: AppTheme.primary),
                          const SizedBox(height: 16),
                          const Text('Loading installed apps...',
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  )
                : _installedApps.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Text('📭',
                                  style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text(
                                'No apps found.\nPlease grant Usage Access permission.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _openUsageAccessSettings,
                                child: const Text(
                                    'Open Usage Access Settings'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredApps.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  const Text('🔍',
                                      style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No apps match "$_searchQuery"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 120),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, index) {
                                  final app = _filteredApps[index];
                                  final isSelected = _selectedPackages
                                      .contains(app.packageName);
                                  return _AppTile(
                                    app: app,
                                    icon: _appIcons[app.packageName],
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedPackages
                                              .remove(app.packageName);
                                        } else {
                                          _selectedPackages
                                              .add(app.packageName);
                                        }
                                      });
                                    },
                                  );
                                },
                                childCount: _filteredApps.length,
                              ),
                            ),
                          ),
        ],
      ),

      // ── Start button (hidden when session active) ───────────────────────
      bottomNavigationBar: isStudyActive
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: GestureDetector(
                  onTap: _startFocus,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _overlayGranted
                            ? [
                                const Color(0xFF7C4DFF),
                                const Color(0xFF5C6BC0)
                              ]
                            : [
                                Colors.grey.shade700,
                                Colors.grey.shade600
                              ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: _overlayGranted
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF)
                                    .withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _overlayGranted
                          ? '🔒 Start Study Focus'
                          : '⚠️ Grant Permissions First',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

// ─── Active Session Banner ────────────────────────────────────────────────────
class _ActiveSessionBanner extends StatelessWidget {
  final AppStateProvider provider;
  const _ActiveSessionBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final r = provider.remainingTime;
    final h = r.inHours.toString().padLeft(2, '0');
    final m = (r.inMinutes % 60).toString().padLeft(2, '0');
    final s = (r.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C4DFF), Color(0xFF5C6BC0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🔒 Session Active',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'A focus session is running. You cannot start\na new one until this timer reaches 00:00.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            '$h:$m:$s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: provider.progressFraction,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${provider.lockedPackages.length} app${provider.lockedPackages.length == 1 ? '' : 's'} locked',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
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
  final ValueChanged<Duration> onChanged;

  const _DurationSection(
      {required this.selected, required this.onChanged});

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

    return Padding(
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
                      onTap: () => onChanged(d),
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
                              color:
                                  AppTheme.primary.withOpacity(0.4)),
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
    );
  }
}

// ─── App Tile ─────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final AppInfo app;
  final Uint8List? icon; // Pre-fetched icon bytes; null = show fallback
  final bool isSelected;
  final VoidCallback onTap;

  const _AppTile({
    required this.app,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: icon != null
                  ? Image.memory(icon!,
                      width: 44, height: 44, fit: BoxFit.cover)
                  : Container(
                      width: 44,
                      height: 44,
                      color: AppTheme.surface,
                      child: const Icon(Icons.android,
                          color: Colors.white54, size: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name,
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
