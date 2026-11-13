import Foundation

/// The world for the Time page: a dotted map, where it's day and night, the moon, and whether a
/// city is at work or asleep. All worked out on the Mac.
public enum WorldMap {
    /// Land as dots, 120 × 52, from 75° north to 56° south (Natural Earth, public domain).
    public static let rows: [String] = [
        "000000000000000000011000001111000000000001111111111110000000000000000000000000100000000111111111111000000000000000000000",
        "100000000000000000010111100010111111000000111111111110000000000000000000000000100011111111111111111111101111111000000000",
        "000001111111111111111110100001111001100000011111111000000000000000111111100000011101011111111111111111111111111111111111",
        "111000111111111111111111111111100001101000111111000010100000000011111110101111111111111111111111111111111111111111111111",
        "000000111111111111111111111111011000110000011100000001000000000111111111111111111111111111111111111111111111111111111111",
        "000001111111111111111111111110000011000000001100000000000000001111011111111111111111111111111111111111111111111101011100",
        "000000001000001111111111111110000011101000000000000000000000001011001111111111111111111111111111111111111110000001000000",
        "000000000000000011111111111111100011111100000000000000000010000010011111111111111111111111111111111111111100000011000000",
        "000000000000000001111111111111111011111110000000000000000101001111111111111111111111111111111111111111111111000010000000",
        "000000000000000001111111111111111111111100000000000000000011011111111111111111111111111111111111111111111111000000000000",
        "000000000000000000111111111111111111111011000000000000000011111111111111111111111111111111111111111111111111000000000000",
        "000000000000000000011111111111111111111000000000000000000000111111111101011111111111111111111111111111111100000000000000",
        "000000000000000000011111111111111111100000000000000000000101110111111000011111111111111111111111111111111001000000000000",
        "000000000000000000011111111111111110000000000000000000000111000001111011111111111111111111111111111111100000000000000000",
        "000000000000000000011111111111111110000000000000000000000111000000010111111111111111111111111111111000100000000000000000",
        "000000000000000000011111111111111110000000000000000000000000111100000000111111111111111111111111111100100110000000000000",
        "000000000000000000000111111111111100000000000000000000000111111100000000111111111111111111111111111100011000000000000000",
        "000000000000000000000111111111111000000000000000000000000111111111011111111111111111111111111111111110000000000000000000",
        "000000000000000000000001111100001000000000000000000000001111111111111110111101111111111111111111111110000000000000000000",
        "000000000000000000000000111100000000000000000000000000011111111111111110111110011111111111111111111100000000000000000000",
        "000000000000000000000001111000000000000000000000000000011111111111111111011111110001111111111111111000000000000000000000",
        "000000000000000000000000011100100010000000000000000000111111111111111111011111110000111110011111000000000000000000000000",
        "000000000000000000000000011101100001100000000000000000011111111111111111101111100000111100011110100010000000000000000000",
        "000000000000000000000000000001110000000000000000000000111111111111111111101110000000011000000111000010000000000000000000",
        "000000000000000000000000000000110000000000000000000000111111111111111111111000000000011000000011000000000000000000000000",
        "000000000000000000000000000000010001100100000000000000011111111111111111111110000000011000000011000000000000000000000000",
        "000000000000000000000000000000000011111100000000000000001111111111111111111110000000000000000000000001000000000000000000",
        "000000000000000000000000000000000011111111000000000000000111001111111111111100000000000000000100000000000000000000000000",
        "000000000000000000000000000000000011111111100000000000000000000111111111111100000000000000001000001000000000000000000000",
        "000000000000000000000000000000000111111111100000000000000000000111111111111000000000000000000100111011100000000000000000",
        "000000000000000000000000000000000111111111111000000000000000000111111111110000000000000000000010011010001000000000000000",
        "000000000000000000000000000000000111111111111110000000000000000011111111100000000000000000000010000000000111000000000000",
        "000000000000000000000000000000000111111111111111000000000000000011111111100000000000000000000001100000000011100000000000",
        "000000000000000000000000000000000011111111111111000000000000000011111111100000000000000000000000000001000000010000000000",
        "000000000000000000000000000000000011111111111110000000000000000001111111100000000000000000000000000000001101000000000000",
        "000000000000000000000000000000000001111111111110000000000000000011111111110010000000000000000000000000111001000000000000",
        "000000000000000000000000000000000000111111111110000000000000000011111111100110000000000000000000000001111101100000000000",
        "000000000000000000000000000000000000011111111110000000000000000011111111000100000000000000000000000011111111100000000000",
        "000000000000000000000000000000000000011111111100000000000000000001111111001100000000000000000000001111111111110000010000",
        "000000000000000000000000000000000000111111110000000000000000000001111111000100000000000000000000001111111111111000000000",
        "000000000000000000000000000000000000111111110000000000000000000001111110000000000000000000000000001111111111111000000000",
        "000000000000000000000000000000000000111111100000000000000000000000111100000000000000000000000000001111111111111000000000",
        "000000000000000000000000000000000000111111100000000000000000000000111100000000000000000000000000000111101111111000000000",
        "000000000000000000000000000000000000111111000000000000000000000000100000000000000000000000000000000100000011110000000000",
        "000000000000000000000000000000000000111110000000000000000000000000000000000000000000000000000000000000000001110000000010",
        "000000000000000000000000000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000000010",
        "000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000100000000100",
        "000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000001000",
        "000000000000000000000000000000000001110000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "000000000000000000000000000000000000110000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    ]
    public static let columns = 120
    public static let northEdge = 75.0
    public static let southEdge = -56.0

