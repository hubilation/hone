import SwiftUI

struct SessionHistoryRow: View {
    let session: Session
    let activities: [SessionActivity]

    private var activityPreview: String {
        let names = activities
            .filter { !$0.isInBetweenTime }
            .prefix(3)
            .map { $0.activityName }

        let count = activities.filter { !$0.isInBetweenTime }.count
        if names.count < count {
            return "\(count) activities: \(names.joined(separator: ", "))..."
        } else if count == 1 {
            return "1 activity: \(names.joined(separator: ", "))"
        } else {
            return "\(count) activities: \(names.joined(separator: ", "))"
        }
    }

    private var hasNotes: Bool {
        activities.contains { $0.notes != nil && !$0.notes!.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Line 1: Time and duration
            HStack {
                if let startDate = Date(iso8601String: session.startTime) {
                    Text(startDate, style: .time)  // e.g., "3:45 PM"
                        .font(.headline)
                }

                Spacer()

                Text(TimeInterval(session.totalDuration).formatted())
                    .font(.headline)
                    .foregroundColor(.blue)

                if hasNotes {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            // Line 2: Activity preview
            Text(activityPreview)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let session = Session(
        id: "session1",
        startTime: Date().toISO8601String(),
        endTime: Date().addingTimeInterval(3600).toISO8601String(),
        totalDuration: 3600,
        createdAt: Date().toISO8601String(),
        updatedAt: Date().toISO8601String(),
        state: "ended",
        pausedAt: nil,
        currentActivityIndex: nil
    )

    let activities = [
        SessionActivity(
            id: "act1",
            activityId: "a1",
            activityName: "Scales",
            startTime: Date().toISO8601String(),
            endTime: Date().addingTimeInterval(1200).toISO8601String(),
            duration: 1200,
            notes: "Good progress",
            isInBetweenTime: false,
            createdAt: Date().toISO8601String(),
            updatedAt: Date().toISO8601String()
        ),
        SessionActivity(
            id: "act2",
            activityId: "a2",
            activityName: "Arpeggios",
            startTime: Date().addingTimeInterval(1200).toISO8601String(),
            endTime: Date().addingTimeInterval(2400).toISO8601String(),
            duration: 1200,
            notes: nil,
            isInBetweenTime: false,
            createdAt: Date().addingTimeInterval(1200).toISO8601String(),
            updatedAt: Date().addingTimeInterval(1200).toISO8601String()
        )
    ]

    List {
        SessionHistoryRow(session: session, activities: activities)
    }
}
