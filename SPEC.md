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