import Foundation

/// Sunrise and sunset, worked out on the Mac from a place and a date (no network, no location
/// access): the standard sunrise equation, good to a few minutes.
public enum SolarTimes {
    /// One day's sun.
    public enum Day: Equatable, Sendable {
        /// Minutes after local midnight.
        case normal(sunrise: Int, sunset: Int)
        /// The sun doesn't set (summer near the poles).
        case alwaysUp
        /// The sun doesn't rise (winter near the poles).
        case alwaysDown
    }

    /// The sun on day `dayOfYear` (1–366) at `latitude`, `longitude` (degrees, east and north
    /// positive), in local time `utcOffsetMinutes` ahead of UTC.
    public static func day(dayOfYear: Int, latitude: Double, longitude: Double, utcOffsetMinutes: Int) -> Day {
        guard let rise = utcHours(dayOfYear: dayOfYear, latitude: latitude, longitude: longitude, rising: true),
            let set = utcHours(dayOfYear: dayOfYear, latitude: latitude, longitude: longitude, rising: false)
        else {
            // No crossing: up all day if the sun is north of the equator for the northern summer.
            let declination = declinationDegrees(dayOfYear: dayOfYear)
            return (declination > 0) == (latitude > 0) ? .alwaysUp : .alwaysDown
        }
        func local(_ hours: Double) -> Int {
            let minutes = Int((hours * 60).rounded()) + utcOffsetMinutes
            return ((minutes % 1440) + 1440) % 1440
        }
        return .normal(sunrise: local(rise), sunset: local(set))
    }

    /// The sun today (or on `date`) where `timeZone` suggests the Mac is, or at `coordinates`.
    public static func day(on date: Date, timeZone: TimeZone, coordinates: (latitude: Double, longitude: Double)? = nil) -> Day {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let place = coordinates ?? ApproximateLocation.coordinates(for: timeZone, on: date)
        return day(dayOfYear: dayOfYear, latitude: place.latitude, longitude: place.longitude,
                   utcOffsetMinutes: timeZone.secondsFromGMT(for: date) / 60)
    }

    private static let zenith = 90.833
    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }
    private static func normalised(_ value: Double, _ range: Double) -> Double {
        let v = value.truncatingRemainder(dividingBy: range)
        return v < 0 ? v + range : v
    }

    private static func trueLongitude(_ t: Double) -> Double {
        let m = 0.9856 * t - 3.289
        return normalised(m + 1.916 * sin(rad(m)) + 0.020 * sin(rad(2 * m)) + 282.634, 360)
    }

    static func declinationDegrees(dayOfYear: Int) -> Double {
        deg(asin(0.39782 * sin(rad(trueLongitude(Double(dayOfYear) + 0.5)))))
    }

    /// Sunrise or sunset in hours after UTC midnight (the "Almanac for Computers" method).
    private static func utcHours(dayOfYear: Int, latitude: Double, longitude: Double, rising: Bool) -> Double? {
        let lngHour = longitude / 15
        let t = Double(dayOfYear) + ((rising ? 6 : 18) - lngHour) / 24
        let l = trueLongitude(t)
        var ra = normalised(deg(atan(0.91764 * tan(rad(l)))), 360)
        ra += floor(l / 90) * 90 - floor(ra / 90) * 90
        ra /= 15
        let sinDec = 0.39782 * sin(rad(l))
        let cosDec = cos(asin(sinDec))
        let cosH = (cos(rad(zenith)) - sinDec * sin(rad(latitude))) / (cosDec * cos(rad(latitude)))
        guard cosH >= -1, cosH <= 1 else { return nil }
        let h = (rising ? 360 - deg(acos(cosH)) : deg(acos(cosH))) / 15
        let localMean = h + ra - 0.06571 * t - 6.622
        return normalised(localMean - lngHour, 24)
    }
}

