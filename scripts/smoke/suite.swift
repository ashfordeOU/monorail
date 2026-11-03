// Plays Keeper on the shared channel: leaves an awake.on request for Monorail, rings the doorbell,
// and waits for the answer. Exits 0 when Monorail answers ok.
import Foundation
let root = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Group Containers/D69G45342Y.group.ashforde.suite/Library/Application Support/Ashforde")
let id = "smoke" + String(Int(Date().timeIntervalSince1970) % 100000)
let requests = root.appendingPathComponent("requests/monorail")
try? FileManager.default.createDirectory(at: requests, withIntermediateDirectories: true)
let request: [String: Any] = ["id": id, "from": "keeper", "op": "awake.on", "args": ["for": "1m"], "at": Date().timeIntervalSince1970 * 1000]
try JSONSerialization.data(withJSONObject: request).write(to: requests.appendingPathComponent("\(id).json"))
DistributedNotificationCenter.default().postNotificationName(.init("com.ashforde.suite.changed"), object: nil, userInfo: nil, deliverImmediately: true)
let answer = root.appendingPathComponent("responses/keeper/\(id).json")
for _ in 0..<40 {
    if let data = try? Data(contentsOf: answer), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        print("answer: \(object)")
        exit((object["ok"] as? Bool) == true ? 0 : 1)
    }
    RunLoop.current.run(until: Date().addingTimeInterval(0.25))
}
print("no answer from Monorail")
exit(1)
