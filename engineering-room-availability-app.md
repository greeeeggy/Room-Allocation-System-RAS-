# Engineering Room Availability App
### Implementation & Planning Document
**Project Type:** School Project — Engineering Building Room Monitoring System
**Tech Stack:** Flutter · Firebase Auth · Cloud Firestore · Flutter CustomPainter
**Last Updated:** April 2026

---

## Table of Contents

1. [Overall Idea & Thought](#1-overall-idea--thought)
2. [Planning](#2-planning)
   - [Scope](#21-scope)
   - [User Roles](#22-user-roles)
   - [Feature List](#23-feature-list)
   - [Data Models](#24-data-models)
   - [Screen Map](#25-screen-map)
   - [Core Logic Decisions](#26-core-logic-decisions)
3. [Implementation](#3-implementation)
   - [Project Structure](#31-project-structure)
   - [Firebase Setup](#32-firebase-setup)
   - [Auth & Role System](#33-auth--role-system)
   - [Room Status Engine](#34-room-status-engine)
   - [Conflict System](#35-conflict-system)
   - [Notification Inbox](#36-notification-inbox)
   - [2.5D Floor Map](#37-25d-floor-map-isometric)
4. [Phases](#4-phases)
   - [Phase 1 — Foundation](#phase-1--foundation-week-1-2)
   - [Phase 2 — Core Features](#phase-2--core-features-week-3-4)
   - [Phase 3 — Advanced Features](#phase-3--advanced-features-week-5-6)
   - [Phase 4 — Polish & Demo](#phase-4--polish--demo-week-7-8)

---

## 1. Overall Idea & Thought

### The Problem

The engineering building has 6 floors of classrooms and labs. At any given time, faculty, students, and class mayors have no reliable way to know which rooms are occupied and which are free — short of physically walking to the room and checking. This creates wasted time, double bookings, and scheduling conflicts that are resolved slowly or not at all.

### The Solution

A real-time room availability monitoring app where **class mayors** are the central actors. Mayors are the natural source of truth for room occupancy — they know their class schedule, they arrive with their section, and they are accountable to their department. The app leverages this existing structure rather than creating a new one.

The system works as follows:
- At the start of each semester, mayors upload their schedule (entered manually as structured time blocks).
- When a class is about to start, the mayor checks in via the app, marking the room as occupied.
- At the end of the scheduled time block, the room is automatically released back to available status.
- If two mayors claim the same room at the same time, the app flags it immediately — blocking the second mayor and routing a notification to the relevant council president.
- All users can see a live dashboard of which rooms are occupied, available, or about to be occupied.

### Why This Works

The design is intentionally lean. It does not require IoT sensors, admin maintenance, or complex integrations. All data entry is done by the mayors themselves as part of their normal pre-semester routine. The conflict system is passive — it only activates when there is an actual problem. The auto-release logic is client-computed, eliminating the need for backend scheduled jobs. The result is a system that is maintainable by a small student development team and usable without training.

### Key Design Principles

- **Mayors are the source of truth** — the system trusts mayor input and enforces accountability through department councils.
- **Minimal data entry friction** — mayors enter their schedule once per semester and reuse it.
- **Client-side logic where possible** — auto-release, no-show detection, and conflict detection all run on the device without Cloud Functions.
- **In-app notifications only** — no push notification infrastructure needed; a Firestore-backed inbox is sufficient for school use.
- **2.5D isometric floor map** — rendered via Flutter CustomPainter, no 3D engine or external library needed.

---

## 2. Planning

### 2.1 Scope

| Dimension | Details |
|---|---|
| Departments | Industrial, Mechanical, Aerospace, Computer, Civil, Electrical, Electronics (7 total) |
| Organizations | 7 department councils + Engineering Council as mother org (8 total) |
| Building | 6 floors, multiple rooms per floor |
| Platform | Flutter (iOS + Android) |
| Backend | Firebase (Auth + Firestore) |

---

### 2.2 User Roles

#### Class Mayor
- The primary actor in the system.
- Registered with a department tag and course section (e.g., BSIE 3-A).
- Responsible for entering and maintaining their semester schedule.
- Checks in to mark a room occupied upon arrival.
- Can release a room early (cancelled class, short session).
- Receives a soft conflict warning when attempting to claim an already-occupied room.

#### Council President
- One per department + one for Engineering Council.
- Receives in-app notifications when a conflict involves a mayor from their department.
- Can view conflict details: which mayors, which room, which time block.
- Conflict notifications auto-clear when resolved.
- Can view the council directory and all room status data (read-only).

---

### 2.3 Feature List

#### Dashboard
- Live clock displayed at the top.
- "My next class" card for the currently logged-in mayor — shows room, subject, start time.
- Room grid color-coded by status: **green** (available), **red** (occupied), **amber** (occupied within 15 min).
- Floor filter tabs (1F through 6F).
- Quick search by room number or room features.

#### Room Check-in
- Check-in button appears on the mayor's active schedule block, enabled up to 15 minutes before scheduled start.
- If the target room is already claimed by another mayor: a **soft block warning** is shown — *"This room is currently claimed by the class mayor of [Section]. Please coordinate with them."* Check-in is blocked until resolved.
- Early release button allows mayors to free the room before the scheduled end time.
- Auto-release: computed client-side on app load — if `currentTime > endTime`, status is set to available automatically.
- No-show logic: if `checkInStatus == pending` and `currentTime > startTime + 20 minutes`, the room is treated as available.

#### Schedule Management
- Add time block form fields: subject name, course and section, instructor name, room, day of week, start time, end time.
- Edit and delete existing blocks at any time.
- Semester reuse: previous semester blocks can be duplicated as a starting point for the new semester.
- Weekly calendar view of the mayor's own schedule.

#### Room Search & Filter
- Filter by features: TV, whiteboard, blackboard, aircon, projector.
- Filter by floor.
- Filter by status: available now, available soon, all.
- Room detail page: room number, floor, features list, current occupant (section name only), and today's schedule.

#### Conflict System
- Conflict is triggered when Mayor A attempts to check in to a room already actively claimed by Mayor B during an overlapping time.
- Mayor A sees a soft block with the other section's name.
- The conflicting block is visually flagged in a distinct highlight color in the schedule view.
- Council president of the relevant department receives an in-app notification.
- Conflict flag and notification auto-clear once one mayor releases the room or reassigns their block to a different room.

#### Isometric 2.5D Floor Map
- Building rendered in isometric perspective with floors stacked bottom to top.
- Room tiles color-coded by live status (same red/green/amber system as the dashboard).
- Tap a room tile to open the room detail sheet.
- Tap a floor layer to expand and see individual rooms.
- Implemented using Flutter's `CustomPainter` — no 3D engine required.

#### Council Directory
- Lists all council officials per department and Engineering Council.
- Fields: name, position, department.
- Viewable by all logged-in users (read-only).

#### In-App Notification Inbox
- Bell icon with unread badge count.
- Notification types: conflict detected, conflict resolved.
- Notifications are scoped by department — council presidents only see notifications for their department.
- Mayors receive a notification when their own block has been flagged or cleared.

---

### 2.4 Data Models

#### `users` collection

| Field | Type | Notes |
|---|---|---|
| `userId` | string | Firebase Auth UID |
| `name` | string | Full name |
| `role` | enum | `mayor` or `council_president` |
| `department` | string | IE, ME, AE, CE, Civil, EE, ECE |
| `courseSection` | string | e.g. BSIE 3-A (mayors only) |
| `createdAt` | timestamp | |

#### `rooms` collection

| Field | Type | Notes |
|---|---|---|
| `roomId` | string | e.g. `301`, `402A` |
| `roomNumber` | string | Display label |
| `floor` | int | 1–6 |
| `features` | list\<string\> | `tv`, `whiteboard`, `blackboard`, `aircon`, `projector` |
| `status` | enum | `available`, `occupied`, `soon` |
| `currentOccupantBlockId` | string? | `blockId` of active claim, null if available |

#### `scheduleBlocks` collection

| Field | Type | Notes |
|---|---|---|
| `blockId` | string | Auto-generated |
| `mayorId` | string | Ref to `users` |
| `subject` | string | |
| `instructor` | string | |
| `courseSection` | string | e.g. BSIE 3-A |
| `roomId` | string | Ref to `rooms` |
| `dayOfWeek` | enum | M, T, W, Th, F, S |
| `startTime` | string | HH:mm 24h format |
| `endTime` | string | HH:mm 24h format |
| `semester` | string | e.g. `2025-1` |
| `isActive` | bool | false = archived |
| `checkInStatus` | enum | `pending`, `checked_in`, `released`, `no_show` |
| `hasConflict` | bool | |

#### `notifications` collection

| Field | Type | Notes |
|---|---|---|
| `notifId` | string | Auto-generated |
| `recipientId` | string | Council president userId |
| `type` | enum | `conflict_detected`, `conflict_resolved` |
| `involvedBlockIds` | list\<string\> | Both conflicting block IDs |
| `roomId` | string | The contested room |
| `isRead` | bool | |
| `createdAt` | timestamp | |

---

### 2.5 Screen Map

#### Mayor Screens
| Screen | Purpose |
|---|---|
| Login / Register | Auth, department tag, role selection |
| Dashboard | Live room grid, my next class card, floor filter tabs |
| Floor Map (2.5D) | Isometric building view, tap to inspect rooms |
| My Schedule | Weekly calendar of the mayor's time blocks |
| Add / Edit Block | Schedule entry form |
| Room Detail | Room info, features, today's schedule, current occupant |
| Check-in Screen | Confirm check-in; shows conflict warning if room is taken |
| Notification Inbox | All notifications for the logged-in user |
| Council Directory | Officials list per department |

#### Council President Additional Screens
| Screen | Purpose |
|---|---|
| Conflict Inbox | Conflicts flagged for their department |
| Conflict Detail | Which mayors, which room, which time block, resolution status |

---

### 2.6 Core Logic Decisions

#### Auto-release (client-side, no Cloud Functions)
On every app open or resume from background:
1. Query all `scheduleBlocks` where `checkInStatus == checked_in`.
2. For each block, compare `endTime` against `currentTime`.
3. If `currentTime > endTime`: update `checkInStatus` to `released` and set the linked room's `status` to `available` and `currentOccupantBlockId` to null.
4. Batch these writes in a single Firestore batch commit.

#### No-show detection (client-side)
On app load:
1. Query all `scheduleBlocks` for `checkInStatus == pending` where today's `dayOfWeek` matches.
2. Parse `startTime` and add 20 minutes.
3. If `currentTime > startTime + 20min`: update `checkInStatus` to `no_show`. The room status does not change (it remains `available` since no check-in occurred).

#### Conflict detection
On check-in attempt:
1. Query `rooms` for the target `roomId`.
2. If `status == occupied` and `currentOccupantBlockId != null`:
   - Fetch the occupying block.
   - Check if its `endTime` overlaps with the attempting mayor's `startTime`.
   - If overlap exists: show the soft block warning with the occupying section name. Do not proceed with check-in.
   - Write a conflict notification to the council president of the attempting mayor's department.
   - Set `hasConflict = true` on both blocks.

#### "Soon" status
A room is marked `soon` (amber) if there is a `scheduleBlock` with `checkInStatus == pending` where `startTime - currentTime <= 15 minutes`. This is computed as part of the dashboard load, not stored permanently.

---

## 3. Implementation

### 3.1 Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── constants.dart          # Departments, room features enum, status enum
│   ├── theme.dart              # App colors, text styles
│   └── utils/
│       ├── time_utils.dart     # Parse HH:mm, compare times, day-of-week helpers
│       └── status_engine.dart  # Auto-release, no-show, "soon" logic
├── models/
│   ├── user_model.dart
│   ├── room_model.dart
│   ├── schedule_block_model.dart
│   └── notification_model.dart
├── services/
│   ├── auth_service.dart       # Firebase Auth wrapper
│   ├── room_service.dart       # Firestore CRUD for rooms
│   ├── schedule_service.dart   # Firestore CRUD for schedule blocks
│   └── notification_service.dart
├── providers/                  # Riverpod or Provider state
│   ├── auth_provider.dart
│   ├── room_provider.dart
│   └── schedule_provider.dart
└── screens/
    ├── auth/
    │   ├── login_screen.dart
    │   └── register_screen.dart
    ├── dashboard/
    │   ├── dashboard_screen.dart
    │   └── widgets/
    │       ├── room_grid.dart
    │       └── my_next_class_card.dart
    ├── floor_map/
    │   ├── floor_map_screen.dart
    │   └── isometric_painter.dart  # CustomPainter implementation
    ├── schedule/
    │   ├── schedule_screen.dart
    │   ├── add_block_screen.dart
    │   └── edit_block_screen.dart
    ├── rooms/
    │   ├── room_detail_screen.dart
    │   └── room_search_screen.dart
    ├── checkin/
    │   └── checkin_screen.dart
    ├── notifications/
    │   └── notification_screen.dart
    └── directory/
        └── council_directory_screen.dart
```

---

### 3.2 Firebase Setup

**Firestore Security Rules (simplified)**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can read their own profile; admins can read all
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }

    // Rooms: anyone logged in can read; mayors can update status
    match /rooms/{roomId} {
      allow read: if request.auth != null;
      allow update: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'mayor';
    }

    // Schedule blocks: mayors own their blocks
    match /scheduleBlocks/{blockId} {
      allow read: if request.auth != null;
      allow create, update, delete: if request.auth != null
        && resource.data.mayorId == request.auth.uid;
    }

    // Notifications: recipients can read and update (mark read)
    match /notifications/{notifId} {
      allow read, update: if request.auth != null
        && resource.data.recipientId == request.auth.uid;
      allow create: if request.auth != null;
    }
  }
}
```

**Firestore Indexes needed:**
- `scheduleBlocks`: composite index on `mayorId` + `isActive` + `dayOfWeek`
- `scheduleBlocks`: composite index on `roomId` + `checkInStatus` + `dayOfWeek`
- `notifications`: composite index on `recipientId` + `isRead` + `createdAt`

---

### 3.3 Auth & Role System

```dart
// auth_service.dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,       // 'mayor' or 'council_president'
    required String department,
    String? courseSection,      // required for mayors
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password
    );
    await _db.collection('users').doc(cred.user!.uid).set({
      'userId': cred.user!.uid,
      'name': name,
      'role': role,
      'department': department,
      'courseSection': courseSection,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<UserModel?> get currentUserStream {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _db.collection('users').doc(user.uid)
        .snapshots()
        .map((snap) => UserModel.fromFirestore(snap));
    });
  }
}
```

---

### 3.4 Room Status Engine

This is the core logic that runs on every app load and app resume.

```dart
// status_engine.dart
class StatusEngine {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> runOnAppLoad() async {
    final now = DateTime.now();
    final todayKey = _dayKey(now.weekday); // e.g. 'Th'
    final batch = _db.batch();

    // 1. Auto-release: checked_in blocks past their end time
    final checkedInQuery = await _db.collection('scheduleBlocks')
      .where('checkInStatus', isEqualTo: 'checked_in')
      .where('dayOfWeek', isEqualTo: todayKey)
      .get();

    for (final doc in checkedInQuery.docs) {
      final endTime = _parseTime(doc['endTime'], now);
      if (now.isAfter(endTime)) {
        batch.update(doc.reference, {'checkInStatus': 'released', 'hasConflict': false});
        batch.update(_db.collection('rooms').doc(doc['roomId']), {
          'status': 'available',
          'currentOccupantBlockId': null,
        });
      }
    }

    // 2. No-show: pending blocks past start + 20 min
    final pendingQuery = await _db.collection('scheduleBlocks')
      .where('checkInStatus', isEqualTo: 'pending')
      .where('dayOfWeek', isEqualTo: todayKey)
      .where('isActive', isEqualTo: true)
      .get();

    for (final doc in pendingQuery.docs) {
      final startTime = _parseTime(doc['startTime'], now);
      final noShowCutoff = startTime.add(const Duration(minutes: 20));
      if (now.isAfter(noShowCutoff)) {
        batch.update(doc.reference, {'checkInStatus': 'no_show'});
      }
    }

    await batch.commit();
  }

  DateTime _parseTime(String hhmm, DateTime today) {
    final parts = hhmm.split(':');
    return DateTime(today.year, today.month, today.day,
      int.parse(parts[0]), int.parse(parts[1]));
  }

  String _dayKey(int weekday) {
    const map = {1: 'M', 2: 'T', 3: 'W', 4: 'Th', 5: 'F', 6: 'S'};
    return map[weekday] ?? 'M';
  }
}
```

---

### 3.5 Conflict System

```dart
// In checkin_screen.dart or schedule_service.dart
Future<CheckInResult> attemptCheckIn({
  required String mayorId,
  required String blockId,
  required String roomId,
  required String mayorSection,
  required String mayorDepartment,
}) async {
  final roomDoc = await _db.collection('rooms').doc(roomId).get();
  final roomData = roomDoc.data()!;

  if (roomData['status'] == 'occupied' && roomData['currentOccupantBlockId'] != null) {
    // Fetch the occupying block to get section info
    final occupyingBlock = await _db.collection('scheduleBlocks')
      .doc(roomData['currentOccupantBlockId']).get();
    final occupyingSection = occupyingBlock['courseSection'];

    // Flag both blocks as conflicting
    final batch = _db.batch();
    batch.update(_db.collection('scheduleBlocks').doc(blockId), {'hasConflict': true});
    batch.update(_db.collection('scheduleBlocks').doc(occupyingBlock.id), {'hasConflict': true});

    // Route notification to council president
    final councilPresidentQuery = await _db.collection('users')
      .where('role', isEqualTo: 'council_president')
      .where('department', isEqualTo: mayorDepartment)
      .limit(1)
      .get();

    if (councilPresidentQuery.docs.isNotEmpty) {
      final notifRef = _db.collection('notifications').doc();
      batch.set(notifRef, {
        'notifId': notifRef.id,
        'recipientId': councilPresidentQuery.docs.first.id,
        'type': 'conflict_detected',
        'involvedBlockIds': [blockId, occupyingBlock.id],
        'roomId': roomId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return CheckInResult.conflict(occupyingSection: occupyingSection);
  }

  // No conflict — proceed with check-in
  final batch = _db.batch();
  batch.update(_db.collection('scheduleBlocks').doc(blockId), {
    'checkInStatus': 'checked_in',
  });
  batch.update(_db.collection('rooms').doc(roomId), {
    'status': 'occupied',
    'currentOccupantBlockId': blockId,
  });
  await batch.commit();
  return CheckInResult.success();
}
```

---

### 3.6 Notification Inbox

The inbox is a simple real-time Firestore stream. No push notification infrastructure needed.

```dart
// notification_service.dart
Stream<List<NotificationModel>> getNotificationsForUser(String userId) {
  return _db.collection('notifications')
    .where('recipientId', isEqualTo: userId)
    .orderBy('createdAt', descending: true)
    .snapshots()
    .map((snap) => snap.docs
      .map((doc) => NotificationModel.fromFirestore(doc))
      .toList()
    );
}

Future<void> markAsRead(String notifId) async {
  await _db.collection('notifications').doc(notifId).update({'isRead': true});
}

// Unread count (for the bell badge)
Stream<int> getUnreadCount(String userId) {
  return _db.collection('notifications')
    .where('recipientId', isEqualTo: userId)
    .where('isRead', isEqualTo: false)
    .snapshots()
    .map((snap) => snap.docs.length);
}
```

---

### 3.7 2.5D Floor Map (Isometric)

The floor map uses Flutter's `CustomPainter` to draw an isometric projection of the building. Each floor is a layer. Each room is a tile. Room tiles are colored by live status.

**Isometric projection formula:**
```
screenX = (col - row) * tileWidth / 2 + originX
screenY = (col + row) * tileHeight / 2 + originY
```

```dart
// isometric_painter.dart
class IsometricFloorPainter extends CustomPainter {
  final List<RoomModel> rooms;
  final Map<String, String> roomStatus; // roomId -> status string

  static const double tileW = 60.0;
  static const double tileH = 30.0;
  static const double tileDepth = 8.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final room in rooms) {
      final col = room.col;  // x position in floor grid
      final row = room.row;  // y position in floor grid
      final floorOffset = (6 - room.floor) * tileDepth * 4; // stack floors vertically

      final sx = (col - row) * tileW / 2 + size.width / 2;
      final sy = (col + row) * tileH / 2 + floorOffset;

      _drawIsometricTile(canvas, sx, sy, roomStatus[room.roomId] ?? 'available');
    }
  }

  void _drawIsometricTile(Canvas canvas, double sx, double sy, String status) {
    final topColor = switch (status) {
      'occupied' => const Color(0xFFE57373),  // red
      'soon'     => const Color(0xFFFFB74D),  // amber
      _          => const Color(0xFF81C784),  // green
    };

    // Top face
    final topPath = Path()
      ..moveTo(sx, sy)
      ..lineTo(sx + tileW / 2, sy + tileH / 2)
      ..lineTo(sx, sy + tileH)
      ..lineTo(sx - tileW / 2, sy + tileH / 2)
      ..close();
    canvas.drawPath(topPath, Paint()..color = topColor);

    // Left face (darker shade)
    final leftPath = Path()
      ..moveTo(sx - tileW / 2, sy + tileH / 2)
      ..lineTo(sx, sy + tileH)
      ..lineTo(sx, sy + tileH + tileDepth)
      ..lineTo(sx - tileW / 2, sy + tileH / 2 + tileDepth)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = topColor.withOpacity(0.6));

    // Right face (even darker)
    final rightPath = Path()
      ..moveTo(sx, sy + tileH)
      ..lineTo(sx + tileW / 2, sy + tileH / 2)
      ..lineTo(sx + tileW / 2, sy + tileH / 2 + tileDepth)
      ..lineTo(sx, sy + tileH + tileDepth)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = topColor.withOpacity(0.4));

    // Outline
    canvas.drawPath(topPath, Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5);
  }

  @override
  bool shouldRepaint(IsometricFloorPainter old) => old.roomStatus != roomStatus;
}
```

**Tap detection:** Wrap the `CustomPaint` in a `GestureDetector`. On `onTapDown`, reverse the projection to determine which room tile was tapped, then open the room detail sheet.

---

## 4. Phases

### Phase 1 — Foundation (Week 1–2)

**Goal:** App runs, auth works, rooms are seeded, basic dashboard is live.

| Task | Details |
|---|---|
| Flutter project setup | Init project, add Firebase dependencies, configure `firebase_options.dart` |
| Firebase project | Create project, enable Auth (email/password), create Firestore database |
| Data seeding | Manually seed all rooms (room number, floor, features) into Firestore |
| Auth screens | Login and Register screens with department and role selection |
| User model | `UserModel` with Firestore read/write |
| Room model | `RoomModel` with Firestore read |
| Dashboard shell | Display room grid with hardcoded status — no real data yet |
| Navigation | Bottom nav bar with Dashboard, Schedule, Floor Map, Notifications, Directory |

**Exit criteria:** A user can register as a mayor, log in, and see a grid of rooms with static status colors.

---

### Phase 2 — Core Features (Week 3–4)

**Goal:** Mayors can manage schedules and check in to rooms. Auto-release works.

| Task | Details |
|---|---|
| Schedule model + service | `ScheduleBlock` CRUD in Firestore |
| Schedule screens | My Schedule (weekly view), Add Block form, Edit/Delete block |
| Semester reuse | Duplicate previous semester blocks with `isActive` toggle |
| Status engine | Implement `StatusEngine.runOnAppLoad()` — auto-release and no-show logic |
| Check-in flow | Check-in screen, update room status in Firestore, link `currentOccupantBlockId` |
| Early release | Button on check-in screen to release room before end time |
| Live dashboard | Room grid now reads live Firestore `rooms` collection via stream |
| "Soon" status | Compute amber status client-side during dashboard load |
| Room detail screen | Show features, floor, current occupant section, today's schedule |
| Room search | Filter by features, floor, availability status |

**Exit criteria:** A mayor can add a schedule, check in to a room, see it turn red on the dashboard, and have it auto-release when the time passes.

---

### Phase 3 — Advanced Features (Week 5–6)

**Goal:** Conflict system, notifications, council directory, and floor map.

| Task | Details |
|---|---|
| Conflict detection | On check-in attempt, query room status and block if occupied — show warning with section name |
| Conflict flagging | Set `hasConflict = true` on both blocks, highlight in schedule view |
| Conflict notification | Write to `notifications` collection routed to council president |
| Notification inbox | Stream-based inbox screen with unread badge on nav bar icon |
| Mark read | Tap notification to mark as read, update Firestore |
| Conflict auto-clear | On room release or block reassignment, set `hasConflict = false` and write resolved notification |
| Council directory | Seed council officials into Firestore, build read-only directory screen |
| Floor map (basic) | Isometric `CustomPainter` with static room grid, color by live status |
| Floor map tap | Tap detection on tiles, open room detail bottom sheet |

**Exit criteria:** Two mayors trying to claim the same room triggers the soft block, the council president sees a notification, and the floor map shows all rooms by status.

---

### Phase 4 — Polish & Demo (Week 7–8)

**Goal:** Stable, demo-ready app with good UX and no obvious rough edges.

| Task | Details |
|---|---|
| Floor map expand/collapse | Tap floor layer to expand and see individual labeled room tiles |
| Schedule calendar view | Improve weekly view with proper time-slot grid rendering |
| Empty states | All screens have proper empty state messaging (no schedule yet, no notifications, etc.) |
| Error handling | Firestore errors, auth errors, and network failures handled gracefully |
| Loading states | Skeleton loaders or progress indicators on all async data loads |
| Form validation | All input forms validate before submission |
| App theming | Finalize color theme, consistent typography, dark/light mode |
| Onboarding | Brief onboarding screen explaining check-in flow for first-time mayors |
| Demo accounts | Create 3–5 seeded demo accounts across departments for live demo |
| Demo script | Prepare a walkthrough scenario: Mayor A checks in → Mayor B conflict → Council President notified → resolved |

**Exit criteria:** App can be handed to a non-developer to demo without guidance and it works end-to-end without errors.

---

## Appendix: Dependencies

```yaml
# pubspec.yaml (key dependencies)
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  cloud_firestore: ^5.0.0
  flutter_riverpod: ^2.5.0      # State management
  intl: ^0.19.0                 # Date/time formatting
  table_calendar: ^3.1.0        # Weekly schedule view
  go_router: ^13.0.0            # Navigation
```

---

*Document prepared for internal development use. Subject to revision as implementation progresses.*
