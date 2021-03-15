// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import Shared
import XCGLogger

private let log = Logger.browserLogger

protocol TabLocationViewDelegate {
    func tabLocationViewDidTapLocation(_ tabLocationView: TabLocationView)
    func tabLocationViewDidLongPressLocation(_ tabLocationView: TabLocationView)
    func tabLocationViewDidTapReaderMode(_ tabLocationView: TabLocationView)
    func tabLocationViewDidTapReload(_ tabLocationView: TabLocationView)
    func tabLocationViewDidTapShield(_ tabLocationView: TabLocationView)
    func tabLocationViewDidTapPageOptions(_ tabLocationView: TabLocationView, from button: UIButton)
    func tabLocationViewDidLongPressPageOptions(_ tabLocationVIew: TabLocationView)
    func tabLocationViewDidBeginDragInteraction(_ tabLocationView: TabLocationView)

    /// - returns: whether the long-press was handled by the delegate; i.e. return `false` when the conditions for even starting handling long-press were not satisfied
    @discardableResult func tabLocationViewDidLongPressReaderMode(_ tabLocationView: TabLocationView) -> Bool
    func tabLocationViewDidLongPressReload(_ tabLocationView: TabLocationView)
    func tabLocationViewLocationAccessibilityActions(_ tabLocationView: TabLocationView) -> [UIAccessibilityCustomAction]?
}

private struct TabLocationViewUX {
    static let HostFontColor = UIColor.black
    static let BaseURLFontColor = UIColor.Photon.Grey50
    static let Spacing: CGFloat = 8
    static let StatusIconSize: CGFloat = 18
    static let TPIconSize: CGFloat = 44
    static let ReaderModeButtonWidth: CGFloat = 34
    static let ButtonSize: CGFloat = 44
    static let URLBarPadding = 4
}

class TabLocationView: UIView {
    var delegate: TabLocationViewDelegate?
    var longPressRecognizer: UILongPressGestureRecognizer!
    var tapRecognizer: UITapGestureRecognizer!
    var contentView: UIStackView!

    fileprivate let menuBadge = BadgeWithBackdrop(imageName: "menuBadge", backdropCircleSize: 32)

    @objc dynamic var baseURLFontColor: UIColor = TabLocationViewUX.BaseURLFontColor {
        didSet { updateTextWithURL() }
    }

    var url: URL? {
        didSet {
            updateTextWithURL()
            pageOptionsButton.isHidden = (url == nil) || ((superview as! TabLocationContainerView).superview as! URLBarView).isBottomToolbar
            trackingProtectionButton.isHidden = !["https", "http"].contains(url?.scheme ?? "")
            setNeedsUpdateConstraints()
        }
    }

