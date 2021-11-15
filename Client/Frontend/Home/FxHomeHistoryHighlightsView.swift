/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Storage

class FxHomeRecentlyVisitedCollectionCell: UICollectionViewCell {

    // MARK: - Properties
    var profile: Profile?
    var viewModel: FirefoxHomeRecentlyVisitedViewModel?

    lazy var collectionView: UICollectionView = {
        let layout = FxHomeRecentlyVisitedCollectionCell.createLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceVertical = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = UIColor.clear
        collectionView.clipsToBounds = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(RecentlyVisitedCell.self, forCellWithReuseIdentifier: RecentlyVisitedCell.cellIdentifier)

        return collectionView
    }()

    // MARK: - Inits
    convenience init(frame: CGRect, with profile: Profile, and viewModel: FirefoxHomeRecentlyVisitedViewModel) {
        self.init(frame: frame)
        setupLayout()

    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Helpers
    private func setupLayout() {
        contentView.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    public static func createLayout(for totalItems: Int? = 1, with width: CGFloat = 360) -> UICollectionViewCompositionalLayout {
        guard let totalItems = totalItems else { fatalError("TotalItems should ALWAYS exist.")}

        // Create the vertical group in which the base item will go into
        var itemFractionalHeight: CGFloat {
            if totalItems == 2 {
                return 0.5
            } else if totalItems >= 3 {
                return 1/3
            }

            return 1
        }

        // Create a base item to be used in the collection view
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .fractionalHeight(itemFractionalHeight)))

        // Create the vertical group in which the base item will go into
        var verticalGroupCount: Int {
            if [1, 2, 3].contains(totalItems) {
                return 1
            } else if [4, 5, 6].contains(totalItems) {
                return 2
            } else if [7, 8, 9].contains(totalItems) {
                return 3
            }

            return 1
        }

        var verticalGroupWidth: NSCollectionLayoutDimension {
            if verticalGroupCount == 1 {
                return .absolute(width)
            } else {
                return .fractionalWidth(1/CGFloat(verticalGroupCount))
            }
        }

        let verticalGroup = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/CGFloat(verticalGroupCount)),
                                               heightDimension: .fractionalHeight(1)),
            subitems: [item])

        // Which are organized into horizontal groups if there are more than three items
//        if totalItems > 3 {
            let horizontalGroup = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(width * CGFloat(verticalGroupCount)),
                                                   heightDimension: .fractionalHeight(1)),
                subitems: [verticalGroup])

            let section = NSCollectionLayoutSection(group: horizontalGroup)
            return UICollectionViewCompositionalLayout(section: section)
