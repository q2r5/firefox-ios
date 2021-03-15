// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit
import SnapKit
import Shared

private struct InstructionsViewControllerUX {
    static let TopPadding = CGFloat(20)
    static let TextFont = UIFont.systemFont(ofSize: UIFont.labelFontSize)
    static let TextColor = UIColor.Photon.Grey60
    static let LinkColor = UIColor.Photon.Blue60
    static let EmptyStateSignInButtonColor = UIColor.Photon.Blue40
    static let EmptyStateSignInButtonHeight: CGFloat = 44
    static let EmptyStateSignInButtonWidth: CGFloat = 200
    static let EmptyStateTopPaddingInBetweenItems: CGFloat = 15
    static let EmptyStateSignInButtonCornerRadius: CGFloat = 8
}

protocol InstructionsViewControllerDelegate: AnyObject {
    func instructionsViewControllerDidClose(_ instructionsViewController: InstructionsViewController)
    func instructionsViewDidRequestToSignIn()
}

private func highlightLink(_ s: NSString, withColor color: UIColor) -> NSAttributedString {
    let start = s.range(of: "<")
    if start.location == NSNotFound {
        return NSAttributedString(string: s as String)
    }

    var s: NSString = s.replacingCharacters(in: start, with: "") as NSString
    let end = s.range(of: ">")
    s = s.replacingCharacters(in: end, with: "") as NSString
    let a = NSMutableAttributedString(string: s as String)
    let r = NSRange(location: start.location, length: end.location-start.location)
    a.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: r)
    return a
}

func setupHelpView(_ view: UIView, introText: String, showMeText: String, target: Any?, action: Selector?) {
    let imageView = UIImageView()
    imageView.image = UIImage(named: "emptySync")
    view.addSubview(imageView)

    let label1 = UILabel()
    view.addSubview(label1)
    label1.text = introText
    label1.numberOfLines = 0
    label1.lineBreakMode = .byWordWrapping
    label1.font = InstructionsViewControllerUX.TextFont
    label1.textColor = InstructionsViewControllerUX.TextColor
    label1.textAlignment = .center
    label1.translatesAutoresizingMaskIntoConstraints = false

    let label2 = UILabel()
    view.addSubview(label2)
    label2.numberOfLines = 0
    label2.lineBreakMode = .byWordWrapping
    label2.font = InstructionsViewControllerUX.TextFont
    label2.textColor = InstructionsViewControllerUX.TextColor
    label2.textAlignment = .center
    label2.attributedText = highlightLink(showMeText as NSString, withColor: InstructionsViewControllerUX.LinkColor)
    label2.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
        imageView.topAnchor.constraint(equalTo: view.topAnchor, constant: InstructionsViewControllerUX.TopPadding),
        imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        label1.widthAnchor.constraint(equalToConstant: 250),
        label1.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: InstructionsViewControllerUX.TopPadding),
        label1.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        label2.widthAnchor.constraint(equalToConstant: 250),
        label2.topAnchor.constraint(equalTo: label1.bottomAnchor, constant: InstructionsViewControllerUX.TopPadding),
        label2.centerXAnchor.constraint(equalTo: view.centerXAnchor)
    ])

    if let target = target, let action = action {
        let signInButton = UIButton()
        signInButton.setTitle(.FxASignInToFirefox, for: [])
        signInButton.setTitleColor(UIColor.Photon.White100, for: [])
        signInButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        signInButton.layer.cornerRadius = InstructionsViewControllerUX.EmptyStateSignInButtonCornerRadius
        signInButton.clipsToBounds = true
        signInButton.addTarget(target, action: action, for: .touchUpInside)
        signInButton.translatesAutoresizingMaskIntoConstraints = false
        signInButton.backgroundColor = InstructionsViewControllerUX.EmptyStateSignInButtonColor
        view.addSubview(signInButton)

        NSLayoutConstraint.activate([
            signInButton.widthAnchor.constraint(equalToConstant: InstructionsViewControllerUX.EmptyStateSignInButtonWidth),
            signInButton.heightAnchor.constraint(equalToConstant: InstructionsViewControllerUX.EmptyStateSignInButtonHeight),
            signInButton.topAnchor.constraint(equalTo: label2.bottomAnchor, constant: InstructionsViewControllerUX.TopPadding),
            signInButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}

class InstructionsViewController: UIViewController {
    weak var delegate: InstructionsViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        edgesForExtendedLayout = []
        view.backgroundColor = UIColor.Photon.White100

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: .SendToCloseButton, style: .done, target: self, action: #selector(close))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "InstructionsViewController.navigationItem.leftBarButtonItem"

        setupHelpView(view,
                introText: .SendToNotSignedInText,
                showMeText: .SendToNotSignedInMessage,
                target: self, action: #selector(signIn))
    }

    @objc func close() {
        delegate?.instructionsViewControllerDidClose(self)
    }

    func showMeHow() {
        print("Show me how") // TODO Not sure what to do or if to keep this. Waiting for UX feedback.
    }

    @objc fileprivate func signIn() {
       delegate?.instructionsViewDidRequestToSignIn()
    }
}
