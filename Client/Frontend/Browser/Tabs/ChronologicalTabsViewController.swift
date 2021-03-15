// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Shared
import UIKit

protocol ChronologicalTabsDelegate: AnyObject {
    func closeTab(forIndex index: IndexPath)
    func closeTabTray()
}

struct ChronologicalTabsControllerUX {
    static let cornerRadius = CGFloat(4.0)
    static let screenshotMarginLeftRight = CGFloat(20.0)
    static let screenshotMarginTopBottom = CGFloat(6.0)
    static let textMarginTopBottom = CGFloat(18.0)
    static let navigationMenuHeight = CGFloat(32.0)
    static let backgroundColor = UIColor.Photon.Grey10
}

class ChronologicalTabsViewController: UIViewController, NotificationThemeable, TabTrayViewDelegate {
    weak var delegate: TabTrayDelegate?
    // View Model
    lazy var viewModel = TabTrayV2ViewModel(viewController: self)
    let profile: Profile
    private var bottomSheetVC: BottomSheetViewController?

    // Views
    lazy var tableView: UITableView = .build { tableView in
        tableView.tableFooterView = UIView()
        tableView.register(TabTableViewCell.self, forCellReuseIdentifier: TabTableViewCell.identifier)
        tableView.register(TabTableViewHeader.self, forHeaderFooterViewReuseIdentifier: self.sectionHeaderIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.sectionHeaderTopPadding = 0
    }

    lazy var emptyPrivateTabsView: EmptyPrivateTabsView = .build { emptyView in
        emptyView.learnMoreButton.addTarget(self, action: #selector(self.didTapLearnMore), for: .touchUpInside)
    }

    lazy var editToolbarItems: [UIBarButtonItem] = {
        let bottomToolbar = [
            UIBarButtonItem(title: .ShareContextMenuTitle, style: .plain, target: self, action: #selector(didTapToolbarShareSelected)),
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(image: UIImage.templateImageNamed("action_delete"), style: .plain, target: self, action: #selector(didTapToolbarDeleteSelected))
        ]
        return bottomToolbar
    }()

    lazy var moreButton: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle.fill"), style: .plain, target: self, action: #selector(didTapToolbarMore))
    }()

    // Constants
    fileprivate let sectionHeaderIdentifier = "SectionHeader"

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    init(tabTrayDelegate: TabTrayDelegate? = nil, profile: Profile) {
        self.delegate = tabTrayDelegate
        self.profile = profile
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        viewSetup()
        applyTheme()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.addPrivateTab()
    }

    private func viewSetup() {
        parent?.navigationItem.leftBarButtonItem = UIBarButtonItem(title: .CloseButtonTitle, style: .done, target: self, action: #selector(dismissTabTray))
        parent?.navigationItem.rightBarButtonItem = moreButton
        // Add Subviews
        view.addSubview(tableView)
        view.addSubview(emptyPrivateTabsView)
        viewModel.updateTabs()
        // Constraints
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyPrivateTabsView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            emptyPrivateTabsView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            emptyPrivateTabsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyPrivateTabsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        emptyPrivateTabsView.isHidden = true

        bottomSheetVC = BottomSheetViewController()
        bottomSheetVC?.delegate = self
        self.addChild(bottomSheetVC!)
        self.view.addSubview(bottomSheetVC!.view)
    }

    func shouldShowPrivateTabsView() {
        emptyPrivateTabsView.isHidden = !viewModel.shouldShowPrivateView
    }

    func applyTheme() {
        tableView.backgroundColor = UIColor.systemGroupedBackground
        emptyPrivateTabsView.titleLabel.textColor = UIColor.label
        emptyPrivateTabsView.descriptionLabel.textColor = UIColor.secondaryLabel

        setNeedsStatusBarAppearanceUpdate()
        bottomSheetVC?.applyTheme()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.view.setNeedsLayout()
        self.view.layoutIfNeeded()
        tableView.reloadData()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if LegacyThemeManager.instance.systemThemeIsOn {
            tableView.reloadData()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        viewModel.selectedTabs = []
        if editing {
            parent?.navigationItem.setRightBarButton(editButtonItem, animated: animated)
            parent?.setToolbarItems(editToolbarItems, animated: animated)
        } else {
            parent?.navigationItem.setRightBarButton(moreButton, animated: animated)
            parent?.setToolbarItems((self.parent as? TabTrayViewController)?.bottomToolbarItems, animated: animated)
        }
    }
}

// MARK: - Toolbar Actions
extension ChronologicalTabsViewController {
    func performToolbarAction(_ action: TabTrayViewAction, sender: UIBarButtonItem) {
        switch action {
        case .addTab:
            didTapToolbarAddTab()
        case .deleteTab:
            if isEditing {
                didTapToolbarDeleteSelected(sender)
            }
            didTapToolbarDelete(sender)
        }
    }

    func didTapToolbarAddTab() {
        viewModel.addTab()
        dismissTabTray()
        TelemetryWrapper.recordEvent(category: .action, method: .add, object: .tab, value: viewModel.isInPrivateMode ? .privateTab : .normalTab)
    }

    func didTapToolbarDelete(_ sender: UIBarButtonItem) {
        let controller = AlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: .AppMenuCloseAllTabsTitleString,
                                           style: .default,
                                           handler: { _ in self.viewModel.closeTabsForCurrentTray() }),
                             accessibilityIdentifier: AccessibilityIdentifiers.TabTray.deleteCloseAllButton)
        controller.addAction(UIAlertAction(title: .CancelString,
                                           style: .cancel,
                                           handler: nil),
                             accessibilityIdentifier: AccessibilityIdentifiers.TabTray.deleteCancelButton)
        controller.popoverPresentationController?.barButtonItem = sender
        present(controller, animated: true, completion: nil)
        TelemetryWrapper.recordEvent(category: .action, method: .deleteAll, object: .tab, value: viewModel.isInPrivateMode ? .privateTab : .normalTab)
    }

    @objc func didTapToolbarDeleteSelected(_ sender: UIBarButtonItem) {
        let controller = AlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Close Selected", style: .default, handler: { _ in self.viewModel.removeSelectedTabs() }), accessibilityIdentifier: "TabTrayController.deleteButton.closeSelected")
        controller.addAction(UIAlertAction(title: .CancelString, style: .cancel, handler: nil), accessibilityIdentifier: AccessibilityIdentifiers.TabTray.deleteCancelButton)
        controller.popoverPresentationController?.barButtonItem = sender
        present(controller, animated: true, completion: nil)
    }

    @objc func didTapToolbarShareSelected(_ sender: UIBarButtonItem) {
        var shareURLs = [URL]()
        for tab in viewModel.selectedTabs {
            guard let url = tab.url else { return }
            shareURLs.append(url)
        }
        guard !shareURLs.isEmpty else { return }
        let controller = UIActivityViewController(activityItems: shareURLs, applicationActivities: nil)

        if let popoverPresentationController = controller.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = view.bounds
            popoverPresentationController.permittedArrowDirections = .up
            popoverPresentationController.delegate = self
        }

        present(controller, animated: true, completion: nil)
    }
}

// MARK: Datastore
extension ChronologicalTabsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        shouldShowPrivateTabsView()
        return viewModel.numberOfSections()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRowsInSection(section: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TabTableViewCell.identifier, for: indexPath)
        guard let tabCell = cell as? TabTableViewCell else { return cell }
        tabCell.closeButton.addTarget(self, action: #selector(onCloseButton(_ :)), for: .touchUpInside)
        tabCell.separatorInset = UIEdgeInsets.zero

        viewModel.configure(cell: tabCell, for: indexPath)
        tabCell.remakeTitleConstraint()
        return tabCell
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let bvc = BrowserViewController.foregroundBVC()
        guard let tab = viewModel.getTab(forIndex: indexPath) else {
            return nil
        }

        let tabVC = TabPeekViewController(tab: tab, delegate: viewModel)

        if let profile = bvc.profile as? BrowserProfile {
            tabVC.setState(withProfile: profile, clientPickerDelegate: bvc)
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: { return tabVC }, actionProvider: tabVC.tabTrayActions(defaultActions:))
    }

    @objc func onCloseButton(_ sender: UIButton) {
        let buttonPosition = sender.convert(CGPoint(), to: tableView)
        if let indexPath = tableView.indexPathForRow(at: buttonPosition) {
            viewModel.removeTab(forIndex: indexPath)
        }
    }

    @objc func didTapToolbarMore(_ sender: UIBarButtonItem) {
        let controller = AlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Select Tabs", style: .default, handler: { _ in
            self.setEditing(true, animated: true)
        }))
        controller.addAction(UIAlertAction(title: "Close \(self.viewModel.getTabs().count) Tabs", style: .destructive, handler: { _ in
            self.didTapToolbarDelete(sender)
        }))
        controller.addAction(UIAlertAction(title: .CancelString, style: .cancel, handler: nil), accessibilityIdentifier: "TabTrayController.moreButton.cancel")
        controller.popoverPresentationController?.barButtonItem = sender
        present(controller, animated: true, completion: nil)
    }

    func didTogglePrivateMode(_ togglePrivateModeOn: Bool) {
        // Toggle private mode
        viewModel.togglePrivateMode(togglePrivateModeOn)

        // Reload data
        viewModel.updateTabs()
    }

    func hideDisplayedTabs(completion: @escaping () -> Void) {
           let cells = tableView.visibleCells

           UIView.animate(withDuration: 0.2,
                          animations: {
                               cells.forEach {
                                   $0.alpha = 0
                               }
                           }, completion: { _ in
                               cells.forEach {
                                   $0.alpha = 1
                                   $0.isHidden = true
                               }
                               completion()
                           })
       }

    @objc func dismissTabTray() {
        // We check if there is private tab then add one if user dismisses
        viewModel.addPrivateTab()
        viewModel.selectedTabs = []
        navigationController?.dismiss(animated: true, completion: nil)
        TelemetryWrapper.recordEvent(category: .action, method: .close, object: .tabTray)
    }

    @objc func didTapLearnMore() {
        if let privateBrowsingUrl = SupportUtils.URLForTopic("private-browsing-ios") {
            let learnMoreRequest = URLRequest(url: privateBrowsingUrl)
            viewModel.addTab(learnMoreRequest)
        }
        self.dismissTabTray()
    }
}

