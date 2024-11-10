import SwiftUI
import CoreData

struct EditContactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var contact: Contact
    
    @State private var name: String
    @State private var descriptionText: String
    var onContactUpdated: () -> Void
    
    init(contact: Contact, onContactUpdated: @escaping () -> Void) {
        self.contact = contact
        self.onContactUpdated = onContactUpdated
        _name = State(initialValue: contact.name ?? "")
        _descriptionText = State(initialValue: contact.descriptionText ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .onChange(of: name) { newValue in
                            contact.name = newValue
                            saveContext()
                        }
                    
                    TextField("Description", text: $descriptionText)
                        .onChange(of: descriptionText) { newValue in
                            contact.descriptionText = newValue
                            saveContext()
                        }
                }
                
                Section {
                    Text("Met on \(contact.timestamp ?? Date(), style: .date)")
                        .foregroundColor(.gray)
                    
                    Text("Location: \(String(format: "%.6f", contact.latitude)), \(String(format: "%.6f", contact.longitude))")
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveContext()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
            DispatchQueue.main.async {
                onContactUpdated()
            }
        } catch {
            print("Error saving context: \(error)")
        }
    }
} 