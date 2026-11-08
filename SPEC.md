# Troop Manager App — Specification

This document is the guideline for how the app should be built. Features are added incrementally against this spec.

## App Structure (6 Screens)

| # | Screen | Route |
|---|--------|-------|
| 1 | Scout List Screen | `/scoutList` |
| 2 | Scout Detail Screen | `/scoutDetail` |
| 3 | Event Calendar Screen (month + year views) | `/eventList` |
| 4 | Event Detail Screen | `/eventDetail` |
| 5 | Navigation Hub Screen (home) | `/` |
| 6 | Calculation Page | `/calculation` |

## Navigation Hub (Screen 5, Home)

First screen shown on launch. Contains four buttons:

- Scout Page → `/scoutList`
- Event Page → `/eventList`
- Calculation Page → `/calculation`
- Upload Data → `/import`

The app bar also has a badge icon opening Branding & Patrols (`/branding`).

## Scout List Screen (Screen 1)

Shows a list of scouts with:

- Name
- Patrol
- Rank

Tapping a scout opens Scout Detail.

## Scout Detail Screen (Screen 2)

Shows:

- Name
- Patrol
- Rank
- Advancement info
- Edit button — **only visible if user has permission**

## Event Calendar Screen (Screen 3)

Full calendar page with month and year views:

- **Month view** — weekday header, tappable day cells showing event chips, and a list of that month's events below.
- **Year view** — 12 mini-months; tapping a month jumps to that month's view.
- **Add event** dialog (title, type, date picker, location, notes).
- **Show/hide by event type** filter (tap a legend chip or open the filter dialog to hide any type, e.g. meetings, campouts, service).
- App bar actions: **export year PDF** and **add event**.
- The year-event list and the PDF export both respect the hidden-type filter.
- Tap an event or day to see details and delete.
- Events come from manual entries plus the CSV calendar and Program Grid imports.

## Year Calendar PDF Export

- One-page Letter-landscape 12-month grid (like a school wall calendar), Scouting America themed.
- Header shows troop name (from Branding), optional troop logo, and the year.
- Days with events are highlighted in red; weekday letters shown.
- Exported via the browser print dialog (choose "Save as PDF") using the `printing` + `pdf` packages.

## Event Detail Screen (Screen 4)

Shows:

- Title
- Date
- Location
- Activities
- Edit button — **only visible if user has permission**

## Calculation Page (Screen 5)

Two tabs sharing one event picker: **Event Calculations** and **Event Plans**. The picker combines consecutive days with the same title and type into one entry, such as a multi-day campout. The calendar still shows each day.

### Event Calculations

User selects:

- An event
- Scouts attending

App outputs:

- Which requirements each scout can complete at that event
- A printable checklist of the results

### Event Plans

For the selected event, the user builds a plan. The draft is kept on the device while typing, and **Save** writes a summary into the description of every day of the event, replacing any earlier summary and keeping other description text. The description shows in the calendar's day sheet and the PDF export.

- **Agenda or planning phases** — starter rows matching the event's official form, with items that can be edited, added, reordered and removed. Each has a title, minutes, who and details, with a running total of minutes.
- **Requirements to cover** — suggested from the event type, most needed first, counted across the scouts ticked on Event Calculations or the whole roster if none are ticked.
- **Materials and notes** — free text.
- **Sorting rows into sections** — on the Meeting Plan, a row added in the user's own words, such as "instruction", goes into the matching section using the local Ollama model only, with an Undo. If Ollama isn't running or nothing matches, the row stays and goes on the form's attached page.
- **Official form** — a button fills out the official form for the event and opens the print dialog: the **Meeting Plan** for meetings and the **Scout Planning Worksheet** (No. 512-505) for everything else, such as campouts. The form's own questions are answered on the tab. Anything with no box on the form, or too long for its box, goes in full on an attached page.

## Scout Roster and Statistics printouts

Both buttons are on the Scout List Screen and open the print dialog.