    public static func isLand(row: Int, column: Int) -> Bool {
        guard rows.indices.contains(row), column >= 0, column < columns else { return false }
        let line = rows[row]
        return line[line.index(line.startIndex, offsetBy: column)] == "1"
    }

    /// Where a place falls on the map, 0…1 across and down.
    public static func position(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
        let x = (longitude + 180) / 360
        let y = (northEdge - latitude) / (northEdge - southEdge)
        return (min(max(x, 0), 1), min(max(y, 0), 1))
    }

    /// The latitude and longitude at the centre of a dot.
    public static func coordinates(row: Int, column: Int) -> (latitude: Double, longitude: Double) {
        let lat = northEdge - (Double(row) + 0.5) * (northEdge - southEdge) / Double(rows.count)
        let lon = -180 + (Double(column) + 0.5) * 360 / Double(columns)
        return (lat, lon)
    }
}

public enum SunMath {
    /// Where the sun is overhead right now.
    public static func subsolar(_ date: Date) -> (latitude: Double, longitude: Double) {
        let days = date.timeIntervalSince1970 / 86400 + 2440587.5 - 2451545.0
        let g = (357.529 + 0.98560028 * days).truncatingRemainder(dividingBy: 360) * .pi / 180
        let q = (280.459 + 0.98564736 * days).truncatingRemainder(dividingBy: 360)
        let l = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)) * .pi / 180
        let e = (23.439 - 0.00000036 * days) * .pi / 180
        let declination = asin(sin(e) * sin(l)) * 180 / .pi
        let ra = atan2(cos(e) * sin(l), cos(l)) * 180 / .pi
        var eqTime = (q - ra).truncatingRemainder(dividingBy: 360)
        if eqTime > 180 { eqTime -= 360 }
        if eqTime < -180 { eqTime += 360 }
        let utcHours = (date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)) / 3600
        var longitude = -15 * (utcHours - 12) - eqTime
        longitude = (longitude + 540).truncatingRemainder(dividingBy: 360) - 180
        return (declination, longitude)
    }

    /// The sun's height above the horizon, in degrees.
    public static func elevation(latitude: Double, longitude: Double, at date: Date) -> Double {
        let sun = subsolar(date)
        let rad = Double.pi / 180
        let cosZenith = sin(latitude * rad) * sin(sun.latitude * rad) + cos(latitude * rad) * cos(sun.latitude * rad) * cos((longitude - sun.longitude) * rad)
        return 90 - acos(min(max(cosZenith, -1), 1)) / rad
    }

    public static func isDay(latitude: Double, longitude: Double, at date: Date) -> Bool { elevation(latitude: latitude, longitude: longitude, at: date) > -0.83 }
}

