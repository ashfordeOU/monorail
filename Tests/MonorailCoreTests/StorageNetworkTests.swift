@testable import MonorailCore
import XCTest

final class StorageMapTests: XCTestCase {
    func testComposeOrdersAndFindsSystemData() {
        let gb: Int64 = 1_000_000_000
        let bar = StorageMap.compose(used: 300 * gb, measured: [.applications: 80 * gb, .music: 54 * gb, .documents: 32 * gb, .mail: 0], macOS: 12 * gb)
        XCTAssertEqual(bar.map(\.category), [.applications, .music, .documents, .systemData, .macOS])
        XCTAssertEqual(bar.first(where: { $0.category == .systemData })?.bytes, 300 * gb - 166 * gb - 12 * gb)
    }

    func testComposeNeverGoesNegative() {
        let bar = StorageMap.compose(used: 10, measured: [.documents: 50], macOS: 5)
        XCTAssertNil(bar.first(where: { $0.category == .systemData }))
    }

    func testExplainSystemData() {
        let parts = StorageMap.explain(systemData: 100, parts: [.caches: 30, .swap: 50, .logs: 0])
        XCTAssertEqual(parts.map(\.part), [.swap, .caches, .other])
        XCTAssertEqual(parts.last?.bytes, 20)
    }

    func testVolumesFromDiskutil() throws {
        let plist: [String: Any] = ["Containers": [[
            "Volumes": [
                ["Roles": ["System"], "CapacityInUse": NSNumber(value: 11_000_000_000)],
                ["Roles": ["Data"], "CapacityInUse": NSNumber(value: 280_000_000_000)],
                ["Roles": ["Preboot"], "CapacityInUse": NSNumber(value: 6_000_000_000)],
                ["Roles": ["Recovery"], "CapacityInUse": NSNumber(value: 1_000_000_000)],
                ["Roles": ["VM"], "CapacityInUse": NSNumber(value: 4_000_000_000)],
            ]]]]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let volumes = try XCTUnwrap(StorageMap.volumes(fromDiskutilPlist: data))
        XCTAssertEqual(volumes.macOS, 18_000_000_000)
        XCTAssertEqual(volumes.vm, 4_000_000_000)
        XCTAssertEqual(volumes.data, 280_000_000_000)
    }

    func testSnapshotCount() {
        let text = "Snapshots for disk /:\ncom.apple.TimeMachine.2026-11-12-101010.local\ncom.apple.TimeMachine.2026-11-13-101010.local\n"
        XCTAssertEqual(StorageMap.snapshotCount(fromTmutil: text), 2)
    }
}

final class NetworkDetailsTests: XCTestCase {
    func testQuality() {
        XCTAssertEqual(NetworkDetails.quality(rssi: -45, noise: -95).quality, .excellent)
        XCTAssertEqual(NetworkDetails.quality(rssi: -62, noise: -92).quality, .good)
        XCTAssertEqual(NetworkDetails.quality(rssi: -72, noise: -92).quality, .fair)
        XCTAssertEqual(NetworkDetails.quality(rssi: -82, noise: -90).quality, .poor)
        XCTAssertEqual(NetworkDetails.quality(rssi: -50, noise: -60).snr, 10)
    }

    func testBand() {
        XCTAssertEqual(NetworkDetails.band(channel: 6), "2.4 GHz")
        XCTAssertEqual(NetworkDetails.band(channel: 149), "5 GHz")
        XCTAssertEqual(NetworkDetails.band(channel: 37, isSixGHz: true), "6 GHz")
    }

    func testNettopAndRates() {
        let first = NetworkDetails.parseNettop(",bytes_in,bytes_out,\nSafari.512,1000,200,\nSafari.900,500,100,\nkernel_task.0,10,10,\n")
        XCTAssertEqual(first.first, NetworkDetails.Traffic(name: "Safari", bytesIn: 1500, bytesOut: 300))
        let second = NetworkDetails.parseNettop(",bytes_in,bytes_out,\nSafari.512,3000,400,\nSafari.900,500,100,\nkernel_task.0,10,10,\n")
        let rates = NetworkDetails.rates(before: first, after: second, seconds: 2)
        XCTAssertEqual(rates, [NetworkDetails.Traffic(name: "Safari", bytesIn: 1000, bytesOut: 100)])
    }

    func testRouteAndPing() {
        let route = "   route to: default\ndestination: default\n    gateway: 192.168.1.1\n  interface: en0\n"
        XCTAssertEqual(NetworkDetails.gateway(fromRoute: route), "192.168.1.1")
        XCTAssertEqual(NetworkDetails.interface(fromRoute: route), "en0")
        let ping = "3 packets transmitted, 3 packets received, 0.0% packet loss\nround-trip min/avg/max/stddev = 1.201/2.512/4.003/1.1 ms\n"
        let result = NetworkDetails.ping(ping)
        XCTAssertEqual(result?.averageMs ?? 0, 2.512, accuracy: 0.001)
        XCTAssertEqual(result?.lossPercent, 0)
        XCTAssertEqual(NetworkDetails.ping("3 packets transmitted, 0 packets received, 100.0% packet loss\n")?.lossPercent, 100)
        XCTAssertEqual(NetworkDetails.latencyWord(12), "Snappy")
    }
}

