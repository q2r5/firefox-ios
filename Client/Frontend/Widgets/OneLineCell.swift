/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit

struct OneLineCellUX {
    static let ImageSize: CGFloat = 29
    static let ImageCornerRadius: CGFloat = 6
    static let HorizontalMargin: CGFloat = 16
}

struct OneLineCellContentConfiguration: UIContentConfiguration, Hashable {
    var image: UIImage?
    var title: String?

    private(set) var trailingMargin: CGFloat = 0
    var indentation: CGFloat = 0

    func makeContentView() -> UIView & UIContentView {
        return OneLineCellContentView(configuration: self)
    }
    
    func updated(for state: UIConfigurationState) -> OneLineCellContentConfiguration {
        guard let state = state as? UICellConfigurationState else { return self }
        var updatedConfig = self
        updatedConfig.trailingMargin = state.isEditing ? 0 : -OneLineCellUX.HorizontalMargin

        return updatedConfig
    }
}

class OneLineCellContentView: UIView, UIContentView {
    init(configuration: OneLineCellContentConfiguration) {
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
            guard let newConfig = newValue as? OneLineCellContentConfiguration else { return }
            apply(configuration: newConfig)
        }
    }

    private var appliedConfiguration: OneLineCellContentConfiguration!

    private func apply(configuration: OneLineCellContentConfiguration) {
        guard appliedConfiguration != configuration else { return }
        appliedConfiguration = configuration
        imageView.image = appliedConfiguration.image
        textLabel.text = appliedConfiguration.title
    }
    
    let imageView = UIImageView()
    let textLabel = UILabel()
    
    private func setupSubviews() {
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = true
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = OneLineCellUX.ImageCornerRadius
        imageView.layer.masksToBounds = true
        imageView.snp.makeConstraints { make in
            make.width.height.equalTo(OneLineCellUX.ImageSize)
            make.leading.equalTo(appliedConfiguration.indentation + OneLineCellUX.HorizontalMargin)
            make.centerY.equalToSuperview()
        }

        addSubview(textLabel)
        textLabel.font = DynamicFontHelper.defaultHelper.DeviceFontHistoryPanel
        textLabel.textColor = UIColor.theme.tableView.rowText
        textLabel.snp.makeConstraints { make in
            make.leading.equalTo(appliedConfiguration.indentation + OneLineCellUX.ImageSize + OneLineCellUX.HorizontalMargin * 2)
            make.trailing.equalTo(appliedConfiguration.trailingMargin)
            make.centerY.equalToSuperview()
        }
    }
}

class OneLineCollectionViewListCell: UICollectionViewListCell {
    var image: UIImage? {
        didSet {
            setNeedsUpdateConfiguration()
        }
    }

    var title: String? {
        didSet {
            setNeedsUpdateConfiguration()
        }
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        var content = OneLineCellContentConfiguration().updated(for: state)
        content.image = image
        content.title = title
        content.indentation = CGFloat(indentationLevel) * indentationWidth
        contentConfiguration = content
    }
}

class OneLineTableViewCell: UITableViewCell, Themeable {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.separatorInset = .zero
        self.applyTheme()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let indentation = CGFloat(indentationLevel) * indentationWidth

        imageView?.translatesAutoresizingMaskIntoConstraints = true
        imageView?.contentMode = .scaleAspectFill
        imageView?.layer.cornerRadius = OneLineCellUX.ImageCornerRadius
        imageView?.layer.masksToBounds = true
        imageView?.snp.remakeConstraints { make in
            guard let _ = imageView?.superview else { return }

            make.width.height.equalTo(OneLineCellUX.ImageSize)
            make.leading.equalTo(indentation + OneLineCellUX.HorizontalMargin)
            make.centerY.equalToSuperview()
        }

        textLabel?.font = DynamicFontHelper.defaultHelper.DeviceFontHistoryPanel
        textLabel?.snp.remakeConstraints { make in
            guard let _ = textLabel?.superview else { return }

            make.leading.equalTo(indentation + OneLineCellUX.ImageSize + OneLineCellUX.HorizontalMargin*2)
            make.trailing.equalTo(isEditing ? 0 : -OneLineCellUX.HorizontalMargin)
            make.centerY.equalToSuperview()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.applyTheme()
    }

    func applyTheme() {
        backgroundColor = UIColor.theme.tableView.rowBackground
        textLabel?.textColor = UIColor.theme.tableView.rowText
    }
}
