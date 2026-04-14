//
//  HoneLiveActivityLiveActivity.swift
//  HoneLiveActivity
//
//  Created by Zack Huber on 4/14/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct HoneLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct HoneLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HoneLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension HoneLiveActivityAttributes {
    fileprivate static var preview: HoneLiveActivityAttributes {
        HoneLiveActivityAttributes(name: "World")
    }
}

extension HoneLiveActivityAttributes.ContentState {
    fileprivate static var smiley: HoneLiveActivityAttributes.ContentState {
        HoneLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: HoneLiveActivityAttributes.ContentState {
         HoneLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: HoneLiveActivityAttributes.preview) {
   HoneLiveActivityLiveActivity()
} contentStates: {
    HoneLiveActivityAttributes.ContentState.smiley
    HoneLiveActivityAttributes.ContentState.starEyes
}