public enum MoonPhase {
    /// How much of the moon is lit (0…1), and the phase's name.
    public static func at(_ date: Date) -> (lit: Double, name: String) {
        let synodic = 29.530588853
        let knownNew = Date(timeIntervalSince1970: 947182440) // 6 January 2000, 18:14 UTC
        var age = (date.timeIntervalSince(knownNew) / 86400).truncatingRemainder(dividingBy: synodic)
        if age < 0 { age += synodic }
        let lit = (1 - cos(2 * .pi * age / synodic)) / 2
        let names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous", "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        let index = Int((age / synodic * 8).rounded()) % 8
        return (lit, names[index])
    }
}

public enum WorkStatus: String, Sendable {
    case working = "Working", offWork = "Off work", asleep = "Asleep", weekend = "Weekend"

    /// What someone in `zone` is probably doing at `date` (work 9–18 on weekdays, sleep 23–7).
    public static func of(_ zone: TimeZone, at date: Date) -> WorkStatus {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.weekday, .hour], from: date)
        let hour = c.hour ?? 12
        if hour >= 23 || hour < 7 { return .asleep }
        if c.weekday == 1 || c.weekday == 7 { return .weekend }
        return (9..<18).contains(hour) ? .working : .offWork
    }

    /// The hours (in `here`'s clock, 0–23) when everyone in `zones` is at work on a weekday.
    public static func sharedWorkingHours(_ zones: [TimeZone], here: TimeZone, on date: Date) -> [Int] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = here
        let start = calendar.startOfDay(for: date)
        var hours: [Int] = []
        for hour in 0..<24 {
            let moment = start.addingTimeInterval(Double(hour) * 3600 + 1800)
            var everyone = true
            for zone in zones {
                var c = Calendar(identifier: .gregorian)
                c.timeZone = zone
                let h = c.component(.hour, from: moment)
                if !(9..<18).contains(h) { everyone = false; break }
            }
            if everyone { hours.append(hour) }
        }
        return hours
    }
}

/// Weather from Open-Meteo (free, no key, no account): parsing and the WMO weather codes.
public struct WeatherReport: Codable, Equatable, Sendable {
    public struct Hour: Codable, Equatable, Sendable {
        public var time: Date
        public var temperature: Double
        public var code: Int
        public var rainChance: Int?
    }

    public struct Day: Codable, Equatable, Sendable {
        public var date: String
        public var low: Double
        public var high: Double
        public var code: Int
        public var rainChance: Int?
        public var sunrise: Date?
        public var sunset: Date?
    }

    public var place: String
    public var temperature: Double
    public var feelsLike: Double?
    public var humidity: Int?
    public var wind: Double?
    public var code: Int
    public var isDay: Bool
    public var hours: [Hour]
    public var days: [Day]
    public var fetched: Date

