//
//  SessionNotesView.swift
//  Practice Timer
//
//  Created by Claude on 3/3/26.
//

import SwiftUI

/// Notes input and display for current activity
/// SINGLE RESPONSIBILITY: Allow user to add and view notes during practice
struct SessionNotesView: View {
    let notes: String?
    let historicalNotes: [PracticeNote]
    let onAddNote: (String) -> Void

    @State private var noteText = ""
    @State private var showingAllHistorical = false
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)

            // All notes - newest first
            if !historicalNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Show 3 most recent, or all if expanded
                    let notesToShow = showingAllHistorical ? historicalNotes : Array(historicalNotes.prefix(3))

                    ForEach(notesToShow) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatDate(note.timestamp))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(note.notes)
                                .font(.body)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }

                    // Show expand/collapse button if more than 3 notes
                    if historicalNotes.count > 3 {
                        Button(action: {
                            showingAllHistorical.toggle()
                        }) {
                            Text(showingAllHistorical ? "Show Less" : "Show All (\(historicalNotes.count) total)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }

                Divider()
            }

            // Add note input
            HStack {
                TextField("Add note...", text: $noteText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        submitNote()
                    }

                Button(action: submitNote) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func submitNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onAddNote(trimmed)
        noteText = ""
        isFocused = false
    }

    private func formatDate(_ isoString: String) -> String {
        guard let date = isoString.toDate() else {
            return isoString
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    @Previewable @FocusState var isFocused: Bool
    let historicalNotes = [
        PracticeNote(
            notes: "Focused on F major scale",
            sessionId: "session1",
            timestamp: Date().addingTimeInterval(-86400).toISO8601String(),  // 1 day ago
            timeSpent: 600
        ),
        PracticeNote(
            notes: "C major feeling more comfortable",
            sessionId: "session2",
            timestamp: Date().addingTimeInterval(-172800).toISO8601String(),  // 2 days ago
            timeSpent: 720
        )
    ]

    VStack {
        SessionNotesView(
            notes: nil,
            historicalNotes: [],
            onAddNote: { print("Note: \($0)") },
            isFocused: $isFocused
        )
        SessionNotesView(
            notes: nil,
            historicalNotes: historicalNotes,
            onAddNote: { print("Note: \($0)") },
            isFocused: $isFocused
        )
    }
}
