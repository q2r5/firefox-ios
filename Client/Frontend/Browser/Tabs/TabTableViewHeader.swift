/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

class TabTableViewHeader: UITableViewHeaderFooterView, Themeable {
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
        if #available(iOS 13.0, *) {
            contentView.backgroundColor = UIColor.systemGroupedBackground
            titleLabel.textColor = UIColor.secondaryLabel
            moreButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
            moreButton.tintColor = UIColor.secondaryLabel
        } else {
            contentView.backgroundColor = UIColor.theme.tableView.headerBackground
            titleLabel.textColor = UIColor.theme.tableView.headerTextLight
            moreButton.setTitleColor(UIColor.theme.tableView.headerTextLight, for: .normal)
            moreButton.tintColor = UIColor.theme.tableView.headerTextLight
        }
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
            titleLabel.snp.remakeConstraints { make in
                make.left.equalTo(self.contentView).inset(UX.titleHorizontalPadding)
                make.top.equalTo(self.contentView).offset(UX.titleVerticalPadding)
                make.bottom.equalTo(self.contentView).offset(-UX.titleVerticalLongPadding)
            }
            moreButton.snp.remakeConstraints { make in
                make.right.equalTo(self.contentView).inset(UX.titleHorizontalPadding)
                make.top.equalTo(self.contentView).offset(UX.titleVerticalPadding)
                make.bottom.equalTo(self.contentView).offset(-UX.titleVerticalLongPadding)
            }
        case .bottom:
            titleLabel.snp.remakeConstraints { make in
                make.left.equalTo(self.contentView).inset(UX.titleHorizontalPadding)
                make.bottom.equalTo(self.contentView).offset(-UX.titleVerticalPadding)
                make.top.equalTo(self.contentView).offset(UX.titleVerticalLongPadding)
            }
            moreButton.snp.remakeConstraints { make in
                make.right.equalTo(self.contentView).inset(UX.titleHorizontalPadding)
                make.top.equalTo(self.contentView).offset(UX.titleVerticalLongPadding)
                make.bottom.equalTo(self.contentView).offset(-UX.titleVerticalPadding)
            }
        }
    }
}
