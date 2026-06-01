import 'package:android_intent_plus/android_intent_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/app_state_provider.dart';
import '../services/billing_service.dart';
import '../services/foreground_monitor_service.dart';
import 'home_screen.dart';

// ─── Background isolate: load apps without blocking UI ───────────────────────
Future<List<Application>> _loadAppsInBackground(bool withIcons) {
  return DeviceApps.getInstalledApplications(
    includeAppIcons: withIcons,
    includeSystemApps: true,
    onlyAppsWithLaunchIntent: true,
  );
}

class StudyFocusScreen extends StatefulWidget {
  const StudyFocusScreen({super.key});

  @override
  State<StudyFocusScreen> createState() => _StudyFocusScreenState();
}

class _StudyFocusScreenState extends State<StudyFocusScreen>
    with WidgetsBindingObserver {

  // ── App list ───────────────────────────────────────────────────────────────
  List<Application> _apps = [];
  bool _loadingPhase1 = true;
  bool _loadingIcons = false;
  String? _loadError;

  // ── Selection ──────────────────────────────────────────────────────────────
  final Set<String> _selected = {};
  Duration _selectedDuration = const Duration(hours: 1);

  // ── Permissions ────────────────────────────────────────────────────────────
  bool _overlayGranted = false;
  bool _permChecked = false;

  // ── UI state ───────────────────────────────────────────────────────────────
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
    await _loadPhase1();
  }

  // ── Permission ─────────────────────────────────────────────────────────────

  Future<void> _checkOverlay() async {
    final g = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) setState(() { _overlayGranted = g; _permChecked = true; });
  }

  Future<void> _requestOverlay() async {
    await FlutterOverlayWindow.requestPermission();
    await _checkOverlay();
  }

  Future<void> _openUsageAccess() async {
    const intent =
        AndroidIntent(action: 'android.settings.USAGE_ACCESS_SETTINGS');
    try { await intent.launch(); } catch (_) {}
  }

  // ── App loading — two-phase ────────────────────────────────────────────────

  Future<void> _loadPhase1() async {
    setState(() { _loadingPhase1 = true; _loadError = null; });
    try {
      final apps = await compute(_loadAppsInBackground, false);
      _sort(apps);
      if (mounted) {
        setState(() {
          _apps = apps;
          _loadingPhase1 = false;
          _loadingIcons = true;
        });
      }
      _loadPhase2(); // fire-and-forget
    } catch (e) {
      if (mounted) setState(() { _loadingPhase1 = false; _loadError = '$e'; });
    }
  }

  Future<void> _loadPhase2() async {
    try {
      final apps = await compute(_loadAppsInBackground, true);
      _sort(apps);
      if (mounted) setState(() { _apps = apps; _loadingIcons = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingIcons = false);
    }
  }

  void _sort(List<Application> apps) {
    apps.sort((a, b) {
      if (a.systemApp != b.systemApp) return a.systemApp ? 1 : -1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });
  }

  // ── Start focus ────────────────────────────────────────────────────────────

  Future<void> _start() async {
    final provider = context.read<AppStateProvider>();

    if (provider.isLocked) {
      _snack('⚠️ A challenge is already active.');
      return;
    }
    if (_selected.isEmpty) {
      _snack('Please select at least one app to block.');
      return;
    }
    if (!_overlayGranted) {
      _snack('Grant "Display over other apps" permission first.');
      await _requestOverlay();
      return;
    }

    setState(() => _starting = true);

    // Wire billing callback
    final billing = context.read<BillingService>();
    billing.onPurchaseSuccess = () {
      provider.unlockAll();
      ForegroundMonitorService.stop();
    };

    // Save state & start wall-clock timer
    provider.startStudyFocus(
      packages: _selected.toList(),
      duration: _selectedDuration,
    );

    // Start the native Kotlin foreground monitor service
    await ForegroundMonitorService.start(_selected.toList());

    if (mounted) {
      setState(() => _starting = false);
      // Navigate to HomeScreen — overlay is managed there
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
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
    final locked = provider.isLocked;
    final canStart =
        _overlayGranted && !locked && !_starting && _selected.isNotEmpty;

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
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('App-Specific Lock',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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

          // ── How it works card ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF7C4DFF).withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only the apps you select will be blocked.\n'
                      'All other apps work normally. '
                      'Opening a blocked app shows the lock overlay.',
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

          // ── Already locked warning ─────────────────────────────────────
          if (locked)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B9D).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFF6B9D).withOpacity(0.3)),
                ),
                child: const Text(
                  '🔒 A challenge is already active. Complete or pay penalty first.',
                  style: TextStyle(
                      color: Color(0xFFFF6B9D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

          // ── Overlay permission banner ──────────────────────────────────
          if (_permChecked && !_overlayGranted)
            SliverToBoxAdapter(
              child: _PermBanner(
                icon: '🪟',
                title: '"Display Over Other Apps" Required',
                subtitle:
                    'Without this, the lock screen cannot appear over blocked apps.',
                color: const Color(0xFFFF6B9D),
                onTap: _requestOverlay,
              ),
            ),

          // ── Usage access banner ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _PermBanner(
              icon: '📊',
              title: 'Usage Access Required',
              subtitle:
                  'Tap to open Settings → Usage Access → Enable for Dopamine Detox.',
              color: const Color(0xFFFFB74D),
              onTap: _openUsageAccess,
            ),
          ),

          // ── Duration picker ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DurationSection(
              selected: _selectedDuration,
              enabled: !locked,
              onChanged:
                  locked ? null : (d) => setState(() => _selectedDuration = d),
            ),
          ),

          // ── App list header ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  const Text('Select Apps to Block',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_loadingIcons)
                    const _LoadingBadge(),
                  if (_selected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _CountBadge(count: _selected.length),
                  ],
                ],
              ),
            ),
          ),

          // ── App list body ──────────────────────────────────────────────
          if (_loadingPhase1)
            const SliverFillRemaining(child: _LoadingState())
          else if (_loadError != null)
            SliverToBoxAdapter(
              child: _ErrorState(
                error: _loadError!,
                onRetry: _loadPhase1,
                onSettings: _openUsageAccess,
              ),
            )
          else if (_apps.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyState(onSettings: _openUsageAccess),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final app = _apps[i];
                    final sel = _selected.contains(app.packageName);
                    return _AppTile(
                      app: app,
                      isSelected: sel,
                      disabled: locked,
                      onTap: locked
                          ? null
                          : () => setState(() {
                                sel
                                    ? _selected.remove(app.packageName)
                                    : _selected.add(app.packageName);
                              }),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: GestureDetector(
            onTap: (canStart && !_starting) ? _start : null,
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
                          ? '🔒 Challenge Already Active'
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700, fontSize: 12)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('Grant',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 11)),
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
  const _DurationSection(
      {required this.selected, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opts = [
      const Duration(minutes: 25), const Duration(minutes: 45),
      const Duration(hours: 1), const Duration(hours: 2),
      const Duration(hours: 3), const Duration(hours: 4),
    ];
    String label(Duration d) =>
        d.inMinutes < 60 ? '${d.inMinutes}m' : '${d.inHours}h';

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lock Duration',
                style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: opts.map((d) => GestureDetector(
                onTap: enabled ? () => onChanged?.call(d) : null,
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
                              ? Colors.white : AppTheme.primary,
                          fontWeight: FontWeight.w700)),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading / Error / Empty states ──────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 14),
            Text('Loading apps…',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            SizedBox(height: 4),
            Text('May take a few seconds.',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry, onSettings;
  const _ErrorState(
      {required this.error, required this.onRetry, required this.onSettings});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const Text('⚠️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text('Could not load apps:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: onSettings,
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFFB74D),
                  side: const BorderSide(color: Color(0xFFFFB74D))),
              child: const Text('Usage Settings'),
            ),
          ]),
        ]),
      );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onSettings;
  const _EmptyState({required this.onSettings});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const Text('📭', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          const Text(
            'No apps found.\n\nGrant "Usage Access" permission so the app can read your installed apps.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
              onPressed: onSettings,
              child: const Text('Open Usage Access Settings')),
        ]),
      );
}

class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: const Color(0xFF00E5FF)),
          ),
          const SizedBox(width: 5),
          const Text('Loading icons…',
              style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11)),
        ],
      );
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10)),
        child: Text('$count selected',
            style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

// ─── App Tile ─────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final Application app;
  final bool isSelected, disabled;
  final VoidCallback? onTap;
  const _AppTile(
      {required this.app, required this.isSelected,
       required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = app is ApplicationWithIcon ? app as ApplicationWithIcon : null;
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
          child: Row(children: [
            // App icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: icon != null
                  ? Image.memory(icon.icon,
                      width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
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
              width: 26, height: 26,
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
          ]),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.android, color: Colors.white38, size: 24),
      );
}
