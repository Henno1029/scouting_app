# Troop Manager App — Specification

This document is the guideline for how the app should be built. Features are added incrementally against this spec.

## App Structure (7 Screens)

| # | Screen | Route |
|---|--------|-------|
| 1 | Scout List Screen | `/scoutList` |
| 2 | Scout Detail Screen | `/scoutDetail` |
| 3 | Event List Screen (no meetings shown) | `/eventList` |
| 4 | Event Detail Screen | `/eventDetail` |
| 5 | Navigation Hub Screen (home) | `/` |
| 6 | Calculation Page | `/calculation` |
| 7 | Profile Page | `/profile` |

## Navigation Hub (Screen 5, Home)

First screen shown on launch. Contains exactly four buttons:

- Scout Page → `/scoutList`
- Event Page → `/eventList`
- Calculation Page → `/calculation`
- Profile Page → `/profile`

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

## Event List Screen (Screen 3)

Shows all events **except meetings**. Tapping an event opens Event Detail.

## Event Detail Screen (Screen 4)

Shows:

- Title
- Date
- Location
- Activities
- Edit button — **only visible if user has permission**

## Calculation Page (Screen 6)

User selects:

- An event
- Scouts attending

App outputs:

- Which requirements each scout can complete at that event

## Profile Page (Screen 7)

Shows:

- User name
- User permission level
- Field to enter special password
- Button to change their own permission level

No extra buttons.

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
- Profile Page is where users change their own permission.
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
- `/profile`