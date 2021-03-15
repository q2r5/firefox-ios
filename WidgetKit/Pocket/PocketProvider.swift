/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import SwiftUI
import WidgetKit
import Shared

struct PocketProvider: TimelineProvider {
    typealias Entry = PocketEntry

    func placeholder(in context: Context) -> PocketEntry {
        return PocketEntry(date: Date(), stories: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (PocketEntry) -> Void) {
        let stories = Pocket().globalFeed().value
        var widgetStories = [PocketWidgetStory]()

        let faviconFetchGroup = DispatchGroup()
        
        // Concurrently fetch each of the top sites icons
        for story in stories {
            faviconFetchGroup.enter()

            var widgetStory = PocketWidgetStory(title: story.title, domain: story.domain, url: story.url)

            getImageForUrl(story.imageURL) { image in
                widgetStory.image = image
            }

            // Get the bundled top site favicon, if available
            if let url = URL(string: story.domain),
               let bundled = FaviconFetcher.getBundledIcon(forUrl: url),
               let uiImage = UIImage(contentsOfFile: bundled.filePath) {
                widgetStory.favicon = Image(uiImage: uiImage)
            } else {
                // If no favicon is available, fall back to the default favicon
                widgetStory.favicon =
                    Image("defaultFavicon")
            }

            widgetStories.append(widgetStory)
            faviconFetchGroup.leave()
        }
        
        faviconFetchGroup.notify(queue: .main) {
            let pocketEntry = PocketEntry(date: Date(), stories: widgetStories)
            
            completion(pocketEntry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PocketEntry>) -> Void) {
        getSnapshot(in: context) { entry in
            let time = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(time))
            completion(timeline)
        }
    }
}

struct PocketEntry: TimelineEntry {
    var date: Date
    var stories: [PocketWidgetStory]
}

struct PocketWidgetStory {
    var favicon: Image?
    var image: Image?
    var title: String
    var domain: String
    var url: URL
}