    var readerModeState: ReaderModeState {
        get {
            return readerModeButton.readerModeState
        }
        set (newReaderModeState) {
            if newReaderModeState != self.readerModeButton.readerModeState {
                let wasHidden = readerModeButton.isHidden
                self.readerModeButton.readerModeState = newReaderModeState
                readerModeButton.isHidden = (newReaderModeState == ReaderModeState.unavailable)
                if wasHidden != readerModeButton.isHidden {
                    UIAccessibility.post(notification: UIAccessibility.Notification.layoutChanged, argument: nil)
                    if !readerModeButton.isHidden {
                        // Delay the Reader Mode accessibility announcement briefly to prevent interruptions.
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                            UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: String.ReaderModeAvailableVoiceOverAnnouncement)
                        }
                    }
                }
                UIView.animate(withDuration: 0.1, animations: { () -> Void in
                    self.readerModeButton.alpha = newReaderModeState == .unavailable ? 0 : 1
                })
            }
        }
    }

    lazy var placeholder: NSAttributedString = {
        return NSAttributedString(string: .TabLocationURLPlaceholder, attributes: [NSAttributedString.Key.foregroundColor: UIColor.Photon.Grey50])
    }()

    lazy var urlTextField: UITextField = {
        let urlTextField = DisplayTextField()

        // Prevent the field from compressing the toolbar buttons on the 4S in landscape.
        urlTextField.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 250), for: .horizontal)
        urlTextField.attributedPlaceholder = self.placeholder
        urlTextField.accessibilityIdentifier = "url"
        urlTextField.accessibilityActionsSource = self
        urlTextField.font = UIConstants.DefaultChromeFont
        urlTextField.backgroundColor = .clear
        urlTextField.accessibilityLabel = "Address Bar"
        urlTextField.font = UIFont.preferredFont(forTextStyle: .body)
        urlTextField.adjustsFontForContentSizeCategory = true
        urlTextField.translatesAutoresizingMaskIntoConstraints = false

        // Remove the default drop interaction from the URL text field so that our
        // custom drop interaction on the BVC can accept dropped URLs.
        if let dropInteraction = urlTextField.textDropInteraction {
            urlTextField.removeInteraction(dropInteraction)
        }

        return urlTextField
    }()

    lazy var trackingProtectionButton: UIButton = .build { [weak self] trackingProtectionButton in
        trackingProtectionButton.setImage(UIImage.templateImageNamed("lock_verified"), for: .normal)
        trackingProtectionButton.addTarget(self, action: #selector(self?.didPressTPShieldButton(_:)), for: .touchUpInside)
        trackingProtectionButton.tintColor = UIColor.Photon.Grey50
        trackingProtectionButton.imageView?.contentMode = .scaleAspectFill
        trackingProtectionButton.clipsToBounds = false
        trackingProtectionButton.accessibilityIdentifier = AccessibilityIdentifiers.TabLocationView.trackingProtectionButton
    }

    fileprivate lazy var readerModeButton: ReaderModeButton = .build { [weak self] readerModeButton in
        readerModeButton.addTarget(self, action: #selector(self?.tapReaderModeButton), for: .touchUpInside)
        readerModeButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self?.longPressReaderModeButton)))
        readerModeButton.isAccessibilityElement = true
        readerModeButton.isHidden = true
        readerModeButton.imageView?.contentMode = .scaleAspectFit
        readerModeButton.contentHorizontalAlignment = .left
        readerModeButton.accessibilityLabel = .TabLocationReaderModeAccessibilityLabel
        readerModeButton.accessibilityIdentifier = AccessibilityIdentifiers.TabLocationView.readerModeButton
        readerModeButton.accessibilityCustomActions = [UIAccessibilityCustomAction(name: .TabLocationReaderModeAddToReadingListAccessibilityLabel, target: self, selector: #selector(self?.readerModeCustomAction))]
    }

    lazy var reloadButton: StatefulButton = {
        let reloadButton = StatefulButton(frame: .zero, state: .disabled)
        reloadButton.addTarget(self, action: #selector(tapReloadButton), for: .touchUpInside)
        reloadButton.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressReloadButton)))
        reloadButton.tintColor = UIColor.Photon.Grey50
        reloadButton.imageView?.contentMode = .scaleAspectFit
        reloadButton.contentHorizontalAlignment = .left
        reloadButton.accessibilityLabel = .TabLocationReloadAccessibilityLabel
        reloadButton.accessibilityIdentifier = AccessibilityIdentifiers.TabLocationView.reloadButton
        reloadButton.isAccessibilityElement = true
        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        return reloadButton
    }()
    
    lazy var pageOptionsButton: ToolbarButton = .build { [weak self] pageOptionsButton in
        pageOptionsButton.setImage(UIImage.templateImageNamed("menu-More-Options"), for: .normal)
        pageOptionsButton.addTarget(self, action: #selector(self?.didPressPageOptionsButton), for: .touchUpInside)
        pageOptionsButton.isAccessibilityElement = true
        pageOptionsButton.isHidden = true
        pageOptionsButton.imageView?.contentMode = .left
        pageOptionsButton.accessibilityLabel = .TabLocationPageOptionsAccessibilityLabel
        pageOptionsButton.accessibilityIdentifier = AccessibilityIdentifiers.TabLocationView.pageOptionsButton
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self?.didLongPressPageOptionsButton))
        pageOptionsButton.addGestureRecognizer(longPressGesture)
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.layer.cornerRadius = 2
        return line
    }

    // A vertical separator next to the page options button.
    lazy var separatorLineForPageOptions: UIView = makeSeparator()

    override init(frame: CGRect) {
        super.init(frame: frame)

        register(self, forTabEvents: .didGainFocus, .didToggleDesktopMode, .didChangeContentBlocking)

        translatesAutoresizingMaskIntoConstraints = false

        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressLocation))
        longPressRecognizer.delegate = self

        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapLocation))
        tapRecognizer.delegate = self

        addGestureRecognizer(longPressRecognizer)
        addGestureRecognizer(tapRecognizer)

        let space1px: UIView = .build()

        pageOptionsButton.separatorLine = separatorLineForPageOptions

        let subviews = [trackingProtectionButton, space1px, urlTextField, readerModeButton, reloadButton, separatorLineForPageOptions, pageOptionsButton]
        contentView = UIStackView(arrangedSubviews: subviews)
        contentView.distribution = .fill
        contentView.alignment = .center
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            space1px.widthAnchor.constraint(equalToConstant: 1),
            contentView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            contentView.topAnchor.constraint(equalTo: self.topAnchor),
            contentView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            trackingProtectionButton.widthAnchor.constraint(equalToConstant: TabLocationViewUX.TPIconSize),
            trackingProtectionButton.heightAnchor.constraint(equalToConstant: TabLocationViewUX.ButtonSize),
            pageOptionsButton.widthAnchor.constraint(equalToConstant: TabLocationViewUX.ButtonSize),
            pageOptionsButton.heightAnchor.constraint(equalToConstant: TabLocationViewUX.ButtonSize),
            separatorLineForPageOptions.widthAnchor.constraint(equalToConstant: 1),
            separatorLineForPageOptions.heightAnchor.constraint(equalToConstant: 26),
            readerModeButton.widthAnchor.constraint(equalToConstant: TabLocationViewUX.ReaderModeButtonWidth),
            readerModeButton.heightAnchor.constraint(equalToConstant: TabLocationViewUX.ButtonSize),
            reloadButton.widthAnchor.constraint(equalToConstant: TabLocationViewUX.ReaderModeButtonWidth),
            reloadButton.heightAnchor.constraint(equalToConstant: TabLocationViewUX.ButtonSize)
        ])

        // Setup UIDragInteraction to handle dragging the location
        // bar for dropping its URL into other apps.
        let dragInteraction = UIDragInteraction(delegate: self)
        dragInteraction.allowsSimultaneousRecognitionDuringLift = true
        self.addInteraction(dragInteraction)

        menuBadge.add(toParent: contentView)
        menuBadge.layout(onButton: pageOptionsButton)
        menuBadge.show(false)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var _accessibilityElements = [urlTextField, readerModeButton, reloadButton, pageOptionsButton, trackingProtectionButton]

    override var accessibilityElements: [Any]? {
        get {
            return _accessibilityElements.filter { !$0.isHidden }
        }
        set {
            super.accessibilityElements = newValue
        }
    }

    func overrideAccessibility(enabled: Bool) {
        _accessibilityElements.forEach {
            $0.isAccessibilityElement = enabled
        }
    }

    @objc func tapReaderModeButton() {
        delegate?.tabLocationViewDidTapReaderMode(self)
    }

    @objc func tapReloadButton() {
        delegate?.tabLocationViewDidTapReload(self)
    }

    @objc func longPressReaderModeButton(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            delegate?.tabLocationViewDidLongPressReaderMode(self)
        }
    }

    @objc func longPressReloadButton(_ recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .began {
            delegate?.tabLocationViewDidLongPressReload(self)
        }
    }

    @objc func didPressPageOptionsButton(_ button: UIButton) {
        delegate?.tabLocationViewDidTapPageOptions(self, from: button)
    }

    @objc func didLongPressPageOptionsButton(_ recognizer: UILongPressGestureRecognizer) {
        delegate?.tabLocationViewDidLongPressPageOptions(self)
    }

    @objc func longPressLocation(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .began {
            delegate?.tabLocationViewDidLongPressLocation(self)
        }
    }

    @objc func tapLocation(_ recognizer: UITapGestureRecognizer) {
        delegate?.tabLocationViewDidTapLocation(self)
    }

    @objc func didPressTPShieldButton(_ button: UIButton) {
        delegate?.tabLocationViewDidTapShield(self)
    }

    @objc func readerModeCustomAction() -> Bool {
        return delegate?.tabLocationViewDidLongPressReaderMode(self) ?? false
    }

    fileprivate func updateTextWithURL() {
        var text: String?
        if let host = url?.host, AppConstants.MOZ_PUNYCODE {
            text = url?.absoluteString.replacingOccurrences(of: host, with: host.asciiHostToUTF8())
        } else {
            text = url?.absoluteString
        }
        // remove https:// (the scheme) from the url when displaying
        if let scheme = url?.scheme, let range = url?.absoluteString.range(of: "\(scheme)://") {
            text = url?.absoluteString.replacingCharacters(in: range, with: "")
        }
        if let baseDomain = url?.baseDomain, let text = text {
            let range = (text as NSString).localizedStandardRange(of: baseDomain)
            guard range.location != NSNotFound else { return }
            let attributedURL = NSMutableAttributedString(string: text)
            attributedURL.addAttribute(.foregroundColor, value: UIColor.theme.textField.domainTint, range: NSMakeRange(0, text.count))
            attributedURL.addAttribute(.foregroundColor, value: UIColor.theme.textField.textAndTint, range: range)
            urlTextField.attributedText = attributedURL
        }
    }
}