//        }
//
//        let section = NSCollectionLayoutSection(group: verticalGroup)
//        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension FxHomeRecentlyVisitedCollectionCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // If there are 3 or less tabs, we can return the standard count, as we don't need
        // to display filler cells. However, if we have 4, 5, 7, or 8 items, we will
        // need to display filler cells to make the collection view behave according
        // to the specified design.
        if let count = viewModel?.historyItems.count, count <= 3 {
            return count
        } else if [4, 5].contains(viewModel?.historyItems.count) {
            return 6
        } else if [7, 8].contains(viewModel?.historyItems.count) {
            return 9
        }

        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecentlyVisitedCell.cellIdentifier, for: indexPath) as! RecentlyVisitedCell
        let hideBottomLine = isBottomCell(indexPath: indexPath, totalItems: viewModel?.historyItems.count)
        let cornersToRound = determineCornerToRound(indexPath: indexPath, totalItems: viewModel?.historyItems.count)

        if let item = viewModel?.historyItems[safe: indexPath.row] {
            let itemURL = item.url?.absoluteString ?? ""
            let site = Site(url: itemURL, title: item.displayTitle, bookmarked: true)
            SiteImageHelper(profile: profile!).fetchImageFor(site: site,
                                                                imageType: .favicon,
                                                                shouldFallback: true) { image in
                let cellOptions = RecentlyVisitedCellOptions(title: site.title,
                                                             shouldHideBottomLine: hideBottomLine,
                                                             with: cornersToRound,
                                                             and: image,
                                                             andIsFillerCell: false)

                cell.updateCell(with: cellOptions)
            }
        } else {
            let cellOptions = RecentlyVisitedCellOptions(shouldHideBottomLine: hideBottomLine,
                                                         with: cornersToRound,
                                                         andIsFillerCell: true)

            cell.updateCell(with: cellOptions)
        }

        return cell
    }

    private func isBottomCell(indexPath: IndexPath, totalItems: Int?) -> Bool {
        guard let totalItems = totalItems else { return false }
        // One cell
        if totalItems == 1
            // Two cells and index is bottom cell
            || (totalItems == 2 && indexPath.row == 1)
            || (totalItems == 3 && indexPath.row == 2)
            // More than two cells AND is a bottom cell in the column
            || ((totalItems > 3 && totalItems <= 6) && ([2, 5].contains(indexPath.row)))
            || ((totalItems >= 7 && totalItems <= 9) && ([2, 5, 8].contains(indexPath.row))) {
            return true
        }

        return false
    }

    private func determineCornerToRound(indexPath: IndexPath, totalItems: Int?) -> UIRectCorner {
        guard let totalItems = totalItems else { return [] }
        var cornersToRound = UIRectCorner()

        if isTopLeftCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.topLeft) }
        if isTopRightCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.topRight) }
        if isBottomLeftCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.bottomLeft) }
        if isBottomRightCell(index: indexPath.row, totalItems: totalItems) { cornersToRound.insert(.bottomRight) }

        return cornersToRound
    }

    private func isTopLeftCell(index: Int, totalItems: Int) -> Bool {
        if index == 0 { return true }

        return false
    }

    private func isTopRightCell(index: Int, totalItems: Int) -> Bool {
        if totalItems > 6 && index == 6 { return true }
        if totalItems > 3 && totalItems < 7 && index == 3 { return true }
        if totalItems <= 3 && index == 0 { return true }

        return false
    }

    private func isBottomLeftCell(index: Int, totalItems: Int) -> Bool {
        if totalItems >= 3 && index == 2 { return true }
        if totalItems == 2 && index == 1 { return true }
        if totalItems == 1 && index == 0 { return true }

        return false
    }

    private func isBottomRightCell(index: Int, totalItems: Int) -> Bool {
        if totalItems > 6 && index == 8 { return true }
        if totalItems > 3 && totalItems < 7 && index == 5 { return true }
        if totalItems == 3 && index == 2 { return true }
        if totalItems == 2 && index == 2 { return true }
        if totalItems == 1 && index == 0 { return true }

        return false
    }
}

extension FxHomeRecentlyVisitedCollectionCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
//        if let tab = viewModel.jumpableTabs[safe: indexPath.row] {
//            viewModel.switchTo(tab)
//        }
        print("section: \(indexPath.section) row: \(indexPath.row)")
    }
}

// MARK: - RecentlyVisitedCell

private struct RecentlyVisitedCellUX {
    static let generalCornerRadius: CGFloat = 10
    static let titleFontSize: CGFloat = 17
    static let detailsFontSize: CGFloat = 12
    static let labelsWrapperSpacing: CGFloat = 4
    static let heroImageDimension: CGFloat = 24
}

struct RecentlyVisitedCellOptions {
    let title: String
    let heroImage: UIImage?
    let corners: UIRectCorner?
    let hideBottomLine: Bool
    let isFillerCell: Bool

    init(title: String, shouldHideBottomLine: Bool, with corners: UIRectCorner? = nil, and heroImage: UIImage? = nil, andIsFillerCell: Bool) {
        self.title = title
        self.hideBottomLine = shouldHideBottomLine
        self.corners = corners
        self.heroImage = heroImage
        self.isFillerCell = andIsFillerCell
    }

    init(shouldHideBottomLine: Bool, with corners: UIRectCorner? = nil, andIsFillerCell: Bool) {
        self.init(title: "", shouldHideBottomLine: shouldHideBottomLine, with: corners, and: nil, andIsFillerCell: andIsFillerCell)
    }
}

