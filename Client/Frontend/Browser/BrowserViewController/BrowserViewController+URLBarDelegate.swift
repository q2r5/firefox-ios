// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import Storage
import Telemetry
import Glean
import UIKit
import Sentry

protocol OnViewDismissable: UIViewController {
    var onViewDismissed: (() -> Void)? { get set }
}

class DismissableNavigationViewController: UINavigationController, OnViewDismissable {
    var onViewDismissed: (() -> Void)? = nil
    var onViewWillDisappear: (() -> Void)? = nil

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onViewWillDisappear?()
        onViewWillDisappear = nil
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onViewDismissed?()
        onViewDismissed = nil
    }
}

extension BrowserViewController: URLBarDelegate, FeatureFlagsProtocol {
    func showTabTray(withFocusOnUnselectedTab tabToFocus: Tab? = nil) {
        Sentry.shared.clearBreadcrumbs()

        updateFindInPageVisibility(visible: false)

        self.tabTrayViewController = TabTrayViewController(tabTrayDelegate: self,
                                                           profile: profile,
                                                           showChronTabs: shouldShowChronTabs(),
                                                           tabToFocus: tabToFocus)

        tabTrayViewController?.openInNewTab = { url, isPrivate in
            let tab = self.tabManager.addTab(URLRequest(url: url), afterTab: self.tabManager.selectedTab, isPrivate: isPrivate)
            // If we are showing toptabs a user can just use the top tab bar
            // If in overlay mode switching doesnt correctly dismiss the homepanels
            guard !self.topTabsVisible, !self.urlBar.inOverlayMode else {
                return
            }
            // We're not showing the top tabs; show a toast to quick switch to the fresh new tab.
            let toast = ButtonToast(labelText: .ContextMenuButtonToastNewTabOpenedLabelText, buttonText: .ContextMenuButtonToastNewTabOpenedButtonText, completion: { buttonPressed in
                if buttonPressed {
                    self.tabManager.selectTab(tab)
                }
            })
            self.show(toast: toast)
        }

        tabTrayViewController?.didSelectUrl = { url, visitType in
            guard let tab = self.tabManager.selectedTab else { return }
            self.finishEditingAndSubmit(url, visitType: visitType, forTab: tab)
        }

        guard self.tabTrayViewController != nil else { return }

        let navigationController = DismissableNavigationViewController(rootViewController: tabTrayViewController!)
        navigationController.presentationController?.delegate = tabTrayViewController

        self.present(navigationController, animated: true, completion: nil)

        if let tab = tabManager.selectedTab {
            screenshotHelper.takeScreenshot(tab)
            tabManager.storeScreenshot(tab: tab)
        }
        TelemetryWrapper.recordEvent(category: .action, method: .open, object: .tabTray)
    }

    private func shouldShowChronTabs() -> Bool {
        var shouldShowChronTabs = false // default don't show
        let chronDebugValue = profile.prefs.boolForKey(PrefsKeys.ChronTabsPrefKey)
        let chronLPValue = false

        // Only allow chron tabs on iPhone
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Respect debug mode chron tab value on
            if chronDebugValue != nil {
                shouldShowChronTabs = chronDebugValue!
            // Respect build channel based settings
            } else if chronDebugValue == nil {
                if featureFlags.isFeatureActiveForBuild(.chronologicalTabs) {
                    shouldShowChronTabs = true
                } else {
                    // Respect LP value
                    shouldShowChronTabs = chronLPValue
                }
                profile.prefs.setBool(shouldShowChronTabs, forKey: PrefsKeys.ChronTabsPrefKey)
            }
        }

