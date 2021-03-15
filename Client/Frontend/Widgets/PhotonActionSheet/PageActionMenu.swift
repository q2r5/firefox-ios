// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import Storage
import UIKit

enum ButtonToastAction {
    case share
    case addToReadingList
    case bookmarkPage
    case removeBookmark
    case copyUrl
    case pinPage
    case removePinPage
}

extension PhotonActionSheetProtocol where Self: FeatureFlagsProtocol {
    fileprivate func share(fileURL: URL, buttonView: UIView, presentableVC: PresentableVC) {
        let helper = ShareExtensionHelper(url: fileURL, tab: tabManager.selectedTab)
        let controller = helper.createActivityViewController { completed, activityType in
            print("Shared downloaded file: \(completed)")
        }

        if let popoverPresentationController = controller.popoverPresentationController {
            popoverPresentationController.sourceView = buttonView
            popoverPresentationController.sourceRect = buttonView.bounds
            popoverPresentationController.permittedArrowDirections = .up
        }
        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .sharePageWith)
        presentableVC.present(controller, animated: true, completion: nil)
    }
    
    func getTabMenuActions(tab: Tab,
                           presentShareMenu: @escaping (URL, Tab, UIView, UIPopoverArrowDirection) -> Void,
                           findInPage: @escaping () -> Void,
                           reportSiteIssue: @escaping () -> Void,
                           presentableVC: PresentableVC,
                           isBookmarked: Bool,
                           isPinned: Bool,
                           success: @escaping (String, ButtonToastAction) -> Void,
                           completion: @escaping () -> Void) -> [UIMenuElement] {
        let urlBar = tab.browserViewController?.urlBar ?? UIView()
        if tab.url?.isFileURL ?? false {
            let shareFile = UIAction(title: .AppMenuSharePageTitleString, image: UIImage.templateImageNamed("action_share")) { action in
                guard let url = tab.url else { return }

                self.share(fileURL: url, buttonView: urlBar, presentableVC: presentableVC)
            }
            shareFile.accessibilityIdentifier = "action_share"

            return [shareFile]
        }

        let defaultUAisDesktop = UserAgent.isDesktop(ua: UserAgent.getUserAgent())
        let toggleActionTitle: String
        let toggleActionImage: UIImage?
        if defaultUAisDesktop {
            toggleActionTitle = tab.changedUserAgent ? .AppMenuViewDesktopSiteTitleString : .AppMenuViewMobileSiteTitleString
            toggleActionImage = tab.changedUserAgent ? UIImage.templateImageNamed("menu-RequestDesktopSite") : UIImage.templateImageNamed("menu-ViewMobile")
        } else {
            toggleActionTitle = tab.changedUserAgent ? .AppMenuViewMobileSiteTitleString : .AppMenuViewDesktopSiteTitleString
            toggleActionImage = tab.changedUserAgent ? UIImage.templateImageNamed("menu-ViewMobile") : UIImage.templateImageNamed("menu-RequestDesktopSite")
        }
        let toggleDesktopSite = UIAction(title: toggleActionTitle, image: toggleActionImage) { _ in
            if let url = tab.url {
                tab.toggleChangeUserAgent()
                Tab.ChangeUserAgent.updateDomainList(forUrl: url, isChangedUA: tab.changedUserAgent, isPrivate: tab.isPrivate)
            }
        }
        toggleDesktopSite.accessibilityIdentifier = "menu-RequestDesktopSite"

        let addReadingList = UIAction(title: .AppMenuAddToReadingListTitleString, image: UIImage.templateImageNamed("addToReadingList")) { _ in
            guard let url = tab.url?.displayURL else { return }

            self.profile.readingList.createRecordWithURL(url.absoluteString, title: tab.title ?? "", addedBy: UIDevice.current.name)
            TelemetryWrapper.recordEvent(category: .action, method: .add, object: .readingListItem, value: .pageActionMenu)
            success(.AppMenuAddToReadingListConfirmMessage, .addToReadingList)
        }
        addReadingList.accessibilityIdentifier = "addToReadingList"

        let bookmarkPage = UIAction(title: .AppMenuAddBookmarkTitleString2, image: UIImage.templateImageNamed("menu-Bookmark")) { _ in
            guard let url = tab.canonicalURL?.displayURL,
                let bvc = presentableVC as? BrowserViewController else {
                    return
            }
            bvc.addBookmark(url: url.absoluteString, title: tab.title, favicon: tab.displayFavicon)
            TelemetryWrapper.recordEvent(category: .action, method: .add, object: .bookmark, value: .pageActionMenu)
            completion()
        }
        bookmarkPage.accessibilityIdentifier = "menu-Bookmark"

        let removeBookmark = UIAction(title: .AppMenuRemoveBookmarkTitleString, image: UIImage.templateImageNamed("menu-Bookmark-Remove")) { _ in
            guard let url = tab.url?.displayURL else { return }

            self.profile.places.deleteBookmarksWithURL(url: url.absoluteString).uponQueue(.main) { result in
                if result.isSuccess {
                    success(.AppMenuRemoveBookmarkConfirmMessage, .removeBookmark)
                }
            }

            TelemetryWrapper.recordEvent(category: .action, method: .delete, object: .bookmark, value: .pageActionMenu)
            completion()
        }
        removeBookmark.accessibilityIdentifier = "menu-Bookmark-Remove"

        let pinToTopSites = UIAction(title: .AddToShortcutsActionTitle, image: UIImage.templateImageNamed("action_pin")) { _ in
            guard let url = tab.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

            sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                    return succeed()
                }
                return self.profile.history.addPinnedTopSite(site)
            }.uponQueue(.main) { result in
                if result.isSuccess {
                    success(.AppMenuAddPinToShortcutsConfirmMessage, .pinPage)
                }
            }
            completion()
        }
        pinToTopSites.accessibilityIdentifier = "action_pin"

        let removeTopSitesPin = UIAction(title: .RemoveFromShortcutsActionTitle, image: UIImage.templateImageNamed("action_unpin")) { _ in
            guard let url = tab.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

            sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                    return succeed()
                }

                return self.profile.history.removeFromPinnedTopSites(site)
            }.uponQueue(.main) { result in
                if result.isSuccess {
                    success(.AppMenuRemovePinFromShortcutsConfirmMessage, .removePinPage)
                }
            }
            completion()
        }
        removeTopSitesPin.accessibilityIdentifier = "action_unpin"

        let sendToDevice = UIAction(title: .SendLinkToDeviceTitle, image: UIImage.templateImageNamed("menu-Send-to-Device")) { _ in
            guard let bvc = presentableVC as? PresentableVC & InstructionsViewControllerDelegate & DevicePickerViewControllerDelegate else { return }
            if !self.profile.hasSyncableAccount() {
                let instructionsViewController = InstructionsViewController()
                instructionsViewController.delegate = bvc
                let navigationController = UINavigationController(rootViewController: instructionsViewController)
                navigationController.modalPresentationStyle = .formSheet
                bvc.present(navigationController, animated: true, completion: nil)
                return
            }

            let devicePickerViewController: DevicePicker
            if #available(iOS 14.0, *) {
                let newPicker = NewDevicePickerViewController()
                newPicker.newPickerDelegate = bvc as? NewDevicePickerViewControllerDelegate
                devicePickerViewController = newPicker
            } else {
                devicePickerViewController = DevicePickerViewController()
            }
            devicePickerViewController.pickerDelegate = bvc
            devicePickerViewController.profile = self.profile
            devicePickerViewController.profileNeedsShutdown = false
            let navigationController = UINavigationController(rootViewController: devicePickerViewController)
            navigationController.modalPresentationStyle = .formSheet
            bvc.present(navigationController, animated: true, completion: nil)
        }
        sendToDevice.accessibilityIdentifier = "menu-Send-to-Device"

        let sharePage = UIAction(title: .AppMenuSharePageTitleString, image: UIImage.templateImageNamed("action_share")) { _ in
            guard let url = tab.canonicalURL?.displayURL else { return }

            if let temporaryDocument = tab.temporaryDocument {
                temporaryDocument.getURL().uponQueue(.main, block: { tempDocURL in
                    // If we successfully got a temp file URL, share it like a downloaded file,
                    // otherwise present the ordinary share menu for the web URL.
                    if tempDocURL.isFileURL {
                        self.share(fileURL: tempDocURL, buttonView: urlBar, presentableVC: presentableVC)
                    } else {
                        presentShareMenu(url, tab, urlBar, .up)
                    }
                })
            } else {
                presentShareMenu(url, tab, urlBar, .up)
            }
        }
        sharePage.accessibilityIdentifier = "action_share"

        let copyURL = UIAction(title: .AppMenuCopyLinkTitleString, image: UIImage.templateImageNamed("menu-Copy-Link")) { _ in
            if let url = tab.canonicalURL?.displayURL {
                UIPasteboard.general.url = url
                success(.AppMenuCopyURLConfirmMessage, .copyUrl)
            }
        }
        copyURL.accessibilityIdentifier = "menu-Copy-Link"

        let zoomIn = UIAction(title: "Zoom In", image: UIImage(systemName: "plus.magnifyingglass"), attributes: tab.pageZoom == 3.0 ? .disabled : []) { _ in
            tab.zoomIn()
            completion()
        }

        let zoomOut = UIAction(title: "Zoom Out", image: UIImage(systemName: "minus.magnifyingglass"), attributes: tab.pageZoom == 0.5 ? .disabled : []) { _ in
            tab.zoomOut()
            completion()
        }
        
        let zoomMenu = UIMenu(title: "Zoom", image: UIImage(systemName: "arrow.up.left.and.down.right.magnifyingglass"), children: [zoomOut, zoomIn])
        zoomMenu.subtitle = String(format: "%.0f%%", tab.pageZoom * 100.0)
        
        var mainActions = [sharePage]

        // Disable bookmarking and reading list if the URL is too long.
        if !tab.urlIsTooLong {
            mainActions.append(isBookmarked ? removeBookmark : bookmarkPage)

            if tab.readerModeAvailableOrActive {
                mainActions.append(addReadingList)
            }
        }

        mainActions.append(contentsOf: [sendToDevice, copyURL])

        let pinAction = (isPinned ? removeTopSitesPin : pinToTopSites)
        var commonActions = [toggleDesktopSite, pinAction]

        // Disable find in page and report site issue if document is pdf.
        if tab.mimeType != MIMEType.PDF {
            let findInPageAction = UIAction(title: .AppMenuFindInPageTitleString, image: UIImage(systemName: "magnifyingglass")) { _ in
                findInPage()
            }
            let reportSiteIssueAction = UIAction(title: .AppMenuReportSiteIssueTitleString, image: UIImage.templateImageNamed("menu-reportSiteIssue")) { _ in
                reportSiteIssue()
            }
            commonActions.insert(contentsOf: [reportSiteIssueAction, findInPageAction], at: 0)
        }

        return [zoomMenu, UIMenu(options: .displayInline, children: mainActions), UIMenu(options: .displayInline, children: commonActions)]
    }

    func getTabActions(tab: Tab, buttonView: UIView,
                       presentShareMenu: @escaping (URL, Tab, UIView, UIPopoverArrowDirection) -> Void,
                       findInPage: @escaping () -> Void,
                       reportSiteIssue: @escaping () -> Void,
                       presentableVC: PresentableVC,
                       isBookmarked: Bool,
                       isPinned: Bool,
                       success: @escaping (String, ButtonToastAction) -> Void) -> Array<[PhotonActionSheetItem]> {
        if tab.url?.isFileURL ?? false {
            let shareFile = PhotonActionSheetItem(title: .AppMenuSharePageTitleString, iconString: "action_share") {  _,_ in
                guard let url = tab.url else { return }

                self.share(fileURL: url, buttonView: buttonView, presentableVC: presentableVC)
            }

            return [[shareFile]]
        }

        let defaultUAisDesktop = UserAgent.isDesktop(ua: UserAgent.getUserAgent())
        let toggleActionTitle: String
        let toggleActionIcon: String
        let siteTypeTelemetryObject: TelemetryWrapper.EventObject
        if defaultUAisDesktop {
            toggleActionTitle = tab.changedUserAgent ? .AppMenuViewDesktopSiteTitleString : .AppMenuViewMobileSiteTitleString
            toggleActionIcon = tab.changedUserAgent ?
                "menu-RequestDesktopSite" : "menu-ViewMobile"
            siteTypeTelemetryObject = .requestDesktopSite
        } else {
            toggleActionTitle = tab.changedUserAgent ? .AppMenuViewMobileSiteTitleString : .AppMenuViewDesktopSiteTitleString
            toggleActionIcon = tab.changedUserAgent ?
                "menu-ViewMobile" : "menu-RequestDesktopSite"
            siteTypeTelemetryObject = .requestMobileSite
        }
        let toggleDesktopSite = PhotonActionSheetItem(title: toggleActionTitle, iconString: toggleActionIcon) { _,_  in
            if let url = tab.url {
                tab.toggleChangeUserAgent()
                Tab.ChangeUserAgent.updateDomainList(forUrl: url, isChangedUA: tab.changedUserAgent, isPrivate: tab.isPrivate)
                TelemetryWrapper.recordEvent(category: .action, method: .tap, object: siteTypeTelemetryObject)
            }
        }

        let addReadingList = PhotonActionSheetItem(title: .AppMenuAddToReadingListTitleString, iconString: "addToReadingList") { _,_  in
            guard let url = tab.url?.displayURL else { return }

            self.profile.readingList.createRecordWithURL(url.absoluteString, title: tab.title ?? "", addedBy: UIDevice.current.name)
            TelemetryWrapper.recordEvent(category: .action, method: .add, object: .readingListItem, value: .pageActionMenu)
            success(.AppMenuAddToReadingListConfirmMessage, .addToReadingList)
        }

        let bookmarkPage = PhotonActionSheetItem(title: .AppMenuAddBookmarkTitleString2, iconString: "menu-Bookmark") { _,_  in
            guard let url = tab.canonicalURL?.displayURL,
                let bvc = presentableVC as? BrowserViewController else {
                    return
            }
            bvc.addBookmark(url: url.absoluteString, title: tab.title, favicon: tab.displayFavicon)
            TelemetryWrapper.recordEvent(category: .action, method: .add, object: .bookmark, value: .pageActionMenu)
        }

        let removeBookmark = PhotonActionSheetItem(title: .AppMenuRemoveBookmarkTitleString, iconString: "menu-Bookmark-Remove") { _,_  in
            guard let url = tab.url?.displayURL else { return }

            self.profile.places.deleteBookmarksWithURL(url: url.absoluteString).uponQueue(.main) { result in
                if result.isSuccess {
                    success(.AppMenuRemoveBookmarkConfirmMessage, .removeBookmark)
                }
            }

            TelemetryWrapper.recordEvent(category: .action, method: .delete, object: .bookmark, value: .pageActionMenu)
        }

        let addToShortcuts = PhotonActionSheetItem(title: .AddToShortcutsActionTitle, iconString: "action_pin") { _,_  in
            guard let url = tab.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

            sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                    return succeed()
                }
                return self.profile.history.addPinnedTopSite(site)
            }.uponQueue(.main) { result in
                if result.isSuccess {
                    success(.AppMenuAddPinToShortcutsConfirmMessage, .pinPage)
                }
            }
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .pinToTopSites)
        }

        let removeFromShortcuts = PhotonActionSheetItem(title: .RemoveFromShortcutsActionTitle, iconString: "action_unpin") { _,_  in
            guard let url = tab.url?.displayURL, let sql = self.profile.history as? SQLiteHistory else { return }

            sql.getSites(forURLs: [url.absoluteString]).bind { val -> Success in
                guard let site = val.successValue?.asArray().first?.flatMap({ $0 }) else {
                    return succeed()
                }

                return self.profile.history.removeFromPinnedTopSites(site)
            }.uponQueue(.main) { result in
                if result.isSuccess {
                    success(.AppMenuRemovePinFromShortcutsConfirmMessage, .removePinPage)
                }
            }
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .removePinnedSite)
        }

        let sendToDevice = PhotonActionSheetItem(title: .SendLinkToDeviceTitle,
                                                 iconString: "menu-Send-to-Device") { _,_  in
            guard let bvc = presentableVC as? PresentableVC & InstructionsViewControllerDelegate & DevicePickerViewControllerDelegate else { return }
            if !self.profile.hasSyncableAccount() {
                let instructionsViewController = InstructionsViewController()
                instructionsViewController.delegate = bvc
                let navigationController = UINavigationController(rootViewController: instructionsViewController)
                navigationController.modalPresentationStyle = .formSheet
                bvc.present(navigationController, animated: true, completion: nil)
                return
            }

            let devicePickerViewController = DevicePickerViewController()
            devicePickerViewController.pickerDelegate = bvc
            devicePickerViewController.profile = self.profile
            devicePickerViewController.profileNeedsShutdown = false
            let navigationController = UINavigationController(rootViewController: devicePickerViewController)
            navigationController.modalPresentationStyle = .formSheet
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .sendToDevice)
            bvc.present(navigationController, animated: true, completion: nil)
        }

        let sharePage = PhotonActionSheetItem(title: .ShareContextMenuTitle, iconString: "action_share") { _,_  in
            guard let url = tab.canonicalURL?.displayURL else { return }

            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .sharePageWith)
            if let temporaryDocument = tab.temporaryDocument {
                temporaryDocument.getURL().uponQueue(.main, block: { tempDocURL in
                    // If we successfully got a temp file URL, share it like a downloaded file,
                    // otherwise present the ordinary share menu for the web URL.
                    if tempDocURL.isFileURL {
                        self.share(fileURL: tempDocURL, buttonView: buttonView, presentableVC: presentableVC)
                    } else {
                        presentShareMenu(url, tab, buttonView, .up)
                    }
                })
            } else {
                presentShareMenu(url, tab, buttonView, .up)
            }
        }

        let copyURL = PhotonActionSheetItem(title: .AppMenuCopyLinkTitleString, iconString: "menu-Copy-Link") { _,_ in
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .copyAddress)
            if let url = tab.canonicalURL?.displayURL {
                UIPasteboard.general.url = url
                success(.AppMenuCopyURLConfirmMessage, .copyUrl)
            }
        }

        let formattedZoomString = String(format: "%.0f%%", tab.pageZoom * 100.0)
        var zoomLevel = PhotonActionSheetItem(title: formattedZoomString)
        zoomLevel.customRender = { (title, contentView) in
            let zoomOutButton: UIButton = .build { button in
                button.setImage(UIImage.templateImageNamed("subtract"), for: .normal)
                button.addTarget(tab, action: #selector(tab.zoomOut), for: .touchUpInside)
                button.isEnabled = tab.pageZoom == 0.5 ? false : true
                button.backgroundColor = .clear
            }

            let zoomInButton: UIButton = .build { button in
                button.setImage(UIImage.templateImageNamed("add"), for: .normal)
                button.addTarget(tab, action: #selector(tab.zoomIn), for: .touchUpInside)
                button.isEnabled = tab.pageZoom == 3.0 ? false : true
                button.backgroundColor = .clear
            }
            
            let separator: UIView = .build { view in
                view.backgroundColor = UIColor.Photon.Grey40
            }
            
            let separator2: UIView = .build { view in
                view.backgroundColor = UIColor.Photon.Grey40
            }

            title.textColor = UIColor.theme.tableView.disabledRowText
            
            contentView.addSubview(zoomOutButton)
            contentView.addSubview(separator)
            contentView.addSubview(title)
            contentView.addSubview(separator2)
            contentView.addSubview(zoomInButton)
            
            contentView.addConstraints([
                zoomOutButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                zoomOutButton.topAnchor.constraint(equalTo: contentView.topAnchor),
                zoomOutButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                zoomOutButton.imageView!.widthAnchor.constraint(equalToConstant: 24),
                zoomOutButton.imageView!.heightAnchor.constraint(equalToConstant: 24),
                zoomOutButton.widthAnchor.constraint(equalTo: contentView.heightAnchor),
                zoomInButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                zoomInButton.topAnchor.constraint(equalTo: contentView.topAnchor),
                zoomInButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                zoomInButton.imageView!.widthAnchor.constraint(equalToConstant: 24),
                zoomInButton.imageView!.heightAnchor.constraint(equalToConstant: 24),
                zoomInButton.widthAnchor.constraint(equalToConstant: 36),
                title.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                separator.widthAnchor.constraint(equalToConstant: 1),
                separator.topAnchor.constraint(equalTo: contentView.topAnchor),
                separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                separator.leadingAnchor.constraint(equalTo: zoomOutButton.trailingAnchor),
                separator2.widthAnchor.constraint(equalToConstant: 1),
                separator2.topAnchor.constraint(equalTo: contentView.topAnchor),
                separator2.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                separator2.trailingAnchor.constraint(equalTo: zoomInButton.leadingAnchor)
            ])
        }

        let zoomActions = [zoomLevel]

        let pinAction = (isPinned ? removeFromShortcuts : addToShortcuts)
        var section1 = [pinAction]
        var section2 = [toggleDesktopSite]
        var section3 = [sharePage]

        // Disable bookmarking and reading list if the URL is too long.
        if !tab.urlIsTooLong {
            if tab.readerModeAvailableOrActive {
                section1.insert(addReadingList, at: 0)
            }
            section1.insert((isBookmarked ? removeBookmark : bookmarkPage), at: 0)
        }

        section3.insert(contentsOf: [copyURL, sendToDevice], at: 0)

        // Disable find in page and report site issue if document is pdf.
        if tab.mimeType != MIMEType.PDF {
            let findInPageAction = PhotonActionSheetItem(title: .AppMenuFindInPageTitleString,
                                                         iconString: "menu-FindInPage") { _,_ in
                findInPage()
            }
            section2.insert(findInPageAction, at: 0)

            if featureFlags.isFeatureActiveForBuild(.reportSiteIssue) {
                let reportSiteIssueAction = PhotonActionSheetItem(title: .AppMenuReportSiteIssueTitleString,
                                                                  iconString: "menu-reportSiteIssue") { _,_ in
                    reportSiteIssue()
                }
                section2.append(reportSiteIssueAction)
            }
        }

        return [zoomActions, section1, section2, section3]
    }
}
