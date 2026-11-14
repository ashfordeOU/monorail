import Foundation

/// Unit conversion for the Tools window and the command palette: "5 km in miles", "72 F to C", "3 GB in MiB".
/// Plain factors (and offsets for temperature), so it works the same on every system.
public enum UnitConverter {
    public struct Unit: Equatable, Sendable, Identifiable {
        public var name: String
        public var symbols: [String]
        /// Value in the category's base unit = value × factor + offset.
        public var factor: Double
        public var offset: Double
        public var id: String { name }
        public init(_ name: String, _ symbols: [String], _ factor: Double, offset: Double = 0) {
            self.name = name; self.symbols = symbols; self.factor = factor; self.offset = offset
        }
        public var symbol: String { symbols.first ?? name }
    }

    public struct Category: Equatable, Sendable, Identifiable {
        public var name: String
        public var units: [Unit]
        public var id: String { name }
    }

    public static let categories: [Category] = [
        Category(name: "Length", units: [
            Unit("Millimetres", ["mm", "millimetre", "millimeter"], 0.001), Unit("Centimetres", ["cm", "centimetre", "centimeter"], 0.01),
            Unit("Metres", ["m", "metre", "meter"], 1), Unit("Kilometres", ["km", "kilometre", "kilometer", "kms"], 1000),
            Unit("Inches", ["in", "inch", "inches", "\""], 0.0254), Unit("Feet", ["ft", "foot", "feet", "'"], 0.3048),
            Unit("Yards", ["yd", "yard"], 0.9144), Unit("Miles", ["mi", "mile"], 1609.344), Unit("Nautical miles", ["nmi", "nautical mile"], 1852)]),
        Category(name: "Weight", units: [
            Unit("Milligrams", ["mg", "milligram"], 0.000001), Unit("Grams", ["g", "gram", "gramme"], 0.001), Unit("Kilograms", ["kg", "kilo", "kilogram"], 1),
            Unit("Tonnes", ["t", "tonne", "metric ton"], 1000), Unit("Ounces", ["oz", "ounce"], 0.028349523125),
            Unit("Pounds", ["lb", "lbs", "pound"], 0.45359237), Unit("Stone", ["st", "stone", "stones"], 6.35029318)]),
        Category(name: "Temperature", units: [
            Unit("Celsius", ["°C", "c", "celsius", "centigrade"], 1, offset: 273.15),
            Unit("Fahrenheit", ["°F", "f", "fahrenheit"], 5.0 / 9.0, offset: 459.67 * 5.0 / 9.0),
            Unit("Kelvin", ["K", "kelvin"], 1)]),
        Category(name: "Volume", units: [
            Unit("Millilitres", ["ml", "millilitre", "milliliter"], 0.001), Unit("Litres", ["l", "litre", "liter"], 1),
            Unit("Cubic metres", ["m3", "m³", "cubic metre"], 1000), Unit("Teaspoons", ["tsp", "teaspoon"], 0.00492892159375),
            Unit("Tablespoons", ["tbsp", "tablespoon"], 0.01478676478125), Unit("US fluid ounces", ["fl oz", "floz", "fluid ounce"], 0.0295735295625),
            Unit("US cups", ["cup", "cups"], 0.2365882365), Unit("UK pints", ["pt", "pint"], 0.56826125),
            Unit("US gallons", ["gal", "gallon", "us gallon"], 3.785411784), Unit("UK gallons", ["imp gal", "uk gallon", "imperial gallon"], 4.54609)]),
        Category(name: "Speed", units: [
            Unit("Metres a second", ["m/s", "mps"], 1), Unit("Kilometres an hour", ["km/h", "kph", "kmh"], 1 / 3.6),
            Unit("Miles an hour", ["mph", "mi/h"], 0.44704), Unit("Knots", ["kn", "kt", "knot"], 1852.0 / 3600.0)]),
        Category(name: "Area", units: [
            Unit("Square centimetres", ["cm2", "cm²"], 0.0001), Unit("Square metres", ["m2", "m²", "sq m"], 1), Unit("Hectares", ["ha", "hectare"], 10_000),
            Unit("Square kilometres", ["km2", "km²"], 1_000_000), Unit("Square feet", ["ft2", "ft²", "sq ft"], 0.09290304),
            Unit("Acres", ["ac", "acre"], 4046.8564224), Unit("Square miles", ["mi2", "mi²", "sq mi"], 2_589_988.110336)]),
        Category(name: "Data", units: [
            Unit("Bits", ["bit", "bits"], 0.125), Unit("Bytes", ["B", "byte", "bytes"], 1), Unit("Kilobytes", ["KB", "kilobyte"], 1e3),
            Unit("Megabytes", ["MB", "megabyte"], 1e6), Unit("Gigabytes", ["GB", "gigabyte"], 1e9), Unit("Terabytes", ["TB", "terabyte"], 1e12),
            Unit("Kibibytes", ["KiB"], 1024), Unit("Mebibytes", ["MiB"], 1_048_576), Unit("Gibibytes", ["GiB"], 1_073_741_824),
            Unit("Megabits", ["Mbit", "megabit", "mbps"], 125_000)]),
        Category(name: "Time", units: [
            Unit("Milliseconds", ["ms", "millisecond"], 0.001), Unit("Seconds", ["s", "sec", "second"], 1), Unit("Minutes", ["min", "minute"], 60),
            Unit("Hours", ["h", "hr", "hour"], 3600), Unit("Days", ["d", "day"], 86400), Unit("Weeks", ["wk", "week"], 604_800),
            Unit("Years", ["yr", "year"], 31_557_600)]),
        Category(name: "Energy", units: [
            Unit("Joules", ["J", "joule"], 1), Unit("Kilojoules", ["kJ", "kilojoule"], 1000), Unit("Calories", ["cal", "calorie"], 4.184),
            Unit("Kilocalories", ["kcal", "kilocalorie"], 4184), Unit("Watt-hours", ["Wh", "watt hour"], 3600), Unit("Kilowatt-hours", ["kWh", "kilowatt hour"], 3_600_000)]),
        Category(name: "Pressure", units: [
            Unit("Pascals", ["Pa", "pascal"], 1), Unit("Kilopascals", ["kPa"], 1000), Unit("Bar", ["bar"], 100_000),
            Unit("Pounds per square inch", ["psi"], 6894.757293168), Unit("Atmospheres", ["atm", "atmosphere"], 101_325)]),
    ]