- **Print Scout Roster** — every scout's name, rank, patrol and member ID, sorted by patrol.
- **Print out Statistics** — the user picks a start date, and the report runs from then through today: each scout's ranks and merit badges earned, plus troop totals such as campouts, camping nights, service projects and hours, miles hiked, awards, requirements, events by type and most-earned badges.
- Campouts come from finished calendar campouts, with a multi-day campout counted once, plus others found only in the activity report. Service hours, nights and miles come from the activity report's Hours, Nights and Miles columns, or text like "3 hours" in Notes.

## More screens

- **Event Detail** (`/eventDetail`): opens from an event in the calendar's month list or day view, with a multi-day campout shown as one event. It shows the event's details, attendance, and the requirements the scouts who came can complete. Saving attendance writes those scouts into the activity report, so Statistics counts the campout, nights and service hours.
- **Merit Badge Planner** (`/badgePlanner`): type the badges a camp offers to see who still needs each, with Eagle-required badges first.
- **Ask Your Troop** (`/ask`): plain-language questions about the troop, answered by the local Ollama model only from a summary of the troop's data.
- **Users & Permissions** (`/users`): opened from the person icon on the hub. See Permission System below.
- **Scout Detail** also shows progress toward the next rank, the Eagle-required merit badges, age, and the 18th-birthday Eagle deadline when a birthday is known.
- **Upload Data** also has Backup and restore: save everything to one file and load it back.
- Scouts are matched to imported records by BSA member ID, falling back on the whole name with or without a middle name.

## Permission System, as built

- With no users added, everyone can do everything. The first user added is always an Admin.
- Viewers can look at and print everything, but editing controls are hidden or disabled.
- The special password unlocks editing for the session and lets that user change their own level. Once a password is set, switching to an Editor or Admin profile needs it.
- There is always at least one Admin.
- This is stored on the device and stops accidental changes. It is not security against someone with access to the computer.

## Planned: Activity Requirements Check

- Use each scout's imported activity log (past activities) to indicate whether they have met the participation/activity requirements for the first three ranks: **Tenderfoot**, **Second Class**, and **First Class**.
- Surfaced as an indicator on the Calculation Page (and/or Scout Detail) showing counted activities against the requirement (# nights / # activities as defined by the handbooks).
- Data source: `import_activity` records; combines with advancement data for a per-scout readiness view.

## CSV Import Screen (`/import`)

Upload report CSVs and map their columns to app fields:

- Supported import types: **Advancements** (Scoutbook Plus Quick Export preset), **Activities**, **Program Calendar**, **Program Grid** (troop annual planning sheet auto-parsed into meetings/campouts/PLC/committee/roundtable/OA events), **Roster** (Scoutbook roster export → creates/merges scout-list entries with patrol + member ID), and **Advancement Record (IAR)** (per-scout auto-parsed file).
- When advancement data is imported, any scout not already on the roster is **auto-created** with their highest earned rank.
- User picks a `.csv`/`.tsv` file, sees detected columns, and remaps any column per field.
- Required-field columns are enforced before saving.
- Preview of the first 5 rows before import.
- Imported records are stored in shared_preferences; the Program Calendar import feeds the calendar page.

## Branding & Patrols Screen (`/branding`)

- Upload/remove the troop logo (shown on the hub and in the year-calendar PDF).
- Set the troop name.
- Upload/remove a patrol emblem for each patrol; emblems show next to scouts in the scout list.
- Register patrol names manually.

## Permission System

Three permission levels only:

- **Viewer** — cannot edit anything
- **Editor** — can edit scouts/events
- **Admin** — can edit everything AND change other users' permissions

Rules:

- Viewer cannot edit anything.
- Editor can edit scouts/events.
- Admin can edit everything and change other users' permissions.
- Special password unlocks editing AND allows the user to change their own permission level.
- Only Admins can change OTHER users' permissions.
- Do NOT add any other permission levels.

## Data Models

**Scout:**
- id
- name
- patrol
- rank
- birthday
- advancement
- permissions

**Event:**
- id
- title
- date
- location
- type
- activities[]

**User:**
- id
- name
- permissionLevel (Viewer | Editor | Admin)
- unlocked (bool)

## Routing

Use named routes:

- `/` → Navigation Hub
- `/scoutList`
- `/eventList`
- `/calculation`
- `/import`
- `/branding`