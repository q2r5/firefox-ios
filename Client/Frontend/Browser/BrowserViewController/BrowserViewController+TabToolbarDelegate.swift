/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared
import Account

extension BrowserViewController: TabToolbarDelegate, PhotonActionSheetProtocol {
    func tabToolbarDidPressBack(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        tabManager.selectedTab?.goBack()
    }

    func tabToolbarDidLongPressBack(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        showBackForwardList()
    }

    func tabToolbarDidPressReload(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        tabManager.selectedTab?.reload()
    }

    func tabToolbarReloadContextMenu(_ suggested: [UIMenuElement]?) -> UIMenu? {
        guard let tab = tabManager.selectedTab,
              tab.webView?.url != nil,
              (tab.getContentScript(name: ReaderMode.name()) as? ReaderMode)?.state != .active else {
            return nil
        }

        let defaultUAisDesktop = UserAgent.isDesktop(ua: UserAgent.getUserAgent())
        let toggleActionTitle: String
        if defaultUAisDesktop {
            toggleActionTitle = tab.changedUserAgent ? Strings.AppMenuViewDesktopSiteTitleString : Strings.AppMenuViewMobileSiteTitleString
        } else {
            toggleActionTitle = tab.changedUserAgent ? Strings.AppMenuViewMobileSiteTitleString : Strings.AppMenuViewDesktopSiteTitleString
        }
        let toggleDesktopSite = UIAction(title: toggleActionTitle) { _ in
            if let url = tab.url {
                tab.toggleChangeUserAgent()
                Tab.ChangeUserAgent.updateDomainList(forUrl: url, isChangedUA: tab.changedUserAgent, isPrivate: tab.isPrivate)
            }
        }

        if let url = tab.webView?.url, let helper = tab.contentBlocker, helper.isEnabled, helper.blockingStrengthPref == .strict {
            let isSafelisted = helper.status == .safelisted

            let title = !isSafelisted ? Strings.TrackingProtectionReloadWithout : Strings.TrackingProtectionReloadWith
            let toggleTP = UIAction(title: title) { _ in
                ContentBlocker.shared.safelist(enable: !isSafelisted, url: url) {
                    tab.reload()
                }
            }
            return UIMenu(children: [toggleDesktopSite, toggleTP])
        } else {
            return UIMenu(children: [toggleDesktopSite])
        }
    }

