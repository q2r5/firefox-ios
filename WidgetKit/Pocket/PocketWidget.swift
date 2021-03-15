/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import SwiftUI
import WidgetKit

struct PocketWidget: Widget {
    private let kind: String = "Pocket"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PocketProvider()) { entry in
            PocketView(entry: entry)
        }
        .supportedFamilies([.systemMedium, .systemLarge])
        .configurationDisplayName(Strings.PocketWidgetGalleryTitle)
        .description(Strings.PocketWidgetGalleryDescription)
    }
}

struct PocketView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: PocketEntry
    
    @ViewBuilder
    func lineItemForStory(_ story: PocketWidgetStory) -> some View {
        switch widgetFamily {
        case .systemMedium:
            TwoLinePocketCell()
        case .systemLarge:
            ThreeLinePocketCell(story: story)
        default:
           EmptyView()
        }
    }
    
    var body: some View {
        Group {
            ForEach(entry.stories, id: \.domain) { story in
                lineItemForStory(story)
            }
            ViewMoreCell()
        }
    }
}