extension TabLocationView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // When long pressing a button make sure the textfield's long press gesture is not triggered
        return !(otherGestureRecognizer.view is UIButton)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // If the longPressRecognizer is active, fail the tap recognizer to avoid conflicts.
        return gestureRecognizer == longPressRecognizer && otherGestureRecognizer == tapRecognizer
    }
}

extension TabLocationView: UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        // Ensure we actually have a URL in the location bar and that the URL is not local.
        guard let url = self.url, !InternalURL.isValid(url: url), let itemProvider = NSItemProvider(contentsOf: url) else {
            return []
        }

        TelemetryWrapper.recordEvent(category: .action, method: .drag, object: .locationBar)

        let dragItem = UIDragItem(itemProvider: itemProvider)
        return [dragItem]
    }

    func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: UIDragSession) {
        delegate?.tabLocationViewDidBeginDragInteraction(self)
    }
}

extension TabLocationView: AccessibilityActionsSource {
    func accessibilityCustomActionsForView(_ view: UIView) -> [UIAccessibilityCustomAction]? {
        if view === urlTextField {
            return delegate?.tabLocationViewLocationAccessibilityActions(self)
        }
        return nil
    }
}

extension TabLocationView: NotificationThemeable {
    func applyTheme() {
        readerModeButton.selectedTintColor = UIColor.theme.urlbar.readerModeButtonSelected
        readerModeButton.unselectedTintColor = UIColor.theme.urlbar.readerModeButtonUnselected
        
        pageOptionsButton.selectedTintColor = UIColor.theme.urlbar.pageOptionsSelected
        pageOptionsButton.unselectedTintColor = UIColor.theme.urlbar.pageOptionsUnselected
        pageOptionsButton.tintColor = pageOptionsButton.unselectedTintColor
        separatorLineForPageOptions.backgroundColor = UIColor.Photon.Grey40

        trackingProtectionButton.tintColor = pageOptionsButton.tintColor

        let color = LegacyThemeManager.instance.currentName == .dark ? UIColor(white: 0.3, alpha: 0.6): UIColor.theme.textField.background
        menuBadge.badge.tintBackground(color: color)

        updateTextWithURL()
    }
}

