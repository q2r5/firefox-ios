// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import Storage
import SnapKit
import Shared

// This file is the cells used for the PhotonActionSheet table view.

private struct PhotonActionSheetCellUX {
    static let LabelColor = UIConstants.SystemBlueColor
    static let BorderWidth = CGFloat(0.5)
    static let CellSideOffset = 20
    static let TitleLabelOffset = 10
    static let CellTopBottomOffset = 12
    static let StatusIconSize = 24
    static let SelectedOverlayColor = UIColor(white: 0.0, alpha: 0.25)
    static let CornerRadius: CGFloat = 3
}

class PhotonActionSheetCell: UITableViewCell {
    static let Padding: CGFloat = 16
    static let HorizontalPadding: CGFloat = 1
    static let topBottomPadding: CGFloat = 10
    static let VerticalPadding: CGFloat = 2
    static let IconSize = 16

    var badgeOverlay: BadgeWithBackdrop?

    private func createLabel() -> UILabel {
        let label = UILabel()
        label.minimumScaleFactor = 0.75 // Scale the font if we run out of space
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        label.adjustsFontSizeToFitWidth = true
        return label
    }

    private func createIconImageView() -> UIImageView {
        let icon = UIImageView()
        icon.contentMode = .scaleAspectFit
        icon.clipsToBounds = true
        icon.layer.cornerRadius = PhotonActionSheetCellUX.CornerRadius
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.setContentCompressionResistancePriority(.required, for: .horizontal)
        return icon
    }

    lazy var titleLabel: UILabel = {
        let label = createLabel()
        label.numberOfLines = 4
        label.font = DynamicFontHelper.defaultHelper.LargeSizeRegularWeightAS
        return label
    }()

    lazy var subtitleLabel: UILabel = {
        let label = createLabel()
        label.numberOfLines = 0
        label.font = DynamicFontHelper.defaultHelper.SmallSizeRegularWeightAS
        return label
    }()

    lazy var statusIcon: UIImageView = {
        return createIconImageView()
    }()

    lazy var disclosureLabel: UILabel = {
        let label = UILabel()
        return label
    }()

    struct ToggleSwitch {
        let mainView: UIImageView = {
            let background = UIImageView(image: UIImage.templateImageNamed("menu-customswitch-background"))
            background.contentMode = .scaleAspectFit
            return background
        }()

        private let foreground = UIImageView()

        init() {
            foreground.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            foreground.contentMode = .scaleAspectFit
            foreground.frame = mainView.frame
            mainView.isAccessibilityElement = true
            mainView.addSubview(foreground)
            setOn(false)
        }

        func setOn(_ on: Bool) {
            foreground.image = on ? UIImage(named: "menu-customswitch-on") : UIImage(named: "menu-customswitch-off")
            mainView.accessibilityIdentifier = on ? "enabled" : "disabled"
            mainView.tintColor = on ? UIColor.theme.general.controlTint : UIColor.theme.general.switchToggle }
    }

    let toggleSwitch = ToggleSwitch()

    lazy var selectedOverlay: UIView = {
        let selectedOverlay = UIView()
        selectedOverlay.backgroundColor = PhotonActionSheetCellUX.SelectedOverlayColor
        selectedOverlay.isHidden = true
        return selectedOverlay
    }()

    lazy var disclosureIndicator: UIImageView = {
        let disclosureIndicator = createIconImageView()
        disclosureIndicator.image = UIImage(named: "menu-Disclosure")?.withRenderingMode(.alwaysTemplate)
        disclosureIndicator.tintColor = UIColor.theme.tableView.accessoryViewTint
        return disclosureIndicator
    }()

    lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = PhotonActionSheetCell.Padding
        stackView.alignment = .center
        stackView.axis = .horizontal
        return stackView
    }()

    override var isSelected: Bool {
        didSet {
            self.selectedOverlay.isHidden = !isSelected
        }
    }

    let bottomBorder = UIView()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.statusIcon.image = nil
        disclosureIndicator.removeFromSuperview()
        disclosureLabel.removeFromSuperview()
        toggleSwitch.mainView.removeFromSuperview()
        statusIcon.layer.cornerRadius = PhotonActionSheetCellUX.CornerRadius
        badgeOverlay?.backdrop.removeFromSuperview()
        badgeOverlay?.badge.removeFromSuperview()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        isAccessibilityElement = true
        contentView.addSubview(selectedOverlay)
        backgroundColor = .clear

        selectedOverlay.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }

        // Setup our StackViews
        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStackView.spacing = PhotonActionSheetCell.VerticalPadding
        textStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStackView.alignment = .leading
        textStackView.axis = .vertical

        stackView.addArrangedSubview(textStackView)
        stackView.addArrangedSubview(statusIcon)
        contentView.addSubview(stackView)

        statusIcon.snp.makeConstraints { make in
            make.size.equalTo(PhotonActionSheetCellUX.StatusIconSize)
        }

        let padding = PhotonActionSheetCell.Padding
        let topPadding = PhotonActionSheetCell.topBottomPadding
        stackView.snp.makeConstraints { make in
            make.edges.equalTo(contentView).inset(UIEdgeInsets(top: topPadding, left: padding, bottom: topPadding, right: padding))
        }
        addSubBorder()
        // Hiding bottom border by default
        bottomBorder.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addSubBorder() {
        bottomBorder.backgroundColor = UIColor.theme.tableView.separator
        self.contentView.addSubview(bottomBorder)
        bottomBorder.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
    }
    
    func configure(with action: PhotonActionSheetItem) {
        titleLabel.text = action.title
        titleLabel.textColor = UIColor.theme.tableView.rowText
        titleLabel.textColor = action.accessory == .Text ? titleLabel.textColor.withAlphaComponent(0.6) : titleLabel.textColor
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.minimumScaleFactor = 0.5

        subtitleLabel.text = action.text
        subtitleLabel.textColor = UIColor.theme.tableView.rowText
        subtitleLabel.isHidden = action.text == nil
        subtitleLabel.numberOfLines = 0
        titleLabel.font = action.bold ? DynamicFontHelper.defaultHelper.DeviceFontLargeBold : DynamicFontHelper.defaultHelper.SemiMediumRegularWeightAS
        accessibilityIdentifier = action.iconString ?? action.accessibilityId
        accessibilityLabel = action.title
        selectionStyle = action.tapHandler != nil ? .default : .none

        if let iconName = action.iconString {
            switch action.iconType {
            case .Image:
                let image = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
                statusIcon.image = image
                statusIcon.tintColor = action.iconTint ?? self.tintColor
            case .URL:
                let image = UIImage(named: iconName)?.createScaled(PhotonActionSheetUX.IconSize)
                statusIcon.layer.cornerRadius = PhotonActionSheetUX.IconSize.width / 2
                statusIcon.sd_setImage(with: action.iconURL, placeholderImage: image, options: []) { (img, err, _, _) in
                    if let img = img {
                        self.statusIcon.image = img.createScaled(PhotonActionSheetUX.IconSize)
                        self.statusIcon.layer.cornerRadius = PhotonActionSheetUX.IconSize.width / 2
                    }
                }
            case .TabsButton:
                let label = UILabel(frame: CGRect())
                label.text = action.tabCount
                label.font = UIFont.boldSystemFont(ofSize: UIConstants.DefaultChromeSmallSize)
                label.textColor = UIColor.theme.textField.textAndTint
                let image = UIImage(named: iconName)?.withRenderingMode(.alwaysTemplate)
                statusIcon.image = image
                statusIcon.addSubview(label)
                label.snp.makeConstraints { (make) in
                    make.centerX.equalTo(statusIcon)
                    make.centerY.equalTo(statusIcon)
                }
            default:
                break
            }
            if statusIcon.superview == nil {
                if action.iconAlignment == .right {
                    stackView.addArrangedSubview(statusIcon)
                } else {
                    stackView.insertArrangedSubview(statusIcon, at: 0)
                }
            } else {
                if action.iconAlignment == .right {
                    statusIcon.removeFromSuperview()
                    stackView.addArrangedSubview(statusIcon)
                }
            }
        } else {
            statusIcon.removeFromSuperview()
        }

        if let name = action.badgeIconName, action.isEnabled, let parent = statusIcon.superview {
            badgeOverlay = BadgeWithBackdrop(imageName: name)
            badgeOverlay?.add(toParent: parent)
            badgeOverlay?.layout(onButton: statusIcon)
            badgeOverlay?.show(true)
            // Custom dark theme tint needed here, it is overkill to create a '.theme' color just for this.
            let color = LegacyThemeManager.instance.currentName == .dark ? UIColor(white: 0.3, alpha: 1): UIColor.theme.actionMenu.closeButtonBackground
            badgeOverlay?.badge.tintBackground(color: color)
        }

        switch action.accessory {
        case .Text:
            disclosureLabel.font = action.bold ? DynamicFontHelper.defaultHelper.DeviceFontLargeBold : DynamicFontHelper.defaultHelper.LargeSizeRegularWeightAS
            disclosureLabel.text = action.accessoryText
            disclosureLabel.textColor = titleLabel.textColor
            stackView.addArrangedSubview(disclosureLabel)
        case .Disclosure:
            stackView.addArrangedSubview(disclosureIndicator)
        case .Switch:
            toggleSwitch.setOn(action.isEnabled)
            stackView.addArrangedSubview(toggleSwitch.mainView)
        case .None:
            titleLabel.snp.makeConstraints { make in
                make.top.bottom.equalTo(contentView).inset(10)
            }
        }
        action.customRender?(titleLabel, contentView)
    }
}
