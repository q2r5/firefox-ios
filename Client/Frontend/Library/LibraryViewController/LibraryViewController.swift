// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import UIKit
import Storage

extension LibraryViewController: UIToolbarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .top
    }
}

class LibraryViewController: UIViewController {

    var viewModel: LibraryViewModel

    // Delegate
    weak var delegate: LibraryPanelDelegate?

    // Variables
    var onViewDismissed: (() -> Void)? = nil

    // Views

    // UI Elements
    lazy var librarySegmentControl: UISegmentedControl = {
        var librarySegmentControl: UISegmentedControl
        librarySegmentControl = UISegmentedControl(items: [UIImage(named: "library-bookmark")!,
                                                           UIImage(named: "library-history")!,
                                                           UIImage(named: "library-downloads")!,
                                                           UIImage(named: "library-readinglist")!])
        librarySegmentControl.accessibilityIdentifier = "librarySegmentControl"
        librarySegmentControl.selectedSegmentIndex = 1
        librarySegmentControl.addTarget(self, action: #selector(panelChanged), for: .valueChanged)
        librarySegmentControl.translatesAutoresizingMaskIntoConstraints = false
        return librarySegmentControl
    }()

    lazy var navigationToolbar: UIToolbar = .build { [weak self] toolbar in
        guard let self = self else { return }
        toolbar.delegate = self
        toolbar.setItems([UIBarButtonItem(customView: self.librarySegmentControl)], animated: false)
    }

    // MARK: - Initializers
    init(profile: Profile) {
        self.viewModel = LibraryViewModel(withProfile: profile)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - View setup & lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        applyTheme()
        setupNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    private func viewSetup() {
        if let appWindow = (UIApplication.shared.delegate?.window),
           let window = appWindow as UIWindow? {
            window.backgroundColor = .black
        }

        view.addSubview(navigationToolbar)

        NSLayoutConstraint.activate([
            navigationToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationToolbar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            navigationToolbar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            librarySegmentControl.widthAnchor.constraint(equalToConstant: 343),
            librarySegmentControl.heightAnchor.constraint(equalToConstant: CGFloat(ChronologicalTabsControllerUX.navigationMenuHeight)),
        ])

        if selectedPanel == nil {
            selectedPanel = .bookmarks
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        onViewDismissed?()
        onViewDismissed = nil
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(applyTheme), name: .DisplayThemeChanged, object: nil)
    }

    fileprivate func updateViewWithState() {
        updatePanelState()
    }

    fileprivate func updateTitle() {
        if let newTitle = selectedPanel?.title {
            navigationItem.title = newTitle
        }
    }

    fileprivate func shouldShowBottomToolbar() {
        switch viewModel.currentPanelState {
        case .bookmarks(state: let subState):
            if subState == .mainView {
                navigationController?.setToolbarHidden(true, animated: true)
            } else {
                navigationController?.setToolbarHidden(false, animated: true)
            }
        default:
            navigationController?.setToolbarHidden(true, animated: true)
        }
    }


    // MARK: - Panel
    var selectedPanel: LibraryPanelType? = nil {
        didSet {
            if oldValue == selectedPanel {
                // Prevent flicker, allocations, and disk access: avoid duplicate view controllers.
                return
            }

            hideCurrentPanel()

            if let index = selectedPanel?.rawValue {
                if index < viewModel.panelDescriptors.count {
                    viewModel.panelDescriptors[index].setup()
                    if let panel = self.viewModel.panelDescriptors[index].viewController {
                        let accessibilityLabel = self.viewModel.panelDescriptors[index].accessibilityLabel
                        setupLibraryPanel(panel, accessibilityLabel: accessibilityLabel)
                        self.showPanel(panel)
                    }
                }
            }
            librarySegmentControl.selectedSegmentIndex = selectedPanel!.rawValue
        }
    }

    func setupLibraryPanel(_ panel: UIViewController, accessibilityLabel: String) {
        (panel as? LibraryPanel)?.libraryPanelDelegate = self
        panel.view.accessibilityNavigationStyle = .combined
        panel.view.accessibilityLabel = accessibilityLabel
        panel.title = accessibilityLabel
        navigationItem.setLeftBarButton(panel.navigationItem.leftBarButtonItem, animated: false)
        navigationItem.setRightBarButton(panel.navigationItem.rightBarButtonItem, animated: false)
        navigationController?.navigationItem.setLeftBarButton(panel.navigationItem.leftBarButtonItem, animated: false)
        navigationController?.navigationItem.setRightBarButton(panel.navigationItem.rightBarButtonItem, animated: false) 
    }

    @objc func panelChanged() {
        switch librarySegmentControl.selectedSegmentIndex {
        case 0:
            selectedPanel = .bookmarks
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .libraryPanel, value: .bookmarksPanel)
        case 1:
            selectedPanel = .history
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .libraryPanel, value: .historyPanel)
        case 2:
            selectedPanel = .downloads
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .libraryPanel, value: .downloadsPanel)
        case 3:
            selectedPanel = .readingList
            TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .libraryPanel, value: .readingListPanel)
        default:
            return
        }
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

    fileprivate func showPanel(_ libraryPanel: UIViewController) {
        updateStateOnShowPanel(to: selectedPanel)
        addChild(libraryPanel)
        libraryPanel.beginAppearanceTransition(true, animated: false)
        view.addSubview(libraryPanel.view)
        view.bringSubviewToFront(navigationToolbar)
        libraryPanel.endAppearanceTransition()

        libraryPanel.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            libraryPanel.view.topAnchor.constraint(equalTo: navigationToolbar.bottomAnchor),
            libraryPanel.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            libraryPanel.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            libraryPanel.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        libraryPanel.didMove(toParent: self)

        if #available(iOS 15, *) {
            switch selectedPanel {
            case .bookmarks:
                let panel = libraryPanel as? BookmarksPanel
                setContentScrollView(panel?.tableView)
                navigationController?.setContentScrollView(panel?.tableView)
            case .history:
                let panel = libraryPanel as? HistoryPanel
                setContentScrollView(panel?.tableView)
                navigationController?.setContentScrollView(panel?.tableView)
            case .downloads:
                let panel = libraryPanel as? DownloadsPanel
                setContentScrollView(panel?.tableView)
                navigationController?.setContentScrollView(panel?.tableView)
            case .readingList:
                let panel = libraryPanel as? ReadingListPanel
                setContentScrollView(panel?.tableView)
                navigationController?.setContentScrollView(panel?.tableView)
            default: return
            }
        }
        updateTitle()
    }

    fileprivate func updatePanelState() {
        guard let panel = children.first as? UINavigationController else { return }

        if selectedPanel == .bookmarks {
            if panel.viewControllers.count > 1 {
                if viewModel.currentPanelState == .bookmarks(state: .mainView) {
                    viewModel.currentPanelState = .bookmarks(state: .inFolder)
                } else if viewModel.currentPanelState == .bookmarks(state: .inFolderEditMode),
                     let _ = panel.viewControllers.last as? BookmarkDetailPanel {
                    viewModel.currentPanelState = .bookmarks(state: .itemEditMode)
                }
            } else {
                viewModel.currentPanelState = .bookmarks(state: .mainView)
            }

        } else if selectedPanel == .history {
            if panel.viewControllers.count > 1 {
                if viewModel.currentPanelState == .history(state: .mainView) {
                    viewModel.currentPanelState = .history(state: .inFolder)
                }
            } else {
                viewModel.currentPanelState = .history(state: .mainView)
            }
        }
    }

    fileprivate func updateStateOnShowPanel(to panelType: LibraryPanelType?) {
        switch panelType {
        case .bookmarks:
            viewModel.currentPanelState = .bookmarks(state: .mainView)
        case .downloads:
            viewModel.currentPanelState = .downloads
        case .history:
            viewModel.currentPanelState = .history(state: .mainView)
        case .readingList:
            viewModel.currentPanelState = .readingList
        default:
            return
        }
    }
}