extension TabLocationView: TabEventHandler {
    func tabDidChangeContentBlocking(_ tab: Tab) {
        updateBlockerStatus(forTab: tab)
    }

    private func updateBlockerStatus(forTab tab: Tab) {
        assertIsMainThread("UI changes must be on the main thread")
        guard let blocker = tab.contentBlocker else { return }
        trackingProtectionButton.alpha = 1.0

        var lockImage: UIImage
        let imageID = LegacyThemeManager.instance.currentName == .dark ? "lock_blocked_dark" : "lock_blocked"
        if !(tab.isSecureConnection) &&
           !(tab.webView?.serverTrust != nil && SecTrustEvaluateWithError(tab.webView!.serverTrust!, nil)) {
            lockImage = UIImage(imageLiteralResourceName: imageID)

        } else {
            lockImage = UIImage(imageLiteralResourceName: "lock_verified").withTintColor(pageOptionsButton.tintColor, renderingMode: .alwaysTemplate)

        }

        switch blocker.status {
        case .blocking, .noBlockedURLs:
            trackingProtectionButton.setImage(lockImage, for: .normal)
        case .safelisted:
            trackingProtectionButton.setImage(lockImage.overlayWith(image: UIImage(imageLiteralResourceName: "MarkAsRead")), for: .normal)
        case .disabled:
            trackingProtectionButton.setImage(lockImage, for: .normal)
        }
    }