final class SystemHistoryExtrasTests: XCTestCase {
    func testDailyTotalsAndWeekHours() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_700_000_000) // a Tuesday afternoon (UTC)
        var history = SystemHistory()
        for minute in 0..<30 { history.add(.init(at: now.addingTimeInterval(Double(minute - 30) * 60), cpu: 50, memory: 40, downBytes: 1000)) }
        let totals = history.dailyTotals({ $0.downBytes }, days: 3, now: now, calendar: cal)
        XCTAssertEqual(totals.count, 3)
        XCTAssertEqual(totals.last?.total ?? 0, 30 * 60 * 1000, accuracy: 1)
        XCTAssertEqual(totals.first?.total, 0)
        let grid = history.weekHours({ $0.cpu }, calendar: cal)
        XCTAssertEqual(grid.count, 7); XCTAssertEqual(grid[0].count, 24)
        let filled = grid.flatMap { $0 }.compactMap { $0 }
        XCTAssertFalse(filled.isEmpty)
        XCTAssertEqual(filled.first ?? 0, 50, accuracy: 0.001)
    }
}

final class NotchShelfTests: XCTestCase {
    func testShelfKeepsNewestFirstWithoutDuplicates() {
        var shelf = NotchShelf(limit: 3)
        shelf.add(["/a", "/b"])
        XCTAssertEqual(shelf.paths, ["/a", "/b"])
        shelf.add(["/c", "/a"])
        XCTAssertEqual(shelf.paths, ["/c", "/a", "/b"])
        shelf.add(["/d"])
        XCTAssertEqual(shelf.paths, ["/d", "/c", "/a"])
        shelf.remove("/c")
        XCTAssertEqual(shelf.paths, ["/d", "/a"])
        shelf.clear()
        XCTAssertTrue(shelf.isEmpty)
    }

    func testRankedActivities() {
        let list = [NotchActivity(.charging, symbol: "bolt", text: "80%", tint: "green"),
                    NotchActivity(.sharing, symbol: "rec", text: "Sharing", tint: "red"),
                    NotchActivity(.timer, symbol: "timer", text: "24:00", tint: "purple")]
        XCTAssertEqual(NotchActivity.ranked(list).map(\.kind), [.sharing, .timer, .charging])
    }
}

final class SmartCardTests: XCTestCase {
    func testHysteresis() {
        var busy = Hysteresis(on: 85, off: 60)
        XCTAssertFalse(busy.update(80))
        XCTAssertTrue(busy.update(90))
        XCTAssertTrue(busy.update(70))   // still busy: above the off level
        XCTAssertFalse(busy.update(55))
    }

    func testBusyProcessorRaisesSystem() {
        var signals = HomeSignals()
        signals.cpuBusy = true
        let layout = HomePlanner.plan(signals)
        XCTAssertEqual(layout.raised, [.system])
        XCTAssertEqual(layout.title, "Processor busy")
    }
}

final class UnitConverterTests: XCTestCase {
    func testConversions() {
        let km = UnitConversion.unit(named: "km")!.1, mi = UnitConversion.unit(named: "miles")!.1
        XCTAssertEqual(UnitConversion.convert(5, from: km, to: mi), 3.10686, accuracy: 0.0001)
        let c = UnitConversion.unit(named: "C")!.1, f = UnitConversion.unit(named: "fahrenheit")!.1
        XCTAssertEqual(UnitConversion.convert(100, from: c, to: f), 212, accuracy: 0.0001)
        XCTAssertEqual(UnitConversion.convert(32, from: f, to: c), 0, accuracy: 0.0001)
    }

    func testParseAndAnswer() {
        XCTAssertEqual(UnitConversion.answer("5 km in miles"), "5 km = 3.10686 mi")
        XCTAssertEqual(UnitConversion.answer("72F to C"), "72 °F = 22.2222 °C")
        XCTAssertEqual(UnitConversion.answer("1 GiB in MB"), "1 GiB = 1073.74 MB")
        XCTAssertEqual(UnitConversion.unit(named: "ms")?.1.name, "Milliseconds")
        XCTAssertNil(UnitConversion.answer("5 km in kg"))
        XCTAssertNil(UnitConversion.answer("hello"))
    }

    func testFormat() {
        XCTAssertEqual(UnitConversion.format(2.5), "2.5")
        XCTAssertEqual(UnitConversion.format(3), "3")
    }
}

final class DownloadingTests: XCTestCase {
    func testDownloads() {
        let files = Downloading.inProgress(["Report.pdf.download", "movie.mp4.crdownload", "done.zip", "photo.jpg.part"])
        XCTAssertEqual(files, ["Report.pdf", "movie.mp4", "photo.jpg"])
        XCTAssertEqual(Downloading.label(["Report.pdf"]), "Report.pdf")
        XCTAssertEqual(Downloading.label(files), "3 files")
        XCTAssertNil(Downloading.label([]))
    }
}
