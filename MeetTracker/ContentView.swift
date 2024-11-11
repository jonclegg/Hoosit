import SwiftUI
import CoreData
import CoreLocation
import MapKit

struct IdentifiableLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

class ShareActivityItem: NSObject, UIActivityItemSource {
    let json: String
    
    init(json: String) {
        self.json = json
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return "Hoosit Contacts"
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return json
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return "Hoosit Contacts"
    }
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
    
    @State private var showingSidebar = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                MapView(
                    region: $region,
                    targetLocation: $targetLocation,
                    contacts: contacts,
                    onClusterTapped: handleClusterTap,
                    onContactSelected: navigateToEditContact,
                    onTargetTapped: { showingAddContact = true }
                )
                .edgesIgnoringSafeArea(.all)
                
                // Add sidebar overlay when shown
                if showingSidebar {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                showingSidebar = false
                            }
                        }
                    
                    SidebarView(isOpen: $showingSidebar)
                        .transition(.move(edge: .leading))
                }
                
                VStack {
                    HStack {
                        Button(action: {
                            withAnimation {
                                showingSidebar = true
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .font(.title2)
                                .foregroundColor(.black)
                                .padding(12)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .opacity(showingSidebar ? 0 : 1)
                        .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.top, 0)
                   
                    Spacer()
                    
                    // Replace ControlsView with just the location button
                    HStack {
                        Button(action: centerOnUser) {
                            Image(systemName: "location.fill")
                                .padding(12)
                                .background(Color(.systemBackground))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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
                AddContactView(initialLocation: region.center, onContactAdded: {
                    // Force a view refresh by slightly modifying the region
                    withAnimation {
                        let currentSpan = region.span
                        region.span = MKCoordinateSpan(
                            latitudeDelta: currentSpan.latitudeDelta * 1.001,
                            longitudeDelta: currentSpan.longitudeDelta * 1.001
                        )
                        // Reset back to original span after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            region.span = currentSpan
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
    var onTargetTapped: () -> Void
    
    @State private var isAnimating = false
    @State private var lastRegion: MKCoordinateRegion?
    
    var body: some View {
        ZStack {
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
            
            // Updated center target marker
            GeometryReader { geometry in
                Image(systemName: "plus.circle")
                    .font(.title)
                    .foregroundColor(.blue)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 32, height: 32)
                    )
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height / 2
                    )
                    .onTapGesture {
                        targetLocation = region.center
                        isAnimating = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAnimating = false
                        }
                        onTargetTapped()
                    }
            }
        }
        .onChange(of: region) { newRegion in
            lastRegion = newRegion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if lastRegion == newRegion {
                    isAnimating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isAnimating = false
                    }
                }
            }
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

struct SidebarView: View {
    @Binding var isOpen: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingShareSheet = false
    @State private var contactsToShare: [Any] = []
    @State private var showingImportDialog = false
    @State private var importText = ""
    @State private var showingImportError = false
    @State private var showingExportDialog = false
    @State private var exportText = ""
    @State private var showCopiedAlert = false
    @State private var showingImportConfirmation = false
    @State private var pendingImportText = ""
    @State private var importStats = (toImport: 0, existing: 0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Hoosit")
                .font(.title)
                .padding(.top, 48)
            
            Button {
                exportText = prepareContactsForSharing().first ?? "No contacts to share"
                showingExportDialog = true
            } label: {
                Label("Export Contacts", systemImage: "square.and.arrow.up")
            }
            
            Button(action: { showingImportDialog = true }) {
                Label("Import Contacts", systemImage: "square.and.arrow.down")
            }
            
            Spacer()
        }
        .frame(width: 180)
        .padding()
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.vertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingImportDialog) {
            NavigationStack {
                VStack {
                    TextEditor(text: $importText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxHeight: .infinity)
                        .padding()
                        .border(Color.gray.opacity(0.2))
                    
                    Button("Import") {
                        if let stats = getImportStats(from: importText) {
                            importStats = stats
                            pendingImportText = importText
                            showingImportConfirmation = true
                        } else {
                            showingImportError = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    .alert("Confirm Import", isPresented: $showingImportConfirmation) {
                        Button("Cancel", role: .cancel) { }
                        Button("Import", role: .destructive) {
                            if importContacts(from: pendingImportText) {
                                showingImportDialog = false
                                importText = ""
                            } else {
                                showingImportError = true
                            }
                        }
                    } message: {
                        Text("This will import \(importStats.toImport) contacts and remove your existing \(importStats.existing) contacts. Are you sure?")
                    }
                }
                .padding()
                .navigationTitle("Import Contacts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingImportDialog = false
                        }
                    }
                }
                .alert("Import Error", isPresented: $showingImportError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Unable to import contacts. Please check the JSON format and try again.")
                }
            }
        }
        .sheet(isPresented: $showingExportDialog) {
            NavigationStack {
                VStack {
                    TextEditor(text: .constant(exportText))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxHeight: .infinity)
                        .padding()
                        .border(Color.gray.opacity(0.2))
                    
                    Button(action: {
                        UIPasteboard.general.string = exportText
                        showCopiedAlert = true
                    }) {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                .padding()
                .navigationTitle("Export Contacts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showingExportDialog = false
                        }
                    }
                }
                .alert("Copied!", isPresented: $showCopiedAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Contact data has been copied to clipboard.")
                }
                .onAppear {
                    exportText = prepareContactsForSharing().first ?? "No contacts to share"
                }
            }
        }
    }
    
    private func prepareContactsForSharing() -> [String] {
        let contacts = (try? viewContext.fetch(Contact.fetchRequest())) ?? []
        let dateFormatter = ISO8601DateFormatter()
        
        let contactData = contacts.map { contact in
            [
                "name": contact.name ?? "",
                "descriptionText": contact.descriptionText ?? "",
                "latitude": contact.latitude,
                "longitude": contact.longitude,
                "timestamp": dateFormatter.string(from: contact.timestamp ?? Date())
            ] as [String : Any]
        }
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: contactData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return [jsonString]
        }
        
        return ["No contacts to share"]
    }
    
    private func importContacts(from jsonString: String) -> Bool {
        guard let jsonData = jsonString.data(using: .utf8),
              let contactsArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return false
        }
        
        let dateFormatter = ISO8601DateFormatter()
        
        // Delete all existing contacts
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Contact.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDeleteRequest)
            
            // Important: Refresh the view context after batch delete
            viewContext.reset()
            
            // Import new contacts
            for contactData in contactsArray {
                let contact = Contact(context: viewContext)
                contact.name = contactData["name"] as? String
                contact.descriptionText = contactData["descriptionText"] as? String
                contact.latitude = contactData["latitude"] as? Double ?? 0
                contact.longitude = contactData["longitude"] as? Double ?? 0
                if let timestampString = contactData["timestamp"] as? String {
                    contact.timestamp = dateFormatter.date(from: timestampString)
                }
            }
            
            try viewContext.save()
            
            // Refresh each registered object individually
            for object in viewContext.registeredObjects {
                viewContext.refresh(object, mergeChanges: false)
            }
            
            return true
        } catch {
            print("Import error: \(error)")
            return false
        }
    }
    
    private func getImportStats(from jsonString: String) -> (toImport: Int, existing: Int)? {
        guard let jsonData = jsonString.data(using: .utf8),
              let contactsArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return nil
        }
        
        let existingCount = (try? viewContext.count(for: Contact.fetchRequest())) ?? 0
        return (contactsArray.count, existingCount)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // Exclude some activity types that don't make sense for our JSON file
        controller.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList,
            .postToFlickr,
            .postToVimeo,
            .markupAsPDF
        ]
        
        // Optional: Add completion handler
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            if let error = error {
                print("Share error: \(error)")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
