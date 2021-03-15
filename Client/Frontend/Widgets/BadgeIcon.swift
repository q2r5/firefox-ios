// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

class ToolbarBadge: UIView {
    private let badgeSize: CGFloat
    private let badgeOffset = CGFloat(10)
    private let background: UIImageView
    private let badge: UIImageView

    init(imageName: String, imageMask: String, size: CGFloat, tint: UIColor? = nil) {
        badgeSize = size
        background = UIImageView(image: UIImage(imageLiteralResourceName: imageMask))
        badge = UIImageView(image: UIImage(imageLiteralResourceName: imageName))
        badge.tintColor = tint
        super.init(frame: CGRect(width: badgeSize, height: badgeSize))
        addSubview(background)
        addSubview(badge)
        isUserInteractionEnabled = false

        [background, badge].forEach {
            $0.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layout(onButton button: UIView) {
        snp.remakeConstraints { make in
            make.size.equalTo(badgeSize)
            make.centerX.equalTo(button).offset(badgeOffset)
            make.centerY.equalTo(button).offset(-badgeOffset)
        }
    }

    func tintBackground(color: UIColor) {
        background.tintColor = color
    }
}

// Puts a backdrop (i.e. dark highlight) circle on the badged button.
class BadgeWithBackdrop {
    let badge: ToolbarBadge
    var backdrop: UIView
    private let backdropCircleSize: CGFloat
    private let backdropCircleColor: UIColor?
    static let backdropAlpha = CGFloat(0.05)

    private static func makeCircle(color: UIColor?, size: CGFloat) -> UIView {
        let circle = UIView()
        circle.alpha = BadgeWithBackdrop.backdropAlpha
        circle.layer.cornerRadius = size / 2
        if let c = color {
            circle.backgroundColor = c
        } else {
            circle.backgroundColor = .black
        }
        return circle
    }

    init(imageName: String, imageMask: String = "badge-mask", imageTint: UIColor? = nil, backdropCircleColor: UIColor? = nil, backdropCircleSize: CGFloat = 40, badgeSize: CGFloat = 20) {
        self.backdropCircleColor = backdropCircleColor
        self.backdropCircleSize = backdropCircleSize
        badge = ToolbarBadge(imageName: imageName, imageMask: imageMask, size: badgeSize, tint: imageTint)
        badge.isHidden = true
        backdrop = BadgeWithBackdrop.makeCircle(color: backdropCircleColor, size: backdropCircleSize)
        backdrop.isHidden = true
        backdrop.isUserInteractionEnabled = false
        backdrop.translatesAutoresizingMaskIntoConstraints = false
    }

    func add(toParent parent: UIView) {
        parent.addSubview(badge)
        parent.addSubview(backdrop)
    }

    func layout(onButton button: UIView) {
        badge.layout(onButton: button)
        NSLayoutConstraint.activate([
            backdrop.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            backdrop.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            backdrop.widthAnchor.constraint(equalToConstant: backdropCircleSize),
            backdrop.heightAnchor.constraint(equalToConstant: backdropCircleSize),
        ])
        button.superview?.sendSubviewToBack(backdrop)
    }

    func show(_ visible: Bool) {
        badge.isHidden = !visible
        backdrop.isHidden = !visible
    }
}
