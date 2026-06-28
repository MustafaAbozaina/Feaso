import SwiftUI
import PDFKit

struct StatementPreviewView: View {
    let salesman: Salesman
    
    @Environment(\.dismiss) private var dismiss
    @State private var pdfData: Data?
    @State private var isGenerating = true
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.Theme.background
                    .ignoresSafeArea()
                
                if isGenerating {
                    ProgressView(String(localized: "Generating statement..."))
                        .foregroundStyle(Color.Theme.ink2)
                } else if let data = pdfData {
                    PDFPreviewView(data: data)
                } else {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(Color.Theme.warning)
                        Text(String(localized: "Failed to generate statement"))
                            .font(.body)
                            .foregroundStyle(Color.Theme.ink2)
                    }
                }
            }
            .navigationTitle(String(localized: "Statement"))
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
                    ShareSheet(items: [data])
                }
            }
        }
    }
    
    @MainActor
    private func generatePDF() async {
        // Small delay for smooth animation
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        pdfData = StatementGenerator.generatePDF(for: salesman)
        isGenerating = false
    }
}

// MARK: - PDF Preview View

struct PDFPreviewView: UIViewRepresentable {
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

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
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

#Preview {
    StatementPreviewView(salesman: {
        let s = Salesman(name: "Ahmed Mohamed", phone: "+201001234567")
        return s
    }())
}
