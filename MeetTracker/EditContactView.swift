import SwiftUI
import CoreData

struct EditContactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var contact: Contact
    
    @State private var name: String
    @State private var descriptionText: String
    var onContactUpdated: () -> Void
    @State private var showingDeleteAlert = false
    
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
                    
                    Link(destination: URL(string: "maps://?q=\(contact.latitude),\(contact.longitude)")!) {
                        Text("Location: \(String(format: "%.6f", contact.latitude)), \(String(format: "%.6f", contact.longitude))")
                            .foregroundColor(.blue)
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Text("Delete Contact")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
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
            .alert("Delete Contact", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteContact()
                }
            } message: {
                Text("Are you sure you want to delete this contact?")
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
    
    private func deleteContact() {
        viewContext.delete(contact)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting contact: \(error)")
        }
    }
} 