    public static func convert(_ value: Double, from: Unit, to: Unit) -> Double {
        let base = value * from.factor + from.offset
        return (base - to.offset) / to.factor
    }

    /// The unit (and its category) a word or symbol names, ignoring case and a plural "s".
    public static func unit(named text: String) -> (Category, Unit)? {
        let word = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !word.isEmpty else { return nil }
        // The word as typed first ("ms" is milliseconds), then without a plural ending ("miles" → "mile").
        var tries = [word]
        if word.hasSuffix("es") { tries.append(String(word.dropLast(2))) }
        if word.hasSuffix("s") { tries.append(String(word.dropLast())) }
        for candidate in tries {
            for category in categories {
                for unit in category.units where (unit.symbols.map { $0.lowercased() } + [unit.name.lowercased()]).contains(candidate) {
                    return (category, unit)
                }
            }
        }
        return nil
    }

    /// Reads "5 km in miles", "72F to C", "3.5 gb as mib". Both units must be the same kind of thing.
    public static func parse(_ text: String) -> (value: Double, from: Unit, to: Unit, category: Category)? {
        let lower = text.lowercased()
        var separator: Range<String.Index>?
        for word in [" in ", " to ", " as ", " into "] {
            if let r = lower.range(of: word, options: .backwards) { separator = r; break }
        }
        guard let separator else { return nil }
        let left = lower[..<separator.lowerBound].trimmingCharacters(in: .whitespaces)
        let right = lower[separator.upperBound...].trimmingCharacters(in: .whitespaces)
        var digits = ""
        var rest = Substring(left)
        while let c = rest.first, c.isNumber || c == "." || c == "," || (c == "-" && digits.isEmpty) {
            if c != "," { digits.append(c) }
            rest = rest.dropFirst()
        }
        guard let value = Double(digits), let (category, from) = unit(named: String(rest)),
              let (other, to) = unit(named: right), other.name == category.name else { return nil }
        return (value, from, to, category)
    }

    /// Up to six significant figures, without a trailing ".0".
    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        if value != 0, abs(value) < 0.0001 || abs(value) >= 1e12 { return String(format: "%.4g", value) }
        var text = String(format: "%.6g", value)
        if text.contains("e") { return text }
        if text.contains(".") { while text.hasSuffix("0") { text.removeLast() }; if text.hasSuffix(".") { text.removeLast() } }
        return text
    }

    /// "5 km = 3.10686 miles", for the palette.
    public static func answer(_ text: String) -> String? {
        guard let p = parse(text) else { return nil }
        let result = convert(p.value, from: p.from, to: p.to)
        return "\(format(p.value)) \(p.from.symbol) = \(format(result)) \(p.to.symbol)"
    }
}
