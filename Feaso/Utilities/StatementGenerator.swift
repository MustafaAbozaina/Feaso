import SwiftUI
import PDFKit

enum StatementGenerator {
    
    /// Generates a PDF statement for a customer
    @MainActor
    static func generatePDF(
        for customer: Customer,
        dateRange: ClosedRange<Date>? = nil,
        companyName: String = "Feaso"
    ) -> Data? {
        let pageWidth: CGFloat = 595.2  // A4 width in points
        let pageHeight: CGFloat = 841.8 // A4 height in points
        let margin: CGFloat = 40
        
        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        
        let transactions = filteredTransactions(for: customer, dateRange: dateRange)
        let currency = CurrencyFormatter.symbol
        
        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = margin
            let contentWidth = pageWidth - (margin * 2)
            
            // MARK: - Header
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            
            let title = String(localized: "Account Statement")
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 35
            
            // Company name
            let companyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            companyName.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: companyAttributes)
            yPosition += 30
            
            // Divider
            drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
            yPosition += 20
            
            // MARK: - Customer Info
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            
            // Name
            String(localized: "Customer").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
            yPosition += 15
            customer.name.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: valueAttributes)
            
            // Date on right side
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let dateString = dateFormatter.string(from: Date())
            String(localized: "Date").draw(at: CGPoint(x: pageWidth - margin - 150, y: yPosition - 15), withAttributes: labelAttributes)
            dateString.draw(at: CGPoint(x: pageWidth - margin - 150, y: yPosition), withAttributes: valueAttributes)
            yPosition += 30
            
            // Phone if available
            if let phone = customer.phone, !phone.isEmpty {
                String(localized: "Phone").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
                yPosition += 15
                phone.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: valueAttributes)
                yPosition += 25
            }
            
            yPosition += 10
            
            // MARK: - Balance Summary Box
            let balanceBoxHeight: CGFloat = 70
            let balanceBox = CGRect(x: margin, y: yPosition, width: contentWidth, height: balanceBoxHeight)
            
            context.cgContext.setFillColor(UIColor.systemBlue.withAlphaComponent(0.1).cgColor)
            context.cgContext.fill(balanceBox)
            
            let balanceLabel = String(localized: "Current Balance")
            let balanceLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.systemBlue
            ]
            balanceLabel.draw(at: CGPoint(x: margin + 15, y: yPosition + 12), withAttributes: balanceLabelAttributes)
            
            let balanceValue = "\(CurrencyFormatter.string(customer.balance)) \(currency)"
            let balanceValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.systemBlue
            ]
            balanceValue.draw(at: CGPoint(x: margin + 15, y: yPosition + 30), withAttributes: balanceValueAttributes)
            
            yPosition += balanceBoxHeight + 25
            
            // MARK: - Transactions Header
            let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            String(localized: "Transaction History").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
            yPosition += 25
            
            // Table header
            let headerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: UIColor.gray
            ]
            
            String(localized: "DATE").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
            String(localized: "DESCRIPTION").draw(at: CGPoint(x: margin + 90, y: yPosition), withAttributes: headerAttributes)
            String(localized: "AMOUNT").draw(at: CGPoint(x: pageWidth - margin - 80, y: yPosition), withAttributes: headerAttributes)
            yPosition += 18
            
            drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition), color: .lightGray)
            yPosition += 8
            
            // MARK: - Transaction Rows
            let rowDateAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.darkGray
            ]
            let rowDescAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            
            let shortDateFormatter = DateFormatter()
            shortDateFormatter.dateFormat = "dd MMM yyyy"
            
            for transaction in transactions {
                // Check if we need a new page
                if yPosition > pageHeight - 100 {
                    context.beginPage()
                    yPosition = margin
                }
                
                let dateStr = shortDateFormatter.string(from: transaction.occurredAt)
                dateStr.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: rowDateAttributes)
                
                let description = transactionDescription(for: transaction)
                description.draw(at: CGPoint(x: margin + 90, y: yPosition), withAttributes: rowDescAttributes)
                
                let amountStr = formatAmount(transaction.amount, currency: currency)
                let amountColor: UIColor = transaction.amount < 0 ? .systemGreen : .black
                let amountAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: amountColor
                ]
                
                let amountSize = amountStr.size(withAttributes: amountAttributes)
                amountStr.draw(at: CGPoint(x: pageWidth - margin - amountSize.width, y: yPosition), withAttributes: amountAttributes)
                
                yPosition += 22
                
                // Light divider
                if transaction.id != transactions.last?.id {
                    drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition - 5), to: CGPoint(x: pageWidth - margin, y: yPosition - 5), color: UIColor.lightGray.withAlphaComponent(0.5))
                }
            }
            
            // MARK: - Footer
            yPosition = pageHeight - 60
            drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
            yPosition += 15
            
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            
            let generatedText = String(localized: "Generated on \(dateFormatter.string(from: Date()))")
            generatedText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: footerAttributes)
            
            let pageText = "Page 1"
            let pageSize = pageText.size(withAttributes: footerAttributes)
            pageText.draw(at: CGPoint(x: pageWidth - margin - pageSize.width, y: yPosition), withAttributes: footerAttributes)
        }
        
        return data
    }
    
    /// Generates a PDF receipt for a single transaction
    @MainActor
    static func generateTransactionPDF(
        for transaction: Transaction,
        companyName: String = "Feaso"
    ) -> Data? {
        let pageWidth: CGFloat = 595.2  // A4 width in points
        let pageHeight: CGFloat = 841.8 // A4 height in points
        let margin: CGFloat = 40
        
        let pdfRenderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )
        
        let currency = CurrencyFormatter.symbol
        
        let data = pdfRenderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = margin
            let contentWidth = pageWidth - (margin * 2)
            
            // MARK: - Header
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            
            let title = transactionTypeTitle(for: transaction)
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 35
            
            // Company name
            let companyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            companyName.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: companyAttributes)
            yPosition += 30
            
            // Divider
            drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
            yPosition += 20
            
            // MARK: - Transaction Info
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            
            // Reference Number
            let ref = String(transaction.id.uuidString.prefix(8)).uppercased()
            String(localized: "Reference").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
            yPosition += 15
            "#\(ref)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: valueAttributes)
            
            // Date on right side
            let dateString = dateFormatter.string(from: transaction.occurredAt)
            String(localized: "Date").draw(at: CGPoint(x: pageWidth - margin - 200, y: yPosition - 15), withAttributes: labelAttributes)
            dateString.draw(at: CGPoint(x: pageWidth - margin - 200, y: yPosition), withAttributes: valueAttributes)
            yPosition += 30
            
            // Customer
            if let customer = transaction.customer {
                String(localized: "Customer").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
                yPosition += 15
                customer.name.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: valueAttributes)
                
                if let phone = customer.phone, !phone.isEmpty {
                    phone.draw(at: CGPoint(x: pageWidth - margin - 200, y: yPosition), withAttributes: valueAttributes)
                }
                yPosition += 30
            }
            
            // Payment Type (for distributions only)
            if transaction.type == .distribution, let paymentType = transaction.paymentType {
                String(localized: "Payment Type").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: labelAttributes)
                yPosition += 15
                paymentType.localizedName.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: valueAttributes)
                yPosition += 30
            }
            
            yPosition += 10
            
            // MARK: - Amount Box
            let amountBoxHeight: CGFloat = 80
            let amountBox = CGRect(x: margin, y: yPosition, width: contentWidth, height: amountBoxHeight)
            
            let boxColor: UIColor = transaction.type == .payment ? .systemGreen : .systemBlue
            context.cgContext.setFillColor(boxColor.withAlphaComponent(0.1).cgColor)
            context.cgContext.fill(amountBox)
            
            let amountLabel = transactionAmountLabel(for: transaction)
            let amountLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: boxColor
            ]
            amountLabel.draw(at: CGPoint(x: margin + 15, y: yPosition + 15), withAttributes: amountLabelAttributes)
            
            let amountSign = transaction.amount < 0 ? "−" : "+"
            let amountValue = "\(amountSign)\(CurrencyFormatter.string(abs(transaction.amount))) \(currency)"
            let amountValueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: boxColor
            ]
            amountValue.draw(at: CGPoint(x: margin + 15, y: yPosition + 38), withAttributes: amountValueAttributes)
            
            yPosition += amountBoxHeight + 25
            
            // MARK: - Items Section (for distributions)
            if !transaction.items.isEmpty {
                let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.black
                ]
                String(localized: "Items").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25
                
                // Table header
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: UIColor.gray
                ]
                
                String(localized: "QTY").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
                String(localized: "PRODUCT").draw(at: CGPoint(x: margin + 50, y: yPosition), withAttributes: headerAttributes)
                String(localized: "UNIT PRICE").draw(at: CGPoint(x: pageWidth - margin - 160, y: yPosition), withAttributes: headerAttributes)
                String(localized: "TOTAL").draw(at: CGPoint(x: pageWidth - margin - 70, y: yPosition), withAttributes: headerAttributes)
                yPosition += 18
                
                drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition), color: .lightGray)
                yPosition += 8
                
                // Item rows
                let rowAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]
                let rowValueAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: UIColor.black
                ]
                
                for item in transaction.items {
                    "\(item.quantity)×".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: rowAttributes)
                    
                    let productName = item.product?.name ?? String(localized: "Unknown")
                    productName.draw(at: CGPoint(x: margin + 50, y: yPosition), withAttributes: rowAttributes)
                    
                    let unitPrice = "\(CurrencyFormatter.string(item.unitPrice)) \(currency)"
                    unitPrice.draw(at: CGPoint(x: pageWidth - margin - 160, y: yPosition), withAttributes: rowAttributes)
                    
                    let lineTotal = "\(CurrencyFormatter.string(item.lineTotal)) \(currency)"
                    let lineTotalSize = lineTotal.size(withAttributes: rowValueAttributes)
                    lineTotal.draw(at: CGPoint(x: pageWidth - margin - lineTotalSize.width, y: yPosition), withAttributes: rowValueAttributes)
                    
                    yPosition += 22
                }
                
                // Subtotal line
                yPosition += 5
                drawLine(in: context.cgContext, from: CGPoint(x: pageWidth - margin - 160, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition), color: .lightGray)
                yPosition += 10
                
                let totalLabelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: UIColor.black
                ]
                String(localized: "Total").draw(at: CGPoint(x: pageWidth - margin - 160, y: yPosition), withAttributes: totalLabelAttributes)
                
                let total = "\(CurrencyFormatter.string(abs(transaction.amount))) \(currency)"
                let totalSize = total.size(withAttributes: totalLabelAttributes)
                total.draw(at: CGPoint(x: pageWidth - margin - totalSize.width, y: yPosition), withAttributes: totalLabelAttributes)
                
                yPosition += 30
            }
            
            // MARK: - Installments Section
            if transaction.hasInstallments {
                let sectionTitleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                    .foregroundColor: UIColor.black
                ]
                String(localized: "Installments").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: sectionTitleAttributes)
                yPosition += 25
                
                // Summary line
                let summaryAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.darkGray
                ]
                let paidCount = transaction.paidInstallmentsCount
                let totalCount = transaction.installments.count
                let summaryText = String(localized: "\(paidCount) of \(totalCount) paid") + " • " + String(localized: "Remaining") + ": \(CurrencyFormatter.string(transaction.remainingInstallmentAmount)) \(currency)"
                summaryText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: summaryAttributes)
                yPosition += 20
                
                // Table header
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: UIColor.gray
                ]
                
                String(localized: "#").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
                String(localized: "AMOUNT").draw(at: CGPoint(x: margin + 40, y: yPosition), withAttributes: headerAttributes)
                String(localized: "DUE DATE").draw(at: CGPoint(x: margin + 140, y: yPosition), withAttributes: headerAttributes)
                String(localized: "STATUS").draw(at: CGPoint(x: pageWidth - margin - 80, y: yPosition), withAttributes: headerAttributes)
                yPosition += 18
                
                drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition), color: .lightGray)
                yPosition += 8
                
                let shortDateFormatter = DateFormatter()
                shortDateFormatter.dateFormat = "dd MMM yyyy"
                
                let rowAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.black
                ]
                
                for installment in transaction.sortedInstallments {
                    // Check if we need a new page
                    if yPosition > pageHeight - 100 {
                        context.beginPage()
                        yPosition = margin
                    }
                    
                    "\(installment.sequenceNumber)".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: rowAttributes)
                    
                    let amountStr = "\(CurrencyFormatter.string(installment.amount)) \(currency)"
                    amountStr.draw(at: CGPoint(x: margin + 40, y: yPosition), withAttributes: rowAttributes)
                    
                    let dateStr = shortDateFormatter.string(from: installment.dueDate)
                    dateStr.draw(at: CGPoint(x: margin + 140, y: yPosition), withAttributes: rowAttributes)
                    
                    let statusColor: UIColor = installment.isPaid ? .systemGreen : (installment.isOverdue ? .systemOrange : .darkGray)
                    let statusAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: statusColor
                    ]
                    let statusText = installment.status.localizedName
                    let statusSize = statusText.size(withAttributes: statusAttributes)
                    statusText.draw(at: CGPoint(x: pageWidth - margin - statusSize.width, y: yPosition), withAttributes: statusAttributes)
                    
                    yPosition += 22
                }
                
                yPosition += 10
            }
            
            // MARK: - Note
            if let note = transaction.note, !note.isEmpty {
                yPosition += 10
                
                let noteHeaderAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: UIColor.gray
                ]
                String(localized: "Note").draw(at: CGPoint(x: margin, y: yPosition), withAttributes: noteHeaderAttributes)
                yPosition += 15
                
                let noteAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: UIColor.black
                ]
                
                let noteRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: 100)
                note.draw(in: noteRect, withAttributes: noteAttributes)
            }
            
            // MARK: - Footer
            yPosition = pageHeight - 60
            drawLine(in: context.cgContext, from: CGPoint(x: margin, y: yPosition), to: CGPoint(x: pageWidth - margin, y: yPosition))
            yPosition += 15
            
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            
            let shortDateFormatter = DateFormatter()
            shortDateFormatter.dateStyle = .long
            let generatedText = String(localized: "Generated on \(shortDateFormatter.string(from: Date()))")
            generatedText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: footerAttributes)
            
            String(localized: "Generated by Feaso").draw(at: CGPoint(x: pageWidth - margin - 100, y: yPosition), withAttributes: footerAttributes)
        }
        
        return data
    }
    
    private static func transactionTypeTitle(for transaction: Transaction) -> String {
        if transaction.isReversal {
            return String(localized: "Reversal Receipt")
        }
        switch transaction.type {
        case .payment:
            return String(localized: "Payment Receipt")
        case .distribution:
            return String(localized: "Distribution Receipt")
        case .return:
            return String(localized: "Return Receipt")
        case .adjustment:
            return String(localized: "Adjustment Receipt")
        case .stockReceipt:
            return String(localized: "Stock Receipt")
        }
    }
    
    private static func transactionAmountLabel(for transaction: Transaction) -> String {
        switch transaction.type {
        case .payment:
            return String(localized: "Payment Amount")
        case .distribution:
            return String(localized: "Distribution Total")
        case .return:
            return String(localized: "Return Total")
        case .adjustment:
            return String(localized: "Adjustment Amount")
        case .stockReceipt:
            return String(localized: "Stock Value")
        }
    }
    
    /// Generates a shareable text summary
    static func generateTextSummary(for customer: Customer) -> String {
        let currency = CurrencyFormatter.symbol
        let balance = CurrencyFormatter.string(customer.balance)
        
        var text = """
        📋 *\(String(localized: "Account Statement"))*
        
        👤 \(customer.name)
        💰 \(String(localized: "Balance")): \(balance) \(currency)
        
        """
        
        // Full journal: reversed transactions appear alongside their reversal
        // so the listed amounts reconcile with the balance.
        let recentTransactions = customer.transactions
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(5)
        
        if !recentTransactions.isEmpty {
            text += "\(String(localized: "Recent Transactions")):\n"
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd/MM"
            
            for transaction in recentTransactions {
                let date = dateFormatter.string(from: transaction.occurredAt)
                let amount = formatAmount(transaction.amount, currency: currency)
                let desc = shortDescription(for: transaction)
                text += "• \(date): \(desc) \(amount)\n"
            }
        }
        
        text += "\n\(String(localized: "Generated by Feaso"))"
        
        return text
    }
    
    // MARK: - Private Helpers
    
    private static func filteredTransactions(for customer: Customer, dateRange: ClosedRange<Date>?) -> [Transaction] {
        // Full journal: reversed transactions appear alongside their reversal
        // so the statement rows reconcile with the balance.
        var transactions = customer.transactions
            .sorted { $0.occurredAt > $1.occurredAt }
        
        if let range = dateRange {
            transactions = transactions.filter { range.contains($0.occurredAt) }
        }
        
        return transactions
    }
    
    private static func transactionDescription(for transaction: Transaction) -> String {
        if transaction.isReversal {
            return String(localized: "Reversal")
        }
        
        switch transaction.type {
        case .payment:
            return transaction.note ?? String(localized: "Payment received")
        case .distribution:
            let items = transaction.items.compactMap { item -> String? in
                guard let name = item.product?.name else { return nil }
                return "\(item.quantity)× \(name)"
            }
            var description: String
            if items.isEmpty {
                description = String(localized: "Products distributed")
            } else {
                description = items.joined(separator: ", ")
            }
            // Append payment type if available
            if let paymentType = transaction.paymentType {
                description += " (\(paymentType.localizedName))"
            }
            return description
        case .return:
            return String(localized: "Products returned")
        case .adjustment:
            return String(localized: "Adjustment")
        case .stockReceipt:
            return String(localized: "Stock received")
        }
    }
    
    private static func shortDescription(for transaction: Transaction) -> String {
        switch transaction.type {
        case .payment:
            return "💵"
        case .distribution:
            return "📦"
        case .return:
            return "↩️"
        case .adjustment:
            return "📝"
        case .stockReceipt:
            return "📥"
        }
    }
    
    private static func formatAmount(_ amount: Decimal, currency: String) -> String {
        let prefix = amount < 0 ? "−" : "+"
        return "\(prefix)\(CurrencyFormatter.string(abs(amount))) \(currency)"
    }
    
    private static func drawLine(in context: CGContext, from: CGPoint, to: CGPoint, color: UIColor = .black) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.5)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
    }
}
