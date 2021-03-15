/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Shared
import SnapKit
import UIKit
import Storage

private enum LibraryViewControllerUX {
    // Height of the top panel switcher button toolbar.
    static let ButtonContainerHeight: CGFloat = 50
}

class LibraryViewController: UIViewController {
    let profile: Profile
    let panelDescriptors: [LibraryPanelDescriptor]

    weak var delegate: LibraryPanelDelegate?

    fileprivate lazy var navigationMenu: UISegmentedControl = {
        let navigationMenu = UISegmentedControl()
        navigationMenu.accessibilityLabel = .LibraryPanelChooserAccessibilityLabel
        navigationMenu.addTarget(self, action: #selector(panelChanged), for: .valueChanged)
        return navigationMenu
    }()

    lazy var navigationToolbar: UIToolbar = {
        let toolbar = UIToolbar()
        toolbar.delegate = self
        toolbar.setItems([UIBarButtonItem(customView: navigationMenu)], animated: false)
        return toolbar
    }()

    fileprivate var controllerContainerView = UIView()

    fileprivate var buttonTintColor: UIColor?
    fileprivate var buttonSelectedTintColor: UIColor?

    init(profile: Profile) {
        self.profile = profile

        self.panelDescriptors = LibraryPanels(profile: profile).enabledPanels

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let window = (UIApplication.shared.delegate?.window)! as UIWindow? {
            window.backgroundColor = .black
        }

        view.addSubview(navigationToolbar)
        view.addSubview(controllerContainerView)
        
        navigationController?.navigationBar.shadowImage = UIImage()
        if #available(iOS 13.0, *) { } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: Strings.CloseButtonTitle, style: .done, target: self, action: #selector(dismissVC))
        }
        
        navigationToolbar.snp.makeConstraints { make in
            make.left.right.equalTo(view)
            make.top.equalTo(view.safeArea.top)
        }

        controllerContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(view)
            make.top.equalTo(navigationToolbar.snp.bottom)
        }

        updateSegments()
        applyTheme()
        if selectedPanel == nil {
            selectedPanel = .bookmarks
            navigationMenu.selectedSegmentIndex = 0
        }
    }

    var selectedPanel: LibraryPanelType? = nil {
        didSet {
            if oldValue == selectedPanel {
                // Prevent flicker, allocations, and disk access: avoid duplicate view controllers.
                return
            }

            navigationController?.popToRootViewController(animated: true)

            if let index = selectedPanel?.rawValue {
                if index < panelDescriptors.count {
                    panelDescriptors[index].setup()
                    if let panel = self.panelDescriptors[index].viewController {
                        let accessibilityLabel = self.panelDescriptors[index].accessibilityLabel
                        setupLibraryPanel(panel, accessibilityLabel: accessibilityLabel)
                        self.navigationItem.title = accessibilityLabel
                        self.showPanel(panel)
                    }
                }
            }
        }
    }

    func setupLibraryPanel(_ panel: UIViewController, accessibilityLabel: String) {
        (panel as? LibraryPanel)?.libraryPanelDelegate = self
        panel.view.accessibilityNavigationStyle = .combined
        panel.view.accessibilityLabel = accessibilityLabel
        panel.title = accessibilityLabel
        panel.navigationItem.title = accessibilityLabel
    }

    fileprivate func hideCurrentPanel() {
        if let panel = children.first {
            panel.willMove(toParent: nil)
            panel.beginAppearanceTransition(false, animated: false)
            panel.view.removeFromSuperview()
            panel.endAppearanceTransition()
            panel.removeFromParent()
        }
    }

    fileprivate func showPanel(_ panel: UIViewController) {
        addChild(panel)
        panel.beginAppearanceTransition(true, animated: false)
        controllerContainerView.addSubview(panel.view)
        panel.endAppearanceTransition()
        panel.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        panel.didMove(toParent: self)
    }

    @objc func panelChanged() {
        let index = navigationMenu.selectedSegmentIndex
        let newSelectedPanel = LibraryPanelType(rawValue: index)

        // If we're already on the selected panel and the user has
        // tapped for a second time, pop it to the root view controller.
        if newSelectedPanel == selectedPanel {
            let panel = self.panelDescriptors[safe: index]?.navigationController
            panel?.popToRootViewController(animated: true)
        }

        selectedPanel = newSelectedPanel
        if selectedPanel == .bookmarks {
            TelemetryWrapper.recordEvent(category: .action, method: .view, object: .bookmarksPanel, value: .homePanelTabButton)
        } else if selectedPanel == .downloads {
            TelemetryWrapper.recordEvent(category: .action, method: .view, object: .downloadsPanel, value: .homePanelTabButton)
        }
    }

    fileprivate func updateSegments() {
        for panel in panelDescriptors {
            navigationMenu.insertSegment(with: UIImage.templateImageNamed(panel.imageName), at: navigationMenu.numberOfSegments, animated: false)
        }
    }
}

// MARK: UIAppearance
extension LibraryViewController: Themeable {
    func applyTheme() {
        panelDescriptors.forEach { item in
            (item.viewController as? Themeable)?.applyTheme()
        }
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = ThemeManager.instance.userInterfaceStyle
            view.backgroundColor = UIColor.systemGroupedBackground
            navigationController?.navigationBar.tintColor = UIColor.label
            navigationController?.toolbar.tintColor = UIColor.label
            navigationItem.rightBarButtonItem?.tintColor = UIColor.label
        } else {
            view.backgroundColor = UIColor.theme.homePanel.toolbarBackground
            navigationController?.navigationBar.barTintColor = UIColor.theme.tabTray.toolbar
            navigationController?.navigationBar.tintColor = UIColor.theme.tabTray.toolbarButtonTint
            navigationController?.toolbar.barTintColor = UIColor.theme.tabTray.toolbar
            navigationController?.toolbar.tintColor = UIColor.theme.tabTray.toolbarButtonTint
            navigationItem.rightBarButtonItem?.tintColor = UIColor.theme.tabTray.toolbarButtonTint
            navigationToolbar.barTintColor = UIColor.theme.tabTray.toolbar
            navigationToolbar.tintColor = UIColor.theme.tabTray.toolbarButtonTint
        }
        setNeedsStatusBarAppearanceUpdate()
    }
}

extension LibraryViewController: UIToolbarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}
