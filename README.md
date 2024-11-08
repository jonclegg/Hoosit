# MeetTracker

MeetTracker is an iOS application that helps you keep track of people you meet and where you met them. The app uses CoreLocation and MapKit to provide a map-based interface for recording and viewing your contacts.

## Features

- 📍 Map-based interface showing all your contacts
- 📱 Add new contacts by tapping the + button or long-pressing on the map
- 📝 Store details about each contact including:
  - Name
  - Description
  - Location
  - Date and time of meeting
- 🔍 View contacts in the current map area
- 📍 Center map on your current location
- ✏️ Edit contact details
- 🗑️ Delete contacts with swipe gestures

## Technical Details

The app is built using:
- SwiftUI for the user interface
- CoreData for persistent storage
- MapKit for map functionality
- CoreLocation for user location services

### Key Components

- **ContentView**: Main view containing the map and contact list
- **LocationManager**: Handles location services and permissions
- **MapView**: Custom map implementation with long press gesture support
- **AddContactView**: Form for adding new contacts
- **EditContactView**: Form for editing existing contacts
- **ContactsListView**: Displays contacts in the current map area

## Requirements

- iOS 15.0 or later
- Xcode 13.0 or later
- Location permissions enabled for device location access

## Data Model

The app uses CoreData with a Contact entity that includes:
- name (String, required)
- descriptionText (String, optional)
- latitude (Double, required)
- longitude (Double, required)
- timestamp (Date, required)

## Privacy

The app requires location permissions to:
- Show your current location on the map
- Add new contacts at your current location
- Center the map on your location

Location data is only used when the app is active ("When In Use" permission).

## Installation

1. Clone the repository
2. Open `MeetTracker.xcodeproj` in Xcode
3. Build and run the project on your device or simulator

## License

[Add your license information here]

## Author

[Add your name and contact information here]