/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared
import Storage
import Account
import FxAClient

fileprivate enum LoadingState {
    case loading
    case loaded
}

class NewDevicePickerViewController: UIViewController, DevicePicker {
    private var devices = [Device]()
    var profile: Profile?
    var profileNeedsShutdown = true
    var pickerDelegate: DevicePickerViewControllerDelegate?
    var newPickerDelegate: NewDevicePickerViewControllerDelegate?
    private var selectedIdentifiers = Set<String>() // Stores Device.id
    private var notification: NSObjectProtocol?
    private var loadingState = LoadingState.loading

    // ShareItem has been added as we are now using this class outside of the ShareTo extension to provide Share To functionality
    // And in this case we need to be able to store the item we are sharing as we may not have access to the
    // url later. Currently used only when sharing an item from the Tab Tray from a Preview Action.
    var shareItem: ShareItem?

    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Int, Device>!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = .SendToTitle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: .SendToCancelButton,
            style: .plain,
            target: self,
            action: #selector(cancel)
        )

        configureHierarchy()
        configureDataSource()

        notification = NotificationCenter.default.addObserver(forName: Notification.Name.constellationStateUpdate
        , object: nil, queue: .main) { [weak self ] _ in
            self?.loadList()
            self?.collectionView.refreshControl?.endRefreshing()
        }
    }

    deinit {
        if let obj = notification {
            NotificationCenter.default.removeObserver(obj)
        }
    }
}

extension NewDevicePickerViewController {
    private func configureHierarchy() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.refreshControl = UIRefreshControl()
        collectionView.refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { section, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: .plain)
            config.headerMode = .supplementary
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        }
    }
    
    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<DevicePickerCell, Device> { (cell, indexPath, item) in
            cell.updateWithDevice(item)
        }
        
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionReusableView>(elementKind: UICollectionView.elementKindSectionHeader){ (view, kind, indexPath) in
            let nameLabel = UILabel()
            view.addSubview(nameLabel)
            nameLabel.font = UIFont.systemFont(ofSize: 16)
            nameLabel.text = .SendToDevicesListTitle
            nameLabel.textColor = UIColor.Photon.Grey50
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                nameLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])

            view.frame.size.height = 50
        }

        dataSource = UICollectionViewDiffableDataSource<Int, Device>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, item: Device) -> UICollectionViewCell? in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
        }
        
        dataSource.supplementaryViewProvider = { (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }

        loadList(animated: false)
    }
}

extension NewDevicePickerViewController {
    fileprivate func ensureOpenProfile() -> Profile {
        // If we were not given a profile, open the default profile. This happens in case we are called from an app
        // extension. That also means that we need to shut down the profile, otherwise the app extension will be
        // terminated when it goes into the background.
        if let profile = self.profile {
            // Re-open the profile if it was shutdown. This happens when we run from an app extension, where we must
            // make sure that the profile is only open for brief moments of time.
            if profile.isShutdown && Bundle.main.bundleURL.pathExtension == "appex" {
                profile._reopen()
            }
            return profile
        }

        let profile = BrowserProfile(localName: "profile")
        self.profile = profile
        self.profileNeedsShutdown = true
        return profile
    }

    private func loadList(animated: Bool = true) {
        let profile = ensureOpenProfile()
        RustFirefoxAccounts.startup(prefs: profile.prefs).uponQueue(.main) { [weak self] accountManager in
            guard let state = accountManager.deviceConstellation()?.state() else {
                self?.loadingState = .loaded
                return
            }
            guard let self = self else { return }

            let currentIds = self.devices.map { $0.id }.sorted()
            let newIds = state.remoteDevices.map { $0.id }.sorted()
            if currentIds.count > 0, currentIds == newIds {
                return
            }

            self.devices = state.remoteDevices

            if self.devices.isEmpty {
                self.navigationItem.rightBarButtonItem = nil
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: .SendToSendButtonTitle, style: .done, target: self, action: #selector(self.send))
                self.navigationItem.rightBarButtonItem?.isEnabled = false
            }

            self.loadingState = .loaded
            
            var snapshot = NSDiffableDataSourceSnapshot<Int, Device>()
            snapshot.appendSections([0])
            snapshot.appendItems(self.devices)
            self.dataSource.apply(snapshot, animatingDifferences: animated)
        }
    }
    
    @objc func send() {
        var pickedItems = [Device]()
        for id in selectedIdentifiers {
            if let item = devices.find({ $0.id == id }) {
                pickedItems.append(item)
            }
        }

        self.newPickerDelegate?.devicePickerViewController(self, didPickDevices: pickedItems)

        // Replace the Send button with a loading indicator since it takes a while to sync
        // up our changes to the server.
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(width: 25, height: 25))
        loadingIndicator.color = UIColor.Photon.Grey60
        loadingIndicator.startAnimating()
        let customBarButton = UIBarButtonItem(customView: loadingIndicator)
        self.navigationItem.rightBarButtonItem = customBarButton
    }

    @objc func refresh() {
        RustFirefoxAccounts.shared.accountManager.peek()?.deviceConstellation()?.refreshState()
        if let refreshControl = self.collectionView.refreshControl {
            refreshControl.beginRefreshing()
            let height = -(refreshControl.bounds.size.height + (self.navigationController?.navigationBar.bounds.size.height ?? 0))
            self.collectionView.contentOffset = CGPoint(x: 0, y: height)
        }
    }

    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension NewDevicePickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? DevicePickerCell else { return }
        var state = cell.configurationState
        guard let id = state.device?.id else { return }
        if selectedIdentifiers.contains(id) {
            state.isChecked = false
            selectedIdentifiers.remove(id)
        } else {
            state.isChecked = true
            selectedIdentifiers.insert(id)
        }
        state.isSelected = false
        cell.updateConfiguration(using: state)
        navigationItem.rightBarButtonItem?.isEnabled = !selectedIdentifiers.isEmpty
    }
}