    func tabToolbarDidLongPressReload(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
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

    func tabToolbarDidPressStop(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        tabManager.selectedTab?.stop()
    }

    func tabToolbarDidPressForward(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        tabManager.selectedTab?.goForward()
    }

    func tabToolbarDidLongPressForward(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        showBackForwardList()
    }

    func tabToolbarDidPressLibrary(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        if let libraryViewController = self.libraryViewController, libraryViewController.isViewLoaded {
            libraryViewController.dismiss(animated: true)
        } else {
            showLibrary()
        }
    }
    
    func tabToolbarDidPressAddNewTab(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        tabManager.selectTab(tabManager.addTab(nil, isPrivate: isPrivate))
        focusLocationTextField(forTab: tabManager.selectedTab)
    }

    func getAppMenu() -> UIMenu {
        var actions = [UIMenuElement]()
        let whatsNewAction = UIAction(title: Strings.WhatsNewString) { _ in
            if let whatsNewTopic = AppInfo.whatsNewTopic, let whatsNewURL = SupportUtils.URLForTopic(whatsNewTopic) {
                TelemetryWrapper.recordEvent(category: .action, method: .open, object: .whatsNew)
                self.openURLInNewTab(whatsNewURL)
            }
        }

        let userProfile = RustFirefoxAccounts.shared.userProfile
        var syncActions = [UIMenuElement]()
        if let userProfile = userProfile {
            let showFxA = UIAction(title: userProfile.displayName ?? userProfile.email) { _ in
                self.presentSignInViewController(FxALaunchParams(query: ["entrypoint" : "browsermenu"]), flowType: .emailLoginFlow, referringPage: .appMenu)
            }
            let syncNow = UIAction(title: Strings.FxASyncNow) { _ in
                self.profile.syncManager.syncEverything(why: .syncNow)
            }
            syncActions.append(syncNow)
            syncActions.append(showFxA)
        } else {
            let signInAction = UIAction(title: Strings.FxASignInToSync) { _ in
                self.presentSignInViewController(FxALaunchParams(query: ["entrypoint" : "browsermenu"]), flowType: .emailLoginFlow, referringPage: .appMenu)
            }
            syncActions.append(signInAction)
        }
        actions.append(UIMenu(options: .displayInline, children: syncActions))

        let isLoginsButtonShowing = LoginListViewController.shouldShowAppMenuShortcut(forPrefs: profile.prefs)
        let viewLogins: UIAction? = !isLoginsButtonShowing ? nil :
            UIAction(title: Strings.LoginsAndPasswordsTitle) { _ in
                guard let navController = self.navigationController else { return }
                let navigationHandler: ((_ url: URL?) -> Void) = { url in
                    BrowserViewController.foregroundBVC().dismiss(animated: true, completion: nil)
                    self.openURLInNewTab(url)
                }

                LoginListViewController.create(authenticateInNavigationController: navController, profile: self.profile, settingsDelegate: self, webpageNavigationHandler: navigationHandler).uponQueue(.main) { loginsVC in
                    guard let loginsVC = loginsVC else { return }
                    loginsVC.shownFromAppMenu = true
                    let navController = ThemedNavigationController(rootViewController: loginsVC)
                    self.present(navController, animated: true)
                }
            }
        if let viewLogins = viewLogins {
            actions.append(UIMenu(options: .displayInline, children: [viewLogins]))
        }

        let openLibrary = UIAction(title: Strings.AppMenuLibraryTitleString) { _ in
            self.showLibrary()
        }
        
        let openHomePage = UIAction(title: Strings.AppMenuOpenHomePageTitleString) { _ in
            let tab = self.tabManager.selectedTab
            let page = NewTabAccessors.getHomePage(self.profile.prefs)
            if page == .homePage, let homePageURL = HomeButtonHomePageAccessors.getHomePage(self.profile.prefs) {
                tab?.loadRequest(PrivilegedRequest(url: homePageURL) as URLRequest)
            } else if let homePanelURL = page.url {
                tab?.loadRequest(PrivilegedRequest(url: homePanelURL) as URLRequest)
            }
        }
        
        actions.append(UIMenu(options: .displayInline, children: [openHomePage, openLibrary]))

        let noImageMode = UIAction(title: "No Image Mode", state: (NoImageModeHelper.isActivated(profile.prefs) ? .on : .off)) { action in
            let actionState = NoImageModeHelper.isActivated(self.profile.prefs)

            NoImageModeHelper.toggle(isEnabled: !actionState, profile: self.profile, tabManager: self.tabManager)

            // This isn't good, but I don't see any other way to force an update to the menu
            self.toolbar?.appMenuButton.menu = self.getAppMenu()
        }

        let nightMode = UIAction(title: "Night Mode", state: (NightModeHelper.isActivated(profile.prefs) ? .on : .off)) { _ in
            NightModeHelper.toggle(self.profile.prefs, tabManager: self.tabManager)

            // If we've enabled night mode and the theme is normal, enable dark theme
            if NightModeHelper.isActivated(self.profile.prefs), ThemeManager.instance.currentName == .normal {
                ThemeManager.instance.current = DarkTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: true)
            }

            // If we've disabled night mode and dark theme was activated by it then disable dark theme
            if !NightModeHelper.isActivated(self.profile.prefs), NightModeHelper.hasEnabledDarkTheme(self.profile.prefs), ThemeManager.instance.currentName == .dark {
                ThemeManager.instance.current = NormalTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: false)
            }

            // This isn't good, but I don't see any other way to force an update to the menu
            self.toolbar?.appMenuButton.menu = self.getAppMenu()
        }

