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
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default location
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isLoading = true
    @State private var longPressLocation: CLLocationCoordinate2D?
    @State private var hasSetInitialLocation = false
    
    // States for editing contact
    @State private var selectedContact: Contact?
    @State private var showingEditContact = false
    
    @State private var targetLocation: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationStack {
            ZStack {
                MapView(
                    region: $region,
                    targetLocation: $targetLocation,
                    contacts: contacts,
                    onClusterTapped: handleClusterTap,
                    onContactSelected: navigateToEditContact
                )
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // Initial setup if needed
                }
                
                VStack {
                    Spacer()
                    
                    // ControlsView remains
                    ControlsView(centerOnUser: centerOnUser, addContactAction: {
                        showingAddContact = true
                    })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20) // Adjust padding as needed
                }
                .ignoresSafeArea(edges: .bottom)
            }
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
                targetLocation = nil
            }) {
                AddContactView(initialLocation: targetLocation, onContactAdded: {
                    if let location = targetLocation {
                        withAnimation {
                            region.center = location
                        }
                    }
                })
                    .environment(\.managedObjectContext, viewContext)
                    .environmentObject(locationManager)
            }
            .sheet(item: $selectedContact) { contact in
                EditContactView(contact: contact, onContactUpdated: {
                    // Handle updates if necessary
                })
            }
        }
    }
    
    // MARK: - Private Methods
    
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
    
    private func handleClusterTap(_ cluster: MKClusterAnnotation) {
        // Calculate the region to zoom into based on cluster's boundingMapRect
        let edgePadding = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
        let mapRect = cluster.memberAnnotations.reduce(MKMapRect.null) { (current, annotation) -> MKMapRect in
            let annotationPoint = MKMapPoint(annotation.coordinate)
            let pointRect = MKMapRect(x: annotationPoint.x, y: annotationPoint.y, width: 0.1, height: 0.1)
            return current.union(pointRect)
        }
        let newRegion = MKCoordinateRegion(mapRect)
        withAnimation {
            region = newRegion
        }
    }
    
    private func navigateToEditContact(_ contact: Contact) {
        selectedContact = contact
        showingEditContact = true
    }
    
    private func updateTargetLocation() {
        targetLocation = region.center
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

extension MKCoordinateRegion: Equatable {
    public static func == (lhs: MKCoordinateRegion, rhs: MKCoordinateRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
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
    @Binding var targetLocation: CLLocationCoordinate2D?
    var contacts: FetchedResults<Contact>
    var onClusterTapped: (MKClusterAnnotation) -> Void
    var onContactSelected: (Contact) -> Void
    
    var body: some View {
        Map(coordinateRegion: $region,
            showsUserLocation: true,
            annotationItems: contacts) { contact in
                MapAnnotation(coordinate: CLLocationCoordinate2D(
                    latitude: contact.latitude,
                    longitude: contact.longitude
                )) {
                    let offset = calculateOffset(for: contact, among: contacts)
                    Text(contact.name ?? "Unknown")
                        .font(.caption)
                        .bold()
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .offset(x: offset.x, y: offset.y)
                        .onTapGesture {
                            onContactSelected(contact)
                        }
                }
        }
        
        // Target overlay
        Image(systemName: "plus.circle")
            .font(.title)
            .foregroundColor(.blue)
            .background(
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
            )
        
        .onChange(of: region) { newRegion in
            targetLocation = newRegion.center
        }
    }
    
    private func calculateOffset(for contact: Contact, among allContacts: FetchedResults<Contact>) -> CGPoint {
        let threshold = 0.0001 // Approximately 10 meters
        var overlappingContacts: [(Contact, Int)] = []
        var currentIndex = 0
        
        // Find all overlapping contacts and assign them indices
        for otherContact in allContacts {
            let latDiff = abs(contact.latitude - otherContact.latitude)
            let lonDiff = abs(contact.longitude - otherContact.longitude)
            
            if latDiff < threshold && lonDiff < threshold {
                overlappingContacts.append((otherContact, currentIndex))
                currentIndex += 1
            }
        }
        
        // If this contact is part of an overlapping group
        if let index = overlappingContacts.first(where: { $0.0 == contact })?.1,
           overlappingContacts.count > 1 {
            let angle = (2 * .pi * Double(index)) / Double(overlappingContacts.count)
            let radius: CGFloat = 60 // Adjust this value to control the spread
            return CGPoint(
                x: radius * cos(angle),
                y: radius * sin(angle)
            )
        }
        
        return CGPoint(x: 0, y: 0)
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
                Text("Add Person")
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
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
