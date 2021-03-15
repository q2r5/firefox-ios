// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

struct TwoLineCellUX {
    static let ImageSize: CGFloat = 29
    static let BorderViewMargin: CGFloat = 16
}

// TODO: Add support for accessibility for when text size changes

class TwoLineImageOverlayCell: UITableViewCell, NotificationThemeable {
    // Tableview cell items
    let selectedView: UIView = .build { view in
        view.backgroundColor = UIColor.theme.tableView.selectedBackground
    }
    
    let leftImageView: UIImageView = .build { imgView in
        imgView.contentMode = .scaleAspectFit
        imgView.layer.cornerRadius = 5.0
        imgView.clipsToBounds = true
    }
    
    let leftOverlayImageView: UIImageView = .build { imgView in
        imgView.contentMode = .scaleAspectFit
        imgView.clipsToBounds = true
    }

    let titleLabel: UILabel = .build { label in
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 1
    }
    
    let descriptionLabel: UILabel = .build { label in
        label.textColor = UIColor.Photon.Grey40
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 1
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialViewSetup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let containerView: UIView = .build()
    let midView: UIView = .build()
    
    private func initialViewSetup() {
        separatorInset = UIEdgeInsets(top: 0, left: TwoLineCellUX.ImageSize + 2 * TwoLineCellUX.BorderViewMargin, bottom: 0, right: 0)
        self.selectionStyle = .default
        midView.addSubview(titleLabel)
        midView.addSubview(descriptionLabel)

        containerView.addSubview(leftImageView)
        containerView.addSubview(midView)

        containerView.addSubview(leftOverlayImageView)
        addSubview(containerView)
        contentView.addSubview(containerView)
        bringSubviewToFront(containerView)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 58),
            containerView.topAnchor.constraint(equalTo: self.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: accessoryView?.leadingAnchor ?? self.trailingAnchor),
            leftImageView.heightAnchor.constraint(equalToConstant: 28),
            leftImageView.widthAnchor.constraint(equalToConstant: 28),
            leftImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 15),
            leftImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            leftOverlayImageView.heightAnchor.constraint(equalToConstant: 22),
            leftOverlayImageView.widthAnchor.constraint(equalToConstant: 22),
            leftOverlayImageView.trailingAnchor.constraint(equalTo: leftImageView.trailingAnchor, constant: 7),
            leftOverlayImageView.bottomAnchor.constraint(equalTo: leftImageView.bottomAnchor, constant: 7),
            midView.heightAnchor.constraint(equalToConstant: 46),
            midView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            midView.leadingAnchor.constraint(equalTo: leftImageView.trailingAnchor, constant: 13),
            midView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -7),
            titleLabel.topAnchor.constraint(equalTo: midView.topAnchor, constant: 4),
            titleLabel.heightAnchor.constraint(equalToConstant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: midView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: midView.trailingAnchor),
            descriptionLabel.heightAnchor.constraint(equalToConstant: 16),
            descriptionLabel.bottomAnchor.constraint(equalTo: midView.bottomAnchor, constant: -4),
            descriptionLabel.leadingAnchor.constraint(equalTo: midView.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: midView.trailingAnchor)
        ])
        
        selectedBackgroundView = selectedView
        applyTheme()
    }
    
    func applyTheme() {
        let theme = BuiltinThemeName(rawValue: LegacyThemeManager.instance.current.name) ?? .normal
        if theme == .dark {
            self.backgroundColor = UIColor.Photon.Grey80
            self.titleLabel.textColor = .white
            self.descriptionLabel.textColor = UIColor.Photon.Grey40
        } else {
            self.backgroundColor = .white
            self.titleLabel.textColor = .black
            self.descriptionLabel.textColor = UIColor.Photon.DarkGrey05
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.selectionStyle = .default
        separatorInset = UIEdgeInsets(top: 0, left: TwoLineCellUX.ImageSize + 2 * TwoLineCellUX.BorderViewMargin, bottom: 0, right: 0)
        applyTheme()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.removeConstraint(containerView.heightAnchor.constraint(equalToConstant: 58))
        containerView.addConstraint(containerView.heightAnchor.constraint(equalToConstant: 55))
    }
}


class SimpleTwoLineCell: UITableViewCell, NotificationThemeable {
    // Tableview cell items
    var selectedView: UIView = .build { view in
        view.backgroundColor = UIColor.theme.tableView.selectedBackground
    }

