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
    let onAddNote: (String) -> Void

    @State private var noteText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.headline)

            // Display existing notes
            if let existingNotes = notes, !existingNotes.isEmpty {
                Text(existingNotes)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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
}

#Preview {
    VStack {
        SessionNotesView(notes: nil, onAddNote: { print("Note: \($0)") })
        SessionNotesView(notes: "Great session!", onAddNote: { print("Note: \($0)") })
    }
}
