// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import UIKit

// MARK: - Common UITableView text styling
extension NSAttributedString {
    static func tableRowTitle(_ string: String, enabled: Bool) -> NSAttributedString {
        let color = enabled ? [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText] : [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.disabledRowText]
        return NSAttributedString(string: string, attributes: color)
    }
}

extension AttributedString {
    static func tableRowTitle(_ string: String, enabled: Bool) -> AttributedString {
        let color = enabled ? [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.rowText] : [NSAttributedString.Key.foregroundColor: UIColor.theme.tableView.disabledRowText]
        return AttributedString(string, attributes: .init(color))
    }
}
