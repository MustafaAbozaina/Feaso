import SwiftUI
import SwiftData

struct CustomerEditorView: View {
    let customer: Customer?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false
    
    private var isEditing: Bool {
        customer != nil
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var canDelete: Bool {
        guard let customer else { return false }
        return customer.transactions.isEmpty
    }
    
    init(customer: Customer? = nil) {
        self.customer = customer
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
                            Text(String(localized: "Delete Customer"))
                            Spacer()
                        }
                    }
                    .disabled(!canDelete)
                } footer: {
                    if !canDelete {
                        Text(String(localized: "Cannot delete a customer with transaction history."))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.Theme.background)
        .navigationTitle(isEditing 
                         ? String(localized: "Edit Customer") 
                         : String(localized: "New Customer"))
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
            if let customer {
                name = customer.name
                phone = customer.phone ?? ""
                notes = customer.notes ?? ""
            }
        }
        .alert(
            String(localized: "Delete Customer?"),
            isPresented: $showingDeleteAlert
        ) {
            Button(String(localized: "Delete"), role: .destructive) {
                deleteCustomer()
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
        
        let customerToSync: Customer
        
        if let customer {
            customer.name = trimmedName
            customer.phone = trimmedPhone.isEmpty ? nil : trimmedPhone
            customer.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            customerToSync = customer
        } else {
            let newCustomer = Customer(
                name: trimmedName,
                phone: trimmedPhone.isEmpty ? nil : trimmedPhone,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(newCustomer)
            customerToSync = newCustomer
        }
        
        try? modelContext.save()
        
        // Sync to Firestore
        Task {
            await SyncService.shared.push(customerToSync)
        }
        
        dismiss()
    }
    
    private func deleteCustomer() {
        guard let customer else { return }
        customer.deletedAt = .now
        try? modelContext.save()
        
        // Sync deletion to Firestore
        Task {
            await SyncService.shared.push(customer)
        }
        
        dismiss()
    }
}

#Preview("New") {
    NavigationStack {
        CustomerEditorView()
    }
    .modelContainer(for: [Customer.self])
}

#Preview("Edit") {
    NavigationStack {
        CustomerEditorView(customer: Customer(name: "Ahmed", phone: "+201001234567"))
    }
    .modelContainer(for: [Customer.self])
}
