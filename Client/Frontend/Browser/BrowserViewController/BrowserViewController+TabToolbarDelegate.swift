// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import Account
import UIKit

extension BrowserViewController: TabToolbarDelegate, PhotonActionSheetProtocol {
    func tabToolbarDidPressHome(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let page = NewTabAccessors.getHomePage(self.profile.prefs)
        if page == .homePage, let homePageURL = HomeButtonHomePageAccessors.getHomePage(self.profile.prefs) {
            tabManager.selectedTab?.loadRequest(PrivilegedRequest(url: homePageURL) as URLRequest)
        } else if let homePanelURL = page.url {
            tabManager.selectedTab?.loadRequest(PrivilegedRequest(url: homePanelURL) as URLRequest)
        }
        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .home)
    }

    func tabToolbarDidPressLibrary(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
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
            toggleActionTitle = tab.changedUserAgent ? .AppMenuViewDesktopSiteTitleString : .AppMenuViewMobileSiteTitleString
        } else {
            toggleActionTitle = tab.changedUserAgent ? .AppMenuViewMobileSiteTitleString : .AppMenuViewDesktopSiteTitleString
        }
        let toggleDesktopSite = UIAction(title: toggleActionTitle) { _ in
            if let url = tab.url {
                tab.toggleChangeUserAgent()
                Tab.ChangeUserAgent.updateDomainList(forUrl: url, isChangedUA: tab.changedUserAgent, isPrivate: tab.isPrivate)
            }
        }
        toggleDesktopSite.accessibilityIdentifier = "menu-RequestDesktopSite"

        if let url = tab.webView?.url, let helper = tab.contentBlocker, helper.isEnabled, helper.blockingStrengthPref == .strict {
            let isSafelisted = helper.status == .safelisted

            let title: String = !isSafelisted ? .TrackingProtectionReloadWithout : .TrackingProtectionReloadWith
            let toggleTP = UIAction(title: title) { _ in
                ContentBlocker.shared.safelist(enable: !isSafelisted, url: url) {
                    tab.reload()
                }
            }
            toggleTP.accessibilityIdentifier = helper.isEnabled ? "menu-TrackingProtection-Off" : "menu-TrackingProtection"
            return UIMenu(children: [toggleDesktopSite, toggleTP])
        } else {
            return UIMenu(children: [toggleDesktopSite])
        }
    }
    
    func tabToolbarDidLongPressReload(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        guard let tab = tabManager.selectedTab else { return }
        
        let urlActions = self.getRefreshLongPressMenu(for: tab)
        guard !urlActions.isEmpty else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        let shouldSuppress = UIDevice.current.userInterfaceIdiom != .pad
        
        presentSheetWith(actions: [urlActions], on: self, from: button, suppressPopover: shouldSuppress)
    }
    
    func tabToolbarDidPressStop(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        tabManager.selectedTab?.stop()
    }
    
    func tabToolbarDidPressBack(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        tabManager.selectedTab?.goBack()
    }

    func tabToolbarDidLongPressBack(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        showBackForwardList()
    }

    func tabToolbarDidPressForward(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        tabManager.selectedTab?.goForward()
    }

    func tabToolbarDidLongPressForward(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        showBackForwardList()
    }

    func tabToolbarDidPressBookmarks(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        if let libraryViewController = self.libraryViewController, libraryViewController.isViewLoaded {
            libraryViewController.dismiss(animated: true)
        } else {
            showLibrary(panel: .bookmarks)
        }
    }
    
    func tabToolbarDidPressAddNewTab(_ tabToolbar: TabToolbarProtocol, button: UIButton) {
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        tabManager.selectTab(tabManager.addTab(nil, isPrivate: isPrivate))
        focusLocationTextField(forTab: tabManager.selectedTab)
    }

    @available(iOS 14, *)
    func getAppMenu(reversed: Bool = true) -> UIMenu {
        var actions = [UIMenuElement]()
        var section1 = [UIMenuElement]()
        var section2 = [UIMenuElement]()
        var section3 = [UIMenuElement]()

        let userProfile = RustFirefoxAccounts.shared.userProfile
        var syncAction: UIAction
        if let userProfile = userProfile {
            var avatar = UIImage.templateImageNamed("placeholder-avatar")
            if let avatarURL = userProfile.avatarUrl?.asURL,
               let data = try? Data(contentsOf: avatarURL),
               let newAvatar = UIImage(data: data) {
                avatar = newAvatar.sd_roundedCornerImage(withRadius: newAvatar.size.height / 2, corners: .allCorners, borderWidth: 0, borderColor: .clear)
            }

            let showFxA = UIAction(title: userProfile.displayName ?? userProfile.email, image: avatar) { _ in
                self.presentSignInViewController(FxALaunchParams(query: ["entrypoint" : "browsermenu"]), flowType: .emailLoginFlow, referringPage: .appMenu)
            }
            syncAction = showFxA
        } else {
            let signInAction = UIAction(title: .AppMenuBackUpAndSyncData, image: UIImage.templateImageNamed("menu-sync")) { _ in
                self.presentSignInViewController(FxALaunchParams(query: ["entrypoint" : "browsermenu"]), flowType: .emailLoginFlow, referringPage: .appMenu)
            }
            syncAction = signInAction
        }

        let isLoginsButtonShowing = LoginListViewController.shouldShowAppMenuShortcut(forPrefs: profile.prefs)
        let viewLogins: UIAction? = !isLoginsButtonShowing ? nil :
            UIAction(title: . AppMenuPasswords, image: UIImage.templateImageNamed("key")) { _ in
                guard let navController = self.navigationController else { return }
                let navigationHandler: ((_ url: URL?) -> Void) = { url in
                    UIWindow.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
                    self.openURLInNewTab(url)
                }

                if AppAuthenticator.canAuthenticateDeviceOwner() {
                    if LoginOnboarding.shouldShow() {
                        let loginOnboardingViewController = LoginOnboardingViewController(shownFromAppMenu: true)
                        loginOnboardingViewController.doneHandler = {
                            loginOnboardingViewController.dismiss(animated: true)
                        }

                        loginOnboardingViewController.proceedHandler = {
                            loginOnboardingViewController.dismiss(animated: true) {
                                LoginListViewController.create(authenticateInNavigationController: navController, profile: self.profile, settingsDelegate: self, webpageNavigationHandler: navigationHandler).uponQueue(.main) { loginsVC in
                                    guard let loginsVC = loginsVC else { return }
                                    loginsVC.shownFromAppMenu = true
                                    let navController = ThemedNavigationController(rootViewController: loginsVC)
                                    self.present(navController, animated: true)
                                    TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .logins)
                                }
                            }
                        }

                        let navController = ThemedNavigationController(rootViewController: loginOnboardingViewController)
                        self.present(navController, animated: true)

                        LoginOnboarding.setShown()
                    } else {
                        LoginListViewController.create(authenticateInNavigationController: navController, profile: self.profile, settingsDelegate: self, webpageNavigationHandler: navigationHandler).uponQueue(.main) { loginsVC in
                            guard let loginsVC = loginsVC else { return }
                            loginsVC.shownFromAppMenu = true
                            let navController = ThemedNavigationController(rootViewController: loginsVC)
                            self.present(navController, animated: true)
                            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .logins)
                        }
                    }
                } else {
                    let navController = ThemedNavigationController(rootViewController: DevicePasscodeRequiredViewController(shownFromAppMenu: true))
                    self.present(navController, animated: true)
                }
            }
        viewLogins?.accessibilityIdentifier = "key"

        let openBookmarks = UIAction(title: .AppMenuBookmarks, image: UIImage.templateImageNamed("menu-panel-Bookmarks")) { _ in
            self.showLibrary(panel: .bookmarks)
        }
        openBookmarks.accessibilityIdentifier = "menu-panel-Bookmarks"

        let openHistory = UIAction(title: .AppMenuHistory, image: UIImage.templateImageNamed("menu-panel-History")) { _ in
            self.showLibrary(panel: .history)
        }
        openHistory.accessibilityIdentifier = "menu-panel-History"

        let openDownloads = UIAction(title: .AppMenuDownloads, image: UIImage.templateImageNamed("menu-panel-Downloads")) { _ in
            self.showLibrary(panel: .downloads)
        }
        openDownloads.accessibilityIdentifier = "menu-panel-Downloads"

        let openReadingList = UIAction(title: .AppMenuReadingList, image: UIImage.templateImageNamed("menu-panel-ReadingList")) { _ in
            self.showLibrary(panel: .readingList)
        }
        openReadingList.accessibilityIdentifier = "menu-panel-ReadingList"

        var libraryItems = [openBookmarks, openHistory, openDownloads, openReadingList]
        if reversed {
            libraryItems.reverse()
        }

        let libraryMenu = UIMenu(title: .AppMenuLibraryTitleString, image: UIImage.templateImageNamed("menu-library"), children: libraryItems)
        libraryMenu.accessibilityIdentifier = "menu-Library"

        section1 = [libraryMenu]

        let optionalActions = [viewLogins, syncAction].compactMap { $0 }
        if !optionalActions.isEmpty {
            section1.append(contentsOf: optionalActions)
        }

        let noImageTitle: String = NoImageModeHelper.isActivated(profile.prefs) ? .AppMenuShowImageMode : .AppMenuNoImageMode
        let noImageIcon = NoImageModeHelper.isActivated(profile.prefs) ? UIImage.templateImageNamed("menu-ShowImages") : UIImage.templateImageNamed("menu-NoImageMode")
        let noImageMode = UIAction(title: noImageTitle, image: noImageIcon) { action in
            let actionState = NoImageModeHelper.isActivated(self.profile.prefs)

            NoImageModeHelper.toggle(isEnabled: !actionState, profile: self.profile, tabManager: self.tabManager)

            // This isn't good, but I don't see any other way to force an update to the menu
            self.toolbar?.appMenuButton.menu = self.getAppMenu()
            self.urlBar.appMenuButton.menu = self.getAppMenu(reversed: false)
        }

        let nightModeTitle: String = NightModeHelper.isActivated(profile.prefs) ? .AppMenuTurnOffNightMode : .AppMenuTurnOnNightMode
        let nightMode = UIAction(title: nightModeTitle, image: UIImage.templateImageNamed("menu-NightMode")) { _ in
            NightModeHelper.toggle(self.profile.prefs, tabManager: self.tabManager)

            // If we've enabled night mode and the theme is normal, enable dark theme
            if NightModeHelper.isActivated(self.profile.prefs), LegacyThemeManager.instance.currentName == .normal {
                LegacyThemeManager.instance.current = DarkTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: true)
            }

            // If we've disabled night mode and dark theme was activated by it then disable dark theme
            if !NightModeHelper.isActivated(self.profile.prefs), NightModeHelper.hasEnabledDarkTheme(self.profile.prefs), LegacyThemeManager.instance.currentName == .dark {
                LegacyThemeManager.instance.current = NormalTheme()
                NightModeHelper.setEnabledDarkTheme(self.profile.prefs, darkTheme: false)
            }

            // This isn't good, but I don't see any other way to force an update to the menu
            self.toolbar?.appMenuButton.menu = self.getAppMenu()
            self.urlBar.appMenuButton.menu = self.getAppMenu(reversed: false)
        }
        nightMode.accessibilityIdentifier = "menu-NightMode"
        
        section2 = [noImageMode, nightMode]

        let whatsNewAction = UIAction(title: .WhatsNewString, image: UIImage.templateImageNamed("whatsnew")) { _ in
            if let whatsNewTopic = AppInfo.whatsNewTopic, let whatsNewURL = SupportUtils.URLForTopic(whatsNewTopic) {
                TelemetryWrapper.recordEvent(category: .action, method: .open, object: .whatsNew)
                self.openURLInNewTab(whatsNewURL)
            }
        }

        if shouldShowWhatsNew() {
            section2.append(whatsNewAction)
        }

        let openSettings = UIAction(title: .AppMenuSettingsTitleString, image: UIImage.templateImageNamed("menu-Settings")) { _ in
            let settingsTableViewController = AppSettingsTableViewController()
            settingsTableViewController.profile = self.profile
            settingsTableViewController.tabManager = self.tabManager
            settingsTableViewController.settingsDelegate = self
            
            let controller = DismissableNavigationViewController(rootViewController: settingsTableViewController)
            controller.presentationController?.delegate = self

            // Wait to present VC in an async dispatch queue to prevent a case where dismissal
            // of this popover on iPad seems to block the presentation of the modal VC.
            DispatchQueue.main.async {
                self.present(controller, animated: true, completion: nil)
            }
        }

        section3 = [openSettings]

        if reversed {
            section1 = section1.reversed()
            section2 = section2.reversed()
        }
        actions = [
            UIMenu(options: .displayInline, children: section1),
            UIMenu(options: .displayInline, children: section2),
            UIMenu(options: .displayInline, children: section3)
        ]
        if urlBar.isBottomToolbar {
            actions.insert(UIDeferredMenuElement.uncached({ completion in
                completion([self.getPageActionMenu()])
            }), at: 0)
        }
        if reversed {
            actions = actions.reversed()
        }
        return UIMenu(children: actions)
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
        whatsNewAction = PhotonActionSheetItem(title: .WhatsNewString, iconString: "whatsnew", isEnabled: showBadgeForWhatsNew) { _, _ in
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
            PhotonActionSheetItem(title: .AppMenuPasswords, iconString: "key", iconType: .Image, iconAlignment: .left, isEnabled: true) { _, _ in
                guard let navController = self.navigationController else { return }
                let navigationHandler: ((_ url: URL?) -> Void) = { url in
                    UIWindow.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
                    self.openURLInNewTab(url)
                }
                            
                if AppAuthenticator.canAuthenticateDeviceOwner() {
                    if LoginOnboarding.shouldShow() {
                        let loginOnboardingViewController = LoginOnboardingViewController(shownFromAppMenu: true)
                        loginOnboardingViewController.doneHandler = {
                            loginOnboardingViewController.dismiss(animated: true)
                        }
                        
                        loginOnboardingViewController.proceedHandler = {
                            loginOnboardingViewController.dismiss(animated: true) {
                                LoginListViewController.create(authenticateInNavigationController: navController, profile: self.profile, settingsDelegate: self, webpageNavigationHandler: navigationHandler).uponQueue(.main) { loginsVC in
                                    guard let loginsVC = loginsVC else { return }
                                    loginsVC.shownFromAppMenu = true
                                    let navController = ThemedNavigationController(rootViewController: loginsVC)
                                    self.present(navController, animated: true)
                                    TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .logins)
                                }
                            }
                        }
                        
                        let navController = ThemedNavigationController(rootViewController: loginOnboardingViewController)
                        self.present(navController, animated: true)
                        
                        LoginOnboarding.setShown()
                    } else {
                        LoginListViewController.create(authenticateInNavigationController: navController, profile: self.profile, settingsDelegate: self, webpageNavigationHandler: navigationHandler).uponQueue(.main) { loginsVC in
                            guard let loginsVC = loginsVC else { return }
                            loginsVC.shownFromAppMenu = true
                            let navController = ThemedNavigationController(rootViewController: loginsVC)
                            self.present(navController, animated: true)
                            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .logins)
                        }
                    }
                } else {
                    let navController = ThemedNavigationController(rootViewController: DevicePasscodeRequiredViewController(shownFromAppMenu: true))
                    self.present(navController, animated: true)
                }
            }
        
        let section0 = getLibraryActions(vcDelegate: self)
        var section1 = getOtherPanelActions(vcDelegate: self)
        let section2 = getSettingsAction(vcDelegate: self)
        
        let optionalActions = [viewLogins, syncAction].compactMap { $0 }
        if !optionalActions.isEmpty {
            section1.append(contentsOf: optionalActions)
        }
        
        if let whatsNewAction = whatsNewAction {
            section1.append(whatsNewAction)
        }
        
        actions.append(contentsOf: [section0, section1, section2])

        presentSheetWith(actions: actions, on: self, from: button)
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

        let privateBrowsingMode = PhotonActionSheetItem(title: .privateBrowsingModeTitle, iconString: "nav-tabcounter", iconType: .TabsButton, tabCount: tabCount) { _, _ in
            action()
        }
        let normalBrowsingMode = PhotonActionSheetItem(title: .normalBrowsingModeTitle, iconString: "nav-tabcounter", iconType: .TabsButton, tabCount: tabCount) { _, _ in
            action()
        }

        if let tab = self.tabManager.selectedTab {
            return tab.isPrivate ? [normalBrowsingMode] : [privateBrowsingMode]
        }
        return [privateBrowsingMode]
    }

    func getMoreTabToolbarLongPressActions() -> [PhotonActionSheetItem] {
        let newTab = PhotonActionSheetItem(title: .NewTabTitle, iconString: "quick_action_new_tab", iconType: .Image) { _, _ in
            let shouldFocusLocationField = NewTabAccessors.getNewTabPage(self.profile.prefs) == .blankPage
            self.openBlankNewTab(focusLocationField: shouldFocusLocationField, isPrivate: false)
        }
        let newPrivateTab = PhotonActionSheetItem(title: .NewPrivateTabTitle, iconString: "quick_action_new_tab", iconType: .Image) { _, _ in
            let shouldFocusLocationField = NewTabAccessors.getNewTabPage(self.profile.prefs) == .blankPage
            self.openBlankNewTab(focusLocationField: shouldFocusLocationField, isPrivate: true)}
        let closeTab = PhotonActionSheetItem(title: .CloseTabTitle, iconString: "tab_close", iconType: .Image) { _, _ in
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

        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        presentSheetWith(actions: actions, on: self, from: button, suppressPopover: true)
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

