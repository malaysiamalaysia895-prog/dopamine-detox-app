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

/// StudyFocusScreen — app selection + start focus.
///
/// Bug #1 fix — why compute() failed:
///   DeviceApps.getInstalledApplications() is a Flutter platform channel call.
///   Platform channels can ONLY run on the main Dart isolate.
///   compute() spawns a background Dart isolate → platform channel call throws
///   MissingPluginException or hangs indefinitely.
///   Fix: plain async/await on the main isolate. Flutter's event loop is
///   cooperative — the async call yields to the UI thread between steps,
///   so the spinner renders fine while the list loads.
///
/// Bug #4 fix — multiple timers:
///   provider.isLocked hard-blocks the Start button AND disables all
///   form inputs (duration chips + app checkboxes).
class StudyFocusScreen extends StatefulWidget {
  const StudyFocusScreen({super.key});

  @override
  State<StudyFocusScreen> createState() => _StudyFocusScreenState();
}

class _StudyFocusScreenState extends State<StudyFocusScreen>
    with WidgetsBindingObserver {

  // ── App list ───────────────────────────────────────────────────────────────
  List<Application> _apps = [];
  bool _loadingApps = true;
  bool _loadingIcons = false;  // second pass to load icons
  String? _loadError;

  // ── Selection ──────────────────────────────────────────────────────────────
  final Set<String> _selected = {};
  Duration _duration = const Duration(hours: 1);

  // ── Permission flags ───────────────────────────────────────────────────────
  bool _overlayGranted = false;
  bool _permChecked = false;

  // ── UI ─────────────────────────────────────────────────────────────────────
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

  // ── Overlay permission check ───────────────────────────────────────────────

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

  // ── App loading — plain async on main isolate ─────────────────────────────
  // Bug #1 fix: NO compute(). Just await the platform channel call directly.
  // The spinner is shown via setState before the call, and hidden after.

  Future<void> _loadApps() async {
    setState(() { _loadingApps = true; _loadError = null; });

    try {
      // Phase 1: load without icons — fast (~1–2 seconds)
      final phase1 = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: true,          // ALL apps including system ones
        onlyAppsWithLaunchIntent: true,   // only launchable apps
      );
      _sortApps(phase1);

      if (!mounted) return;
      setState(() {
        _apps = phase1;
        _loadingApps = false;
        _loadingIcons = true;  // second pass coming
      });

      // Phase 2: reload WITH icons — heavier, but now shows list first
      final phase2 = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,
        onlyAppsWithLaunchIntent: true,
      );
      _sortApps(phase2);

      if (!mounted) return;
      setState(() {
        _apps = phase2;
        _loadingIcons = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() { _loadingApps = false; _loadError = '$e'; });
      }
    }
  }

  void _sortApps(List<Application> list) {
    list.sort((a, b) {
      if (a.systemApp != b.systemApp) return a.systemApp ? 1 : -1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
  }

  // ── Start focus — Bug #4: hard lock once started ───────────────────────────

  Future<void> _start() async {
    final provider = context.read<AppStateProvider>();

    // ── Hard guard: cannot start if already locked ────────────────────────────
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

    // Wire billing
    context.read<BillingService>().onPurchaseSuccess = () {
      provider.unlockAll();
      ForegroundMonitorService.stop();
    };

    // Persist state (wall-clock timer starts here)
    provider.startStudyFocus(
      packages: _selected.toList(),
      duration: _duration,
    );

    // Start Kotlin foreground monitoring service
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();

    // Bug #4: lock entire screen when a challenge is active
    final locked = provider.isLocked;
    final canStart =
        !locked && !_starting && _overlayGranted && _selected.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── AppBar ────────────────────────────────────────────────────
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

          // ── Info card ─────────────────────────────────────────────────
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
                      'Only the selected apps will be blocked. '
                      'All other apps work normally. '
                      'The overlay appears ONLY when you open a blocked app.',
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

          // ── Active lock warning (Bug #4) ──────────────────────────────
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
                  'Wait for the timer to reach 00:00 or pay the ₹99 penalty to stop early.',
                  style: TextStyle(
                      color: Color(0xFFFF6B9D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4),
                ),
              ),
            ),

          // ── Permissions ───────────────────────────────────────────────
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
                  'Opens Settings → Usage Access. Enable for Dopamine Detox.',
              color: const Color(0xFFFFB74D),
              onTap: _openUsageAccess,
            ),
          ),

          // ── Duration picker — disabled when locked ────────────────────
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

          // ── App list header ───────────────────────────────────────────
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
                  if (_loadingIcons) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00E5FF)),
                    ),
                    const SizedBox(width: 5),
                    const Text('Loading icons…',
                        style: TextStyle(
                            color: Color(0xFF00E5FF), fontSize: 11)),
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

          // ── App list ──────────────────────────────────────────────────
          if (_loadingApps)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 14),
                    Text('Loading all installed apps…',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 14)),
                    SizedBox(height: 4),
                    Text('This may take a few seconds.',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 12)),
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
          else if (_apps.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 10),
                    const Text(
                      'No apps found.\n\nPlease grant "Usage Access" permission.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                        onPressed: _openUsageAccess,
                        child: const Text('Open Usage Access Settings')),
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
                    final app = _apps[i];
                    final sel = _selected.contains(app.packageName);
                    return Opacity(
                      opacity: locked ? 0.35 : 1.0,
                      child: _AppTile(
                        app: app,
                        isSelected: sel,
                        onTap: locked
                            ? null
                            : () => setState(() => sel
                                ? _selected.remove(app.packageName)
                                : _selected.add(app.packageName)),
                      ),
                    );
                  },
                  childCount: _apps.length,
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

// ─── Permission Banner ────────────────────────────────────────────────────────
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

// ─── Duration Picker ──────────────────────────────────────────────────────────
class _DurationPicker extends StatelessWidget {
  final Duration selected;
  final ValueChanged<Duration> onChanged;
  const _DurationPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = [
      const Duration(minutes: 25), const Duration(minutes: 45),
      const Duration(hours: 1),    const Duration(hours: 2),
      const Duration(hours: 3),    const Duration(hours: 4),
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
                              color: AppTheme.primary.withOpacity(0.4)),
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

// ─── App Tile ─────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final Application app;
  final bool isSelected;
  final VoidCallback? onTap;
  const _AppTile(
      {required this.app, required this.isSelected, required this.onTap});

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
            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: icon != null
                  ? Image.memory(icon.icon,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            // Text
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
                color:
                    isSelected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primary
                      : Colors.white.withOpacity(0.28),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 15)
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
        child: const Icon(Icons.android, color: Colors.white38, size: 22),
      );
}
