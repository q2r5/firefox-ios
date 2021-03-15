// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

class TabTableViewHeader: UITableViewHeaderFooterView, NotificationThemeable {
    private struct UX {
        static let titleHorizontalPadding: CGFloat = 15
        static let titleVerticalPadding: CGFloat = 6
        static let titleVerticalLongPadding: CGFloat = 20
    }

    enum TitleAlignment {
        case top
        case bottom
    }

    var titleAlignment: TitleAlignment = .bottom {
        didSet {
            remakeTitleAlignmentConstraints()
        }
    }

    lazy var titleLabel: UILabel = {
        var headerLabel = UILabel()
        headerLabel.font = UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.regular)
        headerLabel.numberOfLines = 0
        return headerLabel
    }()

    lazy var moreButton: UIButton = {
        var moreButton = UIButton(type: .system)
        moreButton.setImage(UIImage(systemName: "ellipsis.circle.fill"), for: .normal)
        moreButton.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(font: UIFont.systemFont(ofSize: 12.0, weight: .regular)), forImageIn: .normal)
        moreButton.showsMenuAsPrimaryAction = true
        return moreButton
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        contentView.addSubview(moreButton)
        remakeTitleAlignmentConstraints()
        applyTheme()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        contentView.backgroundColor = UIColor.systemGroupedBackground
        titleLabel.textColor = UIColor.secondaryLabel
        moreButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
        moreButton.tintColor = UIColor.secondaryLabel
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        titleAlignment = .bottom

        applyTheme()
    }

    fileprivate func remakeTitleAlignmentConstraints() {
        switch titleAlignment {
        case .top:
            NSLayoutConstraint.deactivate(titleLabel, moreButton)
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UX.titleHorizontalPadding),
                titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.titleVerticalPadding),
                titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UX.titleVerticalLongPadding),
                moreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UX.titleHorizontalPadding),
                moreButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.titleVerticalPadding),
                moreButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UX.titleVerticalLongPadding)
            ])
        case .bottom:
            NSLayoutConstraint.deactivate(titleLabel, moreButton)
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: UX.titleHorizontalPadding),
                titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.titleVerticalLongPadding),
                titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UX.titleVerticalPadding),
                moreButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -UX.titleHorizontalPadding),
                moreButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.titleVerticalLongPadding),
                moreButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UX.titleVerticalPadding)
            ])
        }
    }
}
