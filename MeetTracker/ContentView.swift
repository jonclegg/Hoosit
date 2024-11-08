import SwiftUI
import CoreData
import CoreLocation
import MapKit  // Import MapKit for map functionality

// Add this structure before ContentView
struct IdentifiableLocation: Identifiable {
    let id = UUID()
    let location: CLLocation
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject var locationManager = LocationManager()
    @FetchRequest(
        entity: Contact.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.timestamp, ascending: false)]
    ) var contacts: FetchedResults<Contact>

    @State private var showingAddContact = false
    @State private var region = MKCoordinateRegion()  // State for map region
    @State private var mapLocations: [IdentifiableLocation] = []
    @State private var hasInitializedRegion = false

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                // Map view filling the entire background
                if let location = locationManager.currentLocation {
                    Map(coordinateRegion: $region,
                        showsUserLocation: true,
                        annotationItems: mapLocations) { location in
                        MapMarker(coordinate: location.coordinate)
                    }
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        if !hasInitializedRegion {
                            centerOnUser(location: location)
                            hasInitializedRegion = true
                        }
                        updateMapLocations()
                    }
                    .onChange(of: region) { _ in
                        updateMapLocations()
                    }
                    
                    // Layer 3: GPS Button (top left)
                    VStack {
                        HStack {
                        Button(action: {
                                if let location = locationManager.currentLocation {
                                    centerOnUser(location: location)
                                }
                            }) {
                                Image(systemName: "location.fill")
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .padding(.leading, 16)
                            Spacer()
                        }
                        .padding(.top, 8)  // Adjust this value to align with navigation bar
                        Spacer()
                    }
                    
                    // Layer 2: Overlay Views
                    VStack {
                        Spacer()
                        
                        // Contacts List (if any)
                        if !contactsInCurrentArea.isEmpty {
                            VStack(spacing: 0) {
                                List {
                                    ForEach(contactsInCurrentArea, id: \.self) { contact in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(contact.name ?? "Unknown")
                                                .font(.headline)
                                            if let description = contact.descriptionText {
                                                Text(description)
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                            if let timestamp = contact.timestamp {
                                                Text(timestamp, style: .date)
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .onDelete(perform: deleteContacts)
                                }
                                .listStyle(PlainListStyle())
                                .frame(maxHeight: listHeight())
                            }
                            .frame(maxWidth: .infinity)
                        } else if locationManager.currentLocation != nil {
                            Text("No contacts in this area.")
                                .padding()
                                .background(Color(.systemBackground).opacity(0.8))
                        }
                        
                        // Add Person Button (now below the list)
                        Button(action: {
                            showingAddContact.toggle()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Person")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(locationManager.currentLocation == nil)
                        .padding(.horizontal)
                        .padding(.bottom)  // Added bottom padding
                    }
                } else {
                    Text("Location services must be enabled for this app to work.")
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle("WhosIt")
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactView()
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(locationManager)
        }
    }

    // Function to dynamically calculate the list's height
    func listHeight() -> CGFloat {
        let rowHeight: CGFloat = 60  // Approximate height of each row
        let maxVisibleRows = 5       // Maximum number of rows to display at once
        let totalRows = contactsInCurrentArea.count
        let height = CGFloat(min(totalRows, maxVisibleRows)) * rowHeight
        return height
    }

    // Filter contacts based on the current visible map region
    var contactsInCurrentArea: [Contact] {
        contacts.filter { contact in
            let contactCoordinate = CLLocationCoordinate2D(latitude: contact.latitude, longitude: contact.longitude)
            return region.contains(contactCoordinate)
        }
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

    private func updateMapLocations() {
        mapLocations = contacts.map { contact in
            let contactLocation = CLLocation(latitude: contact.latitude, longitude: contact.longitude)
            return IdentifiableLocation(location: contactLocation)
        }
    }

    private func centerOnUser(location: CLLocation) {
        withAnimation {
            region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
        }
    }
}

// Extension to check if a coordinate is within the map region
extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latitudeDelta = span.latitudeDelta / 2.0
        let longitudeDelta = span.longitudeDelta / 2.0

        let minLat = center.latitude - latitudeDelta
        let maxLat = center.latitude + latitudeDelta
        let minLon = center.longitude - longitudeDelta
        let maxLon = center.longitude + longitudeDelta

        return (minLat...maxLat).contains(coordinate.latitude) &&
               (minLon...maxLon).contains(coordinate.longitude)
    }
}

// Extension to make MKCoordinateRegion conform to Equatable
extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
}
