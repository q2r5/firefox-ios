/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Leanplum
import Shared

struct LPVariables {
    // Variable Used for New Tab Button AB Test
    static var newTabButtonABTest = Var(name: "newTabButtonABTestProd", boolean: false)
    // Variable Used for Chron tabs AB Test
    static var chronTabsABTest = Var(name: "chronTabsABTestProd", boolean: false)
}
