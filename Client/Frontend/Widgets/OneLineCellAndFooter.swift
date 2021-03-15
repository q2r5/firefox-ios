// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

struct OneLineCellUX {
    static let ImageSize: CGFloat = 29
    static let ImageCornerRadius: CGFloat = 6
    static let HorizontalMargin: CGFloat = 16
}

enum OneLineTableViewCustomization {
    case regular
    case inactiveCell
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

class OneLineTableViewCell: UITableViewCell, NotificationThemeable {
    // Tableview cell items
    var selectedView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.theme.tableView.selectedBackground
        return view
    }()
    
    var leftImageView: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFit
        imgView.layer.cornerRadius = 5.0
        imgView.clipsToBounds = true
        return imgView
    }()
    
    var leftOverlayImageView: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFit
        imgView.clipsToBounds = true
        return imgView
    }()

    var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label.textAlignment = .left
        label.numberOfLines = 1
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        initialViewSetup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let containerView = UIView()
    let midView = UIView()
    var shouldLeftAlignTitle = false
    var customization: OneLineTableViewCustomization = .regular
    func initialViewSetup() {
        separatorInset = UIEdgeInsets(top: 0, left: TwoLineCellUX.ImageSize + 2 * TwoLineCellUX.BorderViewMargin, bottom: 0, right: 0)
        self.selectionStyle = .default
        midView.addSubview(titleLabel)
        containerView.addSubview(leftImageView)
        containerView.addSubview(midView)

        contentView.addSubview(containerView)
        bringSubviewToFront(containerView)
        
        containerView.snp.makeConstraints { make in
            make.height.equalTo(44)
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalTo(accessoryView?.snp.leading ?? contentView.snp.trailing)
        }

        leftImageView.snp.makeConstraints { make in
            make.height.width.equalTo(28)
            make.leading.equalTo(containerView.snp.leading).offset(15)
            make.centerY.equalTo(containerView.snp.centerY)
        }

        midView.snp.makeConstraints { make in
            make.height.equalTo(42)
            make.centerY.equalToSuperview()
            if shouldLeftAlignTitle {
                make.leading.equalTo(containerView.snp.leading).offset(5)
            } else {
                make.leading.equalTo(leftImageView.snp.trailing).offset(13)
            }
            make.trailing.equalTo(containerView.snp.trailing).offset(-7)
        }

        titleLabel.snp.makeConstraints { make in
            make.height.equalTo(40)
            make.centerY.equalTo(midView.snp.centerY)
            make.leading.equalTo(midView.snp.leading)
            make.trailing.equalTo(midView.snp.trailing)
        }
        
        selectedBackgroundView = selectedView
        applyTheme()
    }
    
    func updateMidConstraint() {
        leftImageView.snp.updateConstraints { update in
            let leadingLeft = customization == .regular ? 15 : customization == .inactiveCell ? 5 : 15
            update.leading.equalTo(containerView.snp.leading).offset(leadingLeft)
        }

        midView.snp.remakeConstraints { make in
            make.height.equalTo(42)
            make.centerY.equalToSuperview()
            if shouldLeftAlignTitle {
                make.leading.equalTo(containerView.snp.leading).offset(5)
            } else {
                make.leading.equalTo(leftImageView.snp.trailing).offset(13)
            }
            make.trailing.equalTo(containerView.snp.trailing).offset(-7)
        }
    }
    
    func applyTheme() {
        let theme = LegacyThemeManager.instance.currentName
        selectedView.backgroundColor = UIColor.theme.tableView.selectedBackground
        if theme == .dark {
            self.backgroundColor = UIColor.Photon.Grey80
            self.titleLabel.textColor = .white
        } else {
            self.backgroundColor = .white
            self.titleLabel.textColor = .black
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.selectionStyle = .default
        separatorInset = UIEdgeInsets(top: 0, left: TwoLineCellUX.ImageSize + 2 * TwoLineCellUX.BorderViewMargin, bottom: 0, right: 0)
        applyTheme()
    }
}

class OneLineFooterView: UITableViewHeaderFooterView, NotificationThemeable {
    fileprivate let bordersHelper = ThemedHeaderFooterViewBordersHelper()

    var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .left
        label.numberOfLines = 1
        return label
    }()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        initialViewSetup()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let containerView = UIView()
    var shortheight: Bool = false
    private var shortHeight = 32
    
    private func initialViewSetup() {
        bordersHelper.initBorders(view: containerView)
        setDefaultBordersValues()
        layoutMargins = .zero

        containerView.addSubview(titleLabel)
        addSubview(containerView)
        
        containerView.snp.makeConstraints { make in
            make.height.equalTo(shortheight ? 32 : 58)
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.height.equalTo(16)
            make.bottom.equalToSuperview().offset(-14)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().inset(16)
        }

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
        let theme = LegacyThemeManager.instance.currentName
        self.containerView.backgroundColor = UIColor.theme.tableView.selectedBackground
        self.titleLabel.textColor =  theme == .dark ? .white : .black
        bordersHelper.applyTheme()
    }
    
    func setupHeaderConstraint() {
        containerView.snp.remakeConstraints { make in
            make.height.equalTo(shortheight ? 32 : 58)
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        setupHeaderConstraint()
        setDefaultBordersValues()
        applyTheme()
    }
}
