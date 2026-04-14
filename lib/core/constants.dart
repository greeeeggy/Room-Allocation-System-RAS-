// Departments, roles, room status, and day-of-week enums/constants

enum UserRole { mayor, councilPresident }

enum RoomStatus { available, occupied, soon }

enum DayOfWeek { Sun, Mon, Tue, Wed, Thu, Fri, Sat }

enum CheckInStatus { pending, checkedIn, released, noShow }

class Departments {
  static const List<String> all = [
    'IE',
    'ME',
    'AE',
    'CE',
    'Civil',
    'EE',
    'ECE',
  ];
}

class RoomFeatures {
  static const String tv = 'tv';
  static const String whiteboard = 'whiteboard';
  static const String blackboard = 'blackboard';
  static const String aircon = 'aircon';
  static const String projector = 'projector';

  static const List<String> all = [
    tv,
    whiteboard,
    blackboard,
    aircon,
    projector,
  ];
}

class AppStrings {
  static const String appName = 'Room Availability';
  static const String currentSemester = '2025-2';
}