/// Roughly where the Mac is, from its time zone alone: the main city of well-known zones, or
/// for others the longitude its offset implies and a latitude typical of its region. Close
/// enough for sunset and sunrise to within a few minutes in most places, without asking for
/// location access.
public enum ApproximateLocation {
    /// Latitude and longitude of the main city in common time zones.
    static let cities: [String: (Double, Double)] = [
        "Europe/London": (51.51, -0.13), "Europe/Dublin": (53.35, -6.26), "Europe/Lisbon": (38.72, -9.14),
        "Europe/Paris": (48.86, 2.35), "Europe/Brussels": (50.85, 4.35), "Europe/Amsterdam": (52.37, 4.90),
        "Europe/Berlin": (52.52, 13.40), "Europe/Zurich": (47.37, 8.54), "Europe/Vienna": (48.21, 16.37),
        "Europe/Madrid": (40.42, -3.70), "Europe/Rome": (41.90, 12.50), "Europe/Prague": (50.08, 14.44),
        "Europe/Warsaw": (52.23, 21.01), "Europe/Copenhagen": (55.68, 12.57), "Europe/Oslo": (59.91, 10.75),
        "Europe/Stockholm": (59.33, 18.07), "Europe/Helsinki": (60.17, 24.94), "Europe/Tallinn": (59.44, 24.75),
        "Europe/Riga": (56.95, 24.11), "Europe/Vilnius": (54.69, 25.28), "Europe/Athens": (37.98, 23.73),
        "Europe/Istanbul": (41.01, 28.98), "Europe/Kyiv": (50.45, 30.52), "Europe/Kiev": (50.45, 30.52),
        "Europe/Moscow": (55.76, 37.62), "Europe/Budapest": (47.50, 19.04), "Europe/Bucharest": (44.43, 26.10),
        "Atlantic/Reykjavik": (64.15, -21.94),
        "America/New_York": (40.71, -74.01), "America/Toronto": (43.65, -79.38), "America/Chicago": (41.88, -87.63),
        "America/Denver": (39.74, -104.99), "America/Phoenix": (33.45, -112.07), "America/Los_Angeles": (34.05, -118.24),
        "America/Vancouver": (49.28, -123.12), "America/Anchorage": (61.22, -149.90), "America/Halifax": (44.65, -63.58),
        "America/St_Johns": (47.56, -52.71), "America/Mexico_City": (19.43, -99.13), "America/Bogota": (4.71, -74.07),
        "America/Lima": (-12.05, -77.04), "America/Santiago": (-33.45, -70.67), "America/Sao_Paulo": (-23.55, -46.63),
        "America/Argentina/Buenos_Aires": (-34.60, -58.38), "America/Detroit": (42.33, -83.05),
        "Pacific/Honolulu": (21.31, -157.86), "Pacific/Auckland": (-36.85, 174.76),
        "Asia/Tokyo": (35.68, 139.69), "Asia/Seoul": (37.57, 126.98), "Asia/Shanghai": (31.23, 121.47),
        "Asia/Hong_Kong": (22.32, 114.17), "Asia/Taipei": (25.03, 121.57), "Asia/Singapore": (1.35, 103.82),
        "Asia/Bangkok": (13.76, 100.50), "Asia/Jakarta": (-6.21, 106.85), "Asia/Manila": (14.60, 120.98),
        "Asia/Kolkata": (19.08, 72.88), "Asia/Calcutta": (19.08, 72.88), "Asia/Dubai": (25.20, 55.27),
        "Asia/Karachi": (24.86, 67.01), "Asia/Jerusalem": (31.77, 35.21), "Asia/Tel_Aviv": (32.09, 34.78),
        "Asia/Riyadh": (24.71, 46.68), "Asia/Tehran": (35.69, 51.39),
        "Australia/Sydney": (-33.87, 151.21), "Australia/Melbourne": (-37.81, 144.96), "Australia/Brisbane": (-27.47, 153.03),
        "Australia/Perth": (-31.95, 115.86), "Australia/Adelaide": (-34.93, 138.60),
        "Africa/Johannesburg": (-26.20, 28.05), "Africa/Cairo": (30.04, 31.24), "Africa/Lagos": (6.52, 3.38),
        "Africa/Nairobi": (-1.29, 36.82), "Africa/Casablanca": (33.57, -7.59),
    ]

    /// A typical latitude for each region of the time zone database.
    static let regionLatitudes: [String: Double] = [
        "Europe": 50, "America": 38, "Asia": 30, "Australia": -32, "Africa": 5, "Pacific": -15,
        "Atlantic": 40, "Indian": -10, "Antarctica": -75, "Arctic": 78,
    ]

    public static func coordinates(for timeZone: TimeZone, on date: Date = Date()) -> (latitude: Double, longitude: Double) {
        if let known = cities[timeZone.identifier] { return (known.0, known.1) }
        // Standard time (no daylight saving): 15° of longitude per hour.
        let standard = Double(timeZone.secondsFromGMT(for: date)) - timeZone.daylightSavingTimeOffset(for: date)
        let longitude = min(max(standard / 3600 * 15, -180), 180)
        let region = String(timeZone.identifier.split(separator: "/").first ?? "")
        return (regionLatitudes[region] ?? 40, longitude)
    }
}
