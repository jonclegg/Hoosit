import SwiftUI
import MapKit

struct ContextListView: View {
    // MARK: - Properties

    @Binding var contacts: [Contact]
    @Binding var region: MKCoordinateRegion
    var onContactSelected: (Contact) -> Void

    // Gesture-related properties
    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentHeight: CGFloat = 100 // Minimal height

    // Screen dimensions
    private let screenHeight = UIScreen.main.bounds.height
    private let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.5

    // Computed properties
    private var listHeight: CGFloat {
        let rowHeight: CGFloat = 80
        let padding: CGFloat = 20
        let totalHeight = (rowHeight * CGFloat(contacts.count)) + padding
        return min(totalHeight, maxHeight)
    }

    // MARK: - Body

    var body: some View {
        VStack {
            // Handle
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 6)
                .padding(.top, 8)
                .padding(.bottom, 8)

            // Content
            if contacts.isEmpty {
                Text("No users in view.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(contacts, id: \.self) { contact in
                            NavigationLink(destination: EditContactView(contact: contact, onContactUpdated: {
                                // Trigger any necessary updates
                            })) {
                                ContactRow(contact: contact)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
                .frame(maxHeight: listHeight)
            }
        }
        .frame(width: UIScreen.main.bounds.width, height: currentHeight + dragOffset)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .frame(maxHeight: .infinity, alignment: .bottom)
        .offset(y: max(0, dragOffset))
        .animation(.interactiveSpring(), value: dragOffset)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    // Limit dragging upwards
                    if value.translation.height < 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    // Determine whether to expand or minimize
                    let newHeight = currentHeight - value.translation.height
                    if newHeight > listHeight / 2 {
                        currentHeight = listHeight
                    } else {
                        currentHeight = 100 // Minimal height
                    }
                }
        )
        .onAppear {
            currentHeight = contacts.isEmpty ? 100 : listHeight
        }
        .onChange(of: contacts) { newContacts in
            withAnimation {
                currentHeight = newContacts.isEmpty ? 100 : min(listHeight, maxHeight)
            }
        }
    }
} 