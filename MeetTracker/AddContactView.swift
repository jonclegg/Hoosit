import SwiftUI
import CoreData

struct AddContactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    @State private var descriptionText = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Contact Details")) {
                    TextField("Name", text: $name)
                    TextField("Description (Optional)", text: $descriptionText)
                }
            }
            .navigationBarTitle("Add New Contact", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                addContact()
            }.disabled(name.isEmpty))
        }
    }

    private func addContact() {
        guard let location = locationManager.currentLocation else {
            // Handle the case where location is not available
            return
        }

        let newContact = Contact(context: viewContext)
        newContact.name = name
        newContact.descriptionText = descriptionText.isEmpty ? nil : descriptionText
        newContact.latitude = location.coordinate.latitude
        newContact.longitude = location.coordinate.longitude
        newContact.timestamp = Date()

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            // Handle the error appropriately
            print("Error saving contact: \(error)")
        }
    }
}