    var titleLabel: UILabel = .build { label in
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 1
    }
    
    var descriptionLabel: UILabel = .build { label in
        label.textColor = UIColor.Photon.Grey40
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 1
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialViewSetup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func initialViewSetup() {
        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        self.selectionStyle = .default
        let midView: UIView = .build()
        midView.addSubview(titleLabel)
        midView.addSubview(descriptionLabel)
        let containerView: UIView = .build()
        containerView.addSubview(midView)
        addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 65),
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            midView.heightAnchor.constraint(equalToConstant: 46),
            midView.centerYAnchor.constraint(equalTo: centerYAnchor),
            midView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            midView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: midView.topAnchor, constant: 4),
            titleLabel.heightAnchor.constraint(equalToConstant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: midView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: midView.trailingAnchor, constant: -16),
            descriptionLabel.heightAnchor.constraint(equalToConstant: 14),
            descriptionLabel.bottomAnchor.constraint(equalTo: midView.bottomAnchor, constant: -4),
            descriptionLabel.leadingAnchor.constraint(equalTo: midView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: midView.trailingAnchor, constant: -16)
        ])

        selectedBackgroundView = selectedView
        applyTheme()
    }
    
    func applyTheme() {
        let theme = LegacyThemeManager.instance.currentName
        if theme == .dark {
            self.backgroundColor = UIColor.Photon.Grey80
            self.titleLabel.textColor = .white
            self.descriptionLabel.textColor = UIColor.Photon.Grey40
        } else {
            self.backgroundColor = .white
            self.titleLabel.textColor = .black
            self.descriptionLabel.textColor = UIColor.Photon.DarkGrey05
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.selectionStyle = .default
        separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        applyTheme()
    }
}

// TODO: Add support for accessibility for when text size changes

class TwoLineHeaderFooterView: UITableViewHeaderFooterView, NotificationThemeable {
    fileprivate let bordersHelper = ThemedHeaderFooterViewBordersHelper()
    var leftImageView: UIImageView = .build { imgView in
        imgView.contentMode = .scaleAspectFit
        imgView.clipsToBounds = true
    }
    
    var titleLabel: UILabel = .build { label in
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 1
    }
    
    var descriptionLabel: UILabel = .build { label in
        label.font = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 1
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        initialViewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func initialViewSetup() {
        bordersHelper.initBorders(view: self)
        setDefaultBordersValues()
        layoutMargins = .zero
        contentView.translatesAutoresizingMaskIntoConstraints = false
        let stackView: UIStackView = .build { stackView in
            [self.titleLabel, self.descriptionLabel].forEach {
                stackView.addArrangedSubview($0)
            }
            stackView.axis = .vertical
            stackView.alignment = .leading
            stackView.distribution = .equalCentering
            stackView.spacing = 2
        }

        contentView.addSubview(stackView)
        contentView.addSubview(leftImageView)
        
        NSLayoutConstraint.activate([
            leftImageView.heightAnchor.constraint(equalToConstant: TwoLineCellUX.ImageSize),
            leftImageView.widthAnchor.constraint(equalToConstant: TwoLineCellUX.ImageSize),
            leftImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -15),
            leftImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.heightAnchor.constraint(equalToConstant: 35),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stackView.leadingAnchor.constraint(equalTo: leftImageView.trailingAnchor, constant: 15),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2)
        ])

        applyTheme()
    }
    
    func showBorder(for location: ThemedHeaderFooterViewBordersHelper.BorderLocation, _ show: Bool) {
        bordersHelper.showBorder(for: location, show)
    }

    fileprivate func setDefaultBordersValues() {
        bordersHelper.showBorder(for: .top, true)
        bordersHelper.showBorder(for: .bottom, true)
    }

    func applyTheme() {
        let theme = BuiltinThemeName(rawValue: LegacyThemeManager.instance.current.name) ?? .normal
        self.backgroundColor = UIColor.theme.tableView.selectedBackground
        if theme == .dark {
            self.titleLabel.textColor = .white
            self.descriptionLabel.textColor = UIColor.Photon.Grey40
        } else {
            self.titleLabel.textColor = .black
            self.descriptionLabel.textColor = UIColor.Photon.Grey60
        }
        bordersHelper.applyTheme()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setDefaultBordersValues()
        applyTheme()
    }
}
