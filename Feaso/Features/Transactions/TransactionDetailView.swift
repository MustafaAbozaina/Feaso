import SwiftUI

struct TransactionDetailView: View {
    let transaction: Transaction
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingFullScreenImage = false
    @State private var showingReceiptPreview = false
    
    private var title: String {
        if transaction.isReversal {
            return String(localized: "Reversal")
        }
        switch transaction.type {
        case .payment:
            return String(localized: "Payment")
        case .distribution:
            return String(localized: "Distribution")
        case .return:
            return String(localized: "Return")
        case .adjustment:
            return String(localized: "Adjustment")
        case .stockReceipt:
            return String(localized: "Stock Receipt")
        }
    }
    
    private var iconName: String {
        switch transaction.type {
        case .payment:
            return "checkmark.circle.fill"
        case .distribution:
            return "arrow.right.circle.fill"
        case .return:
            return "arrow.uturn.backward.circle.fill"
        case .adjustment:
            return transaction.isReversal ? "arrow.uturn.backward.circle.fill" : "pencil.circle.fill"
        case .stockReceipt:
            return "arrow.down.to.line.circle.fill"
        }
    }
    
    private var iconColor: Color {
        if transaction.isReversed {
            return Color.Theme.ink3
        }
        switch transaction.type {
        case .payment, .stockReceipt:
            return Color.Theme.success
        case .distribution:
            return Color.Theme.accent
        case .return, .adjustment:
            return Color.Theme.ink2
        }
    }
    
    private var amountSign: String {
        transaction.amount < 0 ? "−" : "+"
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: transaction.occurredAt)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                headerCard
                
                if !transaction.items.isEmpty {
                    itemsCard
                }
                
                detailsCard
                
                if transaction.hasAttachment {
                    attachmentCard
                }
                
                if transaction.isReversed {
                    reversedBanner
                }
            }
            .padding(Spacing.lg)
        }
        .background(Color.Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingReceiptPreview = true
                } label: {
                    Image(systemName: "doc.text")
                }
            }
        }
        .fullScreenCover(isPresented: $showingReceiptPreview) {
            TransactionReceiptPreviewView(transaction: transaction)
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let fileName = transaction.attachmentFileName,
               let image = ImageAttachmentService.loadImage(fileName: fileName) {
                FullScreenImageView(image: image)
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
            
            // Amount
            VStack(spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(amountSign)
                        .font(.system(size: 36, weight: .bold))
                    Text(CurrencyFormatter.string(abs(transaction.amount)))
                        .font(.system(size: 36, weight: .bold))
                    Text(CurrencyFormatter.symbol)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.Theme.ink2)
                }
                .foregroundStyle(transaction.isReversed ? Color.Theme.ink3 : Color.Theme.ink)
                
                Text(transactionDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.Theme.ink2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .padding(.horizontal, Spacing.lg)
        .background(Color.Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .opacity(transaction.isReversed ? 0.7 : 1.0)
    }
    
    private var transactionDescription: String {
        switch transaction.type {
        case .stockReceipt:
            return String(localized: "Stock added to inventory")
        default:
            break
        }
        
        guard let salesman = transaction.salesman else {
            return ""
        }
        
        switch transaction.type {
        case .payment:
            return String(localized: "Payment received from \(salesman.name)")
        case .distribution:
            return String(localized: "Products given to \(salesman.name)")
        case .return:
            return String(localized: "Products returned by \(salesman.name)")
        case .adjustment:
            if transaction.isReversal {
                return String(localized: "Reversal for \(salesman.name)")
            }
            return String(localized: "Balance adjustment for \(salesman.name)")
        case .stockReceipt:
            return "" // Already handled above
        }
    }
    
    // MARK: - Items Card
    
    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "ITEMS"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Theme.ink2)
            
            VStack(spacing: 0) {
                ForEach(Array(transaction.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, Spacing.md)
                    }
                    
                    TransactionItemRow(item: item)
                }
            }
            .background(Color.Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "DETAILS"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Theme.ink2)
            
            VStack(spacing: 0) {
                // Date
                DetailRow(
                    label: String(localized: "Date"),
                    value: formattedDate
                )
                
                Divider()
                    .padding(.horizontal, Spacing.md)
                
                // Salesman
                if let salesman = transaction.salesman {
                    DetailRow(
                        label: String(localized: "Salesman"),
                        value: salesman.name
                    )
                    
                    Divider()
                        .padding(.horizontal, Spacing.md)
                }
                
                // Type
                DetailRow(
                    label: String(localized: "Type"),
                    value: typeDisplayName
                )
                
                // Payment Type (for distributions only)
                if transaction.type == .distribution, let paymentType = transaction.paymentType {
                    Divider()
                        .padding(.horizontal, Spacing.md)
                    
                    DetailRow(
                        label: String(localized: "Payment Type"),
                        value: paymentType.localizedName
                    )
                }
                
                // Note
                if let note = transaction.note, !note.isEmpty {
                    Divider()
                        .padding(.horizontal, Spacing.md)
                    
                    DetailRow(
                        label: String(localized: "Note"),
                        value: note
                    )
                }
                
                // Transaction ID
                Divider()
                    .padding(.horizontal, Spacing.md)
                
                DetailRow(
                    label: String(localized: "Reference"),
                    value: String(transaction.id.uuidString.prefix(8)).uppercased()
                )
            }
            .background(Color.Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }
    
    private var typeDisplayName: String {
        switch transaction.type {
        case .payment:
            return String(localized: "Payment")
        case .distribution:
            return String(localized: "Distribution")
        case .return:
            return String(localized: "Return")
        case .adjustment:
            return transaction.isReversal ? String(localized: "Reversal") : String(localized: "Adjustment")
        case .stockReceipt:
            return String(localized: "Stock Receipt")
        }
    }
    
    // MARK: - Attachment Card
    
    private var attachmentCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(String(localized: "ATTACHMENT"))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Theme.ink2)
            
            if let fileName = transaction.attachmentFileName,
               let image = ImageAttachmentService.loadImage(fileName: fileName) {
                Button {
                    showingFullScreenImage = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption)
                                Text(String(localized: "Tap to view"))
                                    .font(.caption)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                            .padding(Spacing.sm)
                        }
                }
            }
        }
    }
    
    // MARK: - Reversed Banner
    
    private var reversedBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
            
            Text(String(localized: "This transaction has been reversed"))
                .font(.subheadline)
        }
        .foregroundStyle(Color.Theme.warning)
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(Color.Theme.warningBg)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }
}

