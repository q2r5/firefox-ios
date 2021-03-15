/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared
import FxAClient

extension DeviceType {
    func toDisplayImage() -> String {
        switch self {
        case .desktop:
            return "deviceTypeDesktop"
        case .mobile:
            return "deviceTypeMobile"
        case .tablet:
            return "deviceTypeTablet"
        default:
            return "deviceTypeMobile"
        }
    }
}

struct DevicePickerCellContentConfiguration: UIContentConfiguration, Hashable {
    var deviceType: DeviceType?
    var deviceName: String?

    func makeContentView() -> UIView & UIContentView {
        return DevicePickerCellContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> DevicePickerCellContentConfiguration {
        guard let state = state as? UICellConfigurationState else { return self }
        let updatedConfig = self
        if state.isSelected {
            
        }
        return updatedConfig
    }
}

class DevicePickerCellContentView: UIView, UIContentView {
    init(configuration: DevicePickerCellContentConfiguration) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupSubviews()
        apply(configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var configuration: UIContentConfiguration {
        get { appliedConfiguration }
        set {
            guard let newConfig = newValue as? DevicePickerCellContentConfiguration else { return }
            apply(configuration: newConfig)
        }
    }

    private var appliedConfiguration: DevicePickerCellContentConfiguration!

    private func apply(configuration: DevicePickerCellContentConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        let imageName: String
        switch appliedConfiguration.deviceType {
        case .desktop:
            imageName = "deviceTypeDesktop"
        case .mobile:
            imageName = "deviceTypeMobile"
        case .tablet:
            imageName = "deviceTypeTablet"
        default:
            imageName = "deviceTypeMobile"
        }
        imageView.image = UIImage.templateImageNamed(imageName)
        label.text = appliedConfiguration.deviceName
    }

    let imageView: UIImageView = .build { imageView in
        imageView.image = UIImage.templateImageNamed("deviceTypeMobile")
        imageView.tintColor = .label
    }

    let label: UILabel = .build { label in
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
    }

    private func setupSubviews() {
        addSubview(imageView)
        addSubview(label)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50)
        ])
    }
}

fileprivate extension UIConfigurationStateCustomKey {
    static let isChecked = UIConfigurationStateCustomKey("org.mozilla.firefox.DevicePickerCell.isChecked")
    static let device = UIConfigurationStateCustomKey("org.mozilla.firefox.DevicePickerCell.device")
}

public extension UICellConfigurationState {
    var isChecked: Bool {
        set { self[.isChecked] = newValue }
        get { return self[.isChecked] as? Bool ?? false }
    }
    
    var device: Device? {
        set { self[.device] = newValue }
        get { return self[.device] as? Device }
    }
}

class DevicePickerCell: UICollectionViewListCell {
    var device: Device? = nil
    var isChecked: Bool = false
    
    func updateWithDevice(_ newDevice: Device) {
        guard device != newDevice else { return }
        device = newDevice
        setNeedsUpdateConfiguration()
    }

    override var configurationState: UICellConfigurationState {
        var state = super.configurationState
        state.device = self.device
        state.isChecked = self.isChecked
        state.isSelected = false
        return state
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
//        var content = DevicePickerCellContentConfiguration().updated(for: state)
//        content.deviceName = state.device?.displayName
//        content.deviceType = state.device?.deviceType
        var content = self.defaultContentConfiguration()
        content.text = state.device?.displayName
        content.image = UIImage.templateImageNamed(state.device?.deviceType.toDisplayImage() ?? "deviceTypeMobile")
        content.imageToTextPadding = 18
        content.imageProperties.tintColor = .label
        content.imageProperties.reservedLayoutSize.height = 20
        content.imageProperties.reservedLayoutSize.width = 36
        content.textProperties.font = UIFont.systemFont(ofSize: 16)
        content.textProperties.numberOfLines = 2
        content.textProperties.lineBreakMode = .byWordWrapping
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 50)
        contentConfiguration = content
        isChecked = state.isChecked
        
        if isChecked {
            accessories = [.checkmark()]
        } else {
            accessories = []
        }
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attribs = super.preferredLayoutAttributesFitting(layoutAttributes)
        attribs.frame = CGRect(origin: .zero, size: CGSize(width: attribs.frame.width, height: 50))
        return attribs
    }
}
