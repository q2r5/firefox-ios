// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import Shared

protocol FindInPageBarDelegate: AnyObject {
    func findInPage(_ findInPage: FindInPageBar, didTextChange text: String)
    func findInPage(_ findInPage: FindInPageBar, didFindPreviousWithText text: String)
    func findInPage(_ findInPage: FindInPageBar, didFindNextWithText text: String)
    func findInPageDidPressClose(_ findInPage: FindInPageBar)
}

private struct FindInPageUX {
    static let ButtonColor = UIColor.black
    static let MatchCountColor = UIColor.Photon.Grey40
    static let MatchCountFont = UIConstants.DefaultChromeFont
    static let SearchTextColor = UIColor.Photon.Orange60
    static let SearchTextFont = UIConstants.DefaultChromeFont
    static let TopBorderColor = UIColor.Photon.Grey20
}

class FindInPageBar: UIView {
    weak var delegate: FindInPageBarDelegate?
    fileprivate let searchText: UITextField = .build { textField in
        textField.addTarget(self, action: #selector(didTextChange), for: .editingChanged)
        textField.textColor = FindInPageUX.SearchTextColor
        textField.font = FindInPageUX.SearchTextFont
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.inputAssistantItem.leadingBarButtonGroups = []
        textField.inputAssistantItem.trailingBarButtonGroups = []
        textField.enablesReturnKeyAutomatically = true
        textField.returnKeyType = .search
        textField.accessibilityIdentifier = "FindInPage.searchField"
    }

    fileprivate let matchCountView: UILabel = .build { label in
        label.textColor = FindInPageUX.MatchCountColor
        label.font = FindInPageUX.MatchCountFont
        label.isHidden = true
        label.accessibilityIdentifier = "FindInPage.matchCount"
    }

    fileprivate let previousButton: UIButton = .build { button in
        button.setImage(UIImage(named: "find_previous"), for: [])
        button.setTitleColor(FindInPageUX.ButtonColor, for: [])
        button.accessibilityLabel = .FindInPagePreviousAccessibilityLabel
        button.addTarget(self, action: #selector(didFindPrevious), for: .touchUpInside)
        button.accessibilityIdentifier = "FindInPage.find_previous"
    }

    fileprivate let nextButton: UIButton = .build { button in
        button.setImage(UIImage(named: "find_next"), for: [])
        button.setTitleColor(FindInPageUX.ButtonColor, for: [])
        button.accessibilityLabel = .FindInPageNextAccessibilityLabel
        button.addTarget(self, action: #selector(didFindNext), for: .touchUpInside)
        button.accessibilityIdentifier = "FindInPage.find_next"
    }

    fileprivate let closeButton: UIButton = .build { button in
        button.setImage(UIImage(named: "find_close"), for: [])
        button.setTitleColor(FindInPageUX.ButtonColor, for: [])
        button.accessibilityLabel = .FindInPageDoneAccessibilityLabel
        button.addTarget(self, action: #selector(didPressClose), for: .touchUpInside)
        button.accessibilityIdentifier = "FindInPage.close"
    }

    var currentResult = 0 {
        didSet {
            if totalResults > 500 {
                matchCountView.text = "\(currentResult)/500+"
            } else {
                matchCountView.text = "\(currentResult)/\(totalResults)"
            }
        }
    }

    var totalResults = 0 {
        didSet {
            if totalResults > 500 {
                matchCountView.text = "\(currentResult)/500+"
            } else {
                matchCountView.text = "\(currentResult)/\(totalResults)"
            }
            previousButton.isEnabled = totalResults > 1
            nextButton.isEnabled = previousButton.isEnabled
        }
    }

    var text: String? {
        get {
            return searchText.text
        }

        set {
            searchText.text = newValue
            didTextChange(searchText)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .white

        searchText.delegate = self

        let topBorder: UIView = .build()
        topBorder.backgroundColor = FindInPageUX.TopBorderColor

        addSubviews(searchText, matchCountView, previousButton, nextButton, closeButton, topBorder)

        NSLayoutConstraint.activate([
            searchText.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            searchText.topAnchor.constraint(equalTo: self.topAnchor),
            searchText.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            matchCountView.leadingAnchor.constraint(equalTo: searchText.trailingAnchor),
            matchCountView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            previousButton.leadingAnchor.constraint(equalTo: matchCountView.trailingAnchor),
            previousButton.heightAnchor.constraint(equalTo: self.heightAnchor),
            previousButton.widthAnchor.constraint(equalTo: self.heightAnchor),
            previousButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            nextButton.leadingAnchor.constraint(equalTo: previousButton.trailingAnchor),
            nextButton.heightAnchor.constraint(equalTo: self.heightAnchor),
            nextButton.widthAnchor.constraint(equalTo: self.heightAnchor),
            nextButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: nextButton.trailingAnchor),
            closeButton.heightAnchor.constraint(equalTo: self.heightAnchor),
            closeButton.widthAnchor.constraint(equalTo: self.heightAnchor),
            closeButton.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 1),
            topBorder.leftAnchor.constraint(equalTo: self.leftAnchor),
            topBorder.rightAnchor.constraint(equalTo: self.rightAnchor),
            topBorder.topAnchor.constraint(equalTo: self.topAnchor)
        ])

        searchText.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchText.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        matchCountView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        matchCountView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult override func becomeFirstResponder() -> Bool {
        searchText.becomeFirstResponder()
        return super.becomeFirstResponder()
    }

    @objc fileprivate func didFindPrevious(_ sender: UIButton) {
        delegate?.findInPage(self, didFindPreviousWithText: searchText.text ?? "")
    }

    @objc fileprivate func didFindNext(_ sender: UIButton) {
        delegate?.findInPage(self, didFindNextWithText: searchText.text ?? "")
    }

    @objc fileprivate func didTextChange(_ sender: UITextField) {
        matchCountView.isHidden = searchText.text?.trimmingCharacters(in: .whitespaces).isEmpty ?? true
        delegate?.findInPage(self, didTextChange: searchText.text ?? "")
    }

    @objc fileprivate func didPressClose(_ sender: UIButton) {
        delegate?.findInPageDidPressClose(self)
    }
}

extension FindInPageBar: UITextFieldDelegate {
    // Keyboard with a .search returnKeyType doesn't dismiss when return pressed. Handle this manually.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string == "\n" {
            textField.resignFirstResponder()
            return false
        }
        return true
    }
}
