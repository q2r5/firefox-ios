// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0
import UIKit

class ThemedTableViewCell: UITableViewCell, NotificationThemeable {
    var detailTextColor = UIColor.theme.tableView.disabledRowText

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        applyTheme()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        textLabel?.textColor = UIColor.theme.tableView.rowText
        detailTextLabel?.textColor = detailTextColor
        backgroundColor = UIColor.theme.tableView.rowBackground
        tintColor = UIColor.theme.general.controlTint
    }
}

class ThemedTableViewController: UITableViewController, NotificationThemeable {
    override init(style: UITableView.Style = .insetGrouped) {
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = ThemedTableViewCell(style: .subtitle, reuseIdentifier: nil)
        return cell
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.sectionHeaderTopPadding = 0
        applyTheme()
    }

    func applyTheme() {
        tableView.separatorColor = UIColor.theme.tableView.separator
        tableView.backgroundColor = UIColor.theme.tableView.headerBackground
        tableView.reloadData()

        (tableView.tableHeaderView as? NotificationThemeable)?.applyTheme()
    }
}

class ThemedTableSectionHeaderFooterView: UITableViewHeaderFooterView, NotificationThemeable {
    private struct UX {
        static let titleHorizontalPadding: CGFloat = 10
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

    lazy var titleLabel: UILabel = .build { headerLabel in
        headerLabel.font = UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.regular)
        headerLabel.numberOfLines = 0
    }

    var topConstraint: NSLayoutConstraint?
    var bottomConstraint: NSLayoutConstraint?

    fileprivate lazy var bordersHelper = ThemedHeaderFooterViewBordersHelper()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        bordersHelper.initBorders(view: self.contentView)
        setDefaultBordersValues()
        setupInitialConstraints()
        applyTheme()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        bordersHelper.applyTheme()
        contentView.backgroundColor = UIColor.theme.tableView.headerBackground
        titleLabel.textColor = UIColor.theme.tableView.headerTextLight
    }

    func setupInitialConstraints() {
        topConstraint = titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: UX.titleVerticalPadding)
        bottomConstraint = titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -UX.titleVerticalLongPadding)
        NSLayoutConstraint.activate([
            titleLabel.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: UX.titleHorizontalPadding),
            titleLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -UX.titleHorizontalPadding),
            topConstraint!,
            bottomConstraint!
        ])
        remakeTitleAlignmentConstraints()
    }

    func showBorder(for location: ThemedHeaderFooterViewBordersHelper.BorderLocation, _ show: Bool) {
        bordersHelper.showBorder(for: location, show)
    }

    func setDefaultBordersValues() {
        bordersHelper.showBorder(for: .top, false)
        bordersHelper.showBorder(for: .bottom, false)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        setDefaultBordersValues()
        titleLabel.text = nil
        titleAlignment = .bottom

        applyTheme()
    }

    fileprivate func remakeTitleAlignmentConstraints() {
        switch titleAlignment {
        case .top:
            topConstraint?.constant = UX.titleVerticalPadding
            bottomConstraint?.constant = -UX.titleVerticalLongPadding
        case .bottom:
            topConstraint?.constant = UX.titleVerticalLongPadding
            bottomConstraint?.constant = -UX.titleVerticalPadding
        }
    }
}

class ThemedHeaderFooterViewBordersHelper: NotificationThemeable {
    enum BorderLocation {
        case top
        case bottom
    }

    fileprivate lazy var topBorder: UIView = .build()

    fileprivate lazy var bottomBorder: UIView = .build()

    func showBorder(for location: BorderLocation, _ show: Bool) {
        switch location {
        case .top:
            topBorder.isHidden = !show
        case .bottom:
            bottomBorder.isHidden = !show
        }
    }

    func initBorders(view: UIView) {
        view.addSubview(topBorder)
        view.addSubview(bottomBorder)

        NSLayoutConstraint.activate([
            topBorder.leftAnchor.constraint(equalTo: view.leftAnchor),
            topBorder.rightAnchor.constraint(equalTo: view.rightAnchor),
            topBorder.topAnchor.constraint(equalTo: view.topAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.25),
            bottomBorder.leftAnchor.constraint(equalTo: view.leftAnchor),
            bottomBorder.rightAnchor.constraint(equalTo: view.rightAnchor),
            bottomBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBorder.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    func applyTheme() {
        topBorder.backgroundColor = UIColor.theme.tableView.separator
        bottomBorder.backgroundColor = UIColor.theme.tableView.separator
    }
}

class UISwitchThemed: UISwitch {
    override func layoutSubviews() {
        super.layoutSubviews()
        onTintColor = UIColor.theme.general.controlTint
    }
}
