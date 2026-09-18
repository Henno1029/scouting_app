import 'package:flutter/material.dart';

import 'scoutList_screen.dart';
import 'scoutDetail_screen.dart';

void main() {
  runApp(TroopApp());
}

class TroopApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Troop Manager",
      initialRoute: "/",
      routes: {
        "/": (context) => NavigationHub(),
        "/scoutList": (context) => ScoutListScreen(),
        "/scoutDetail": (context) {
          final scout = ModalRoute.of(context)!.settings.arguments
              as Map<String, String>;
          return ScoutDetailScreen(scout: scout);
        },
        "/eventList": (context) => Placeholder(),     // temporary
        "/calculation": (context) => Placeholder(),   // temporary
        "/profile": (context) => Placeholder(),       // temporary
      },
    );
  }
}

class NavigationHub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Navigation Hub")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _navButton(context, "Scout Page", () => Navigator.pushNamed(context, "/scoutList")),
            _navButton(context, "Event Page", () => Navigator.pushNamed(context, "/eventList")),
            _navButton(context, "Calculation Page", () => Navigator.pushNamed(context, "/calculation")),
            _navButton(context, "Profile Page", () => Navigator.pushNamed(context, "/profile")),
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
