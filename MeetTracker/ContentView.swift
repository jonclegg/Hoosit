import SwiftUI
import CoreData
import CoreLocation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var locationManager = LocationManager()
    @FetchRequest(
        entity: Contact.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.timestamp, ascending: false)]
    ) var contacts: FetchedResults<Contact>

    @State private var showingAddContact = false

    var body: some View {
        NavigationView {
            VStack {
                if locationManager.currentLocation == nil {
                    Text("Location services must be enabled for this app to work.")
                        .multilineTextAlignment(.center)
                        .padding()
                } else if contactsInCurrentArea.isEmpty {
                    Text("No contacts in this area.")
                        .padding()
                } else {
                    List {
                        ForEach(contactsInCurrentArea, id: \.self) { contact in
                            VStack(alignment: .leading) {
                                Text(contact.name ?? "Unknown")
                                    .font(.headline)
                                if let description = contact.descriptionText {
                                    Text(description)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("People Met Here")
            .navigationBarItems(trailing:
                Button(action: {
                    showingAddContact.toggle()
                }) {
                    Image(systemName: "plus")
                }
                .disabled(locationManager.currentLocation == nil)
            )
            .sheet(isPresented: $showingAddContact) {
                AddContactView()
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(locationManager)
            }
        }
    }

    // Filter contacts based on current location
    var contactsInCurrentArea: [Contact] {
        guard let currentLocation = locationManager.currentLocation else {
            return []
        }
        return contacts.filter { contact in
            let contactLocation = CLLocation(latitude: contact.latitude, longitude: contact.longitude)
            return isWithinArea(contactLocation: contactLocation, currentLocation: currentLocation, radius: 500)
        }
    }

    func isWithinArea(contactLocation: CLLocation, currentLocation: CLLocation, radius: Double) -> Bool {
        let distance = contactLocation.distance(from: currentLocation)
        return distance <= radius
    }
}
