import SwiftUI
import CoreData
import CoreLocation
import MapKit

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
            ZStack {
                // Add a subtle gradient background
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                    startPoint: .top,
                    endPoint: .bottom
                ).ignoresSafeArea()

                VStack {
                    if contactsInCurrentArea.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No contacts in this area.")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        List {
                            ForEach(contactsInCurrentArea, id: \.self) { contact in
                                ContactRowView(contact: contact)
                                    .listRowBackground(Color(.systemBackground).opacity(0.8))
                            }
                            .onDelete(perform: deleteContacts)
                        }
                        .listStyle(InsetGroupedListStyle())
                    }
                }
            }
            .navigationBarTitle("Whosit", displayMode: .large)
            .navigationBarItems(trailing:
                Button(action: { showingAddContact.toggle() }) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 20))
                }
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

    private func deleteContacts(offsets: IndexSet) {
        withAnimation {
            offsets.map { contactsInCurrentArea[$0] }.forEach(viewContext.delete)
            
            do {
                try viewContext.save()
            } catch {
                // Handle the error appropriately
                print("Error deleting contact: \(error)")
            }
        }
    }
}

// New separate view for contact rows
struct ContactRowView: View {
    let contact: Contact
    @State private var showingMap = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(contact.name ?? "Unknown")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        showingMap = true
                    }
                Spacer()
                if let timestamp = contact.timestamp {
                    Text(timestamp, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let description = contact.descriptionText {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingMap) {
            ContactLocationMapView(contact: contact)
        }
    }
}

// Add this new view
struct ContactLocationMapView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: contact.latitude,
                    longitude: contact.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )), annotationItems: [contact]) { contact in
                MapMarker(coordinate: CLLocationCoordinate2D(
                    latitude: contact.latitude,
                    longitude: contact.longitude
                ))
            }
            .navigationBarTitle("\(contact.name ?? "Unknown")'s Location", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
