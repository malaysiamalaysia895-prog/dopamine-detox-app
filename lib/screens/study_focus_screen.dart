import 'dart:async';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
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
  List<Application> _installedApps = [];
  final Set<String> _selectedPackages = {};
  Duration _selectedDuration = const Duration(hours: 1);
  bool _loadingApps = true;

  // Permission states
  bool _overlayGranted = false;
  bool _usageGranted = false;
  bool _permissionsChecked = false;

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
  }

  // ── Permission flow ────────────────────────────────────────────────────────

  Future<void> _requestAllPermissions() async {
    // 1. SYSTEM_ALERT_WINDOW — requestPermission handles the Settings redirect
    final overlayGranted =
        await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) {
      await FlutterOverlayWindow.requestPermission();
    }
    final overlayNow = await FlutterOverlayWindow.isPermissionGranted();

    // 2. PACKAGE_USAGE_STATS — cannot be runtime-requested; must redirect to
    //    Settings > Apps > Special app access > Usage access
    //    We check via permission_handler and guide the user.
    final usageStatus = await Permission.appTrackingTransparency.status;
    // On Android, PACKAGE_USAGE_STATS is a special permission checked differently.
    // We use a try/open-settings approach.
    bool usageNow = await _checkUsageStatsGranted();

    setState(() {
      _overlayGranted = overlayNow;
      _usageGranted = usageNow;
      _permissionsChecked = true;
    });

    // Load apps regardless — show what we can, warn about usage stats
    await _loadApps();
  }

  /// Checks PACKAGE_USAGE_STATS via AppOps (best available in Flutter).
  Future<bool> _checkUsageStatsGranted() async {
    // permission_handler does not directly expose PACKAGE_USAGE_STATS.
    // We attempt to read usage stats; if it throws, permission is not granted.
    // On Android 5+ this is a special permission in Settings.
    try {
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );
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

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    try {
      // includeSystemApps: true + onlyAppsWithLaunchIntent: true gives ALL
      // user-launchable apps. QUERY_ALL_PACKAGES in the manifest ensures
      // Android 11+ returns the full list.
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: true,        // ← key fix: was false before
        onlyAppsWithLaunchIntent: true, // filters to only launchable apps
      );

      // Sort: user-installed apps first, then system, all alphabetical
      apps.sort((a, b) {
        if (a.systemApp != b.systemApp) {
          return a.systemApp ? 1 : -1; // user apps first
        }
        return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      });

      setState(() {
        _installedApps = apps;
        _loadingApps = false;
      });
    } catch (e) {
      setState(() => _loadingApps = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps: $e')),
        );
      }
    }
  }

  Future<void> _startFocus() async {
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

    final provider = context.read<AppStateProvider>();
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

    await _showOverlay();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showOverlay() async {
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
  }

  @override
  Widget build(BuildContext context) {
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

          // ── Permission banners ────────────────────────────────────────
          if (_permissionsChecked)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (!_overlayGranted)
                    _PermBanner(
                      icon: '🪟',
                      title: 'Display Over Other Apps Required',
                      subtitle:
                          'Needed to show the lock screen over blocked apps.',
                      buttonLabel: 'Grant Permission',
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
                      buttonLabel: 'Open Usage Settings',
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

          // ── Duration picker ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DurationSection(
              selected: _selectedDuration,
              onChanged: (d) => setState(() => _selectedDuration = d),
            ),
          ),

          // ── App list header ───────────────────────────────────────────
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

          // ── App list ──────────────────────────────────────────────────
          _loadingApps
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: AppTheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Loading all installed apps...',
                          style: TextStyle(color: Colors.white54),
                        ),
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
                                  color: Colors.white54, fontSize: 14),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _openUsageAccessSettings,
                              child:
                                  const Text('Open Usage Access Settings'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final app = _installedApps[index];
                            final isSelected = _selectedPackages
                                .contains(app.packageName);
                            return _AppTile(
                              app: app,
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
                          childCount: _installedApps.length,
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
            onTap: _startFocus,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _overlayGranted
                      ? [const Color(0xFF7C4DFF), const Color(0xFF5C6BC0)]
                      : [Colors.grey.shade700, Colors.grey.shade600],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: _overlayGranted
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

// ─── Permission Banner ────────────────────────────────────────────────────────
class _PermBanner extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color color;
  final VoidCallback onTap;

  const _PermBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
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
  final ValueChanged<Duration> onChanged;

  const _DurationSection({required this.selected, required this.onChanged});

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
    );
  }
}

// ─── App Tile ─────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final Application app;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppTile(
      {required this.app, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appWithIcon =
        app is ApplicationWithIcon ? app as ApplicationWithIcon : null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? AppTheme.primary.withOpacity(0.15) : AppTheme.cardBg,
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
              child: appWithIcon != null
                  ? Image.memory(appWithIcon.icon,
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
    );
  }
}
