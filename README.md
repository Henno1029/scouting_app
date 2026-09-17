# Troop Manager App

## Project Overview

The Troop Manager App is a Flutter-based application that helps manage a scouting troop. Built as a programming merit badge project, it provides tools to track scout data, events, calculations, and profiles through a central navigation hub.

A core feature of this project: **AI will be used to automatically build a calendar of events based on scout advancement reports and activity reports**. The app will analyze these reports to generate and schedule troop events intelligently.

## Active Layouts / Widgets

### 1. TroopApp
- **Type**: StatelessWidget
- **Purpose**: Main entry point. Uses `MaterialApp` to configure the app title, initial route, and the named route table.
- **Routes**:
  - `/` → `NavigationHub`
  - `/scoutList` → `ScoutListScreen`
  - `/eventList` → `Placeholder` (temporary)
  - `/calculation` → `Placeholder` (temporary)
  - `/profile` → `Placeholder` (temporary)

### 2. NavigationHub
- **Type**: StatelessWidget
- **Purpose**: Central navigation screen. Shows an `AppBar` titled "Navigation Hub" and a centered column of buttons for each section.
- **Widgets Used**: `Scaffold`, `AppBar`, `Column`, `ElevatedButton`, `Padding`

### 3. _navButton
- **Type**: Helper method on `NavigationHub`
- **Purpose**: Builds a reusable navigation button.
- **Parameters**: `context`, `label`, `onPressed`
- **Widgets Used**: `Padding`, `ElevatedButton`

### 4. ScoutListScreen
- **Type**: StatefulWidget
- **Purpose**: Manages a dynamic list of scouts. A scout's name is entered in a text field, their rank is selected from a dropdown (Tenderfoot through Eagle), and an **Add Scout** button appends them to a scrollable `ListView`.
- **Widgets Used**: `Scaffold`, `AppBar`, `TextField` (+ `TextEditingController`), `DropdownButtonFormField`, `ElevatedButton`, `ListView.builder`, `ListTile`

## Dependencies

The app currently relies on the Flutter core package:

- `flutter/material.dart` — the Material Design library providing widgets, themes, and components used throughout the app.

## Setup Instructions

1. **Clone the Repository**
   ```bash
   git clone git@github.com:Henno1029/scouting_app.git
   ```

2. **Install Flutter**
   - Download and install Flutter from the [official Flutter website](https://flutter.dev/docs/get-started/install).

3. **Get Dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the App**
   ```bash
   flutter run
   ```

5. **Build the App** (Android release)
   ```bash
   flutter build apk
   ```

6. **Install on Device**
   - Once the build completes, install the generated APK on your Android device.

## Roadmap

- Implement the `/eventList`, `/calculation`, and `/profile` sections (currently placeholders).
- Integrate AI to generate a troop event calendar from scout advancement reports and activity reports.
- Add data persistence, user authentication, and richer analytics.
- Continue refining the UI/UX.

## Contact

For inquiries or support, please contact the developer.