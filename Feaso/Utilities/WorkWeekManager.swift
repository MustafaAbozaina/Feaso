import Foundation

// MARK: - Weekday

enum Weekday: String, CaseIterable, Identifiable {
    case sunday = "sunday"
    case monday = "monday"
    case tuesday = "tuesday"
    case wednesday = "wednesday"
    case thursday = "thursday"
    case friday = "friday"
    case saturday = "saturday"
    
    var id: String { rawValue }
    
    /// Calendar weekday value (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }
    
    var localizedName: String {
        switch self {
        case .sunday: return String(localized: "Sunday")
        case .monday: return String(localized: "Monday")
        case .tuesday: return String(localized: "Tuesday")
        case .wednesday: return String(localized: "Wednesday")
        case .thursday: return String(localized: "Thursday")
        case .friday: return String(localized: "Friday")
        case .saturday: return String(localized: "Saturday")
        }
    }
    
    var shortName: String {
        switch self {
        case .sunday: return String(localized: "Sun")
        case .monday: return String(localized: "Mon")
        case .tuesday: return String(localized: "Tue")
        case .wednesday: return String(localized: "Wed")
        case .thursday: return String(localized: "Thu")
        case .friday: return String(localized: "Fri")
        case .saturday: return String(localized: "Sat")
        }
    }
}

// MARK: - WorkWeekManager

/// Handles work week settings and date calculations
enum WorkWeekManager {
    
    private static let workWeekStartKey = "workWeekStart"
    private static let workWeekEndKey = "workWeekEnd"
    
    // MARK: - Settings
    
    static var workWeekStart: Weekday {
        get {
            if let saved = UserDefaults.standard.string(forKey: workWeekStartKey),
               let weekday = Weekday(rawValue: saved) {
                return weekday
            }
            return .sunday // Default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: workWeekStartKey)
        }
    }
    
    static var workWeekEnd: Weekday {
        get {
            if let saved = UserDefaults.standard.string(forKey: workWeekEndKey),
               let weekday = Weekday(rawValue: saved) {
                return weekday
            }
            return .thursday // Default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: workWeekEndKey)
        }
    }
    
    // MARK: - Date Calculations
    
    /// Returns the end of work week date from a given date
    static func endOfWorkWeek(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let targetWeekday = workWeekEnd.calendarWeekday
        
        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd < 0 {
            daysToAdd += 7
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
    }
    
    /// Returns the start of work week date from a given date
    static func startOfWorkWeek(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        let targetWeekday = workWeekStart.calendarWeekday
        
        var daysToSubtract = currentWeekday - targetWeekday
        if daysToSubtract < 0 {
            daysToSubtract += 7
        }
        
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date
    }
}
