// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import Storage
import AVFoundation
import XCGLogger
import MessageUI
import SDWebImage
import SwiftKeychainWrapper
import SyncTelemetry
import LocalAuthentication
import SyncTelemetry
import Sync
import CoreSpotlight
import UserNotifications
import Account
import Sentry

#if canImport(BackgroundTasks)
 import BackgroundTasks
#endif

private let log = Logger.browserLogger

let LatestAppVersionProfileKey = "latestAppVersion"
let AllowThirdPartyKeyboardsKey = "settings.allowThirdPartyKeyboards"
private let InitialPingSentKey = "initialPingSent"

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var tabTrayController: GridTabViewController!
    weak var profile: Profile?
    var tabManager: TabManager!
    var applicationCleanlyBackgrounded = true
    var shutdownWebServer: DispatchSourceTimer?
    var orientationLock = UIInterfaceOrientationMask.all
    weak var application: UIApplication?
    var launchOptions: [AnyHashable: Any]?

    var receivedURLs = [URL]()
    var telemetry: TelemetryWrapper?

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        //
        // Determine if the application cleanly exited last time it was used. We default to true in
        // case we have never done this before. Then check if the "ApplicationCleanlyBackgrounded" user
        // default exists and whether was properly set to true on app exit.
        //
        // Then we always set the user default to false. It will be set to true when we the application
        // is backgrounded.
        //

        self.applicationCleanlyBackgrounded = true

        let defaults = UserDefaults()
        if defaults.object(forKey: "ApplicationCleanlyBackgrounded") != nil {
            self.applicationCleanlyBackgrounded = defaults.bool(forKey: "ApplicationCleanlyBackgrounded")
        }
        defaults.set(false, forKey: "ApplicationCleanlyBackgrounded")

        // Hold references to willFinishLaunching parameters for delayed app launch
        self.application = application
        self.launchOptions = launchOptions

        // If the 'Save logs to Files app on next launch' toggle
        // is turned on in the Settings app, copy over old logs.
        if DebugSettingsBundleOptions.saveLogsToDocuments {
            Logger.copyPreviousLogsToDocuments()
        }

        return startApplication(application, withLaunchOptions: launchOptions)
    }

    func startApplication(_ application: UIApplication, withLaunchOptions launchOptions: [AnyHashable: Any]?) -> Bool {
        log.info("startApplication begin")

        // Need to get "settings.sendUsageData" this way so that Sentry can be initialized
        // before getting the Profile.
        let sendUsageData = NSUserDefaultsPrefs(prefix: "profile").boolForKey(AppConstants.PrefSendUsageData) ?? true
        Sentry.shared.setup(sendUsageData: sendUsageData)

        // Set the Firefox UA for browsing.
        setUserAgent()

        // Start the keyboard helper to monitor and cache keyboard state.
        KeyboardHelper.defaultHelper.startObserving()

        DynamicFontHelper.defaultHelper.startObserving()

        MenuHelper.defaultHelper.setItems()

        let logDate = Date()
        // Create a new sync log file on cold app launch. Note that this doesn't roll old logs.
        Logger.syncLogger.newLogWithDate(logDate)

        Logger.browserLogger.newLogWithDate(logDate)

        let profile = getProfile(application)

        telemetry = TelemetryWrapper(profile: profile)
        profile.prefs.setBool(true, forKey: "isColdLaunch")
        FeatureFlagsManager.shared.initializeFeatures(with: profile)
        ThemeManager.shared.updateProfile(with: profile)

        // Start intialzing the Nimbus SDK. This should be done after Glean
        // has been started.
        initializeExperiments()

        // Set up a web server that serves us static content. Do this early so that it is ready when the UI is presented.
        setUpWebServer(profile)

        let imageStore = DiskImageStore(files: profile.files, namespace: "TabManagerScreenshots", quality: UIConstants.ScreenshotQuality)

        self.tabManager = TabManager(profile: profile, imageStore: imageStore)
        self.tabTrayController = GridTabViewController(tabManager: self.tabManager, profile: profile)

        NotificationCenter.default.addObserver(forName: .FSReadingListAddReadingListItem, object: nil, queue: nil) { (notification) -> Void in
            if let userInfo = notification.userInfo, let url = userInfo["URL"] as? URL {
                let title = (userInfo["Title"] as? String) ?? ""
                profile.readingList.createRecordWithURL(url.absoluteString, title: title, addedBy: UIDevice.current.name)
            }
        }

        SystemUtils.onFirstRun()

        RustFirefoxAccounts.startup(prefs: profile.prefs).uponQueue(.main) { _ in
            print("RustFirefoxAccounts started")
        }
        log.info("startApplication end")
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // We have only five seconds here, so let's hope this doesn't take too long.
        profile?._shutdown()

        // Allow deinitializers to close our database connections.
        profile = nil
        tabManager = nil
    }

    /**
     * We maintain a weak reference to the profile so that we can pause timed
     * syncs when we're backgrounded.
     *
     * The long-lasting ref to the profile lives in BrowserViewController,
     * which we set in application:willFinishLaunchingWithOptions:.
     *
     * If that ever disappears, we won't be able to grab the profile to stop
     * syncing... but in that case the profile's deinit will take care of things.
     */
    func getProfile(_ application: UIApplication) -> Profile {
        if let profile = self.profile {
            return profile
        }
        let p = BrowserProfile(localName: "profile", syncDelegate: application.syncDelegate)
        self.profile = p
        return p
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        var shouldPerformAdditionalDelegateHandling = true

        // Now roll logs.
        DispatchQueue.global(qos: DispatchQoS.background.qosClass).async {
            Logger.syncLogger.deleteOldLogsDownToSizeLimit()
            Logger.browserLogger.deleteOldLogsDownToSizeLimit()
        }

        // If a shortcut was launched, display its information and take the appropriate action
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {

            QuickActions.sharedInstance.launchedShortcutItem = shortcutItem
            // This will block "performActionForShortcutItem:completionHandler" from being called.
            shouldPerformAdditionalDelegateHandling = false
        }

        // Force the ToolbarTextField in LTR mode - without this change the UITextField's clear
        // button will be in the incorrect position and overlap with the input text. Not clear if
        // that is an iOS bug or not.
        AutocompleteTextField.appearance().semanticContentAttribute = .forceLeftToRight

        pushNotificationSetup()

        // user research variable setup for Chron tabs user research
        _ = ChronTabsUserResearch()

        if let profile = self.profile {
            let persistedCurrentVersion = InstallType.persistedCurrentVersion()
            let introScreen = profile.prefs.intForKey(PrefsKeys.IntroSeen)
            // upgrade install - Intro screen shown & persisted current version does not match
            if introScreen != nil && persistedCurrentVersion != AppInfo.appVersion {
                InstallType.set(type: .upgrade)
                InstallType.updateCurrentVersion(version: AppInfo.appVersion)
            }

            // We need to check if the app is a clean install to use for
            // preventing the What's New URL from appearing.
            if introScreen == nil {
                // fresh install - Intro screen not yet shown
                InstallType.set(type: .fresh)
                InstallType.updateCurrentVersion(version: AppInfo.appVersion)
                // Profile setup
                profile.prefs.setString(AppInfo.appVersion, forKey: LatestAppVersionProfileKey)

            } else if profile.prefs.boolForKey(PrefsKeys.KeySecondRun) == nil {
                profile.prefs.setBool(true, forKey: PrefsKeys.KeySecondRun)
            }
        }


        BGTaskScheduler.shared.register(forTaskWithIdentifier: "org.mozilla.ios.sync.part1", using: DispatchQueue.global()) { task in
            guard self.profile?.hasSyncableAccount() ?? false else {
                self.shutdownProfileWhenNotActive(application)
                return
            }

            NSLog("background sync part 1") // NSLog to see in device console
            let collection = ["bookmarks", "history"]
            self.profile?.syncManager.syncNamedCollections(why: .backgrounded, names: collection).uponQueue(.main) { _ in
                task.setTaskCompleted(success: true)
                let request = BGProcessingTaskRequest(identifier: "org.mozilla.ios.sync.part2")
                request.earliestBeginDate = Date(timeIntervalSinceNow: 1)
                request.requiresNetworkConnectivity = true
                do {
                    try BGTaskScheduler.shared.submit(request)
                } catch {
                    NSLog(error.localizedDescription)
                }
            }
        }

        // Split up the sync tasks so each can get maximal time for a bg task.
        // This task runs after the bookmarks+history sync.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "org.mozilla.ios.sync.part2", using: DispatchQueue.global()) { task in
            NSLog("background sync part 2") // NSLog to see in device console
            let collection = ["tabs", "logins", "clients"]
            self.profile?.syncManager.syncNamedCollections(why: .backgrounded, names: collection).uponQueue(.main) { _ in
                self.shutdownProfileWhenNotActive(application)
                task.setTaskCompleted(success: true)
            }
        }
        updateSessionCount()

        return shouldPerformAdditionalDelegateHandling
    }

    func updateSessionCount() {
        var sessionCount: Int32 = 0

        // Get the session count from preferences
        if let currentSessionCount = profile?.prefs.intForKey(PrefsKeys.SessionCount) {
            sessionCount = currentSessionCount
        }
        // increase session count value
        profile?.prefs.setInt(sessionCount + 1, forKey: PrefsKeys.SessionCount)
    }

    // We sync in the foreground only, to avoid the possibility of runaway resource usage.
    // Eventually we'll sync in response to notifications.
    func applicationDidBecomeActive(_ application: UIApplication) {
        shutdownWebServer?.cancel()
        shutdownWebServer = nil

        //
        // We are back in the foreground, so set CleanlyBackgrounded to false so that we can detect that
        // the application was cleanly backgrounded later.
        //

        let defaults = UserDefaults()
        defaults.set(false, forKey: "ApplicationCleanlyBackgrounded")

        if let profile = self.profile {
            profile._reopen()

            if profile.prefs.boolForKey(PendingAccountDisconnectedKey) ?? false {
                profile.removeAccount()
            }

            profile.syncManager.applicationDidBecomeActive()

            setUpWebServer(profile)
        }

        BrowserViewController.foregroundBVC().firefoxHomeViewController?.reloadAll()

        // Resume file downloads.
        for session in application.openSessions {
            (session.scene?.delegate as? SceneDelegate)?.browserViewController.downloadQueue.resumeAll()
        }

        // handle quick actions is available
        let quickActions = QuickActions.sharedInstance
        if let shortcut = quickActions.launchedShortcutItem {
            // dispatch asynchronously so that BVC is all set up for handling new tabs
            // when we try and open them
            quickActions.handleShortCutItem(shortcut, withBrowserViewController: BrowserViewController.foregroundBVC())
            quickActions.launchedShortcutItem = nil
        }

        TelemetryWrapper.recordEvent(category: .action, method: .foreground, object: .app)

        // Delay these operations until after UIKit/UIApp init is complete
        // - loadQueuedTabs accesses the DB and shows up as a hot path in profiling
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // We could load these here, but then we have to futz with the tab counter
            // and making NSURLRequests.
            BrowserViewController.foregroundBVC().loadQueuedTabs(receivedURLs: self.receivedURLs)
            self.receivedURLs.removeAll()
            application.applicationIconBadgeNumber = 0
        }
        // Create fx favicon cache directory
        FaviconFetcher.createWebImageCacheDirectory()
        // update top sites widget
        updateTopSitesWidget()

        // Cleanup can be a heavy operation, take it out of the startup path. Instead check after a few seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.profile?.cleanupHistoryIfNeeded()
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        updateTopSitesWidget()
        UserDefaults.standard.setValue(Date(), forKey: "LastActiveTimestamp")
        self.profile?.prefs.setBool(false, forKey: "isColdLaunch")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        //
        // At this point we are happy to mark the app as CleanlyBackgrounded. If a crash happens in background
        // sync then that crash will still be reported. But we won't bother the user with the Restore Tabs
        // dialog. We don't have to because at this point we already saved the tab state properly.
        //

        let defaults = UserDefaults()
        defaults.set(true, forKey: "ApplicationCleanlyBackgrounded")

        // Pause file downloads.
        for session in application.openSessions {
            (session.scene?.delegate as? SceneDelegate)?.browserViewController.downloadQueue.pauseAll()
        }

        TelemetryWrapper.recordEvent(category: .action, method: .background, object: .app)

        let singleShotTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        // 2 seconds is ample for a localhost request to be completed by GCDWebServer. <500ms is expected on newer devices.
        singleShotTimer.schedule(deadline: .now() + 2.0, repeating: .never)
        singleShotTimer.setEventHandler {
            WebServer.sharedInstance.server.stop()
            self.shutdownWebServer = nil
        }
        singleShotTimer.resume()
        shutdownWebServer = singleShotTimer

        scheduleBGSync(application: application)

        tabManager.preserveTabs()
    }

    private func updateTopSitesWidget() {
        // Since we only need the topSites data in the archiver, let's write it
        // only if iOS 14 is available.
        if #available(iOS 14.0, *) {
            guard let profile = profile else { return }
            TopSitesHandler.writeWidgetKitTopSites(profile: profile)
        }
    }

    fileprivate func shutdownProfileWhenNotActive(_ application: UIApplication) {
        // Only shutdown the profile if we are not in the foreground
        guard application.applicationState != .active else {
            return
        }

        profile?._shutdown()
    }

    fileprivate func setUpWebServer(_ profile: Profile) {
        let server = WebServer.sharedInstance
        guard !server.server.isRunning else { return }

        ReaderModeHandlers.register(server, profile: profile)

        let responders: [(String, InternalSchemeResponse)] =
            [ (AboutHomeHandler.path, AboutHomeHandler()),
              (AboutLicenseHandler.path, AboutLicenseHandler()),
              (SessionRestoreHandler.path, SessionRestoreHandler()),
              (ErrorPageHandler.path, ErrorPageHandler())]
        responders.forEach { (path, responder) in
            InternalSchemeHandler.responders[path] = responder
        }

        if AppConstants.IsRunningTest || AppConstants.IsRunningPerfTest {
            registerHandlersForTestMethods(server: server.server)
        }

        // Bug 1223009 was an issue whereby CGDWebserver crashed when moving to a background task
        // catching and handling the error seemed to fix things, but we're not sure why.
        // Either way, not implicitly unwrapping a try is not a great way of doing things
        // so this is better anyway.
        do {
            try server.start()
        } catch let err as NSError {
            print("Error: Unable to start WebServer \(err)")
        }
    }

    fileprivate func setUserAgent() {
        let firefoxUA = UserAgent.getUserAgent()

        // Set the UA for WKWebView (via defaults), the favicon fetcher, and the image loader.
        // This only needs to be done once per runtime. Note that we use defaults here that are
        // readable from extensions, so they can just use the cached identifier.

        SDWebImageDownloader.shared.setValue(firefoxUA, forHTTPHeaderField: "User-Agent")
        //SDWebImage is setting accept headers that report we support webp. We don't
        SDWebImageDownloader.shared.setValue("image/*;q=0.8", forHTTPHeaderField: "Accept")

        // Record the user agent for use by search suggestion clients.
        SearchViewController.userAgent = firefoxUA

        // Some sites will only serve HTML that points to .ico files.
        // The FaviconFetcher is explicitly for getting high-res icons, so use the desktop user agent.
        FaviconFetcher.userAgent = UserAgent.desktopUserAgent()
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handledShortCutItem = QuickActions.sharedInstance.handleShortCutItem(shortcutItem, withBrowserViewController: BrowserViewController.foregroundBVC())

        completionHandler(handledShortCutItem)
    }

    private func scheduleBGSync(application: UIApplication) {
        if profile?.syncManager.isSyncing ?? false {
            // If syncing, create a bg task because _shutdown() is blocking and might take a few seconds to complete
            var taskId = UIBackgroundTaskIdentifier(rawValue: 0)
            taskId = application.beginBackgroundTask(expirationHandler: {
                self.shutdownProfileWhenNotActive(application)
                application.endBackgroundTask(taskId)
            })

            DispatchQueue.main.async {
                self.shutdownProfileWhenNotActive(application)
                application.endBackgroundTask(taskId)
            }
        } else {
            // Blocking call, however without sync running it should be instantaneous
            profile?._shutdown()

            let request = BGProcessingTaskRequest(identifier: "org.mozilla.ios.sync.part1")
            request.earliestBeginDate = Date(timeIntervalSinceNow: 1)
            request.requiresNetworkConnectivity = true
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                NSLog(error.localizedDescription)
            }
        }
    }
}

