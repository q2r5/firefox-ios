/* This Source Code Form is subject to the terms of the Mozilla Public
* License, v. 2.0. If a copy of the MPL was not distributed with this
* file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared

enum NavigationItemLocation {
    case Left
    case Right
}

enum NavigationItemText {
    case Done
    case Close

    func localizedString() -> String {
        switch self {
        case .Done:
            return .SettingsSearchDoneButton
        case .Close:
            return .CloseButtonTitle
        }
    }
}

struct ViewControllerConsts {
    struct PreferredSize {
        static let IntroViewController = CGSize(width: 375, height: 667)
        static let UpdateViewController = CGSize(width: 375, height: 667)
        static let DBOnboardingViewController = CGSize(width: 624, height: 680)
    }
}

extension UIViewController {
    /// Determines whether, based on size class, the particular view controller should
    /// use iPad setup, as defined by design requirements. All iPad devices use a
    /// combination of either (.compact, .regular) or (.regular, .regular) size class
    /// for (width, height) for both fullscreen AND multi-tasking layouts. In some
    /// instances, we may wish to use iPhone layouts on the iPad when its size class
    /// is of type (.compact, .regular).
    var shouldUseiPadSetup: Bool {
        get {
            if UIDevice.current.userInterfaceIdiom == .pad {
                if traitCollection.horizontalSizeClass == .compact { return false }
                return true
            }

            return false
        }
    }

    /// This presents a View Controller with a bar button item that can be used to dismiss the VC
    /// - Parameters:
    ///     - navItemLocation: Define whether dismiss bar button item should be on the right or left of the navigation bar
    ///     - navItemText: Define whether bar button item text should be "Done" or "Close"
    ///     - vcBeingPresented: ViewController to present with this bar button item
    ///     - topTabsVisible: If tabs of browser should still be visible. iPad only.
    func presentThemedViewController(navItemLocation: NavigationItemLocation, navItemText: NavigationItemText, vcBeingPresented: UIViewController, topTabsVisible: Bool) {
        let vcToPresent = vcBeingPresented
        let buttonItem = UIBarButtonItem(title: navItemText.localizedString(), style: .plain, target: self, action: #selector(dismissVC))
        switch navItemLocation {
        case .Left:
            vcToPresent.navigationItem.leftBarButtonItem = buttonItem
        case .Right:
            vcToPresent.navigationItem.rightBarButtonItem = buttonItem
        }
        let navController: UINavigationController
        if #available(iOS 13.0, *) {
            navController = DismissableNavigationViewController(rootViewController: vcToPresent)
        } else {
            navController = ThemedNavigationController(rootViewController: vcToPresent)
        }
        if topTabsVisible {
            navController.preferredContentSize = CGSize(width: ViewControllerConsts.PreferredSize.IntroViewController.width, height: ViewControllerConsts.PreferredSize.IntroViewController.height)
            navController.modalPresentationStyle = .formSheet
        } else {
            navController.modalPresentationStyle = .pageSheet
        }
        self.present(navController, animated: true, completion: nil)
    }
    
    @objc func dismissVC() {
        self.dismiss(animated: true, completion: nil)
    }
}
 

