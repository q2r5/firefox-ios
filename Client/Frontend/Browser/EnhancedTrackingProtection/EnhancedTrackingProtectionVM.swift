// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import Storage

class EnhancedTrackingProtectionMenuVM {

    // MARK: - Variables
    var tab: Tab
    var tabManager: TabManager
    var profile: Profile
    var onOpenSettingsTapped: (() -> Void)?

    var websiteTitle: String {
        return tab.url?.baseDomain ?? ""
    }

    var favIcon: URL? {
        if let icon = tab.displayFavicon, let url = URL(string: icon.url) { return url }
        return nil
    }

    var connectionStatusString: String {
        return connectionSecure ? .ProtectionStatusSecure : .ProtectionStatusNotSecure
    }

    var connectionStatusImage: UIImage {
        let insecureImageString = LegacyThemeManager.instance.currentName == .dark ? "lock_blocked_dark" : "lock_blocked"
        let image = connectionSecure ? UIImage(imageLiteralResourceName: "lock_verified").withRenderingMode(.alwaysTemplate) : UIImage(imageLiteralResourceName: insecureImageString)
        return image
    }

    var connectionSecure: Bool {
        return (tab.isSecureConnection)
            && (trust != nil && SecTrustEvaluateWithError(trust!, nil))
    }

    var isSiteETPEnabled: Bool {
        guard let blocker = tab.contentBlocker else { return true }

        switch blocker.status {
        case .noBlockedURLs, .blocking, .disabled: return true
        case .safelisted: return false
        }
    }

    var globalETPIsEnabled: Bool {
        return FirefoxTabContentBlocker.isTrackingProtectionEnabled(prefs: profile.prefs)
    }
    
    private var trust: SecTrust? {
        return tab.webView?.serverTrust
    }

    // MARK: - Initializers

    init(tab: Tab, profile: Profile, tabManager: TabManager) {
        self.tab = tab
        self.profile = profile
        self.tabManager = tabManager
    }

    // MARK: - Functions

    func getDetailsViewModel(withCachedImage cachedImage: UIImage?) -> EnhancedTrackingProtectionDetailsVM {
        return EnhancedTrackingProtectionDetailsVM(topLevelDomain: websiteTitle,
                                                   title: tab.displayTitle,
                                                   image: cachedImage ?? UIImage(imageLiteralResourceName: "defaultFavicon"),
                                                   URL: tab.url?.absoluteDisplayString ?? websiteTitle,
                                                   lockIcon: connectionStatusImage,
                                                   connectionStatusMessage: connectionStatusString,
                                                   connectionVerifier: verifyCertificate(),
                                                   connectionSecure: connectionSecure)
    }

    func toggleSiteSafelistStatus() {
        guard let currentURL = tab.url else { return }

        TelemetryWrapper.recordEvent(category: .action, method: .add, object: .trackingProtectionSafelist)
        ContentBlocker.shared.safelist(enable: tab.contentBlocker?.status != .safelisted, url: currentURL) {
            self.tab.reload()
        }
    }

    func verifyCertificate() -> String {
        guard let trust = tab.webView?.serverTrust,
              let certChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
                  return ""
              }
        
        var error = CFErrorCreate(nil, "" as CFErrorDomain, 0, nil)
        let validity = SecTrustEvaluateWithError(trust, &error)
        if !validity,
           let nsError = error as Error? as NSError?, // Workaround SR-3206
           let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return underlyingError.localizedDescription
        }


        var summaryString: String = ""
        if let cert = certChain.last,
           let summary = SecCertificateCopySubjectSummary(cert) {
            summaryString = summary as String
        }

        return String(format: .TPDetailsVerifiedBy, summaryString)
    }
}