/// A cell used in FxHomeScreen's Jump Back In section.
class RecentlyVisitedCell: UICollectionViewCell {

    // MARK: - Properties
    static let cellIdentifier = "recentlyVisitedCell"

    // UI
    let heroImage: UIImageView = .build { imageView in
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = RecentlyVisitedCellUX.generalCornerRadius
        imageView.image = UIImage.templateImageNamed("recently_closed")
    }

    let itemTitle: UILabel = .build { label in
        label.adjustsFontSizeToFitWidth = false
        label.font = UIFont.systemFont(ofSize: RecentlyVisitedCellUX.titleFontSize)
    }

    let bottomLine: UIView = .build { line in
        line.isHidden = false
    }

    let hiddenContainer: UIView = .build { container in

    }

    var isFillerCell: Bool = false {
        didSet {
            itemTitle.isHidden = isFillerCell
            heroImage.isHidden = isFillerCell
            bottomLine.isHidden = isFillerCell
//            self.isUserInteractionEnabled = isFillerCell
        }
    }

    // MARK: - Inits
    override init(frame: CGRect) {
        super.init(frame: .zero)

        applyTheme()
        setupObservers()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateCell(with options: RecentlyVisitedCellOptions) {
        itemTitle.text = options.title
        bottomLine.alpha = options.hideBottomLine ? 0 : 1
        isFillerCell = options.isFillerCell
        heroImage.image = options.heroImage

        if let corners = options.corners {
            contentView.addRoundedCorners([corners], radius: RecentlyVisitedCellUX.generalCornerRadius)
        }
    }

    // MARK: - Helpers
    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleNotifications), name: .DisplayThemeChanged, object: nil)
    }

    private func setupLayout() {
//        contentView.layer.cornerRadius = HistoryHighlightsCellUX.generalCornerRadius
//        contentView.layer.shadowRadius = HistoryHighlightsCellUX.stackViewShadowRadius
//        contentView.layer.shadowOffset = CGSize(width: 0, height: HistoryHighlightsCellUX.stackViewShadowOffset)
//        contentView.layer.shadowColor = UIColor.theme.homePanel.shortcutShadowColor
//        contentView.layer.shadowOpacity = 0.12

        contentView.addSubview(hiddenContainer)
        contentView.addSubview(heroImage)
        contentView.addSubview(itemTitle)
        contentView.addSubview(bottomLine)

        NSLayoutConstraint.activate([
            hiddenContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -5),
            hiddenContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hiddenContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hiddenContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            heroImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            heroImage.heightAnchor.constraint(equalToConstant: RecentlyVisitedCellUX.heroImageDimension),
            heroImage.widthAnchor.constraint(equalToConstant: RecentlyVisitedCellUX.heroImageDimension),
            heroImage.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            itemTitle.heightAnchor.constraint(equalToConstant: 22),
            itemTitle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            itemTitle.leadingAnchor.constraint(equalTo: heroImage.trailingAnchor, constant: 12),
            itemTitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            bottomLine.heightAnchor.constraint(equalToConstant: 0.5),
            bottomLine.leadingAnchor.constraint(equalTo: itemTitle.leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -25),
            bottomLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    @objc private func handleNotifications(_ notification: Notification) {
        switch notification.name {
        case .DisplayThemeChanged:
            applyTheme()
        default: break
        }
    }
}

extension RecentlyVisitedCell: NotificationThemeable {
    func applyTheme() {
        contentView.backgroundColor = UIColor.theme.homePanel.recentlySavedBookmarkCellBackground
        hiddenContainer.backgroundColor = UIColor.theme.homePanel.recentlySavedBookmarkCellBackground
        heroImage.tintColor = UIColor.theme.homePanel.recentlyVisitedCellGroupImage
        bottomLine.backgroundColor = UIColor.theme.homePanel.recentlyVisitedCellBottomLine
    }
}
