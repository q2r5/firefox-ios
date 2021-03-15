// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import Foundation
import SnapKit
import Shared

class SnackBarUX {
    static var MaxWidth: CGFloat = 400
    static let BorderWidth: CGFloat = 0.5
}

/**
 * A specialized version of UIButton for use in SnackBars. These are displayed evenly
 * spaced in the bottom of the bar. The main convenience of these is that you can pass
 * in a callback in the constructor (although these also style themselves appropriately).
 */
typealias SnackBarCallback = (_ bar: SnackBar) -> Void
class SnackButton: UIButton {
    let callback: SnackBarCallback?
    fileprivate var bar: SnackBar!

    override open var isHighlighted: Bool {
        didSet {
            self.backgroundColor = isHighlighted ? UIColor.theme.snackbar.highlight : .clear
        }
    }

    init(title: String, accessibilityIdentifier: String, bold: Bool = false, callback: @escaping SnackBarCallback) {
        self.callback = callback

        super.init(frame: .zero)

        if bold {
            titleLabel?.font = DynamicFontHelper.defaultHelper.DefaultStandardFontBold
        } else {
            titleLabel?.font = DynamicFontHelper.defaultHelper.DefaultStandardFont
        }
        titleLabel?.adjustsFontForContentSizeCategory = false
        setTitle(title, for: .normal)
        translatesAutoresizingMaskIntoConstraints = false
        setTitleColor(UIColor.theme.snackbar.highlightText, for: .highlighted)
        setTitleColor(UIColor.theme.snackbar.title, for: .normal)
        addTarget(self, action: #selector(onClick), for: .touchUpInside)
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func onClick() {
        callback?(bar)
    }

    func drawSeparator() {
        let separator: UIView = .build()
        separator.backgroundColor = UIColor.theme.snackbar.border
        self.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            separator.widthAnchor.constraint(equalToConstant: SnackBarUX.BorderWidth),
            separator.topAnchor.constraint(equalTo: self.topAnchor),
            separator.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

}

class SnackBar: UIView {
    let snackbarClassIdentifier: String
    let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    private lazy var imageView: UIImageView = .build { imageView in
        imageView.contentMode = .scaleAspectFit
        // These are required to make sure that the image is _never_ smaller or larger than its actual size
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private lazy var textLabel: UILabel = .build { label in
        label.font = DynamicFontHelper.defaultHelper.DefaultStandardFont
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.numberOfLines = 0
        label.textColor = UIColor.Photon.Grey90 // If making NotificationThemeable, change to UIColor.theme.tableView.rowText
        label.backgroundColor = UIColor.clear
    }

    private lazy var buttonsView: UIStackView = .build { stack in
        stack.distribution = .fillEqually
    }

    private lazy var titleView: UIStackView = .build { stack in
        stack.spacing = UIConstants.DefaultPadding
        stack.distribution = .fill
        stack.axis = .horizontal
        stack.alignment = .center
    }
    
    private lazy var separator: UIView = .build {
        $0.backgroundColor = UIColor.theme.snackbar.border
    }

    // The Constraint for the bottom of this snackbar. We use this to transition it
    var bottom: Constraint?

    init(text: String, img: UIImage?, snackbarClassIdentifier: String? = nil) {
        self.snackbarClassIdentifier = snackbarClassIdentifier ?? text
        super.init(frame: .zero)
        imageView.image = img ?? UIImage(named: "defaultFavicon")?.withRenderingMode(.alwaysOriginal)
        textLabel.text = text
        setup()
    }

    fileprivate func setup() {
        addSubview(backgroundView)
        titleView.addArrangedSubview(imageView)
        titleView.addArrangedSubview(textLabel)

        addSubview(titleView)
        addSubview(separator)
        addSubview(buttonsView)

        backgroundView.snp.makeConstraints { make in
            make.bottom.left.right.equalTo(self)
            make.top.equalTo(self)
        }

        NSLayoutConstraint.activate([
            titleView.topAnchor.constraint(equalTo: self.topAnchor, constant: UIConstants.DefaultPadding),
            titleView.heightAnchor.constraint(greaterThanOrEqualToConstant: UIConstants.SnackbarButtonHeight - 2 * UIConstants.DefaultPadding),
            titleView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            titleView.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor, constant: -UIConstants.DefaultPadding * 2),
            separator.topAnchor.constraint(equalTo: titleView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: SnackBarUX.BorderWidth),
            separator.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            buttonsView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            buttonsView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            buttonsView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            buttonsView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])

        backgroundColor = UIColor.clear
        self.clipsToBounds = true //overridden by masksToBounds = false
        self.layer.borderWidth = SnackBarUX.BorderWidth
        self.layer.borderColor = UIColor.theme.snackbar.border.cgColor
        self.layer.cornerRadius = 8
        self.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     * Called to check if the snackbar should be removed or not. By default, Snackbars persist forever.
     * Override this class or use a class like CountdownSnackbar if you want things expire
     * - returns: true if the snackbar should be kept alive
     */
    func shouldPersist(_ tab: Tab) -> Bool {
        return true
    }

    override func updateConstraints() {
        super.updateConstraints()
    }

    var showing: Bool {
        return alpha != 0 && self.superview != nil
    }

    func show() {
        alpha = 1
        bottom?.update(offset: 0)
    }

    func addButton(_ snackButton: SnackButton) {
        snackButton.bar = self
        buttonsView.addArrangedSubview(snackButton)

        // Only show the separator on the left of the button if it is not the first view
        if buttonsView.arrangedSubviews.count != 1 {
            snackButton.drawSeparator()
        }
        buttonsView.heightAnchor.constraint(equalToConstant: UIConstants.SnackbarButtonHeight).isActive = true
    }
}

/**
 * A special version of a snackbar that persists for at least a timeout. After that
 * it will dismiss itself on the next page load where this tab isn't showing. As long as
 * you stay on the current tab though, it will persist until you interact with it.
 */
class TimerSnackBar: SnackBar {
    fileprivate var timer: Timer?
    fileprivate var timeout: TimeInterval

    init(timeout: TimeInterval = 10, text: String, img: UIImage?) {
        self.timeout = timeout
        super.init(text: text, img: img)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func showAppStoreConfirmationBar(forTab tab: Tab, appStoreURL: URL, completion: @escaping (Bool) -> Void) {
        let bar = TimerSnackBar(text: .ExternalLinkAppStoreConfirmationTitle, img: UIImage(named: "defaultFavicon")?.withRenderingMode(.alwaysOriginal))
        let openAppStore = SnackButton(title: .AppStoreString, accessibilityIdentifier: "ConfirmOpenInAppStore", bold: true) { bar in
            tab.removeSnackbar(bar)
            UIApplication.shared.open(appStoreURL, options: [:])
            completion(true)
        }
        let cancelButton = SnackButton(title: .NotNowString, accessibilityIdentifier: "CancelOpenInAppStore", bold: false) { bar in
            tab.removeSnackbar(bar)
            completion(false)
        }
        bar.addButton(cancelButton)
        bar.addButton(openAppStore)
        tab.addSnackbar(bar)
    }

    override func show() {
        self.timer = Timer(timeInterval: timeout, target: self, selector: #selector(timerDone), userInfo: nil, repeats: false)
        RunLoop.current.add(self.timer!, forMode: RunLoop.Mode.default)
        super.show()
    }

    @objc func timerDone() {
        self.timer = nil
    }

    override func shouldPersist(_ tab: Tab) -> Bool {
        if !showing {
            return timer != nil
        }
        return super.shouldPersist(tab)
    }
}
