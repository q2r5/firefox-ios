// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import UIKit
import Shared

class TabTableViewCell: UITableViewCell, NotificationThemeable {
    static let identifier = "tabCell"
    var screenshotView: UIImageView?
    var websiteTitle: UILabel?
    var urlLabel: UILabel?
    
    let closeButton: UIButton = .build { button in
        button.setImage(UIImage.templateImageNamed("tab_close"), for: [])
        button.accessibilityIdentifier = "closeTabButtonTabTray"
        button.tintColor = UIColor.theme.tabTray.cellCloseButton
        button.sizeToFit()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        guard let imageView = imageView, let title = textLabel, let label = detailTextLabel else { return }
        
        self.screenshotView = imageView
        self.websiteTitle = title
        self.urlLabel = label
        
        viewSetup()
        applyTheme()
    }
    
    private func viewSetup() {
        guard let websiteTitle = websiteTitle, let screenshotView = screenshotView, let urlLabel = urlLabel else { return }
        
        screenshotView.contentMode = .scaleAspectFill
        screenshotView.clipsToBounds = true
        screenshotView.layer.cornerRadius = ChronologicalTabsControllerUX.cornerRadius
        screenshotView.layer.borderWidth = 1
        screenshotView.layer.borderColor = UIColor.Photon.Grey30.cgColor
        screenshotView.translatesAutoresizingMaskIntoConstraints = false
        
        websiteTitle.numberOfLines = 2
        websiteTitle.translatesAutoresizingMaskIntoConstraints = false
        
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            screenshotView.heightAnchor.constraint(equalToConstant: 100),
            screenshotView.widthAnchor.constraint(equalToConstant: 100),
            screenshotView.leadingAnchor.constraint(equalTo: screenshotView.superview!.leadingAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginLeftRight),
            screenshotView.topAnchor.constraint(equalTo: screenshotView.superview!.topAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginTopBottom),
            screenshotView.bottomAnchor.constraint(equalTo: screenshotView.superview!.bottomAnchor, constant: -ChronologicalTabsControllerUX.screenshotMarginTopBottom),
            websiteTitle.leadingAnchor.constraint(equalTo: screenshotView.trailingAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginLeftRight),
            websiteTitle.topAnchor.constraint(equalTo: websiteTitle.superview!.topAnchor, constant: ChronologicalTabsControllerUX.textMarginTopBottom),
            websiteTitle.trailingAnchor.constraint(equalTo: websiteTitle.superview!.trailingAnchor, constant: -16),
            urlLabel.leadingAnchor.constraint(equalTo: screenshotView.trailingAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginLeftRight),
            urlLabel.trailingAnchor.constraint(equalTo: urlLabel.superview!.trailingAnchor),
            urlLabel.topAnchor.constraint(equalTo: websiteTitle.bottomAnchor, constant: 3),
            urlLabel.bottomAnchor.constraint(equalTo: urlLabel.superview!.bottomAnchor, constant: -ChronologicalTabsControllerUX.textMarginTopBottom * 2)
        ])
    }
    
    // Helper method to remake title constraint
    func remakeTitleConstraint() {
        guard let websiteTitle = websiteTitle, let text = websiteTitle.text, !text.isEmpty, let screenshotView = screenshotView, let urlLabel = urlLabel else { return }
        websiteTitle.numberOfLines = 2
        NSLayoutConstraint.deactivate(websiteTitle.constraints)
        NSLayoutConstraint.activate([
            websiteTitle.leadingAnchor.constraint(equalTo: screenshotView.trailingAnchor, constant: ChronologicalTabsControllerUX.screenshotMarginLeftRight),
            websiteTitle.topAnchor.constraint(equalTo: websiteTitle.superview!.topAnchor, constant: ChronologicalTabsControllerUX.textMarginTopBottom),
            websiteTitle.trailingAnchor.constraint(equalTo: websiteTitle.superview!.trailingAnchor, constant: -16),
            websiteTitle.bottomAnchor.constraint(equalTo: urlLabel.topAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        applyTheme()
    }

    func applyTheme() {
        backgroundColor = UIColor.secondarySystemGroupedBackground
        textLabel?.textColor = UIColor.label
        detailTextLabel?.textColor = UIColor.secondaryLabel
        closeButton.tintColor = UIColor.secondaryLabel
    }
}
