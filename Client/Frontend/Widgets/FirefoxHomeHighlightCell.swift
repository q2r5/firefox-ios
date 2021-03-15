// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import Shared
import Storage

private struct FirefoxHomeHighlightCellUX {
    static let BorderWidth: CGFloat = 0.5
    static let SiteImageViewSize = CGSize(width: 99, height: UIDevice.current.userInterfaceIdiom == .pad ? 120 : 100)
    static let StatusIconSize = 12
    static let FaviconSize = CGSize(width: 45, height: 45)
    static let SelectedOverlayColor = UIColor(white: 0.0, alpha: 0.25)
    static let CornerRadius: CGFloat = 8
}

class FirefoxHomeHighlightCell: UICollectionViewCell, NotificationThemeable {

    private let titleLabel: UILabel = .build { titleLabel in
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.textAlignment = .left
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 3
    }

    private let domainLabel: UILabel = .build { descriptionLabel in
        descriptionLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 1
        descriptionLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 1000), for: .vertical)
        descriptionLabel.adjustsFontForContentSizeCategory = true
    }

    private let imageWrapperView: UIView = .build { view in
        view.layer.cornerRadius = FirefoxHomeHighlightCellUX.CornerRadius
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 6
    }

    private let siteImageView: UIImageView = .build { siteImageView in
        siteImageView.contentMode = .scaleAspectFill
        siteImageView.clipsToBounds = true
        siteImageView.contentMode = .center
        siteImageView.layer.cornerRadius = FirefoxHomeHighlightCellUX.CornerRadius
        siteImageView.layer.masksToBounds = true
    }

    private let selectedOverlay: UIView = .build { selectedOverlay in
        selectedOverlay.backgroundColor = FirefoxHomeHighlightCellUX.SelectedOverlayColor
        selectedOverlay.isHidden = true
    }

    override var isSelected: Bool {
        didSet {
            self.selectedOverlay.isHidden = !isSelected
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale

        isAccessibilityElement = true

        imageWrapperView.addSubview(siteImageView)
        contentView.addSubview(imageWrapperView)
        contentView.addSubview(selectedOverlay)
        contentView.addSubview(titleLabel)
        contentView.addSubview(domainLabel)

        NSLayoutConstraint.activate([
            imageWrapperView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageWrapperView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
            imageWrapperView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
            imageWrapperView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageWrapperView.widthAnchor.constraint(equalToConstant: FirefoxHomeHighlightCellUX.SiteImageViewSize.width),
            imageWrapperView.heightAnchor.constraint(equalToConstant: FirefoxHomeHighlightCellUX.SiteImageViewSize.height),
            siteImageView.leadingAnchor.constraint(equalTo: imageWrapperView.leadingAnchor),
            siteImageView.trailingAnchor.constraint(equalTo: imageWrapperView.trailingAnchor),
            siteImageView.topAnchor.constraint(equalTo: imageWrapperView.topAnchor),
            siteImageView.bottomAnchor.constraint(equalTo: imageWrapperView.bottomAnchor),
            selectedOverlay.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
            selectedOverlay.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
            selectedOverlay.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            selectedOverlay.bottomAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.bottomAnchor),
            domainLabel.leadingAnchor.constraint(equalTo: siteImageView.leadingAnchor),
            domainLabel.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
            domainLabel.topAnchor.constraint(equalTo: siteImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: siteImageView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: domainLabel.bottomAnchor, constant: 5)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        siteImageView.image = nil
        siteImageView.backgroundColor = UIColor.clear
        applyTheme()
    }

    func configureWithPocketStory(_ pocketStory: PocketStory) {
        siteImageView.sd_setImage(with: pocketStory.imageURL)
        siteImageView.contentMode = .scaleAspectFill

        domainLabel.text = pocketStory.domain
        titleLabel.text = pocketStory.title

        applyTheme()
    }

    func applyTheme() {
        titleLabel.textColor = UIColor.theme.homePanel.activityStreamCellTitle
        domainLabel.textColor = UIColor.theme.homePanel.activityStreamCellDescription
        imageWrapperView.layer.shadowColor = UIColor.theme.homePanel.shortcutShadowColor
        imageWrapperView.layer.shadowOpacity = UIColor.theme.homePanel.shortcutShadowOpacity
    }
}
