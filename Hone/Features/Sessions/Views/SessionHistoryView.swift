import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var viewModel: SessionHistoryViewModel
    @State private var selectedSession: Session?
    @State private var sessionToDelete: Session?
    @State private var showingDeleteConfirmation = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let userId: String
    private let sessionViewModel: SessionViewModel
    @Binding private var selectedTab: Int

    init(userId: String, sessionViewModel: SessionViewModel, selectedTab: Binding<Int>) {
        self.userId = userId
        self.sessionViewModel = sessionViewModel
        self._selectedTab = selectedTab
        _viewModel = StateObject(wrappedValue: SessionHistoryViewModel(userId: userId))
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: two-column NavigationSplitView
                NavigationSplitView {
                    sessionList
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
                } detail: {
                    if let session = selectedSession {
                        ReactiveSessionSummaryView(
                            session: session,
                            viewModel: viewModel,
                            onStartNewPractice: { ids in
                                sessionViewModel.repeatActivityIds = ids
                                selectedSession = nil
                                selectedTab = 0
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Select a Session",
                            systemImage: "calendar",
                            description: Text("Choose a session from the sidebar to view details")
                        )
                    }
                }
            } else {
                // iPhone: standard NavigationStack with sheet presentation
                NavigationStack {
                    sessionList
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
                            ReactiveSessionSummaryView(
                                session: session,
                                viewModel: viewModel,
                                onStartNewPractice: { ids in
                                    sessionViewModel.repeatActivityIds = ids
                                    selectedSession = nil
                                    selectedTab = 0
                                }
                            )
                        }
                }
            }
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
        .onAppear {
            print("DEBUG: SessionHistoryView.onAppear called with userId: '\(userId)'")
            viewModel.startListening()
        }
    }

    // MARK: - Shared List Content

    private var sessionList: some View {
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
    }
}

#Preview {
    SessionHistoryView(
        userId: "preview-user",
        sessionViewModel: SessionViewModel(userId: "preview-user"),
        selectedTab: .constant(3)
    )
}
