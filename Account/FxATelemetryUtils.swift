// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0

import SyncTelemetry

open class FxATelemetry {
    /// Parses a JSON blob returned from `FxAccountManager#parseTelemetry()`
    /// into a list of events that can be recorded into prefs, and then
    /// included in the next Sync ping. Ignores malformed and unknown events.
    public static func parseTelemetry(fromJSONString string: String) -> [Event] {
        guard let data = string.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? [String: Any] else {
            return []
        }
        let commandsSent = (json["commands_sent"] as? Array<[String: Any]>)?.compactMap {
            sentCommand -> Event? in
                guard let flowID = sentCommand["flow_id"] as? String,
                    let streamID = sentCommand["stream_id"] as? String else {
                        return nil
                }
                let extra: [String: String] = [
                    flowID: flowID,
                    streamID: streamID,
                ]
                return Event(category: "sync",
                             method: "open-uri",
                             object: "command-sent",
                             extra: extra)
        } ?? []
        let commandsReceived = (json["commands_received"] as? Array<[String: Any]>)?.compactMap {
            receivedCommand -> Event? in
                guard let flowID = receivedCommand["flow_id"] as? String,
                    let streamID = receivedCommand["stream_id"] as? String,
                    let reason = receivedCommand["reason"] as? String else {
                        return nil
                }
                let extra: [String: String] = [
                    flowID: flowID,
                    streamID: streamID,
                    reason: reason,
                ]
                return Event(category: "sync",
                             method: "open-uri",
                             object: "command-received",
                             extra: extra)
        } ?? []
        return commandsSent + commandsReceived
    }
}
