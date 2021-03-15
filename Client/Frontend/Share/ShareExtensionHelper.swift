// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import Shared
import ShareTo
import Storage
import UniformTypeIdentifiers

private let log = Logger.browserLogger

class ShareExtensionHelper: NSObject {
    fileprivate weak var selectedTab: Tab?

    fileprivate let url: URL

    fileprivate func isFile(url: URL) -> Bool { url.scheme == "file" }
    fileprivate let profile = BrowserProfile(localName: "profile")
    var devicesActions = [DevicesShareSheet]()

    // Can be a file:// or http(s):// url
    init(url: URL, tab: Tab?) {
        self.url = url
        self.selectedTab = tab
    }

    func createActivityViewController(_ completionHandler: @escaping (_ completed: Bool, _ activityType: UIActivity.ActivityType?) -> Void) -> UIActivityViewController {
        var activityItems = [AnyObject]()

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = (url.absoluteString as NSString).lastPathComponent
        printInfo.outputType = .general
        activityItems.append(printInfo)

        // when tab is not loaded (webView != nil) don't show print activity
        if let tab = selectedTab, tab.webView != nil {
            activityItems.append(TabPrintPageRenderer(tab: tab))
        }

        if let title = selectedTab?.title {
            activityItems.append(TitleActivityItemProvider(title: title))
        }
        activityItems.append(self)

        if let devices = self.profile.remoteClientsAndTabs.getRemoteDevices().value.successValue {
            for device in devices {
                let deviceShareItem = DevicesShareSheet(title: device.name, image: UIImage(named: "faviconFox")) { sharedItems in
                    _ = self.profile.sendItem(ShareItem(url: self.url.absoluteString, title: nil, favicon: nil), toDevices: [device])
                }
                devicesActions.append(deviceShareItem)
            }
        }

        var activityViewController: UIActivityViewController
        if isFile(url: url) {
            activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: devicesActions)
        } else {
            activityViewController = UIActivityViewController(activityItems: activityItems, applicationActivities: devicesActions)
        }

        // Hide 'Add to Reading List' which currently uses Safari.
        // We would also hide View Later, if possible, but the exclusion list doesn't currently support
        // third-party activity types (rdar://19430419).
        activityViewController.excludedActivityTypes = [
            UIActivity.ActivityType.addToReadingList,
        ]

        activityViewController.completionWithItemsHandler = { activityType, completed, returnedItems, activityError in
            if !completed {
                completionHandler(completed, activityType)
                return
            }

            completionHandler(completed, activityType)
        }
        return activityViewController
    }
}

extension ShareExtensionHelper: UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        
        if isOpenByCopy(activityType: activityType) {
            return url
        }

        // Return the URL for the selected tab. If we are in reader view then decode
        // it so that we copy the original and not the internal localhost one.
        return url.isReaderModeURL ? url.decodeReaderModeURL : url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        if isOpenByCopy(activityType: activityType) {
            return isFile(url: url) ? UTType.fileURL.identifier : UTType.url.identifier
        }

        return UTType.url.identifier
    }

    private func isOpenByCopy(activityType: UIActivity.ActivityType?) -> Bool {
        guard let activityType = activityType?.rawValue else { return false }
        return activityType.lowercased().range(of: "remoteopeninapplication-bycopy") != nil
    }
}
