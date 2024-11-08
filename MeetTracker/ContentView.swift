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

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Map view filling the entire background
                if let location = locationManager.currentLocation {
                    Map(coordinateRegion: $region,
                        showsUserLocation: true,
                        annotationItems: mapLocations) { location in
                        MapMarker(coordinate: location.coordinate)
                    }
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        )
                        updateMapLocations()
                    }
                    .onChange(of: location) { _ in
                        updateMapLocations()
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: radiusInPixels(), height: radiusInPixels())
                            .opacity(0.5)
                    )
                } else {
                    Text("Location services must be enabled for this app to work.")
                        .multilineTextAlignment(.center)
                        .padding()
                }

                // List of contacts at the bottom
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
                        .frame(maxHeight: listHeight())  // Limit the height based on content
                    }
                    .background(Color(.systemBackground).opacity(0.8))
                } else if locationManager.currentLocation != nil {
                    Text("No contacts in this area.")
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarTitle("WhosIt")
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

    // Function to dynamically calculate the list's height
    func listHeight() -> CGFloat {
        let rowHeight: CGFloat = 60  // Approximate height of each row
        let maxVisibleRows = 5       // Maximum number of rows to display at once
        let totalRows = contactsInCurrentArea.count
        let height = CGFloat(min(totalRows, maxVisibleRows)) * rowHeight
        return height
    }

    // Function to convert radius to pixels for the circle overlay
    func radiusInPixels() -> CGFloat {
        let radiusInMeters = 500.0  // Your radius value
        let mapViewWidth = UIScreen.main.bounds.width
        let regionSpanInMeters = region.span.longitudeDelta * 111_000  // Approximate meters per degree

        // Prevent division by zero or invalid calculations
        guard regionSpanInMeters > 0 else { return 100 } // Default fallback size

        let pixelsPerMeter = mapViewWidth / CGFloat(regionSpanInMeters)
        let diameter = CGFloat(radiusInMeters * 2) * pixelsPerMeter

        // Ensure the result is valid and reasonable
        if diameter.isFinite && diameter > 0 && diameter < mapViewWidth * 2 {
            return diameter
        }
        return 100 // Default fallback size
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

    // Add this function before the last closing brace of ContentView
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
        guard let currentLocation = locationManager.currentLocation else { return }
        
        var locations: [IdentifiableLocation] = []
        
        // Only add contact locations, skip current location
        for contact in contactsInCurrentArea {
            let contactLocation = CLLocation(latitude: contact.latitude, longitude: contact.longitude)
            locations.append(IdentifiableLocation(location: contactLocation))
        }
        
        mapLocations = locations
    }
}
