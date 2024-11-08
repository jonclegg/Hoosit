import SwiftUI
import CoreData
import CoreLocation

struct AddContactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.presentationMode) var presentationMode

    let initialLocation: CLLocationCoordinate2D?
    var onContactAdded: (() -> Void)

    @State private var name = ""
    @State private var descriptionText = ""

    init(initialLocation: CLLocationCoordinate2D? = nil, onContactAdded: @escaping () -> Void) {
        self.initialLocation = initialLocation
        self.onContactAdded = onContactAdded
    }

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
        // Use initialLocation if available, otherwise fall back to current location
        let coordinate: CLLocationCoordinate2D
        if let location = initialLocation {
            coordinate = location
        } else if let currentLocation = locationManager.currentLocation {
            coordinate = currentLocation.coordinate
        } else {
            // Handle the case where no location is available
            return
        }

        let newContact = Contact(context: viewContext)
        newContact.name = name
        newContact.descriptionText = descriptionText.isEmpty ? nil : descriptionText
        newContact.latitude = coordinate.latitude
        newContact.longitude = coordinate.longitude
        newContact.timestamp = Date()

        do {
            try viewContext.save()
            onContactAdded()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving contact: \(error)")
        }
    }
}
