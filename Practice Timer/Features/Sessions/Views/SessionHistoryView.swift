import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var viewModel: SessionHistoryViewModel
    @State private var selectedSession: Session?
    @State private var selectedActivities: [SessionActivity] = []
    @State private var sessionToDelete: Session?
    @State private var showingDeleteConfirmation = false

    private let userId: String

    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: SessionHistoryViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.groupedSessions) { group in
                    Section(header: Text(group.dayHeader)) {
                        ForEach(group.sessions) { session in
                            SessionHistoryRow(
                                session: session,
                                activities: viewModel.sessionActivities[session.id ?? ""] ?? []
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedActivities = viewModel.sessionActivities[session.id ?? ""] ?? []
                                selectedSession = session
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .overlay {
                if viewModel.sessions.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Practice History",
                        systemImage: "calendar",
                        description: Text("Start a practice session to see your history")
                    )
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionSummaryView(
                    session: session,
                    activities: selectedActivities
                )
            }
            .alert("Delete Session?", isPresented: $showingDeleteConfirmation, presenting: sessionToDelete) { session in
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteSession(session)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("This will permanently delete this practice session. This action cannot be undone.")
            }
        }
        .onAppear {
            viewModel.startListening()
        }
    }
}

#Preview {
    SessionHistoryView(userId: "preview-user")
}