extension ChronologicalTabsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel.didSelectRowAt(index: indexPath)
        if !isEditing {
            dismissTabTray()
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: sectionHeaderIdentifier) as? TabTableViewHeader, viewModel.numberOfRowsInSection(section: section) != 0 else {
            return nil
        }
        headerView.titleLabel.text = viewModel.getSectionDateHeader(section)
        if #available(iOS 14, *) {
            headerView.moreButton.menu = UIMenu(children: [
                UIAction(title: "Share All") { _ in
                },
                UIAction(title: "Close All", attributes: .destructive) { _ in
                    self.viewModel.removeTabs(forSection: section)
                }
            ])
        }
        headerView.applyTheme()
        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == TabSection(rawValue: section)?.rawValue && viewModel.numberOfRowsInSection(section: section) != 0 ? UITableView.automaticDimension : 0
    }
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let share = UIContextualAction(style: .normal, title: .ShareContextMenuTitle) { (_, _, _) in
            guard let tab = self.viewModel.getTab(forIndex: indexPath), let url = tab.url else { return }
            self.presentActivityViewController(url, tab: tab)
        }

        let more = UIContextualAction(style: .normal, title: .PocketMoreStoriesText) { (_, _, _) in
            // Bottom toolbar
            self.parent?.navigationController?.isToolbarHidden = true

            let moreViewController = TabMoreMenuViewController(tabTrayDelegate: self.delegate, tab: self.viewModel.getTab(forIndex: indexPath), index: indexPath, profile: self.profile)
            moreViewController.chronTabsTrayDelegate = self
            moreViewController.bottomSheetDelegate = self
            if #available(iOS 15, *) {
                if let sheet = moreViewController.presentationController as? UISheetPresentationController /*moreViewController.sheetPresentationController*/ {
                    sheet.detents = [.medium(), .large()]
                }
                self.present(moreViewController, animated: true, completion: nil)
            } else {
                self.bottomSheetVC?.containerViewController = moreViewController
                self.bottomSheetVC?.showView()
            }
        }

        let delete = UIContextualAction(style: .destructive, title: .CloseButtonTitle) { (_, _, _) in
            self.viewModel.removeTab(forIndex: indexPath)
        }

        share.backgroundColor = UIColor.systemOrange
        share.image = UIImage.templateImageNamed("menu-Send")?.withTintColor(.white)
        more.image = UIImage.templateImageNamed("menu-More-Options")?.withTintColor(.white)
        delete.image = UIImage.templateImageNamed("menu-CloseTabs")?.withTintColor(.white)

        return UISwipeActionsConfiguration(actions: [delete, share, more])
    }
}

