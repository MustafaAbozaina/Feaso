import Foundation
import SwiftData

@Model
final class Installment {
    var id: UUID
    var sequenceNumber: Int
    var amount: Decimal
    var dueDate: Date
    var isPaid: Bool
    var paidDate: Date?
    var note: String?
    var createdAt: Date
    
    var transaction: Transaction?
    
    /// The payment transaction created when this installment was marked as paid
    var paymentTransaction: Transaction?
    
    init(
        sequenceNumber: Int,
        amount: Decimal,
        dueDate: Date,
        transaction: Transaction? = nil,
        isPaid: Bool = false,
        paidDate: Date? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        self.sequenceNumber = sequenceNumber
        self.amount = amount
        self.dueDate = dueDate
        self.transaction = transaction
        self.isPaid = isPaid
        self.paidDate = paidDate
        self.note = note
        self.createdAt = .now
    }
    
    // MARK: - Computed Properties
    
    var isOverdue: Bool {
        !isPaid && dueDate < Date()
    }
    
    var status: InstallmentStatus {
        if isPaid {
            return .paid
        } else if isOverdue {
            return .overdue
        } else {
            let calendar = Calendar.current
            let daysUntilDue = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            if daysUntilDue <= 7 {
                return .dueSoon
            } else {
                return .upcoming
            }
        }
    }
}

// MARK: - Installment Status

enum InstallmentStatus: String, CaseIterable {
    case paid
    case overdue
    case dueSoon
    case upcoming
    
    var localizedName: String {
        switch self {
        case .paid:
            return String(localized: "Paid")
        case .overdue:
            return String(localized: "Overdue")
        case .dueSoon:
            return String(localized: "Due Soon")
        case .upcoming:
            return String(localized: "Upcoming")
        }
    }
}

// MARK: - Installment Interval

enum InstallmentInterval: Int, CaseIterable, Identifiable {
    case weekly = 7
    case biweekly = 14
    case monthly = 30
    
    var id: Int { rawValue }
    
    var localizedName: String {
        switch self {
        case .weekly:
            return String(localized: "Weekly")
        case .biweekly:
            return String(localized: "Bi-weekly")
        case .monthly:
            return String(localized: "Monthly")
        }
    }
}
