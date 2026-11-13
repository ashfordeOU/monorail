@testable import MonorailCore
import XCTest

final class WorldTimeTests: XCTestCase {
    func testMap() {
        XCTAssertEqual(WorldMap.rows.count, 52)
        XCTAssertTrue(WorldMap.rows.allSatisfy { $0.count == WorldMap.columns })
        // Central Africa is land; the middle of the Pacific isn't.
        func dot(_ lat: Double, _ lon: Double) -> Bool {
            let p = WorldMap.position(latitude: lat, longitude: lon)
            return WorldMap.isLand(row: Int(p.y * Double(WorldMap.rows.count)), column: Int(p.x * Double(WorldMap.columns)))
        }
        XCTAssertTrue(dot(5, 20))
        XCTAssertTrue(dot(40, -100))
        XCTAssertFalse(dot(0, -150))
        XCTAssertFalse(dot(-30, 80))
    }

    func testSun() {
        // 21 June 2026, 12:00 UTC: the sun is over the Tropic of Cancer, near Greenwich.
        let june = Date(timeIntervalSince1970: 1_782_043_200)
        let s = SunMath.subsolar(june)
        XCTAssertEqual(s.latitude, 23.4, accuracy: 0.3)
        XCTAssertEqual(s.longitude, 0, accuracy: 2)
        XCTAssertTrue(SunMath.isDay(latitude: 51.5, longitude: 0, at: june))
        XCTAssertFalse(SunMath.isDay(latitude: -33.9, longitude: 151.2, at: june))
    }

    func testMoon() {
        // 3 March 2026 was a full moon (11:38 UTC).
        let full = MoonPhase.at(Date(timeIntervalSince1970: 1_772_537_880))
        XCTAssertGreaterThan(full.lit, 0.97)
        XCTAssertEqual(full.name, "Full moon")
        XCTAssertLessThan(MoonPhase.at(Date(timeIntervalSince1970: 947_182_440)).lit, 0.01)
    }

    func testWorkStatus() {
        let london = TimeZone(identifier: "Europe/London")!
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        // Thursday 12 November 2026, 10:00 in London (UTC).
        let date = Date(timeIntervalSince1970: 1_794_477_600)
        XCTAssertEqual(WorkStatus.of(london, at: date), .working)
        XCTAssertEqual(WorkStatus.of(tokyo, at: date), .offWork)
        XCTAssertEqual(WorkStatus.of(TimeZone(identifier: "America/Los_Angeles")!, at: date), .asleep)
        XCTAssertEqual(WorkStatus.sharedWorkingHours([london, TimeZone(identifier: "America/New_York")!], here: london, on: date), [14, 15, 16, 17])
    }

    func testWeatherParsing() {
        let json = #"{"utc_offset_seconds":0,"current":{"temperature_2m":18.4,"apparent_temperature":17,"relative_humidity_2m":72,"wind_speed_10m":11,"weather_code":2,"is_day":1},"hourly":{"time":["2026-11-13T10:00","2026-11-13T11:00"],"temperature_2m":[17,18],"weather_code":[2,3],"precipitation_probability":[10,40]},"daily":{"time":["2026-11-13","2026-11-14"],"temperature_2m_min":[9,8],"temperature_2m_max":[19,15],"weather_code":[2,61],"precipitation_probability_max":[20,80],"sunrise":["2026-11-13T07:12","2026-11-14T07:14"],"sunset":["2026-11-13T16:15","2026-11-14T16:13"]}}"#
        let r = WeatherReport.parse(Data(json.utf8), place: "London", now: Date(timeIntervalSince1970: 1_794_564_000))
        XCTAssertEqual(r?.temperature, 18.4)
        XCTAssertEqual(r?.hours.count, 2)
        XCTAssertEqual(r?.days.count, 2)
        XCTAssertEqual(r?.days[1].rainChance, 80)
        XCTAssertNotNil(r?.days[0].sunrise)
        XCTAssertEqual(WeatherCode.describe(61).text, "Rain")
        XCTAssertEqual(WeatherCode.describe(0, isDay: false).symbol, "moon.stars.fill")
        XCTAssertNotNil(WeatherReport.url(latitude: 51.5, longitude: -0.12))
        let places = WeatherPlace.parseSearch(Data(#"{"results":[{"name":"London","country":"United Kingdom","latitude":51.5,"longitude":-0.12}]}"#.utf8))
        XCTAssertEqual(places.first?.country, "United Kingdom")
    }
}