    func tabDidGainFocus(_ tab: Tab) {
        updateBlockerStatus(forTab: tab)
    }
}

enum ReloadButtonState: String {
    case reload = "Reload"
    case stop = "Stop"
    case disabled = "Disabled"
}

class StatefulButton: UIButton {
    convenience init(frame: CGRect, state: ReloadButtonState) {
        self.init(frame: frame)
        reloadButtonState = state
    }

    required override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var _reloadButtonState = ReloadButtonState.disabled
    
    var reloadButtonState: ReloadButtonState {
        get {
            return _reloadButtonState
        }
        set (newReloadButtonState) {
            _reloadButtonState = newReloadButtonState
            switch _reloadButtonState {
            case .reload:
                setImage(UIImage.templateImageNamed("nav-refresh"), for: .normal)
            case .stop:
                setImage(UIImage.templateImageNamed("nav-stop"), for: .normal)
            case .disabled:
                self.isHidden = true
            }
        }
    }
}

class ReaderModeButton: UIButton {
    var selectedTintColor: UIColor? {
        didSet {
            setNeedsUpdateConfiguration()
        }
    }
    var unselectedTintColor: UIColor? {
        didSet {
            setNeedsUpdateConfiguration()
        }
    }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configuration = .plain()
        configuration?.image = UIImage.templateImageNamed("reader")
        configuration?.imagePlacement = .leading
        configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5)
        self.configurationUpdateHandler = { [unowned self] button in
            var config = configuration
            config?.imageColorTransformer = UIConfigurationColorTransformer() { baseColor -> UIColor in
                return ((isHighlighted || isSelected) ? selectedTintColor : unselectedTintColor) ?? baseColor
            }
            config?.baseBackgroundColor = .clear
            button.configuration = config
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var _readerModeState = ReaderModeState.unavailable

    var readerModeState: ReaderModeState {
        get {
            return _readerModeState
        }
        set (newReaderModeState) {
            _readerModeState = newReaderModeState
            switch _readerModeState {
            case .available:
                self.isEnabled = true
                self.isSelected = false
            case .unavailable:
                self.isEnabled = false
                self.isSelected = false
            case .active:
                self.isEnabled = true
                self.isSelected = true
            }
        }
    }
}

private class DisplayTextField: UITextField {
    weak var accessibilityActionsSource: AccessibilityActionsSource?

    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            return accessibilityActionsSource?.accessibilityCustomActionsForView(self)
        }
        set {
            super.accessibilityCustomActions = newValue
        }
    }

    fileprivate override var canBecomeFirstResponder: Bool {
        return false
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: TabLocationViewUX.Spacing, dy: 0)
    }
}
