import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F14),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const InstaAdBlockerApp());
}

class InstaAdBlockerApp extends StatelessWidget {
  const InstaAdBlockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shorts & Ad Shield',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE1306C),
          secondary: Color(0xFF833AB4),
          tertiary: Color(0xFFF77737),
          surface: Color(0xFF161822),
          surfaceContainerHighest: Color(0xFF222638),
          onPrimary: Colors.white,
          onSurface: Color(0xFFEDEDED),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF161822),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF262A3D), width: 1),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isServiceEnabled = false;
  bool _masterEnabled = true;
  String _blockAction = 'back';
  int _skipCount = 0;
  int _cooldownMs = 600;
  Timer? _refreshTimer;
  Timer? _breakTimer;
  bool _isLoading = true;

  // Mindful Break
  bool _isBreakActive = false;
  int _remainingBreakSeconds = 0;

  // Individual App Toggles
  bool _instagramAds = true;
  bool _instagramReels = true;
  bool _youtubeShorts = true;
  bool _snapchatSpotlight = true;
  bool _facebookReels = true;
  bool _tiktok = false;
  bool _redditShorts = false;
  bool _xShorts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadState();

    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _silentRefresh();
    });

    _breakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isBreakActive && _remainingBreakSeconds > 0) {
        setState(() {
          _remainingBreakSeconds--;
          if (_remainingBreakSeconds <= 0) {
            _isBreakActive = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _breakTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadState();
    }
  }

  Future<void> _loadState() async {
    final serviceEnabled = await NativeBridge.isServiceEnabled();
    final count = await NativeBridge.getCount();
    final settings = await NativeBridge.getAllSettings();

    if (mounted) {
      setState(() {
        _isServiceEnabled = serviceEnabled;
        _skipCount = count;
        _masterEnabled = settings['master'] as bool? ?? true;
        _blockAction = settings['blockAction'] as String? ?? 'back';
        _cooldownMs = settings['cooldownMs'] as int? ?? 600;

        _instagramAds = settings['instagramAds'] as bool? ?? true;
        _instagramReels = settings['instagramReels'] as bool? ?? true;
        _youtubeShorts = settings['youtubeShorts'] as bool? ?? true;
        _snapchatSpotlight = settings['snapchatSpotlight'] as bool? ?? true;
        _facebookReels = settings['facebookReels'] as bool? ?? true;
        _tiktok = settings['tiktok'] as bool? ?? false;
        _redditShorts = settings['redditShorts'] as bool? ?? false;
        _xShorts = settings['xShorts'] as bool? ?? false;

        _isBreakActive = settings['isBreakActive'] as bool? ?? false;
        _remainingBreakSeconds = (settings['remainingBreakSeconds'] as num?)?.toInt() ?? 0;

        _isLoading = false;
      });
    }
  }

  Future<void> _silentRefresh() async {
    final serviceEnabled = await NativeBridge.isServiceEnabled();
    final count = await NativeBridge.getCount();
    final breakStatus = await NativeBridge.getBreakStatus();
    final isBreak = breakStatus['isBreakActive'] as bool? ?? false;
    final rem = (breakStatus['remainingSeconds'] as num?)?.toInt() ?? 0;

    if (mounted) {
      if (_isServiceEnabled != serviceEnabled ||
          _skipCount != count ||
          _isBreakActive != isBreak ||
          (_remainingBreakSeconds - rem).abs() > 3) {
        setState(() {
          _isServiceEnabled = serviceEnabled;
          _skipCount = count;
          _isBreakActive = isBreak;
          _remainingBreakSeconds = rem;
        });
      }
    }
  }

  Future<void> _startBreak(int minutes) async {
    await NativeBridge.startBreak(minutes);
    setState(() {
      _isBreakActive = true;
      _remainingBreakSeconds = minutes * 60;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mindful break started for $minutes minutes! Shield paused.'),
          backgroundColor: const Color(0xFFF77737),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _cancelBreak() async {
    await NativeBridge.cancelBreak();
    setState(() {
      _isBreakActive = false;
      _remainingBreakSeconds = 0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Break ended! Shield re-engaged.'),
          backgroundColor: Color(0xFF20BF6B),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCustomBreakDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.timer_rounded, color: Color(0xFFF77737)),
            SizedBox(width: 8),
            Text('Custom Break Duration'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter duration in minutes to temporarily pause the short blocker:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'e.g. 7',
                suffixText: 'min',
                filled: true,
                fillColor: const Color(0xFF0F1018),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2B2E42)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF77737)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF77737),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final mins = int.tryParse(controller.text.trim()) ?? 0;
              if (mins > 0) {
                Navigator.pop(ctx);
                _startBreak(mins);
              }
            },
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      switch (key) {
        case 'master':
          _masterEnabled = value as bool;
          break;
        case 'blockAction':
          _blockAction = value as String;
          break;
        case 'cooldownMs':
          _cooldownMs = value as int;
          break;
        case 'instagramAds':
          _instagramAds = value as bool;
          break;
        case 'instagramReels':
          _instagramReels = value as bool;
          break;
        case 'youtubeShorts':
          _youtubeShorts = value as bool;
          break;
        case 'snapchatSpotlight':
          _snapchatSpotlight = value as bool;
          break;
        case 'facebookReels':
          _facebookReels = value as bool;
          break;
        case 'tiktok':
          _tiktok = value as bool;
          break;
        case 'redditShorts':
          _redditShorts = value as bool;
          break;
        case 'xShorts':
          _xShorts = value as bool;
          break;
      }
    });

    if (key == 'master') {
      await NativeBridge.setEnabled(value as bool);
    } else {
      await NativeBridge.setSetting(key, value);
    }
  }

  Future<void> _resetCounter() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Reset Counter?'),
        content: const Text('This will reset your total blocked & skipped count to zero.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE1306C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await NativeBridge.resetCount();
      setState(() => _skipCount = 0);
    }
  }

  void _showLogsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const LogsModalSheet(),
    );
  }

  void _showHierarchyDumpDialog() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Capturing active screen layout...'), duration: Duration(seconds: 1)),
    );
    final dump = await NativeBridge.triggerDump();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161824),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.code_rounded, color: Color(0xFFF77737)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Active Screen Dump', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: 'Copy Dump',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: dump));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hierarchy copied to clipboard!')),
                );
              },
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 380,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                dump,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF90CAF9)),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFE1306C))),
      );
    }

    final savedMinutes = (_skipCount * 15 / 60).toStringAsFixed(1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF833AB4), Color(0xFFE1306C), Color(0xFFF77737)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shorts & Ad Shield',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                ),
                Text(
                  'Multi-Platform Short Video Blocker',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Live Activity Logs',
            onPressed: _showLogsBottomSheet,
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Screen Inspector',
            onPressed: _showHierarchyDumpDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadState,
        color: const Color(0xFFE1306C),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Accessibility Service Status Banner
              _buildServiceStatusCard(),

              const SizedBox(height: 14),

              // 2. Master Shield Switch
              _buildMasterSwitchCard(),

              const SizedBox(height: 14),

              // 2.5 Mindful Break Card
              _buildMindfulBreakCard(),

              const SizedBox(height: 14),

              // 3. Impact Stats Card
              _buildStatsDashboard(savedMinutes),

              const SizedBox(height: 14),

              // 4. Block Action Selector (Back vs Swipe)
              _buildBlockActionCard(),

              const SizedBox(height: 14),

              // 5. Individual Platform Controls
              _buildPlatformControlsSection(),

              const SizedBox(height: 14),

              // 6. Quick Launch & Battery Bar
              _buildQuickActions(),

              const SizedBox(height: 14),

              // 7. Setup Guide Card
              _buildSetupInstructionsCard(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    final isWorking = _isServiceEnabled && _masterEnabled;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWorking
              ? [const Color(0xFF103322), const Color(0xFF0C2418)]
              : [const Color(0xFF381A1A), const Color(0xFF241010)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWorking ? const Color(0xFF1E6F43) : const Color(0xFF8B2525),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isWorking ? const Color(0xFF20BF6B).withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWorking ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: isWorking ? const Color(0xFF20BF6B) : const Color(0xFFFF6B6B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isServiceEnabled ? 'Shield Active & Protecting' : 'Accessibility Permission Required',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isWorking ? const Color(0xFF20BF6B) : const Color(0xFFFF8585),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isServiceEnabled
                          ? (_masterEnabled ? 'Monitoring YouTube, Instagram, Snapchat & more' : 'Shield is paused')
                          : 'Grant Accessibility so the shield can detect and block shorts',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isServiceEnabled) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE1306C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.settings_accessibility_rounded, size: 18),
                label: const Text('Enable Accessibility Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () async => await NativeBridge.openAccessibilitySettings(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMasterSwitchCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _masterEnabled ? const Color(0xFFE1306C).withValues(alpha: 0.15) : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shield_rounded,
                color: _masterEnabled ? const Color(0xFFE1306C) : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Master Shield', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    _masterEnabled ? 'All active short-video blockers enabled' : 'Shield paused for all platforms',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Switch(
              value: _masterEnabled,
              activeThumbColor: const Color(0xFFE1306C),
              activeTrackColor: const Color(0xFFE1306C).withValues(alpha: 0.4),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.white12,
              onChanged: (val) => _updateSetting('master', val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMindfulBreakCard() {
    final minutesLeft = _remainingBreakSeconds ~/ 60;
    final secondsLeft = _remainingBreakSeconds % 60;
    final timeFormatted = '${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isBreakActive
                        ? const Color(0xFFF77737).withValues(alpha: 0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isBreakActive ? Icons.coffee_rounded : Icons.coffee_outlined,
                    color: _isBreakActive ? const Color(0xFFF77737) : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isBreakActive ? 'Break Active ($timeFormatted)' : 'Take a Mindful Break',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: _isBreakActive ? const Color(0xFFF77737) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isBreakActive
                            ? 'Shield is paused. Re-engages automatically in $timeFormatted'
                            : 'Temporarily pause blockers for a set duration',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_isBreakActive)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B6B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('End Break', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _cancelBreak,
                  ),
              ],
            ),
            if (!_isBreakActive) ...[
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildBreakChip(5, '5 min'),
                    const SizedBox(width: 8),
                    _buildBreakChip(10, '10 min'),
                    const SizedBox(width: 8),
                    _buildBreakChip(15, '15 min'),
                    const SizedBox(width: 8),
                    _buildBreakChip(30, '30 min'),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFFF77737)),
                      label: const Text('Custom', style: TextStyle(fontSize: 12, color: Colors.white)),
                      backgroundColor: const Color(0xFF141622),
                      side: const BorderSide(color: Color(0xFF2A2E44)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onPressed: _showCustomBreakDialog,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreakChip(int minutes, String label) {
    return ActionChip(
      avatar: const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFF77737)),
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: const Color(0xFF141622),
      side: const BorderSide(color: Color(0xFF2A2E44)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: () => _startBreak(minutes),
    );
  }

  Widget _buildStatsDashboard(String savedMinutes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Distraction Impact', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFC0C4D6))),
                if (_skipCount > 0)
                  GestureDetector(
                    onTap: _resetCounter,
                    child: const Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: Colors.grey),
                        SizedBox(width: 3),
                        Text('Reset', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1018),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF232738)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shorts & Ads Blocked', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '$_skipCount',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE1306C)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1018),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF232738)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Time Saved', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              savedMinutes,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFF77737)),
                            ),
                            const SizedBox(width: 4),
                            const Text('min', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockActionCard() {
    final isBack = _blockAction == 'back';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('When a Short / Reel Opens', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            const Text('Choose how the shield should intervene when you open a short', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _updateSetting('blockAction', 'back'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: isBack ? const Color(0xFFE1306C).withValues(alpha: 0.18) : const Color(0xFF0E1017),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBack ? const Color(0xFFE1306C) : const Color(0xFF25293C),
                          width: isBack ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.arrow_back_rounded, color: isBack ? const Color(0xFFE1306C) : Colors.grey, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            'Auto-Exit (Back)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isBack ? Colors.white : Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          const Text('Kicks you to feed (Best)', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _updateSetting('blockAction', 'skip'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        color: !isBack ? const Color(0xFFF77737).withValues(alpha: 0.18) : const Color(0xFF0E1017),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !isBack ? const Color(0xFFF77737) : const Color(0xFF25293C),
                          width: !isBack ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.swipe_up_rounded, color: !isBack ? const Color(0xFFF77737) : Colors.grey, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            'Auto-Skip (Swipe)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: !isBack ? Colors.white : Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          const Text('Fast-forwards past', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!isBack) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Skip Cooldown', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text('${_cooldownMs}ms', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF77737))),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbColor: const Color(0xFFF77737),
                  activeTrackColor: const Color(0xFFF77737),
                  inactiveTrackColor: Colors.white12,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _cooldownMs.toDouble().clamp(400.0, 1500.0),
                  min: 400,
                  max: 1500,
                  divisions: 11,
                  onChanged: (val) => _updateSetting('cooldownMs', val.round()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformControlsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Individual Platform Blockers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            const Text('Toggle blocking on or off for each individual app', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            const SizedBox(height: 14),

            // 1. YouTube Shorts
            _buildAppRow(
              icon: Icons.play_circle_fill_rounded,
              iconColor: const Color(0xFFFF0000),
              title: 'YouTube Shorts',
              subtitle: 'Blocks short-form videos so you only watch regular long videos',
              value: _youtubeShorts,
              onChanged: (val) => _updateSetting('youtubeShorts', val),
            ),

            const Divider(color: Color(0xFF222638), height: 20),

            // 2. Instagram Ads
            _buildAppRow(
              icon: Icons.ad_units_rounded,
              iconColor: const Color(0xFFE1306C),
              title: 'Instagram Ads (Reels & Feed)',
              subtitle: 'Auto-skips "Ad" tags and conversion CTA buttons',
              value: _instagramAds,
              onChanged: (val) => _updateSetting('instagramAds', val),
            ),

            const Divider(color: Color(0xFF222638), height: 20),

            // 3. Instagram Reels
            _buildAppRow(
              icon: Icons.video_library_rounded,
              iconColor: const Color(0xFF833AB4),
              title: 'Block ALL Instagram Reels',
              subtitle: 'Anti-doomscroll mode: Disables Instagram Reels viewer entirely',
              value: _instagramReels,
              onChanged: (val) => _updateSetting('instagramReels', val),
            ),

            const Divider(color: Color(0xFF222638), height: 20),

            // 4. Snapchat Spotlight
            _buildAppRow(
              icon: Icons.camera_alt_rounded,
              iconColor: const Color(0xFFFFFC00),
              title: 'Snapchat Spotlight',
              subtitle: 'Stops infinite vertical scrolling in Snapchat Spotlight',
              value: _snapchatSpotlight,
              onChanged: (val) => _updateSetting('snapchatSpotlight', val),
            ),

            const Divider(color: Color(0xFF222638), height: 20),

            // 5. Facebook Reels
            _buildAppRow(
              icon: Icons.thumb_up_rounded,
              iconColor: const Color(0xFF1877F2),
              title: 'Facebook Reels',
              subtitle: 'Exits Facebook Reels feeds and video reels',
              value: _facebookReels,
              onChanged: (val) => _updateSetting('facebookReels', val),
            ),

            const Divider(color: Color(0xFF222638), height: 20),

            // 6. TikTok
            _buildAppRow(
              icon: Icons.music_note_rounded,
              iconColor: const Color(0xFF00F2FE),
              title: 'TikTok Feed',
              subtitle: 'Blocks TikTok vertical video scrolling',
              value: _tiktok,
              onChanged: (val) => _updateSetting('tiktok', val),
            ),

            const Divider(color: Color(0xFF222638), height: 20),

            // 7. Reddit Video Feed
            _buildAppRow(
              icon: Icons.reddit_rounded,
              iconColor: const Color(0xFFFF4500),
              title: 'Reddit Shorts & Video Player',
              subtitle: 'Blocks Reddit vertical video viewer',
              value: _redditShorts,
              onChanged: (val) => _updateSetting('redditShorts', val),
            ),

            const Divider(color: Color(0xFF222638), height: 20),

            // 8. X / Twitter
            _buildAppRow(
              icon: Icons.close_rounded,
              iconColor: Colors.white,
              title: 'X (Twitter) Immersive Videos',
              subtitle: 'Blocks full-screen vertical video feeds on X',
              value: _xShorts,
              onChanged: (val) => _updateSetting('xShorts', val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: iconColor == Colors.white ? const Color(0xFFE1306C) : iconColor,
          activeTrackColor: (iconColor == Colors.white ? const Color(0xFFE1306C) : iconColor).withValues(alpha: 0.35),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.white12,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2132),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2C324C)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.battery_charging_full_rounded, size: 17, color: Color(0xFFF77737)),
                label: const Text('Battery Fix', style: TextStyle(fontSize: 12.5)),
                onPressed: () async => await NativeBridge.openBatteryOptimizationSettings(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E2132),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF2C324C)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.security_rounded, size: 17, color: Color(0xFF20BF6B)),
                label: const Text('Autostart (MIUI)', style: TextStyle(fontSize: 12.5)),
                onPressed: () async => await NativeBridge.openAutostartSettings(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE1306C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.camera_alt_outlined, size: 17),
                label: const Text('Instagram', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () async => await NativeBridge.openInstagram(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('YouTube', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                onPressed: () async => await NativeBridge.openApp('com.google.android.youtube'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSetupInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF833AB4), size: 18),
                SizedBox(width: 8),
                Text('Quick Setup & Xiaomi Guide', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            _buildStepRow(
              number: '1',
              title: 'Enable Accessibility',
              description: 'Turn on "Instagram Ad Skipper Service" in Android Settings.',
            ),
            const SizedBox(height: 8),
            _buildStepRow(
              number: '2',
              title: 'Autostart & Battery Fix',
              description: 'Tap "Autostart (MIUI)" and "Battery Fix" above to allow permanent background operation.',
            ),
            const SizedBox(height: 8),
            _buildStepRow(
              number: '3',
              title: 'Lock in Recent Apps (Padlock 🔒)',
              description: 'In your Recent Apps screen, hold this app and tap the Lock 🔒 icon so MIUI never kills the shield when clearing apps.',
            ),
            const SizedBox(height: 8),
            _buildStepRow(
              number: '4',
              title: 'Enjoy Productive Browsing',
              description: 'Whenever a short opens in YouTube, Instagram, Snapchat or Facebook, the shield immediately intervenes.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: const Color(0xFF2A2E44),
          child: Text(number, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}

class LogsModalSheet extends StatefulWidget {
  const LogsModalSheet({super.key});

  @override
  State<LogsModalSheet> createState() => _LogsModalSheetState();
}

class _LogsModalSheetState extends State<LogsModalSheet> {
  List<String> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    final logs = await NativeBridge.getRecentLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    await NativeBridge.clearLogs();
    setState(() => _logs = []);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Shield Activity Logs', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.refresh, size: 20), tooltip: 'Refresh', onPressed: _fetchLogs),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20), tooltip: 'Clear Logs', onPressed: _clearLogs),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _logs.isEmpty
                        ? const Center(
                            child: Text(
                              'No activity recorded yet.\nOpen YouTube Shorts or Instagram to see actions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              final isBlock = log.contains('Blocked') || log.contains('Skipped') || log.contains('Exited');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isBlock ? const Color(0xFF133221) : const Color(0xFF1C1F2E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                    color: isBlock ? const Color(0xFF55EFC4) : const Color(0xFFCBD2EC),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