        return shouldShowChronTabs
    }

    func urlBarDidPressReload(_ urlBar: URLBarView) {
        tabManager.selectedTab?.reload()
    }

    func urlBarDidPressQRButton(_ urlBar: URLBarView) {
        let qrCodeViewController = QRCodeViewController()
        qrCodeViewController.qrCodeDelegate = self
        let controller = QRCodeNavigationController(rootViewController: qrCodeViewController)
        self.present(controller, animated: true, completion: nil)
    }

    @available(iOS 14, *)
    func getPageActionMenu() -> UIMenu {
        guard let tab = tabManager.selectedTab, let urlString = tab.url?.absoluteString, !urlBar.inOverlayMode else { return UIMenu() }

        let actionMenuPresenter: (URL, Tab, UIView, UIPopoverArrowDirection) -> Void  = { (url, tab, view, _) in
            self.presentActivityViewController(url, tab: tab, sourceView: view, sourceRect: view.bounds, arrowDirection: .up)
        }

        let findInPageAction = {
            self.updateFindInPageVisibility(visible: true)
        }

        let reportSiteIssue = {
            self.openURLInNewTab(SupportUtils.URLForReportSiteIssue(self.urlBar.currentURL?.absoluteString))
        }

        let successCallback: (String, ButtonToastAction) -> Void = { (successMessage, toastAction) in
            switch toastAction {
            case .bookmarkPage:
                let toast = ButtonToast(labelText: successMessage, buttonText: .BookmarksEdit, textAlignment: .left) { isButtonTapped in
                    guard isButtonTapped,
                          let bookmarkItems = self.profile.places.getBookmarksWithURL(url: urlString).value.successValue,
                          !bookmarkItems.isEmpty,
                          let folder = self.profile.places.getBookmark(guid: bookmarkItems[0].parentGUID ?? BookmarkRoots.MobileFolderGUID).value.successValue as? BookmarkFolder else {
                        return
                    }
                    let editVC = BookmarkDetailPanel(profile: self.profile, bookmarkNode: bookmarkItems[0], parentBookmarkFolder: folder)
                    let navController: UINavigationController
                    navController = UINavigationController(rootViewController: editVC)
                    navController.navigationBar.isTranslucent = false
                    navController.preferredContentSize = CGSize(width: ViewControllerConsts.PreferredSize.IntroViewController.width, height: ViewControllerConsts.PreferredSize.IntroViewController.height)
                    self.present(navController, animated: true, completion: nil)
                }
                self.show(toast: toast)
            case .removeBookmark:
                let toast = ButtonToast(labelText: successMessage, buttonText: .UndoString, textAlignment: .left) { isButtonTapped in
                    isButtonTapped ? self.addBookmark(url: urlString) : nil
                }
                self.show(toast: toast)
            default:
                SimpleToast().showAlertWithText(successMessage, bottomContainer: self.webViewContainer)
            }
        }
        
        let completion: () -> Void = {
            self.urlBar.locationView.pageOptionsButton.menu = self.getPageActionMenu()
            self.urlBar.locationView.pageOptionsButton.showsMenuAsPrimaryAction = true
        }

        let isBookmarked = fetchBookmarkStatus(for: urlString).value.successValue ?? false
        let isPinned = fetchPinnedTopSiteStatus(for: urlString).value.successValue ?? false
        let pageActions = self.getTabMenuActions(tab: tab, presentShareMenu: actionMenuPresenter, findInPage: findInPageAction,
                                             reportSiteIssue: reportSiteIssue, presentableVC: self,
                                             isBookmarked: isBookmarked, isPinned: isPinned, success: successCallback, completion: completion)
        if urlBar.isBottomToolbar {
            return UIMenu(title: "Page Actions", image: UIImage.templateImageNamed("menu-More-Options"), children: pageActions)
        } else {
            return UIMenu(children: pageActions)
        }
    }

    func urlBarDidPressPageOptions(_ urlBar: URLBarView, from button: UIButton) {
        guard let tab = tabManager.selectedTab, let urlString = tab.url?.absoluteString, !urlBar.inOverlayMode else { return }

        let actionMenuPresenter: (URL, Tab, UIView, UIPopoverArrowDirection) -> Void  = { (url, tab, view, _) in
            self.presentActivityViewController(url, tab: tab, sourceView: view, sourceRect: view.bounds, arrowDirection: .up)
        }

        let findInPageAction = {
            self.updateFindInPageVisibility(visible: true)
        }

        let reportSiteIssue = {
            self.openURLInNewTab(SupportUtils.URLForReportSiteIssue(self.urlBar.currentURL?.absoluteString))
        }

        let successCallback: (String, ButtonToastAction) -> Void = { (successMessage, toastAction) in
            switch toastAction {
            case .bookmarkPage:
                let toast = ButtonToast(labelText: successMessage, buttonText: .BookmarksEdit, textAlignment: .left) { isButtonTapped in
                    guard isButtonTapped,
                          let bookmarkItems = self.profile.places.getBookmarksWithURL(url: urlString).value.successValue,
                          !bookmarkItems.isEmpty,
                          let folder = self.profile.places.getBookmark(guid: bookmarkItems[0].parentGUID ?? BookmarkRoots.MobileFolderGUID).value.successValue as? BookmarkFolder else {
                        return
                    }
                    let editVC = BookmarkDetailPanel(profile: self.profile, bookmarkNode: bookmarkItems[0], parentBookmarkFolder: folder)
                    self.present(editVC, animated: true)
                }
                self.show(toast: toast)
            case .removeBookmark:
                let toast = ButtonToast(labelText: successMessage, buttonText: .UndoString, textAlignment: .left) { isButtonTapped in
                    isButtonTapped ? self.addBookmark(url: urlString) : nil
                }
                self.show(toast: toast)
            default:
                SimpleToast().showAlertWithText(successMessage, bottomContainer: self.webViewContainer)
            }
        }

        let deferredBookmarkStatus: Deferred<Maybe<Bool>> = fetchBookmarkStatus(for: urlString)
        let deferredPinnedTopSiteStatus: Deferred<Maybe<Bool>> = fetchPinnedTopSiteStatus(for: urlString)

        // Wait for both the bookmark status and the pinned status
        deferredBookmarkStatus.both(deferredPinnedTopSiteStatus).uponQueue(.main) {
            let isBookmarked = $0.successValue ?? false
            let isPinned = $1.successValue ?? false
            let pageActions = self.getTabActions(tab: tab, buttonView: button, presentShareMenu: actionMenuPresenter,
                                                 findInPage: findInPageAction, reportSiteIssue: reportSiteIssue, presentableVC: self, isBookmarked: isBookmarked,
                                                 isPinned: isPinned, success: successCallback)
            self.presentSheetWith(actions: pageActions, on: self, from: button)
        }
    }

    func urlBarDidLongPressPageOptions(_ urlBar: URLBarView, from button: UIButton) {
        guard let tab = tabManager.selectedTab else { return }
        guard let url = tab.canonicalURL?.displayURL, self.presentedViewController == nil else {
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        presentActivityViewController(url, tab: tab, sourceView: button, sourceRect: button.bounds, arrowDirection: .up)
    }

    func urlBarDidTapShield(_ urlBar: URLBarView) {
        if let tab = self.tabManager.selectedTab {
            let etpViewModel = EnhancedTrackingProtectionMenuVM(tab: tab, profile: profile, tabManager: tabManager)
            etpViewModel.onOpenSettingsTapped = {
                let settingsTableViewController = AppSettingsTableViewController()
                settingsTableViewController.profile = self.profile
                settingsTableViewController.tabManager = self.tabManager
                settingsTableViewController.settingsDelegate = self
                settingsTableViewController.deeplinkTo = .contentBlocker

                let controller = ThemedNavigationController(rootViewController: settingsTableViewController)
                controller.presentingModalViewControllerDelegate = self

                // Wait to present VC in an async dispatch queue to prevent a case where dismissal
                // of this popover on iPad seems to block the presentation of the modal VC.
                DispatchQueue.main.async {
                    self.present(controller, animated: true, completion: nil)
                }
            }

            let etpVC = EnhancedTrackingProtectionMenuVC(viewModel: etpViewModel)
            if UIDevice.current.userInterfaceIdiom == .phone {
                etpVC.modalPresentationStyle = .custom
                etpVC.transitioningDelegate = self
            } else {
                etpVC.asPopover = true
                etpVC.modalPresentationStyle = .popover
                etpVC.popoverPresentationController?.sourceView = urlBar.locationView.trackingProtectionButton
                etpVC.popoverPresentationController?.permittedArrowDirections = .up
                etpVC.popoverPresentationController?.delegate = self
            }

            TelemetryWrapper.recordEvent(category: .action, method: .press, object: .trackingProtectionMenu)
            self.present(etpVC, animated: true, completion: nil)
        }
    }

    func urlBarDidPressStop(_ urlBar: URLBarView) {
        tabManager.selectedTab?.stop()
    }

    func urlBarDidPressTabs(_ urlBar: URLBarView) {
        showTabTray()
    }

    func urlBarDidPressReaderMode(_ urlBar: URLBarView) {
        libraryViewController?.dismiss(animated: true)

        guard let tab = tabManager.selectedTab, let readerMode = tab.getContentScript(name: "ReaderMode") as? ReaderMode else {
            return
        }
        switch readerMode.state {
        case .available:
            enableReaderMode()
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .readerModeOpenButton)
        case .active:
            disableReaderMode()
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .readerModeCloseButton)
        case .unavailable:
            break
        }
    }

    func urlBarDidLongPressReaderMode(_ urlBar: URLBarView) -> Bool {
        guard let tab = tabManager.selectedTab,
               let url = tab.url?.displayURL
            else {
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: String.ReaderModeAddPageGeneralErrorAccessibilityLabel)
                return false
        }

        let result = profile.readingList.createRecordWithURL(url.absoluteString, title: tab.title ?? "", addedBy: UIDevice.current.name)

        switch result.value {
        case .success:
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: String.ReaderModeAddPageSuccessAcessibilityLabel)
            SimpleToast().showAlertWithText(.ShareAddToReadingListDone, bottomContainer: self.webViewContainer)
        case .failure(let error):
            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: String.ReaderModeAddPageMaybeExistsErrorAccessibilityLabel)
            print("readingList.createRecordWithURL(url: \"\(url.absoluteString)\", ...) failed with error: \(error)")
        }
        return true
    }

    func urlBarDidLongPressReload(_ urlBar: URLBarView, from button: UIButton) {
        guard let tab = tabManager.selectedTab else {
            return
        }
        let urlActions = self.getRefreshLongPressMenu(for: tab)
        guard !urlActions.isEmpty else {
            return
        }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        let shouldSuppress = !topTabsVisible && UIDevice.current.userInterfaceIdiom == .pad
        presentSheetWith(actions: [urlActions], on: self, from: button, suppressPopover: shouldSuppress)
    }

    func urlBarReloadContextMenu(_ suggested: [UIMenuElement]?) -> UIMenu? {
        guard let tab = tabManager.selectedTab,
              tab.webView?.url != nil,
              (tab.getContentScript(name: ReaderMode.name()) as? ReaderMode)?.state != .active else {
            return nil
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
        let toggleDesktopSite = UIAction(title: toggleActionTitle, image: toggleActionImage, state: (tab.changedUserAgent ? .on : .off)) { _ in
            if let url = tab.url {
                tab.toggleChangeUserAgent()
                Tab.ChangeUserAgent.updateDomainList(forUrl: url, isChangedUA: tab.changedUserAgent, isPrivate: tab.isPrivate)
            }
        }

        if let url = tab.webView?.url, let helper = tab.contentBlocker, helper.isEnabled, helper.blockingStrengthPref == .strict {
            let isSafelisted = helper.status == .safelisted

            let title: String = !isSafelisted ? .TrackingProtectionReloadWithout : .TrackingProtectionReloadWith
            let image = !isSafelisted ? UIImage.templateImageNamed("menu-TrackingProtection-Off") : UIImage.templateImageNamed("menu-TrackingProtection")
            let toggleTP = UIAction(title: title, image: image) { _ in
                ContentBlocker.shared.safelist(enable: !isSafelisted, url: url) {
                    tab.reload()
                }
            }
            return UIMenu(children: [toggleDesktopSite, toggleTP])
        } else {
            return UIMenu(children: [toggleDesktopSite])
        }
    }

    func locationActionsForURLBar(_ urlBar: URLBarView) -> [AccessibleAction] {
        if UIPasteboard.general.string != nil {
            return [pasteGoAction, pasteAction, copyAddressAction]
        } else {
            return [copyAddressAction]
        }
    }

    func urlBarDisplayTextForURL(_ url: URL?) -> (String?, Bool) {
        // use the initial value for the URL so we can do proper pattern matching with search URLs
        var searchURL = self.tabManager.selectedTab?.url
        if let url = searchURL, InternalURL.isValid(url: url) {
            searchURL = url
        }
        if let query = profile.searchEngines.queryForSearchURL(searchURL as URL?) {
            return (query, true)
        } else {
            return (url?.absoluteString, false)
        }
    }

    func urlBarLocationContextMenu(_ suggested: [UIMenuElement]?) -> UIMenu? {
        let pasteGoAction = UIAction(title: .PasteAndGoTitle) { _ in
            if let pasteboardContents = UIPasteboard.general.string {
                self.urlBar.delegate?.urlBar(self.urlBar, didSubmitText: pasteboardContents)
            }
        }
        pasteGoAction.accessibilityIdentifier = "menu-PasteAndGo"
        let pasteAction = UIAction(title: .PasteTitle) { _ in
            if let pasteboardContents = UIPasteboard.general.string {
                self.urlBar.enterOverlayMode(pasteboardContents, pasted: true, search: true)
            }
        }
        pasteAction.accessibilityIdentifier = "menu-Paste"
        let copyAddressAction = UIAction(title: .CopyAddressTitle) { _ in
            if let url = self.tabManager.selectedTab?.canonicalURL?.displayURL ?? self.urlBar.currentURL {
                UIPasteboard.general.url = url
                SimpleToast().showAlertWithText(.AppMenuCopyURLConfirmMessage, bottomContainer: self.webViewContainer)
            }
        }
        copyAddressAction.accessibilityIdentifier = "menu-Copy-Link"
        if UIPasteboard.general.string != nil {
            return UIMenu(children: [pasteGoAction, pasteAction, copyAddressAction])
        } else {
            return UIMenu(children: [copyAddressAction])
        }
    }

    func urlBarDidLongPressLocation(_ urlBar: URLBarView) {
        let urlActions = self.getLongPressLocationBarActions(with: urlBar, webViewContainer: self.webViewContainer)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        let shouldSuppress = UIDevice.current.userInterfaceIdiom != .pad
        self.presentSheetWith(actions: [urlActions], on: self, from: urlBar, suppressPopover: shouldSuppress)
    }

    func urlBarDidPressScrollToTop(_ urlBar: URLBarView) {
        if let selectedTab = tabManager.selectedTab, firefoxHomeViewController == nil {
            // Only scroll to top if we are not showing the home view controller
            selectedTab.webView?.scrollView.setContentOffset(CGPoint.zero, animated: true)
        }
    }

    func urlBarLocationAccessibilityActions(_ urlBar: URLBarView) -> [UIAccessibilityCustomAction]? {
        return locationActionsForURLBar(urlBar).map { $0.accessibilityCustomAction }
    }

    func urlBar(_ urlBar: URLBarView, didRestoreText text: String) {
        if text.isEmpty {
            hideSearchController()
        } else {
            showSearchController()
        }

        searchController?.searchQuery = text
        searchLoader?.setQueryWithoutAutocomplete(text)
    }

    func urlBar(_ urlBar: URLBarView, didEnterText text: String) {
        urlBar.updateSearchEngineImage()
        if text.isEmpty {
            hideSearchController()
        } else {
            showSearchController()
        }

        searchController?.searchQuery = text
        searchLoader?.query = text
    }

    func urlBar(_ urlBar: URLBarView, didSubmitText text: String) {
        guard let currentTab = tabManager.selectedTab else { return }

        if let fixupURL = URIFixup.getURL(text) {
            // The user entered a URL, so use it.
            finishEditingAndSubmit(fixupURL, visitType: VisitType.typed, forTab: currentTab)
            return
        }

        // We couldn't build a URL, so check for a matching search keyword.
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        guard let possibleKeywordQuerySeparatorSpace = trimmedText.firstIndex(of: " ") else {
            submitSearchText(text, forTab: currentTab)
            return
        }

        let possibleKeyword = String(trimmedText[..<possibleKeywordQuerySeparatorSpace])
        let possibleQuery = String(trimmedText[trimmedText.index(after: possibleKeywordQuerySeparatorSpace)...])

        profile.places.getBookmarkURLForKeyword(keyword: possibleKeyword).uponQueue(.main) { result in

            if var urlString = result.successValue ?? "",
                let escapedQuery = possibleQuery.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed),
                let range = urlString.range(of: "%s") {
                urlString.replaceSubrange(range, with: escapedQuery)

                if let url = URL(string: urlString) {
                    self.finishEditingAndSubmit(url, visitType: VisitType.typed, forTab: currentTab)
                    return
                }
            }

            self.submitSearchText(text, forTab: currentTab)
        }
    }

    func submitSearchText(_ text: String, forTab tab: Tab) {
        let engine = profile.searchEngines.defaultEngine

        if let searchURL = engine.searchURLForQuery(text) {
            // We couldn't find a matching search keyword, so do a search query.
            Telemetry.default.recordSearch(location: .actionBar, searchEngine: engine.engineID ?? "other")
            GleanMetrics.Search.counts["\(engine.engineID ?? "custom").\(SearchesMeasurement.SearchLocation.actionBar.rawValue)"].add()
            searchTelemetry?.shouldSetUrlTypeSearch = true
            tab.updateTimerAndObserving(state: .navSearchLoaded, searchTerm: text, searchProviderUrl: searchURL.absoluteString, nextUrl: "")
            finishEditingAndSubmit(searchURL, visitType: VisitType.typed, forTab: tab)
        } else {
            // We still don't have a valid URL, so something is broken. Give up.
            print("Error handling URL entry: \"\(text)\".")
            assertionFailure("Couldn't generate search URL: \(text)")
        }
    }

    func urlBarDidEnterOverlayMode(_ urlBar: URLBarView) {
        libraryViewController?.dismiss(animated: true)
        urlBar.updateSearchEngineImage()
        guard let profile = profile as? BrowserProfile else {
            return
        }

        if .blankPage == NewTabAccessors.getNewTabPage(profile.prefs) {
            UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: UIAccessibility.Notification.screenChanged)
        } else {
            if let toast = clipboardBarDisplayHandler?.clipboardToast {
                toast.removeFromSuperview()
            }

            showFirefoxHome(inline: false)
        }
    }

    func urlBarDidLeaveOverlayMode(_ urlBar: URLBarView) {
        destroySearchController()
        updateInContentHomePanel(tabManager.selectedTab?.url as URL?)
    }

    func urlBarDidBeginDragInteraction(_ urlBar: URLBarView) {
        dismissVisibleMenus()
    }
}

extension BrowserViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let globalETPStatus = FirefoxTabContentBlocker.isTrackingProtectionEnabled(prefs: profile.prefs)
        return SlideOverPresentationController(presentedViewController: presented,
                                               presenting: presenting,
                                               withGlobalETPStatus: globalETPStatus)
    }
}
