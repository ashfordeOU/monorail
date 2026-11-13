@testable import MonorailCore
import XCTest

final class DeveloperTests: XCTestCase {
    func testHomebrew() {
        let outdated = #"{"formulae":[{"name":"node","installed_versions":["22.1.0"],"current_version":"22.4.0","pinned":false}],"casks":[{"name":"firefox","installed_versions":["131.0"],"current_version":"132.0"}]}"#
        let list = Homebrew.outdated(Data(outdated.utf8))
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list[0].outdated)
        XCTAssertTrue(list[1].isCask)
        XCTAssertEqual(Homebrew.installed("git 2.47.0\nnode 22.1.0 22.4.0\n", casks: false).map(\.installed), ["2.47.0", "22.4.0"])
        let services = Homebrew.services(Data(#"[{"name":"postgresql@16","status":"started","user":"me"},{"name":"redis","status":"none"}]"#.utf8))
        XCTAssertEqual(services.filter(\.running).map(\.name), ["postgresql@16"])
    }

    func testDocker() {
        let ps = """
        {"ID":"a1","Names":"web","Image":"nginx","State":"exited","Status":"Exited (0) 2 hours ago","Ports":""}
        {"ID":"b2","Names":"db","Image":"postgres:16","State":"running","Status":"Up 3 hours","Ports":"0.0.0.0:5432->5432/tcp"}
        """
        let list = Docker.containers(ps)
        XCTAssertEqual(list.map(\.name), ["db", "web"])
        let stats = Docker.stats(#"{"ID":"b2","CPUPerc":"1.25%","MemUsage":"48.2MiB / 7.6GiB"}"#)
        XCTAssertEqual(stats["b2"]?.cpu, 1.25)
        XCTAssertEqual(stats["b2"]?.memory, "48.2MiB")
    }
}

final class HomeArrangeTests: XCTestCase {
    func testOrderAndHidden() {
        let order = HomePlanner.order(saved: ["battery", "nope", "windows", "battery"])
        XCTAssertEqual(Array(order.prefix(2)), [.battery, .windows])
        XCTAssertEqual(order.count, HomePlanner.arrangeable.count)
        var s = HomeSignals()
        s.percent = 80
        let layout = HomePlanner.plan(s, order: order, hidden: [.windows, .layouts])
        XCTAssertEqual(layout.cards.first, .battery)
        XCTAssertFalse(layout.cards.contains(.windows))
        XCTAssertFalse(layout.cards.contains(.layouts))
    }
}