// MARK: - Root View Controller Animations
extension AppDelegate: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        switch operation {
        case .push:
            return BrowserToTrayAnimator()
        case .pop:
            return TrayToBrowserAnimator()
        default:
            return nil
        }
    }
}

extension AppDelegate: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Dismiss the view controller and start the app up
        controller.dismiss(animated: true, completion: nil)
        _ = startApplication(application!, withLaunchOptions: self.launchOptions)
    }
}

extension UIApplication {
    static var isInPrivateMode: Bool {
        return BrowserViewController.foregroundBVC().tabManager.selectedTab?.isPrivate ?? false
    }
}

extension AppDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// Orientation lock for views that use new modal presenter
extension AppDelegate {
    /// ref: https://stackoverflow.com/questions/28938660/
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return self.orientationLock
    }

    struct AppUtility {
        static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
            if let delegate = UIApplication.shared.delegate as? AppDelegate {
                delegate.orientationLock = orientation
            }
        }

        static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
            self.lockOrientation(orientation)
            UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
        }
    }
}

extension AppDelegate {
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        guard builder.system == .main else { return }
        let newPrivateTab = UICommandAlternate(title: .NewPrivateTabTitle, action: #selector(BrowserViewController.newPrivateTabKeyCommand), modifierFlags: [.shift])

        let fileMenu = UIMenu(options: .displayInline, children: [
            UIKeyCommand(title: .NewTabTitle, action: #selector(BrowserViewController.newTabKeyCommand), input: "t", modifierFlags: .command, alternates: [newPrivateTab], discoverabilityTitle: .NewTabTitle),
            UIKeyCommand(title: .NewPrivateTabTitle, action: #selector(BrowserViewController.newPrivateTabKeyCommand), input: "p", modifierFlags: [.command, .shift], discoverabilityTitle: .NewPrivateTabTitle),
            UIKeyCommand(title: .CloseTabTitle, action: #selector(BrowserViewController.closeTabKeyCommand), input: "w", modifierFlags: .command, discoverabilityTitle: .CloseTabTitle),
            UIKeyCommand(title: .ReloadPageTitle, action: #selector(BrowserViewController.reloadTabKeyCommand), input: "r", modifierFlags: .command, discoverabilityTitle: .ReloadPageTitle),
            UIKeyCommand(title: .BackTitle, action: #selector(BrowserViewController.goBackKeyCommand), input: "[", modifierFlags: .command, discoverabilityTitle: .BackTitle),
            UIKeyCommand(title: .ForwardTitle, action: #selector(BrowserViewController.goForwardKeyCommand), input: "]", modifierFlags: .command, discoverabilityTitle: .ForwardTitle)
        ])

        let editMenu = UIMenu(options: .displayInline, children: [
            UIKeyCommand(title: .FindTitle, action: #selector(BrowserViewController.findInPageKeyCommand), input: "f", modifierFlags: .command, discoverabilityTitle: .FindTitle),
        ])

        let viewMenu = UIMenu(options: .displayInline, children: [
            UIKeyCommand(title: .ShowNextTabTitle, action: #selector(BrowserViewController.nextTabKeyCommand), input: "\t", modifierFlags: .control, discoverabilityTitle: .ShowNextTabTitle),
            UIKeyCommand(title: .ShowPreviousTabTitle, action: #selector(BrowserViewController.previousTabKeyCommand), input: "\t", modifierFlags: [.control, .shift], discoverabilityTitle: .ShowPreviousTabTitle),
            UIKeyCommand(title: .ShowTabTrayFromTabKeyCodeTitle, action: #selector(BrowserViewController.showTabTrayKeyCommand), input: "\t", modifierFlags: [.command, .alternate], discoverabilityTitle: .ShowTabTrayFromTabKeyCodeTitle)
        ])

        builder.insertChild(fileMenu, atStartOfMenu: .file)
        builder.insertChild(editMenu, atStartOfMenu: .edit)
        builder.insertChild(viewMenu, atStartOfMenu: .view)
    }
}