// MARK: - Transaction Item Row

private struct TransactionItemRow: View {
    let item: TransactionItem
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Quantity badge
            Text("\(item.quantity)×")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Theme.accent)
                .frame(width: 40, alignment: .leading)
            
            // Product name
            VStack(alignment: .leading, spacing: 2) {
                Text(item.product?.name ?? String(localized: "Unknown Product"))
                    .font(.body)
                    .foregroundStyle(Color.Theme.ink)
                
                Text("\(CurrencyFormatter.string(item.unitPrice)) \(CurrencyFormatter.symbol) \(String(localized: "each"))")
                    .font(.caption)
                    .foregroundStyle(Color.Theme.ink3)
            }
            
            Spacer()
            
            // Line total
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(CurrencyFormatter.string(item.lineTotal))
                    .font(.body)
                    .fontWeight(.medium)
                Text(CurrencyFormatter.symbol)
                    .font(.caption)
            }
            .foregroundStyle(Color.Theme.ink)
        }
        .padding(Spacing.md)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink2)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(Spacing.md)
    }
}

// MARK: - Full Screen Image View

private struct FullScreenImageView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * scale)
                        .frame(minHeight: geometry.size.height)
                }
            }
            .background(Color.black)
            .ignoresSafeArea()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: Spacing.md) {
                        Button {
                            withAnimation {
                                scale = max(1.0, scale - 0.5)
                            }
                        } label: {
                            Image(systemName: "minus.magnifyingglass")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Button {
                            withAnimation {
                                scale = min(3.0, scale + 0.5)
                            }
                        } label: {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// MARK: - Transaction Receipt Preview View

import PDFKit

private struct TransactionReceiptPreviewView: View {
    let transaction: Transaction
    
    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?
    @State private var isGenerating = true
    @State private var showingShareSheet = false
    
    private var receiptTitle: String {
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.Theme.background
                    .ignoresSafeArea()
                
                if isGenerating {
                    ProgressView(String(localized: "Generating receipt..."))
                        .foregroundStyle(Color.Theme.ink2)
                } else if let data = pdfData {
                    ReceiptPDFPreviewView(data: data)
                } else {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(Color.Theme.warning)
                        Text(String(localized: "Failed to generate receipt"))
                            .font(.body)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                }
            }
            .navigationTitle(receiptTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(pdfData == nil || isGenerating)
                }
            }
            .task {
                await generatePDF()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let data = pdfData {
                    ReceiptShareSheet(items: [data])
                }
            }
        }
    }
    
    @MainActor
    private func generatePDF() async {
        // Small delay for smooth animation
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        pdfData = StatementGenerator.generateTransactionPDF(for: transaction)
        isGenerating = false
    }
}

// MARK: - Receipt PDF Preview

private struct ReceiptPDFPreviewView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor.systemGray6
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
    }
}

// MARK: - Receipt Share Sheet

private struct ReceiptShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview("Distribution") {
    NavigationStack {
        TransactionDetailView(transaction: {
            let s = Salesman(name: "Ahmed")
            let t = Transaction(type: .distribution, amount: 26000, salesman: s)
            return t
        }())
    }
}

#Preview("Payment") {
    NavigationStack {
        TransactionDetailView(transaction: {
            let s = Salesman(name: "Ahmed")
            let t = Transaction(type: .payment, amount: -5000, salesman: s, note: "Partial payment - cash")
            return t
        }())
    }
}
