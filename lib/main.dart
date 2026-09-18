import 'package:flutter/material.dart';

import 'screens/branding_screen.dart';
import 'screens/event_list_screen.dart';
import 'screens/import_screen.dart';
import 'scoutList_screen.dart';
import 'scoutDetail_screen.dart';
import 'services/branding_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(TroopApp());
}

class TroopApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Troop Manager",
      theme: AppTheme.build(),
      initialRoute: "/",
      routes: {
        "/": (context) => NavigationHub(),
        "/scoutList": (context) => ScoutListScreen(),
        "/scoutDetail": (context) {
          final scout = ModalRoute.of(context)!.settings.arguments
              as Map<String, String>;
          return ScoutDetailScreen(scout: scout);
        },
        "/eventList": (context) => EventListScreen(),
        "/calculation": (context) => Placeholder(),   // temporary
        "/branding": (context) => BrandingScreen(),
        "/import": (context) => ImportScreen(),
      },
    );
  }
}

class NavigationHub extends StatefulWidget {
  @override
  _NavigationHubState createState() => _NavigationHubState();
}

class _NavigationHubState extends State<NavigationHub> {
  TroopLogo? _troopLogo;
  String? _troopName;

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    final logo = await BrandingService.loadTroopLogo();
    final name = await BrandingService.loadTroopName();
    if (!mounted) return;
    setState(() {
      _troopLogo = logo;
      _troopName = name;
    });
  }

  Widget _logo() {
    if (_troopLogo == null) {
      return Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          color: AppTheme.scoutingTan,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.face_3,
          size: 56,
          color: AppTheme.scoutingBlue,
        ),
      );
    }
    return Container(
      width: 104,
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(10),
      child: Image.memory(
        _troopLogo!.bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.face_3,
          size: 56,
          color: AppTheme.scoutingBlue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation Hub"),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'Branding & Patrols',
            onPressed: () {
              Navigator.pushNamed(context, '/branding')
                  .then((_) => _loadBranding());
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _logo(),
            const SizedBox(height: 12),
            Text(
              _troopName == null || _troopName!.isEmpty
                  ? "Troop Manager"
                  : _troopName!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.scoutingDarkBlue,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Text(
              "Scouting America",
              style: TextStyle(
                color: AppTheme.scoutingWarmGray,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _navButton(context, "Scout Page", () => Navigator.pushNamed(context, "/scoutList")),
            _navButton(context, "Event Page", () => Navigator.pushNamed(context, "/eventList")),
            _navButton(context, "Calculation Page", () => Navigator.pushNamed(context, "/calculation")),
            _navButton(context, "Upload Data", () => Navigator.pushNamed(context, "/import")),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
        style: ElevatedButton.styleFrom(
          minimumSize: Size(200, 50),
        ),
      ),
    );
  }
}