    public static func parse(_ data: Data, place: String, now: Date = Date()) -> WeatherReport? {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let current = root["current"] as? [String: Any], let temperature = number(current["temperature_2m"]) else { return nil }
        let offset = Int(number(root["utc_offset_seconds"]) ?? 0)
        func date(_ text: Any?) -> Date? {
            guard let text = text as? String else { return nil }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: offset)
            f.dateFormat = text.count > 10 ? "yyyy-MM-dd'T'HH:mm" : "yyyy-MM-dd"
            return f.date(from: text)
        }
        var hours: [Hour] = []
        if let h = root["hourly"] as? [String: Any], let times = h["time"] as? [Any], let temps = h["temperature_2m"] as? [Any] {
            let codes = h["weather_code"] as? [Any] ?? []
            let rain = h["precipitation_probability"] as? [Any] ?? []
            for i in times.indices {
                guard let t = date(times[i]), t >= now.addingTimeInterval(-3600), hours.count < 24, i < temps.count, let temp = number(temps[i]) else { continue }
                hours.append(Hour(time: t, temperature: temp, code: Int(number(i < codes.count ? codes[i] : nil) ?? 0),
                                  rainChance: (i < rain.count ? number(rain[i]) : nil).map { Int($0) }))
            }
        }
        var days: [Day] = []
        if let d = root["daily"] as? [String: Any], let times = d["time"] as? [Any] {
            let lows = d["temperature_2m_min"] as? [Any] ?? [], highs = d["temperature_2m_max"] as? [Any] ?? []
            let codes = d["weather_code"] as? [Any] ?? [], rain = d["precipitation_probability_max"] as? [Any] ?? []
            let rises = d["sunrise"] as? [Any] ?? [], sets = d["sunset"] as? [Any] ?? []
            for i in times.indices {
                guard let day = times[i] as? String, i < lows.count, i < highs.count, let low = number(lows[i]), let high = number(highs[i]) else { continue }
                days.append(Day(date: day, low: low, high: high, code: Int(number(i < codes.count ? codes[i] : nil) ?? 0),
                                rainChance: (i < rain.count ? number(rain[i]) : nil).map { Int($0) },
                                sunrise: i < rises.count ? date(rises[i]) : nil, sunset: i < sets.count ? date(sets[i]) : nil))
            }
        }
        return WeatherReport(place: place, temperature: temperature, feelsLike: number(current["apparent_temperature"]),
                             humidity: number(current["relative_humidity_2m"]).map { Int($0) }, wind: number(current["wind_speed_10m"]),
                             code: Int(number(current["weather_code"]) ?? 0), isDay: (number(current["is_day"]) ?? 1) == 1,
                             hours: hours, days: days, fetched: now)
    }

    static func number(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let n = v as? NSNumber { return n.doubleValue }
        return nil
    }

    /// The forecast request for a place.
    public static func url(latitude: Double, longitude: Double, fahrenheit: Bool = false) -> URL? {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        c?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"),
            URLQueryItem(name: "forecast_days", value: "10"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        if fahrenheit { c?.queryItems?.append(URLQueryItem(name: "temperature_unit", value: "fahrenheit")) }
        return c?.url
    }
}

public struct WeatherPlace: Codable, Equatable, Hashable, Sendable {
    public var name: String
    public var country: String
    public var latitude: Double
    public var longitude: Double

    public init(name: String, country: String, latitude: Double, longitude: Double) {
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Open-Meteo's place search.
    public static func searchURL(_ query: String) -> URL? {
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        c?.queryItems = [URLQueryItem(name: "name", value: query), URLQueryItem(name: "count", value: "6"), URLQueryItem(name: "language", value: "en")]
        return c?.url
    }

    public static func parseSearch(_ data: Data) -> [WeatherPlace] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let results = root["results"] as? [[String: Any]] else { return [] }
        var places: [WeatherPlace] = []
        for r in results {
            guard let name = r["name"] as? String, let lat = WeatherReport.number(r["latitude"]), let lon = WeatherReport.number(r["longitude"]) else { continue }
            places.append(WeatherPlace(name: name, country: (r["country"] as? String) ?? "", latitude: lat, longitude: lon))
        }
        return places
    }
}

public enum WeatherCode {
    /// An SF Symbol and a short description for a WMO weather code.
    public static func describe(_ code: Int, isDay: Bool = true) -> (symbol: String, text: String) {
        switch code {
        case 0: return (isDay ? "sun.max.fill" : "moon.stars.fill", "Clear")
        case 1: return (isDay ? "sun.max.fill" : "moon.fill", "Mostly clear")
        case 2: return (isDay ? "cloud.sun.fill" : "cloud.moon.fill", "Partly cloudy")
        case 3: return ("cloud.fill", "Cloudy")
        case 45, 48: return ("cloud.fog.fill", "Fog")
        case 51, 53, 55, 56, 57: return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 66: return ("cloud.rain.fill", "Rain")
        case 65, 67: return ("cloud.heavyrain.fill", "Heavy rain")
        case 71, 73, 75, 77: return ("cloud.snow.fill", "Snow")
        case 80, 81: return ("cloud.sun.rain.fill", "Showers")
        case 82: return ("cloud.heavyrain.fill", "Heavy showers")
        case 85, 86: return ("cloud.snow.fill", "Snow showers")
        case 95, 96, 99: return ("cloud.bolt.rain.fill", "Thunderstorms")
        default: return ("cloud.fill", "Cloudy")
        }
    }
}
