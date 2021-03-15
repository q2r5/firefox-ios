/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import SnapKit
import Shared

struct DevicePickerCellContentConfiguration: UIContentConfiguration, Hashable {
    var deviceType: ClientType?
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
        imageView.image = UIImage.templateImageNamed(appliedConfiguration.deviceType?.rawValue ?? "deviceTypeMobile")
        label.text = appliedConfiguration.deviceName
    }

    let imageView = UIImageView()
    let label = UILabel()

    private func setupSubviews() {
        addSubview(imageView)
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.snp.makeConstraints { make in
            make.leading.equalTo(self.snp.leadingMargin)
            make.centerY.equalToSuperview()
        }

        addSubview(label)
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-50)
        }
    }
}

fileprivate extension UIConfigurationStateCustomKey {
    static let isChecked = UIConfigurationStateCustomKey("org.mozilla.firefox.DevicePickerCell.isChecked")
    static let device = UIConfigurationStateCustomKey("org.mozilla.firefox.DevicePickerCell.device")
}

public extension UICellConfigurationState {
    var isChecked: Bool? {
        set { self[.isChecked] = newValue }
        get { return self[.isChecked] as? Bool }
    }
    
    var device: RemoteDevice? {
        set { self[.device] = newValue }
        get { return self[.device] as? RemoteDevice }
    }
}

class DevicePickerCell: UICollectionViewListCell {
    var device: RemoteDevice? = nil
    
    func updateWithDevice(_ newDevice: RemoteDevice) {
        guard device != newDevice else { return }
        device = newDevice
        setNeedsUpdateConfiguration()
    }

    override var configurationState: UICellConfigurationState {
        var state = super.configurationState
        state.device = self.device
        return state
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        var content = DevicePickerCellContentConfiguration().updated(for: state)
        content.deviceName = state.device?.name
        content.deviceType = ClientType.fromFxAType(state.device?.type)
        contentConfiguration = content
        
        if state.isChecked ?? false {
            accessories = [.checkmark()]
        }
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attribs = super.preferredLayoutAttributesFitting(layoutAttributes)
        attribs.frame = CGRect(origin: .zero, size: CGSize(width: attribs.frame.width, height: 50))
        return attribs
    }
}