extension ChronologicalTabsViewController: UIPopoverPresentationControllerDelegate {
    func presentActivityViewController(_ url: URL, tab: Tab? = nil) {
        let helper = ShareExtensionHelper(url: url, tab: tab)

        let controller = helper.createActivityViewController({ _,_ in })

        if let popoverPresentationController = controller.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = view.bounds
            popoverPresentationController.permittedArrowDirections = .up
            popoverPresentationController.delegate = self
        }

        present(controller, animated: true, completion: nil)
    }
}

extension ChronologicalTabsViewController: UIToolbarDelegate {
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }
}

extension ChronologicalTabsViewController: ChronologicalTabsDelegate {
    func closeTab(forIndex index: IndexPath) {
        viewModel.removeTab(forIndex: index)
    }
    func closeTabTray() {
        dismissTabTray()
    }
}

extension ChronologicalTabsViewController: BottomSheetDelegate {
    func showBottomToolbar() {
        // Show bottom toolbar when we hide bottom sheet
        parent?.navigationController?.isToolbarHidden = false
    }
    func closeBottomSheet() {
        showBottomToolbar()
        self.bottomSheetVC?.hideView(shouldAnimate: true)
    }
}

extension ChronologicalTabsViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        TelemetryWrapper.recordEvent(category: .action, method: .close, object: .tabTray)
    }
}
