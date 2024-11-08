import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct IdentifiableLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    @FetchRequest(
        entity: Contact.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Contact.timestamp, ascending: false)]
    ) private var contacts: FetchedResults<Contact>
    
    @State private var showingAddContact = false
    @State private var region = MKCoordinateRegion()
    @State private var mapLocations: [IdentifiableLocation] = []
    @State private var isLoading = true
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var hasSetInitialLocation = false
    
    var body: some View {
        ZStack {
            MapView(region: $region,
                    mapLocations: $mapLocations,
                    onLongPress: handleLongPress)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    updateMapLocations()
                }
            
            VStack {
                Spacer()
                
                if !contactsInCurrentArea.isEmpty {
                    ContactsListView(contacts: contactsInCurrentArea, deleteAction: deleteContacts)
                        .frame(maxHeight: listHeight())
                        .padding(.bottom, 16)
                } else if locationManager.currentLocation != nil {
                    NoContactsView()
                        .padding(.bottom, 16)
                }
                
                ControlsView(centerOnUser: centerOnUser, addContactAction: {
                    showingAddContact = true
                })
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            
            if isLoading {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.5), value: isLoading)
        .onChange(of: locationManager.currentLocation) { newLocation in
            if let location = newLocation, !hasSetInitialLocation {
                withAnimation {
                    region = MKCoordinateRegion(
                        center: location.coordinate,
                        latitudinalMeters: 1000,
                        longitudinalMeters: 1000
                    )
                    hasSetInitialLocation = true
                }
            }
        }
        .onAppear(perform: simulateLoading)
        .sheet(isPresented: $showingAddContact, onDismiss: {
            longPressLocation = nil
            updateMapLocations()
        }) {
            AddContactView(initialLocation: longPressLocation, onContactAdded: {
                updateMapLocations()
            })
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(locationManager)
        }
    }
    
    // MARK: - Private Methods
    
    private func updateMapLocations() {
        mapLocations = contacts.map { contact in
            IdentifiableLocation(coordinate: CLLocationCoordinate2D(latitude: contact.latitude, longitude: contact.longitude))
        }
    }
    
    private func centerOnUser() {
        if let location = locationManager.currentLocation {
            withAnimation {
                region.center = location.coordinate
            }
        }
    }
    
    private func simulateLoading() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }
    
    private func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        longPressLocation = coordinate
        showingAddContact = true
    }
    
    // MARK: - Computed Properties
    
    private var contactsInCurrentArea: [Contact] {
        contacts.filter { contact in
            let coordinate = CLLocationCoordinate2D(latitude: contact.latitude, longitude: contact.longitude)
            return region.contains(coordinate)
        }
    }
    
    // MARK: - Actions
    
    private func deleteContacts(offsets: IndexSet) {
        withAnimation {
            offsets.map { contactsInCurrentArea[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting contact: \(error)")
            }
            updateMapLocations()
        }
    }
    
    private func listHeight() -> CGFloat {
        let rowHeight: CGFloat = 60
        let maxVisibleRows = 5
        let totalRows = contactsInCurrentArea.count
        return CGFloat(min(totalRows, maxVisibleRows)) * rowHeight
    }
}

// MARK: - Extensions

extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let spanLat = span.latitudeDelta / 2.0
        let spanLon = span.longitudeDelta / 2.0
        
        let minLat = center.latitude - spanLat
        let maxLat = center.latitude + spanLat
        let minLon = center.longitude - spanLon
        let maxLon = center.longitude + spanLon
        
        return coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon && coordinate.longitude <= maxLon
    }
}

// MARK: - Subviews

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            VStack {
                if let icon = UIImage(named: getAppIconName() ?? "") {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width / 3)
                        .cornerRadius(20)
                } else {
                    Text("Could not load app icon")
                        .foregroundColor(.gray)
                }
                ProgressView()
                    .padding(.top)
            }
        }
        .transition(.opacity)
    }
    
    private func getAppIconName() -> String? {
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
              let lastIcon = iconFiles.last else {
            return nil
        }
        return lastIcon
    }
}

struct MapView: View {
    @Binding var region: MKCoordinateRegion
    @Binding var mapLocations: [IdentifiableLocation]
    var onLongPress: (CLLocationCoordinate2D) -> Void
    
    var body: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true,
            annotationItems: mapLocations) { location in
            MapMarker(coordinate: location.coordinate)
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onEnded(handleGesture)
        )
    }
    
    private func handleGesture(value: SequenceGesture<LongPressGesture, DragGesture>.Value) {
        if case let .second(true, drag?) = value {
            let coordinate = getMapCoordinate(from: drag.location)
            onLongPress(coordinate)
        }
    }
    
    private func getMapCoordinate(from point: CGPoint) -> CLLocationCoordinate2D {
        let mapView = MKMapView(frame: UIScreen.main.bounds)
        mapView.region = region
        return mapView.convert(point, toCoordinateFrom: nil)
    }
}

struct ControlsView: View {
    var centerOnUser: () -> Void
    var addContactAction: () -> Void
    
    var body: some View {
        HStack {
            Button(action: centerOnUser) {
                Image(systemName: "location.fill")
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            
            Spacer()
            
            Button(action: addContactAction) {
                Image(systemName: "plus")
                    .font(.title2)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
    }
}

struct ContactsListView: View {
    var contacts: [Contact]
    var deleteAction: (IndexSet) -> Void
    
    var body: some View {
        List {
            ForEach(contacts, id: \.self) { contact in
            NavigationLink(destination: EditContactView(contact: contact)) {
                    ContactRow(contact: contact)
                }
            }
            .onDelete(perform: deleteAction)
        }
        .listStyle(PlainListStyle())
    }
}

struct ContactRow: View {
    var contact: Contact
    
    var body: some View {
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
                    .padding(.bottom, 4)
            }
        }
    }
}

struct NoContactsView: View {
    var body: some View {
        Text("No people in this area.")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground).opacity(0.8))
            )
    }
}