// MARK: UIAppearance
extension LibraryViewController: NotificationThemeable {
    @objc func applyTheme() {
        viewModel.panelDescriptors.forEach { item in
            (item.viewController as? NotificationThemeable)?.applyTheme()
        }        

        // There is an ANNOYING bar in the nav bar above the segment control. These are the
        // UIBarBackgroundShadowViews. We must set them to be clear images in order to
        // have a seamless nav bar, if embedding the segmented control.
        navigationController?.navigationBar.shadowImage = UIImage()

        view.backgroundColor = UIColor.theme.homePanel.panelBackground
        navigationController?.navigationBar.barTintColor = UIColor.theme.tabTray.toolbar
        navigationController?.navigationBar.tintColor = .systemBlue
        navigationController?.navigationBar.backgroundColor = UIColor.theme.tabTray.toolbar
        navigationController?.toolbar.barTintColor = UIColor.theme.tabTray.toolbar
        navigationController?.toolbar.tintColor = .systemBlue
        navigationToolbar.barTintColor = UIColor.theme.tabTray.toolbar
        navigationToolbar.tintColor = UIColor.theme.tabTray.toolbarButtonTint
        navigationToolbar.isTranslucent = false

        let theme = BuiltinThemeName(rawValue: LegacyThemeManager.instance.current.name) ?? .normal
        if theme == .dark {
            navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        } else {
            navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]
        }
        setNeedsStatusBarAppearanceUpdate()
    }
}