        let openSettings = UIAction(title: Strings.AppMenuSettingsTitleString) { _ in
            let settingsTableViewController = AppSettingsTableViewController()
            settingsTableViewController.profile = self.profile
            settingsTableViewController.tabManager = self.tabManager
            settingsTableViewController.settingsDelegate = self

            let controller = ThemedNavigationController(rootViewController: settingsTableViewController)
            // On iPhone iOS13 the WKWebview crashes while presenting file picker if its not full screen. Ref #6232
            if UIDevice.current.userInterfaceIdiom == .phone {
                controller.modalPresentationStyle = .fullScreen
            }
            controller.presentingModalViewControllerDelegate = self

            // Wait to present VC in an async dispatch queue to prevent a case where dismissal
            // of this popover on iPad seems to block the presentation of the modal VC.
            DispatchQueue.main.async {
                self.present(controller, animated: true, completion: nil)
            }
        }
        actions.append(UIMenu(options: .displayInline, children: [openSettings, whatsNewAction, nightMode, noImageMode]))
        
        return UIMenu(children: actions.reversed())
    }

    func tabToolbarDidPressMenu(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        var whatsNewAction: PhotonActionSheetItem?
        let showBadgeForWhatsNew = shouldShowWhatsNew()
        if showBadgeForWhatsNew {
            // Set the version number of the app, so the What's new will stop showing
            profile.prefs.setString(AppInfo.appVersion, forKey: LatestAppVersionProfileKey)
            // Redraw the toolbar so the badge hides from the appMenu button.
            updateToolbarStateForTraitCollection(view.traitCollection)
        }
        whatsNewAction = PhotonActionSheetItem(title: Strings.WhatsNewString, iconString: "whatsnew", isEnabled: showBadgeForWhatsNew, badgeIconNamed: "menuBadge") { _, _ in
            if let whatsNewTopic = AppInfo.whatsNewTopic, let whatsNewURL = SupportUtils.URLForTopic(whatsNewTopic) {
                TelemetryWrapper.recordEvent(category: .action, method: .open, object: .whatsNew)
                self.openURLInNewTab(whatsNewURL)
            }
        }

        // ensure that any keyboards or spinners are dismissed before presenting the menu
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        libraryViewController?.dismiss(animated: true)
        var actions: [[PhotonActionSheetItem]] = []

        let syncAction = syncMenuButton(showFxA: presentSignInViewController)
        let isLoginsButtonShowing = LoginListViewController.shouldShowAppMenuShortcut(forPrefs: profile.prefs)
        let viewLogins: PhotonActionSheetItem? = !isLoginsButtonShowing ? nil :
            PhotonActionSheetItem(title: Strings.LoginsAndPasswordsTitle, iconString: "key", iconType: .Image, iconAlignment: .left, isEnabled: true) { _, _ in
            guard let navController = self.navigationController else { return }
            let navigationHandler: ((_ url: URL?) -> Void) = { url in
                BrowserViewController.foregroundBVC().dismiss(animated: true, completion: nil)
                self.openURLInNewTab(url)
            }
            LoginListViewController.create(authenticateInNavigationController: navController, profile: self.profile, settingsDelegate: self, webpageNavigationHandler: navigationHandler).uponQueue(.main) { loginsVC in
                guard let loginsVC = loginsVC else { return }
                loginsVC.shownFromAppMenu = true
                let navController = ThemedNavigationController(rootViewController: loginsVC)
                self.present(navController, animated: true)
            }
        }

        let optionalActions = [syncAction, viewLogins].compactMap { $0 }
        if !optionalActions.isEmpty {
            actions.append(optionalActions)
        }

        actions.append(getLibraryActions(vcDelegate: self))
        actions.append(getOtherPanelActions(vcDelegate: self))

        if let whatsNewAction = whatsNewAction, var lastGroup = actions.last, lastGroup.count > 1 {
            lastGroup.insert(whatsNewAction, at: lastGroup.count - 1)
            actions.removeLast()
            actions.append(lastGroup)
        }

        // force a modal if the menu is being displayed in compact split screen
        let shouldSuppress = !topTabsVisible && UIDevice.current.userInterfaceIdiom == .pad
        presentSheetWith(actions: actions, on: self, from: button, suppressPopover: shouldSuppress)
    }

    func tabToolbarDidPressTabs(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        showTabTray()
        TelemetryWrapper.recordEvent(category: .action, method: .press, object: .tabToolbar, value: .tabView)
    }

    func getTabToolbarLongPressActionsForModeSwitching() -> [PhotonActionSheetItem] {
        guard let selectedTab = tabManager.selectedTab else { return [] }
        let count = selectedTab.isPrivate ? tabManager.normalTabs.count : tabManager.privateTabs.count
        let infinity = "\u{221E}"
        let tabCount = (count < 100) ? count.description : infinity

        func action() {
            let result = tabManager.switchPrivacyMode()
            if result == .createdNewTab, NewTabAccessors.getNewTabPage(self.profile.prefs) == .blankPage {
                focusLocationTextField(forTab: tabManager.selectedTab)
            }
        }

        let privateBrowsingMode = PhotonActionSheetItem(title: Strings.privateBrowsingModeTitle, iconString: "nav-tabcounter", iconType: .TabsButton, tabCount: tabCount) { _, _ in
            action()
        }
        let normalBrowsingMode = PhotonActionSheetItem(title: Strings.normalBrowsingModeTitle, iconString: "nav-tabcounter", iconType: .TabsButton, tabCount: tabCount) { _, _ in
            action()
        }

        if let tab = self.tabManager.selectedTab {
            return tab.isPrivate ? [normalBrowsingMode] : [privateBrowsingMode]
        }
        return [privateBrowsingMode]
    }

    func getMoreTabToolbarLongPressActions() -> [PhotonActionSheetItem] {
        let newTab = PhotonActionSheetItem(title: Strings.NewTabTitle, iconString: "quick_action_new_tab", iconType: .Image) { _, _ in
            let shouldFocusLocationField = NewTabAccessors.getNewTabPage(self.profile.prefs) == .blankPage
            self.openBlankNewTab(focusLocationField: shouldFocusLocationField, isPrivate: false)
        }
        let newPrivateTab = PhotonActionSheetItem(title: Strings.NewPrivateTabTitle, iconString: "quick_action_new_tab", iconType: .Image) { _, _ in
            let shouldFocusLocationField = NewTabAccessors.getNewTabPage(self.profile.prefs) == .blankPage
            self.openBlankNewTab(focusLocationField: shouldFocusLocationField, isPrivate: true)}
        let closeTab = PhotonActionSheetItem(title: Strings.CloseTabTitle, iconString: "tab_close", iconType: .Image) { _, _ in
            if let tab = self.tabManager.selectedTab {
                self.tabManager.removeTabAndUpdateSelectedIndex(tab)
                self.updateTabCountUsingTabManager(self.tabManager)
            }}
        if let tab = self.tabManager.selectedTab {
            return tab.isPrivate ? [newPrivateTab, closeTab] : [newTab, closeTab]
        }
        return [newTab, closeTab]
    }

    func tabToolbarDidLongPressTabs(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        guard self.presentedViewController == nil else {
            return
        }
        var actions: [[PhotonActionSheetItem]] = []
        actions.append(getTabToolbarLongPressActionsForModeSwitching())
        actions.append(getMoreTabToolbarLongPressActions())

        // Force a modal if the menu is being displayed in compact split screen.
        let shouldSuppress = !topTabsVisible && UIDevice.current.userInterfaceIdiom == .pad

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        presentSheetWith(actions: actions, on: self, from: button, suppressPopover: shouldSuppress)
    }

    func showBackForwardList() {
        if let backForwardList = tabManager.selectedTab?.webView?.backForwardList {
            let backForwardViewController = BackForwardListViewController(profile: profile, backForwardList: backForwardList)
            backForwardViewController.tabManager = tabManager
            backForwardViewController.bvc = self
            backForwardViewController.modalPresentationStyle = .overCurrentContext
            backForwardViewController.backForwardTransitionDelegate = BackForwardListAnimator()
            self.present(backForwardViewController, animated: true, completion: nil)
        }
    }

    func tabToolbarDidPressSearch(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        focusLocationTextField(forTab: tabManager.selectedTab)
    }
}

