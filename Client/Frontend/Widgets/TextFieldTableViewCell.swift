// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

struct TextFieldTableViewCellUX {
    static let HorizontalMargin: CGFloat = 16
    static let VerticalMargin: CGFloat = 10
    static let TitleLabelFont = UIFont.systemFont(ofSize: 12)
    static let TitleLabelTextColor = UIConstants.SystemBlueColor
    static let TextFieldFont = UIFont.systemFont(ofSize: 16)
}

protocol TextFieldTableViewCellDelegate: AnyObject {
    func textFieldTableViewCell(_ textFieldTableViewCell: TextFieldTableViewCell, didChangeText text: String)
}

struct TextFieldCellContentConfiguration: UIContentConfiguration, Hashable {
    var titleText: NSAttributedString
    var titleColor: UIColor
    var titleFont: UIFont
    var textViewColor: UIColor
    var textViewFont: UIFont

    func makeContentView() -> UIView & UIContentView {
        return TextFieldCellContentView(configuration: self)
    }

    func updated(for state: UIConfigurationState) -> TextFieldCellContentConfiguration {
//        guard let state = state as? UICellConfigurationState else { return self }

        var updatedConfiguration = self
        updatedConfiguration.textViewColor = UIColor.theme.tableView.rowText
        return updatedConfiguration
    }
}

class TextFieldCellContentView: UIView, UIContentView {
    private var contentConfiguration: TextFieldCellContentConfiguration
    var configuration: UIContentConfiguration {
        get {
            return contentConfiguration
        }
        set {
            guard let newConfig = newValue as? TextFieldCellContentConfiguration else {
                return
            }

            configure(for: newConfig)
        }
    }

    private let titleLabel: UILabel = .build()
    private let textField: UITextField = .build()

    init(configuration: TextFieldCellContentConfiguration) {
        self.contentConfiguration = configuration
        super.init(frame: .zero)
        self.addSubview(self.titleLabel)
        self.addSubview(self.textField)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TextFieldTableViewCellUX.HorizontalMargin),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TextFieldTableViewCellUX.HorizontalMargin),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: TextFieldTableViewCellUX.VerticalMargin),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TextFieldTableViewCellUX.HorizontalMargin),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TextFieldTableViewCellUX.HorizontalMargin),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -TextFieldTableViewCellUX.VerticalMargin)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(for configuration: TextFieldCellContentConfiguration) {
        guard contentConfiguration != configuration else {
            return
        }
        contentConfiguration = configuration

        titleLabel.font = configuration.titleFont
        titleLabel.attributedText = configuration.titleText
        titleLabel.textColor = configuration.titleColor

        textField.font = configuration.textViewFont
        textField.textColor = configuration.textViewColor
    }
}

class TextFieldTableViewCell: UITableViewCell, NotificationThemeable {
    let titleLabel: UILabel
    let textField: UITextField

    weak var delegate: TextFieldTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.titleLabel = .build { label in
            label.font = TextFieldTableViewCellUX.TitleLabelFont
        }
        self.textField = .build()

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.textField)
        self.textField.delegate = self
        self.selectionStyle = .none
        self.separatorInset = .zero
        self.applyTheme()

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TextFieldTableViewCellUX.HorizontalMargin),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TextFieldTableViewCellUX.HorizontalMargin),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: TextFieldTableViewCellUX.VerticalMargin),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TextFieldTableViewCellUX.HorizontalMargin),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TextFieldTableViewCellUX.HorizontalMargin),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -TextFieldTableViewCellUX.VerticalMargin)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.applyTheme()
    }

    func applyTheme() {
        backgroundColor = UIColor.theme.tableView.rowBackground
        titleLabel.textColor = TextFieldTableViewCellUX.TitleLabelTextColor
        textField.textColor = UIColor.theme.tableView.rowText
    }
}

extension TextFieldTableViewCell: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let text = textField.text,
            let textRange = Range(range, in: text) {
            let updatedText = text.replacingCharacters(in: textRange, with: string)
            delegate?.textFieldTableViewCell(self, didChangeText: updatedText)
        }
        return true
    }
}
