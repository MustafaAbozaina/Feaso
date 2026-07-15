import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case distribution  // products given to a salesman (debt +, stock -)
    case payment       // money received from a salesman (debt -)
    case `return`      // products returned by a salesman (debt -, stock +)
    case adjustment    // manual correction (signed amount)
    case stockReceipt  // products added to inventory (stock +, no salesman)
}
