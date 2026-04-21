// Departments, roles, room status, and day-of-week enums/constants

enum UserRole { mayor, councilPresident }

enum RoomStatus { available, occupied, soon, noClass }

enum DayOfWeek { Sun, Mon, Tue, Wed, Thu, Fri, Sat }

enum CheckInStatus { pending, checkedIn, released, noShow }

class Departments {
  static const String bsie = 'BS in Industrial Engineering';
  static const String bsase = 'BS in Aerospace Engineering';
  static const String bsee = 'BS in Electrical Engineering';
  static const String bsece = 'BS in Electronics Engineering';
  static const String bsme = 'BS in Mechanical Engineering';
  static const String bscpe = 'BS in Computer Engineering';
  static const String bsce = 'BS in Civil Engineering';

  // Order for registration dropdown
  static const List<String> allFullNames = [
    bsie,
    bsase,
    bsee,
    bsece,
    bsme,
    bscpe,
    bsce,
  ];

  // Legacy/abbreviation mapping
  static const Map<String, String> _toAbbreviation = {
    bsie: 'BSIE',
    bsase: 'BSASE',
    bsee: 'BSEE',
    bsece: 'BSECE',
    bsme: 'BSME',
    bscpe: 'BSCpE',
    bsce: 'BSCE',
    // Legacy support
    'IE': 'BSIE',
    'AE': 'BSASE',
    'ASE': 'BSASE',
    'EE': 'BSEE',
    'ECE': 'BSECE',
    'ME': 'BSME',
    'CE': 'BSCE',
    'Civil': 'BSCE',
    'CpE': 'BSCpE',
  };

  static String getAbbreviation(String fullNameOrLegacy) {
    return _toAbbreviation[fullNameOrLegacy] ?? fullNameOrLegacy;
  }

  static List<String> get allAbbreviations => [
        'BSIE',
        'BSASE',
        'BSEE',
        'BSECE',
        'BSME',
        'BSCpE',
        'BSCE',
      ];

  // Backward compatibility
  static const List<String> all = allFullNames;
}


enum RoomType { classroom, laboratory, office, unknown }

class RoomFeatures {
  static const String tv = 'tv';
  static const String whiteboard = 'whiteboard';
  static const String blackboard = 'blackboard';
  static const String aircon = 'aircon';
  static const String projector = 'projector';
  static const String computer = 'computer';

  static const List<String> all = [
    tv,
    whiteboard,
    blackboard,
    aircon,
    projector,
    computer,
  ];
}

class AppStrings {
  static const String appName = 'Room Allocation System';
  static const String currentSemester = '2025-2';
}
