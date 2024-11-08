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
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Loading screen
            if isLoading {
                ZStack {
                    Color(.systemBackground).edgesIgnoringSafeArea(.all)
                    VStack {
                        if let iconDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
                           let primaryIconDictionary = iconDictionary["CFBundlePrimaryIcon"] as? [String: Any],
                           let iconFiles = primaryIconDictionary["CFBundleIconFiles"] as? [String],
                           let lastIcon = iconFiles.last,
                           let icon = UIImage(named: lastIcon) {
                            Image(uiImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .cornerRadius(20)
                        } else {
                            // Add this else clause for debugging
                            Text("Could not load app icon")
                                .foregroundColor(.gray)
                        }
                        
                        ProgressView()
                            .padding(.top)
                    }
                }
            }
            
            // Existing NavigationView
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
                        .onChange(of: region) { oldValue, newValue in
                            updateMapLocations()
                        }
                        .gesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onEnded { value in
                                    switch value {
                                    case .second(true, let dragValue):
                                        if let dragValue = dragValue {  // Unwrap the optional drag value
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            
                                            // Convert tap location to map coordinate
                                            let mapView = MKMapView()
                                            mapView.region = region
                                            let coordinate = mapView.convert(dragValue.location, toCoordinateFrom: nil)
                                            longPressLocation = coordinate
                                            showingAddContact = true
                                        }
                                    default:
                                        break
                                    }
                                }
                        )
                        
                        // Layer 3: GPS and Add buttons row
                        VStack {
                            Spacer()
                            
                            // GPS and Add buttons row
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
                                
                                Button(action: {
                                    showingAddContact.toggle()
                                }) {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .padding(12)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .disabled(locationManager.currentLocation == nil)
                                .padding(.trailing, 20)
                            }
                            
                            // Contacts List (if any)
                            if !contactsInCurrentArea.isEmpty {
                                VStack(spacing: 0) {
                                    List {
                                        ForEach(contactsInCurrentArea, id: \.self) { contact in
                                            NavigationLink(destination: EditContactView(contact: contact)) {
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
                                        }
                                        .onDelete(perform: deleteContacts)
                                    }
                                    .listStyle(PlainListStyle())
                                    .frame(maxHeight: listHeight())
                                }
                                .frame(maxWidth: .infinity)
                            } else if locationManager.currentLocation != nil {
                                Text("No people in this area.")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemBackground).opacity(0.8))
                                    )
                                    .padding(.bottom, 16)
                            }
                        }
                    } else {
                        Text("Location services must be enabled for this app to work.")
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarTitle("")
            }
            .opacity(isLoading ? 0 : 1)
        }
        .onAppear {
            // Simulate loading delay and fade out splash screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoading = false
                }
            }
        }
        .sheet(isPresented: $showingAddContact) {
            AddContactView(initialLocation: longPressLocation, onContactAdded: {
                updateMapLocations()
            })
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
