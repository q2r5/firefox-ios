/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import SwiftUI
import WidgetKit

struct TwoLinePocketCell: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12.0) {
            Image("search-button")
                .frame(width: 16.0, height: 16.0, alignment: .top)
            Text("On Portland’s Streets, Chaotic Scenes Continue Tradition of Protest")
                .font(.subheadline)
                .frame(height: 40.0)
            Spacer()
        }
        .padding(.leading, 16.0)
        .padding(.vertical, 10.0)
    }
}

struct ThreeLinePocketCell: View {
    let story: PocketWidgetStory

    var body: some View {
        Link(destination: linkToContainingApp("?url=\(story.url.absoluteString)", query: "open-url")) {
            HStack(alignment: .top, spacing: 12.0) {
                if story.image != nil {
                    story.image
                        .scaledToFit()
                        .frame(width: 60.0, height: 60.0, alignment: .top)
                } else {
                    story.favicon
                        .scaledToFit()
                        .frame(width: 60.0, height: 60.0, alignment: .top)
                }
                VStack(alignment: .leading) {
                    Text(story.title)
                        .font(.body)
                        .lineLimit(2)
                    Text(story.domain)
                        .font(.subheadline)
                        .foregroundColor(Color("subtitleLabelColor"))
                }
                Spacer()
            }
            .padding(.all, 16.0)
        }
    }
}

struct ViewMoreCell: View {
    var body: some View {
        Link(destination: linkToContainingApp("?url=\(Pocket.MoreStoriesURL)", query: "open-url")) {
            HStack(alignment: .top, spacing: 12.0) {
                Image("placeholderFavicon")
                    .frame(width: 16.0, height: 16.0, alignment: .top)
                Text(Strings.ViewMoreDots)
                    .font(.subheadline)
                    .frame(height: 20.0)
                Spacer()
            }
            .padding(.vertical, 14.0)
            .padding(.leading, 16.0)
        }
    }
}

struct PocketCell_Previews: PreviewProvider {
    static var previews: some View {
        ZStack(alignment: .leading) {
            ContainerRelativeShape()
                .fill(Color("backgroundColor"))

            VStack(spacing: 0) {
                TwoLinePocketCell()
                Divider()
                TwoLinePocketCell()
                Divider()
                ViewMoreCell()
            }
        }
        .previewContext(WidgetPreviewContext(family: .systemMedium))
        .environment(\.colorScheme, .dark)
    }
}
