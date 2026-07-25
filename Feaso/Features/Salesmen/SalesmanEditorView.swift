import SwiftUI
import SwiftData

struct SalesmanEditorView: View {
    let salesman: Salesman?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false
    
    private var isEditing: Bool {
        salesman != nil
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var canDelete: Bool {
        guard let salesman else { return false }
        return salesman.transactions.isEmpty
    }
    
    init(salesman: Salesman? = nil) {
        self.salesman = salesman
    }
    
    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Name"), text: $name)
                TextField(String(localized: "Phone (optional)"), text: $phone)
                    .keyboardType(.phonePad)
            }
            
            Section {
                TextField(String(localized: "Notes (optional)"), text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "Delete Salesman"))
                            Spacer()
                        }
                    }
                    .disabled(!canDelete)
                } footer: {
                    if !canDelete {
                        Text(String(localized: "Cannot delete a salesman with transaction history."))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .navigationTitle(isEditing 
                         ? String(localized: "Edit Salesman") 
                         : String(localized: "New Salesman"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel")) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save")) {
                    save()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            if let salesman {
                name = salesman.name
                phone = salesman.phone ?? ""
                notes = salesman.notes ?? ""
            }
        }
        .alert(
            String(localized: "Delete Salesman?"),
            isPresented: $showingDeleteAlert
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                deleteSalesman()
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "This action cannot be undone."))
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        
        let salesmanToSync: Salesman
        
        if let salesman {
            salesman.name = trimmedName
            salesman.phone = trimmedPhone.isEmpty ? nil : trimmedPhone
            salesman.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            salesmanToSync = salesman
        } else {
            let newSalesman = Salesman(
                name: trimmedName,
                phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(newSalesman)
            salesmanToSync = newSalesman
        }
        
        try? modelContext.save()
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(salesmanToSync)
        }
        
        dismiss()
    }
    
    private func deleteSalesman() {
        guard let salesman else { return }
        salesman.deletedAt = .now
        try? modelContext.save()
        
        // Sync deletion to Firestore
        Task {
            await SyncService.shared.push(salesman)
        }
        
        dismiss()
    }
}

#Preview("New") {
    NavigationStack {
        SalesmanEditorView()
    }
    .modelContainer(for: [Salesman.self])
}

#Preview("Edit") {
    NavigationStack {
        SalesmanEditorView(salesman: Salesman(name: "Ahmed", phone: "+201001234567"))
    }
    .modelContainer(for: [Salesman.self])
}
