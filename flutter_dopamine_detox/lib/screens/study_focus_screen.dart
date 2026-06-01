import 'package:android_intent_plus/android_intent_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';
import '../services/foreground_monitor_service.dart';
import 'home_screen.dart';

/// StudyFocusScreen
///
/// App loading strategy — WHY the previous version froze and missed apps:
///
///   FREEZE: DeviceApps.getInstalledApplications(includeAppIcons: true) encodes
///   every app icon as PNG bytes synchronously in Java before returning. On a
///   phone with 80–150 apps this can take 8–15 seconds. Even though Dart awaits
///   the call, the Android platform thread is fully occupied, so Flutter cannot
///   pump frames → the spinner itself freezes.
///
///   MISSING APPS (Instagram, Facebook etc.): On Android 11+ (API 30+) the OS
///   enforces package visibility filtering. Apps are hidden unless the manifest
///   declares either QUERY_ALL_PACKAGES permission OR <queries> entries for those
///   specific packages. Both are now present in AndroidManifest.xml.
///
///   FIX — three-phase progressive loading:
///     Phase 1 (fast, ~0.5–1 s): getInstalledApplications(includeAppIcons: false)
///             → display the full list immediately, user can start selecting.
///     Phase 2 (background enrichment): for each app call DeviceApps.getApp()
///             individually WITH icon, then setState() → icons fill in one by one
///             without blocking the UI thread for the entire batch.
///
///   Bug #4 — multiple timers: provider.isLocked is checked at the start of
///   _start() AND the entire form is wrapped in IgnorePointer when locked.
class StudyFocusScreen extends StatefulWidget {
  const StudyFocusScreen({super.key});

  @override
  State<StudyFocusScreen> createState() => _StudyFocusScreenState();
}

