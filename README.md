# Room Availability System (RAS)

A premium, architectural-grade room management and availability system designed specifically for the Engineering Building. RAS provides a seamless, real-time environment for coordinating room occupancy, managing academic schedules, and facilitating communication between class mayors and the Engineering Council.

---

## ✨ Core Functionalities

### 🏦 Role-Based Ecosystem
- **Engineering Council President (Super-Admin)**: 
  - Exclusive access to the **System Reset** console.
  - Ability to perform a "Full System Wipe" at the end of the school year.
  - Overview of all department activities.
- **Council Presidents**:
  - Manage and authorize Class Mayors within their respective departments (e.g., BSIE, BSEE, BSCE).
  - Mediate schedule conflicts reported by the system.
- **Class Mayors**:
  - Manage personal and class schedules.
  - Real-time room check-in and check-out.
  - Report and resolve scheduling overlaps.

### 🏛️ Room Search & Management
- **Architectural Room Search**: Real-time visualization of room statuses:
  - **Available**: Room is free for occupancy.
  - **Occupied**: Room is currently in use (shows current occupant).
  - **Soon**: Room will be occupied within the next 30 minutes.
- **Detailed Room Insights**: View room features, complete weekly schedules, and historical usage logs.

### 📅 Dynamic Scheduling
- **Intelligent Check-in**: One-tap check-in system that automatically flags conflicts if a room is occupied by another section.
- **Conflict Detection Engine**:
  - **Dynamic Conflicts**: Real-time detection during check-in.
  - **Static Conflicts**: Automatic detection of overlaps in the master schedule database.
- **End-of-Term Actions**:
  - **End of Semester**: Hidden 5-tap easter egg for mayors to wipe their semester schedules.
  - **End of School Year**: Secure, multi-stage reset for the Engineering Council to prepare for the new academic year.

### 🔔 Smart Notifications
- **Context-Aware Alerts**: Specialized messaging for different roles during conflicts.
- **Conflict Mediation**: Automatic notification to Mayors, Council Presidents, and the EC President when overlaps occur.
- **Lost & Found Broadcasts**: System-wide notifications when items are reported found in the building.

### 🎨 Design Language: "Architectural Metropolis"
- **Premium Aesthetics**: Glassmorphism-inspired UI with a curated neutral palette and vibrant accent tokens.
- **Micro-Interactions**: Smooth staggered animations, pulsing indicators, and ease-in-out transitions.
- **Responsive Layout**: Designed for high-density information display while maintaining clean, minimalist composition.

---

## 🛠️ Technology Stack
- **Framework**: [Flutter](https://flutter.dev) (iOS, Android, Web)
- **Backend**: [Firebase](https://firebase.google.com) (Firestore, Authentication, Hosting)
- **Notifications**: [OneSignal](https://onesignal.com)
- **Typography**: Outfit, Syne, Instrument Sans (Google Fonts)

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Firebase Project configured
- OneSignal App ID

### Installation
1. Clone the repository
2. Run `flutter pub get`
3. Configure Firebase using `flutterfire configure`
4. Run the app: `flutter run`

---

## 📂 Project Structure
- `lib/core`: Constants, themes, and global routing.
- `lib/models`: Data structures and serialization.
- `lib/providers`: Riverpod state management.
- `lib/services`: Firebase and Notification logic layers.
- `lib/screens`: 
  - `admin/`: Super-admin reset tools.
  - `auth/`: Premium registration and login flows.
  - `directory/`: Council contact list.
  - `rooms/`: Room search and details.
  - `schedule/`: Personal and weekly schedule management.