class _StudyFocusScreenState extends State<StudyFocusScreen>
    with WidgetsBindingObserver {

  // ── App list ───────────────────────────────────────────────────────────────
  // We keep a mutable map so individual apps can be updated with icons
  // progressively (phase 2) without rebuilding the whole list.
  final Map<String, Application> _apps = {};
  List<String> _orderedPkgs = [];       // display order
  bool _loadingPhase1 = true;
  int  _iconsLoaded   = 0;
  int  _totalApps     = 0;
  String? _loadError;

  // Cancelled when the widget is disposed, stopping icon loading if user leaves
  bool _disposed = false;

  // ── Selection & settings ───────────────────────────────────────────────────
  final Set<String> _selected = {};
  Duration _duration = const Duration(hours: 1);

  // ── Permissions ────────────────────────────────────────────────────────────
  bool _overlayGranted = false;
  bool _permChecked    = false;

  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkOverlay();
  }

  Future<void> _init() async {
    await _checkOverlay();
    await _loadApps();
  }

  // ── Overlay permission ─────────────────────────────────────────────────────

  Future<void> _checkOverlay() async {
    final g = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) setState(() { _overlayGranted = g; _permChecked = true; });
  }

  Future<void> _requestOverlay() async {
    await FlutterOverlayWindow.requestPermission();
    await _checkOverlay();
  }

  Future<void> _openUsageAccess() async {
    try {
      await const AndroidIntent(
              action: 'android.settings.USAGE_ACCESS_SETTINGS')
          .launch();
    } catch (_) {}
  }

  // ── Three-phase app loading ────────────────────────────────────────────────

  Future<void> _loadApps() async {
    if (!mounted) return;
    setState(() {
      _loadingPhase1 = true;
      _loadError     = null;
      _apps.clear();
      _orderedPkgs.clear();
      _iconsLoaded = 0;
      _totalApps   = 0;
    });

    try {
      // ── Phase 1: fast list, no icons (~0.5–1 s) ──────────────────────────
      // MUST run on main isolate — platform channel restriction.
      // UI shows spinner → list appears immediately after this await.
      final phase1 = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: true,         // show ALL apps, including system
        onlyAppsWithLaunchIntent: true,  // only launchable (has launcher icon)
      );

      _sortApps(phase1);

      if (!mounted || _disposed) return;
      setState(() {
        _loadingPhase1 = false;
        _totalApps     = phase1.length;
        for (final a in phase1) {
          _apps[a.packageName] = a;
          _orderedPkgs.add(a.packageName);
        }
      });

      // ── Phase 2: enrich with icons one-by-one ────────────────────────────
      // Loading all icons in one call blocks the Java thread for 8–15s.
      // Loading them individually is slower overall but non-blocking —
      // each getApp() call is fast (~5–20 ms) and yields between calls.
      for (final pkg in List<String>.from(_orderedPkgs)) {
        if (_disposed || !mounted) break;

        try {
          final withIcon = await DeviceApps.getApp(pkg, true);
          if (withIcon != null && mounted && !_disposed) {
            setState(() {
              _apps[pkg] = withIcon;
              _iconsLoaded++;
            });
          }
        } catch (_) {
          // Icon load failed for this app — skip, keep the icon-less entry
        }

        // Yield to the event loop between apps so the UI stays responsive
        await Future.delayed(Duration.zero);
      }

    } catch (e) {
      if (mounted) {
        setState(() { _loadingPhase1 = false; _loadError = '$e'; });
      }
    }
  }

  void _sortApps(List<Application> list) {
    list.sort((a, b) {
      // User-installed apps first, then system apps, both alphabetical
      if (a.systemApp != b.systemApp) return a.systemApp ? 1 : -1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
  }

  // ── Start focus — hard lock guard ─────────────────────────────────────────

  Future<void> _start() async {
    final provider = context.read<AppStateProvider>();

    // Bug #4 fix: hard guard — no second timer while one is running
    if (provider.isLocked) {
      _snack('⚠️ A challenge is already running. Wait for it to finish.');
      return;
    }
    if (_selected.isEmpty) {
      _snack('Select at least one app to block.');
      return;
    }
    if (!_overlayGranted) {
      _snack('Grant "Display over other apps" permission first.');
      await _requestOverlay();
      return;
    }

    setState(() => _starting = true);

    context.read<BillingService>().onPurchaseSuccess = () {
      provider.unlockAll();
      ForegroundMonitorService.stop();
    };

    provider.startStudyFocus(
      packages: _selected.toList(),
      duration: _duration,
    );

    await ForegroundMonitorService.start(_selected.toList());

    if (mounted) {
      setState(() => _starting = false);
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 350),
        ),
        (_) => false,
      );
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final locked   = provider.isLocked;

    final canStart =
        !locked && !_starting && _overlayGranted && _selected.isNotEmpty;

    // Progress of icon loading (shown in header)
    final iconPct = _totalApps == 0 ? 0.0 : _iconsLoaded / _totalApps;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── AppBar ─────────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: AppTheme.bg,
            pinned: true,
            expandedHeight: 150,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.glassWhite,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('App-Specific Lock',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7C4DFF), Color(0xFF0D0D1A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: const Center(
                    child: Text('📚', style: TextStyle(fontSize: 56))),
              ),
            ),
          ),

          // ── Info ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF7C4DFF).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Only selected apps are blocked. '
                      'All others remain usable. '
                      'Overlay appears ONLY when you open a blocked app.',
                      style: TextStyle(
                          color: Color(0xFFCCCCDD),
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Active lock warning ────────────────────────────────────────
          if (locked)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B9D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFF6B9D).withOpacity(0.3)),
                ),
                child: const Text(
                  '🔒 A session is already active.\n'
                  'Wait for 00:00 or pay the ₹99 penalty to stop early.',
                  style: TextStyle(
                      color: Color(0xFFFF6B9D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4),
                ),
              ),
            ),

          // ── Permissions ────────────────────────────────────────────────
          if (_permChecked && !_overlayGranted)
            SliverToBoxAdapter(
              child: _PermBanner(
                icon: '🪟',
                title: '"Display Over Apps" Permission',
                subtitle:
                    'Required for the lock screen to appear over blocked apps.',
                color: const Color(0xFFFF6B9D),
                onTap: _requestOverlay,
              ),
            ),

          SliverToBoxAdapter(
            child: _PermBanner(
              icon: '📊',
              title: 'Usage Access Permission',
              subtitle:
                  'Settings → Usage Access → enable Dopamine Detox.',
              color: const Color(0xFFFFB74D),
              onTap: _openUsageAccess,
            ),
          ),

          // ── Duration picker ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Opacity(
              opacity: locked ? 0.35 : 1.0,
              child: IgnorePointer(
                ignoring: locked,
                child: _DurationPicker(
                  selected: _duration,
                  onChanged: (d) => setState(() => _duration = d),
                ),
              ),
            ),
          ),

          // ── App list header ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Row(
                children: [
                  const Text('Apps to Block',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Icon loading progress
                  if (!_loadingPhase1 && _iconsLoaded < _totalApps) ...[
                    SizedBox(
                      width: 60,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: iconPct,
                          backgroundColor:
                              const Color(0xFF00E5FF).withOpacity(0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00E5FF)),
                          minHeight: 3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('$_iconsLoaded/$_totalApps',
                        style: const TextStyle(
                            color: Color(0xFF00E5FF), fontSize: 10)),
                  ],
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_selected.length} selected',
                          style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── App list body ──────────────────────────────────────────────
          if (_loadingPhase1)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 14),
                    Text('Loading installed apps…',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 14)),
                    SizedBox(height: 4),
                    Text(
                      'First load only — takes ~1 second.',
                      style: TextStyle(
                          color: Colors.white24, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else if (_loadError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 10),
                    Text('Could not load apps:\n$_loadError',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                            onPressed: _loadApps,
                            child: const Text('Retry')),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _openUsageAccess,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFB74D),
                              side: const BorderSide(
                                  color: Color(0xFFFFB74D))),
                          child: const Text('Usage Settings'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (_orderedPkgs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 10),
                    const Text(
                      'No apps found.\n\nPlease grant "Usage Access" permission '
                      'and restart the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                        onPressed: _openUsageAccess,
                        child: const Text('Open Usage Access')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _loadApps,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(
                              color: Color(0xFF00E5FF))),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final pkg = _orderedPkgs[i];
                    final app = _apps[pkg];
                    if (app == null) return const SizedBox.shrink();
                    final sel = _selected.contains(pkg);
                    return Opacity(
                      opacity: locked ? 0.35 : 1.0,
                      child: IgnorePointer(
                        ignoring: locked,
                        child: _AppTile(
                          app: app,
                          isSelected: sel,
                          onTap: () => setState(() =>
                              sel
                                  ? _selected.remove(pkg)
                                  : _selected.add(pkg)),
                        ),
                      ),
                    );
                  },
                  childCount: _orderedPkgs.length,
                ),
              ),
            ),
        ],
      ),

      // ── Start button ───────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: GestureDetector(
            onTap: canStart ? _start : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: canStart
                      ? [const Color(0xFF7C4DFF), const Color(0xFF5C6BC0)]
                      : locked
                          ? [
                              const Color(0xFFFF6B9D),
                              const Color(0xFFFF8E53)
                            ]
                          : [Colors.grey.shade800, Colors.grey.shade700],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: canStart
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF7C4DFF).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: _starting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      locked
                          ? '🔒 Session Already Active'
                          : !_overlayGranted
                              ? '⚠️ Grant Overlay Permission First'
                              : _selected.isEmpty
                                  ? 'Select Apps to Continue'
                                  : '🔒 Start App-Specific Focus',
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

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _PermBanner extends StatelessWidget {
  final String icon, title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PermBanner({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Grant',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ),
          ],
        ),
      );
}

class _DurationPicker extends StatelessWidget {
  final Duration selected;
  final ValueChanged<Duration> onChanged;
  const _DurationPicker(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = [
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lock Duration',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: opts
                .map((d) => GestureDetector(
                      onTap: () => onChanged(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        decoration: BoxDecoration(
                          color: selected == d
                              ? AppTheme.primary
                              : AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  AppTheme.primary.withOpacity(0.4)),
                        ),
                        child: Text(label(d),
                            style: TextStyle(
                                color: selected == d
                                    ? Colors.white
                                    : AppTheme.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final Application app;
  final bool isSelected;
  final VoidCallback? onTap;
  const _AppTile(
      {required this.app,
       required this.isSelected,
       required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon =
        app is ApplicationWithIcon ? app as ApplicationWithIcon : null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.14)
              : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            // App icon — shows placeholder until phase-2 icon arrives
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: icon != null
                  ? Image.memory(
                      icon.icon,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.appName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(app.packageName,
                      style: const TextStyle(
                          color: Color(0xFF6666AA), fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : Colors.white.withOpacity(0.28),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 15)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(9)),
        child:
            const Icon(Icons.android, color: Colors.white38, size: 22),
      );
}
