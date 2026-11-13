#if os(macOS)
import AppKit
import MonorailCore
import SwiftUI

// MARK: - Time

/// The Dashboard's Time page: a dotted world map with day and night, a slider to look ahead,
/// your clocks with who's at work, and the sun and moon where you are.
struct TimeSection: View {
    @State private var shift = 0.0
    @State private var adding = false
    @State private var query = ""
    @State private var now = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var moment: Date { now.addingTimeInterval(shift * 3600) }

    var body: some View {
        let store = DashboardContext.store
        let zones = (store?.settings.worldClocks ?? []).compactMap(TimeZone.init(identifier:))
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(moment.formatted(date: .omitted, time: .shortened)).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(moment.formatted(.dateTime.weekday(.wide).day().month(.wide)) + " · " + TimeModel.city(TimeZone.current.identifier))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { adding.toggle() } label: { Label("Add a City", systemImage: "plus") }
            }
            if adding, let store { addCity(store) }
            DashCard(title: "World", trailing: shift == 0 ? "Now" : (shift > 0 ? "+" : "") + "\(Int(shift))h") {
                WorldMapView(moment: moment, zones: [TimeZone.current] + zones)
                    .frame(height: 260)
                HStack(spacing: 10) {
                    Text("−12h").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    Slider(value: $shift, in: -12...36, step: 1)
                    Text("+36h").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    Button("Now") { shift = 0 }.disabled(shift == 0).controlSize(.small)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                DashCard(title: "Here") { SunMoonView(zone: .current, moment: moment) }
                DashCard(title: "Clocks") {
                    if zones.isEmpty { Text("Add the cities you work with.").foregroundStyle(.secondary) }
                    ForEach(zones, id: \.identifier) { zone in clockRow(zone, store: store) }
                    if zones.count >= 1 {
                        let hours = WorkStatus.sharedWorkingHours([TimeZone.current] + zones, here: .current, on: moment)
                        Divider()
                        Text(hours.isEmpty ? "No weekday hour has everyone at work." :
                             "Everyone's at work \(String(format: "%02d:00", hours.first!))–\(String(format: "%02d:00", hours.last! + 1)) your time.")
                            .font(.system(size: 12)).foregroundStyle(hours.isEmpty ? Color.secondary : Color(nsColor: .systemGreen))
                    }
                }
            }
        }
        .sectionScroll()
        .onReceive(tick) { now = $0 }
    }

    private func clockRow(_ zone: TimeZone, store: SettingsStore?) -> some View {
        let status = WorkStatus.of(zone, at: moment)
        var calendar = Calendar.current
        calendar.timeZone = zone
        let time = moment.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
        return HStack(spacing: 10) {
            Image(systemName: TimeModel.isNight(in: zone, at: moment) ? "moon.fill" : "sun.max.fill")
                .foregroundStyle(TimeModel.isNight(in: zone, at: moment) ? Color(nsColor: .systemIndigo) : Color(nsColor: .systemYellow))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(TimeModel.city(zone.identifier)).font(.system(size: 13, weight: .semibold))
                HStack(spacing: 6) {
                    Text(status.rawValue).font(.system(size: 10, weight: .semibold)).padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(statusColour(status).opacity(0.22))).foregroundStyle(statusColour(status))
                    Text(TimeModel.offset(zone, from: .current, at: moment)).font(.system(size: 10.5)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(time).font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .padding(.vertical, 2)
        .contextMenu {
            if let store { Button("Remove \(TimeModel.city(zone.identifier))") { store.settings.worldClocks.removeAll { $0 == zone.identifier } } }
        }
    }

    private func statusColour(_ s: WorkStatus) -> Color {
        switch s {
        case .working: return Color(nsColor: .systemGreen)
        case .offWork: return Color(nsColor: .systemOrange)
        case .asleep: return Color(nsColor: .systemIndigo)
        case .weekend: return Color(nsColor: .systemTeal)
        }
    }

    private func addCity(_ store: SettingsStore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("City", text: $query).textFieldStyle(.roundedBorder)
            let matches = TimeZone.knownTimeZoneIdentifiers.filter {
                !query.isEmpty && TimeModel.city($0).localizedCaseInsensitiveContains(query) && !store.settings.worldClocks.contains($0)
            }.prefix(6)
            ForEach(Array(matches), id: \.self) { zone in
                Button { store.settings.worldClocks.append(zone); query = ""; adding = false } label: {
                    Text("\(TimeModel.city(zone)) · \(zone)").frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 360)
    }
}

/// Land as dots, night shaded, the sun's place, and a pin for each clock.
struct WorldMapView: View {
    let moment: Date
    let zones: [TimeZone]

    var body: some View {
        Canvas { context, size in
            let rows = WorldMap.rows.count, cols = WorldMap.columns
            let cellW = size.width / CGFloat(cols), cellH = size.height / CGFloat(rows)
            let dot = min(cellW, cellH) * 0.62
            for r in 0..<rows {
                for c in 0..<cols where WorldMap.isLand(row: r, column: c) {
                    let place = WorldMap.coordinates(row: r, column: c)
                    let day = SunMath.isDay(latitude: place.latitude, longitude: place.longitude, at: moment)
                    let rect = CGRect(x: CGFloat(c) * cellW + (cellW - dot) / 2, y: CGFloat(r) * cellH + (cellH - dot) / 2, width: dot, height: dot)
                    context.fill(Path(ellipseIn: rect), with: .color(day ? Color.white.opacity(0.75) : Color.white.opacity(0.18)))
                }
            }
            // The sun.
            let sun = SunMath.subsolar(moment)
            let sp = WorldMap.position(latitude: sun.latitude, longitude: sun.longitude)
            let sunRect = CGRect(x: sp.x * size.width - 7, y: sp.y * size.height - 7, width: 14, height: 14)
            context.fill(Path(ellipseIn: sunRect.insetBy(dx: -6, dy: -6)), with: .color(Color(nsColor: .systemYellow).opacity(0.25)))
            context.fill(Path(ellipseIn: sunRect), with: .color(Color(nsColor: .systemYellow)))
            // Clocks.
            for (index, zone) in zones.enumerated() {
                let place = ApproximateLocation.coordinates(for: zone, on: moment)
                let p = WorldMap.position(latitude: place.latitude, longitude: place.longitude)
                let point = CGPoint(x: p.x * size.width, y: p.y * size.height)
                let colour = index == 0 ? Color(nsColor: .systemOrange) : Color.white
                context.fill(Path(ellipseIn: CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)), with: .color(colour))
                context.stroke(Path(ellipseIn: CGRect(x: point.x - 6.5, y: point.y - 6.5, width: 13, height: 13)), with: .color(colour.opacity(0.6)), lineWidth: 1.5)
                let label = TimeModel.city(zone.identifier) + " " + moment.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
                context.draw(Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.white), at: CGPoint(x: point.x, y: point.y - 14))
            }
        }
        .accessibilityLabel("World map showing day and night, the sun and your clocks")
    }
}

/// Sunrise, sunset, the sun's arc today, golden and blue hours, and the moon.
struct SunMoonView: View {
    let zone: TimeZone
    let moment: Date

    var body: some View {
        let day = SolarTimes.day(on: moment, timeZone: zone)
        let moon = MoonPhase.at(moment)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                SunArc(day: day, zone: zone, moment: moment).frame(height: 70)
                VStack(spacing: 2) {
                    MoonGlyph(lit: moon.lit).frame(width: 34, height: 34)
                    Text(moon.name).font(.system(size: 10.5, weight: .semibold))
                    Text("\(Int((moon.lit * 100).rounded()))% lit").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                .frame(width: 96)
            }
            if case .normal(let rise, let set) = day {
                HStack(spacing: 14) {
                    Label(clock(rise), systemImage: "sunrise.fill")
                    Label(clock(set), systemImage: "sunset.fill")
                    Text("\(String(format: "%dh %02dm", (set - rise) / 60, (set - rise) % 60)) of daylight").foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
                HStack(spacing: 14) {
                    Text("Golden hour \(clock(set - 60))").foregroundStyle(Color(nsColor: .systemOrange))
                    Text("Blue hour \(clock(set + 20))").foregroundStyle(Color(nsColor: .systemBlue))
                }
                .font(.system(size: 11.5))
            } else {
                Text(day == .alwaysUp ? "The sun doesn't set today." : "The sun doesn't rise today.").foregroundStyle(.secondary)
            }
        }
    }

    private func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", ((minutes % 1440) + 1440) % 1440 / 60, ((minutes % 60) + 60) % 60) }
}

private struct SunArc: View {
    let day: SolarTimes.Day
    let zone: TimeZone
    let moment: Date

    var body: some View {
        Canvas { context, size in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let c = calendar.dateComponents([.hour, .minute], from: moment)
            let nowMin = Double((c.hour ?? 0) * 60 + (c.minute ?? 0))
            let horizon = size.height * 0.72
            context.stroke(Path { p in p.move(to: CGPoint(x: 0, y: horizon)); p.addLine(to: CGPoint(x: size.width, y: horizon)) },
                           with: .color(.secondary.opacity(0.4)), lineWidth: 1)
            guard case .normal(let rise, let set) = day, set > rise else { return }
            var arc = Path()
            for i in 0...60 {
                let m = Double(i) / 60 * 1440
                let x = size.width * m / 1440
                let phase = (m - Double(rise)) / Double(set - rise)
                let y = horizon - sin(phase * .pi) * horizon * 0.9 * (phase >= 0 && phase <= 1 ? 1 : 0.35)
                if i == 0 { arc.move(to: CGPoint(x: x, y: y)) } else { arc.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(arc, with: .color(Color(nsColor: .systemYellow).opacity(0.8)), lineWidth: 2)
            let phase = (nowMin - Double(rise)) / Double(set - rise)
            let sx = size.width * nowMin / 1440
            let sy = horizon - sin(phase * .pi) * horizon * 0.9 * (phase >= 0 && phase <= 1 ? 1 : 0.35)
            context.fill(Path(ellipseIn: CGRect(x: sx - 6, y: sy - 6, width: 12, height: 12)),
                         with: .color(phase >= 0 && phase <= 1 ? Color(nsColor: .systemYellow) : Color(nsColor: .systemIndigo)))
        }
        .accessibilityHidden(true)
    }
}

private struct MoonGlyph: View {
    let lit: Double

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.12)))
            // A lit ellipse whose width follows the phase (good enough at this size).
            let w = rect.width * lit
            context.clip(to: Path(ellipseIn: rect))
            context.fill(Path(ellipseIn: CGRect(x: rect.maxX - w, y: rect.minY, width: w, height: rect.height)), with: .color(Color.white.opacity(0.9)))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Weather

/// Weather from Open-Meteo: free, no account, no location access (places are found by name).
final class WeatherWatch: ObservableObject {
    static let shared = WeatherWatch()
    @Published private(set) var reports: [WeatherPlace: WeatherReport] = [:]
    @Published private(set) var failed = false
    private var lastFetch: [WeatherPlace: Date] = [:]

    func refresh(_ places: [WeatherPlace], fahrenheit: Bool, force: Bool = false) {
        for place in places {
            if !force, let last = lastFetch[place], Date().timeIntervalSince(last) < 900 { continue }
            lastFetch[place] = Date()
            guard let url = WeatherReport.url(latitude: place.latitude, longitude: place.longitude, fahrenheit: fahrenheit) else { continue }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                let report = data.flatMap { WeatherReport.parse($0, place: place.name) }
                DispatchQueue.main.async {
                    if let report { self.reports[place] = report; self.failed = false } else { self.failed = true }
                }
            }.resume()
        }
    }

    func search(_ query: String, done: @escaping ([WeatherPlace]) -> Void) {
        guard let url = WeatherPlace.searchURL(query) else { done([]); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let places = data.map(WeatherPlace.parseSearch) ?? []
            DispatchQueue.main.async { done(places) }
        }.resume()
    }

    /// The first time: the city your Mac's time zone is set to.
    func ensurePlace(_ store: SettingsStore) {
        guard store.settings.weatherPlaces.isEmpty else { return }
        search(TimeModel.city(TimeZone.current.identifier)) { places in
            if let first = places.first, store.settings.weatherPlaces.isEmpty { store.settings.weatherPlaces = [first] }
        }
    }
}

struct WeatherSection: View {
    @ObservedObject private var weather = WeatherWatch.shared
    @State private var chosen = 0
    @State private var query = ""
    @State private var found: [WeatherPlace] = []

    var body: some View {
        let store = DashboardContext.store
        let places = store?.settings.weatherPlaces ?? []
        let place = places.indices.contains(chosen) ? places[chosen] : places.first
        let unit = (store?.settings.weatherFahrenheit ?? false) ? "°F" : "°C"
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ForEach(Array(places.enumerated()), id: \.offset) { index, p in
                    Button { chosen = index } label: {
                        Label(p.name, systemImage: index == 0 ? "location.fill" : "mappin")
                            .font(.system(size: 12, weight: index == chosen ? .semibold : .regular))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Capsule().fill(index == chosen ? Color(nsColor: .systemOrange).opacity(0.3) : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { if let store { Button("Remove \(p.name)") { store.settings.weatherPlaces.remove(at: index); chosen = 0 } } }
                }
                Spacer()
                TextField("Add a place", text: $query).textFieldStyle(.roundedBorder).frame(width: 180)
                    .onSubmit { weather.search(query) { found = $0 } }
                if let store {
                    Picker("", selection: Binding(get: { store.settings.weatherFahrenheit }, set: { store.settings.weatherFahrenheit = $0; weather.refresh(places, fahrenheit: $0, force: true) })) {
                        Text("°C").tag(false); Text("°F").tag(true)
                    }
                    .pickerStyle(.segmented).frame(width: 90).labelsHidden()
                }
            }
            if !found.isEmpty, let store {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(found, id: \.self) { p in
                        Button("\(p.name), \(p.country)") {
                            store.settings.weatherPlaces.append(p)
                            found = []
                            query = ""
                            weather.refresh([p], fahrenheit: store.settings.weatherFahrenheit)
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            if let place, let r = weather.reports[place] {
                current(r, unit: unit)
                DashCard(title: "Next 24 hours", trailing: hoursRange(r, unit: unit)) { HourlyStrip(hours: r.hours) }
                DashCard(title: "10-day forecast") { DailyRows(days: r.days) }
            } else if place == nil {
                DashCard(title: "Weather") { Text("Add a place to see its weather.").foregroundStyle(.secondary) }
            } else {
                DashCard(title: "Weather") {
                    Text(weather.failed ? "Couldn't reach the weather service." : "Getting the forecast…").foregroundStyle(.secondary)
                }
            }
            Text("Weather by Open-Meteo.com (CC BY 4.0). Places are found by name: no location access.").font(.system(size: 10.5)).foregroundStyle(.tertiary)
        }
        .sectionScroll()
        .onAppear {
            guard let store else { return }
            weather.ensurePlace(store)
            weather.refresh(store.settings.weatherPlaces, fahrenheit: store.settings.weatherFahrenheit)
        }
        .onChange(of: places.count) { _ in
            if let store { weather.refresh(store.settings.weatherPlaces, fahrenheit: store.settings.weatherFahrenheit) }
        }
    }

    private func hoursRange(_ r: WeatherReport, unit: String) -> String {
        guard let low = r.hours.map(\.temperature).min(), let high = r.hours.map(\.temperature).max() else { return "" }
        return "\(Int(low.rounded()))° – \(Int(high.rounded()))°"
    }

    private func current(_ r: WeatherReport, unit: String) -> some View {
        let look = WeatherCode.describe(r.code, isDay: r.isDay)
        let today = r.days.first
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Label(r.place, systemImage: "location.fill").font(.system(size: 13, weight: .semibold))
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(Int(r.temperature.rounded()))°").font(.system(size: 52, weight: .light, design: .rounded))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(look.text).font(.system(size: 15, weight: .semibold))
                        if let today { Text("H \(Int(today.high.rounded()))°  L \(Int(today.low.rounded()))°").font(.system(size: 12)) }
                        if let feels = r.feelsLike { Text("Feels like \(Int(feels.rounded()))°").font(.system(size: 11.5)).foregroundStyle(.secondary) }
                    }
                }
                HStack(spacing: 14) {
                    if let h = r.humidity { Label("\(h)%", systemImage: "humidity") }
                    if let w = r.wind { Label("\(Int(w.rounded())) km/h", systemImage: "wind") }
                    if let rise = today?.sunrise { Label(rise.formatted(date: .omitted, time: .shortened), systemImage: "sunrise") }
                    if let set = today?.sunset { Label(set.formatted(date: .omitted, time: .shortened), systemImage: "sunset") }
                }
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: look.symbol).symbolRenderingMode(.multicolor).font(.system(size: 64))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: r.isDay ? [Color(red: 0.2, green: 0.35, blue: 0.6), Color(red: 0.12, green: 0.2, blue: 0.4)] : [Color(red: 0.1, green: 0.12, blue: 0.3), Color(red: 0.05, green: 0.06, blue: 0.15)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
        .foregroundStyle(.white)
    }
}

private struct HourlyStrip: View {
    let hours: [WeatherReport.Hour]

    var body: some View {
        let temps = hours.map(\.temperature)
        let low = (temps.min() ?? 0) - 1, high = (temps.max() ?? 1) + 1
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(hours.enumerated()), id: \.offset) { index, hour in
                    VStack(spacing: 6) {
                        Text(index == 0 ? "Now" : hour.time.formatted(.dateTime.hour())).font(.system(size: 11, weight: index == 0 ? .semibold : .regular))
                        Image(systemName: WeatherCode.describe(hour.code).symbol).symbolRenderingMode(.multicolor).font(.system(size: 15))
                        Spacer(minLength: 0)
                        Text("\(Int(hour.temperature.rounded()))°").font(.system(size: 12.5, weight: .semibold))
                        Capsule().fill(LinearGradient(colors: [Color(nsColor: .systemOrange), Color(nsColor: .systemYellow)], startPoint: .bottom, endPoint: .top))
                            .frame(width: 6, height: max(6, 50 * (hour.temperature - low) / (high - low)))
                        Text(hour.rainChance.map { $0 >= 20 ? "\($0)%" : " " } ?? " ").font(.system(size: 10)).foregroundStyle(Color(nsColor: .systemBlue))
                    }
                    .frame(width: 52, height: 150)
                }
            }
        }
    }
}

private struct DailyRows: View {
    let days: [WeatherReport.Day]

    var body: some View {
        let low = days.map(\.low).min() ?? 0, high = days.map(\.high).max() ?? 1
        VStack(spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                HStack(spacing: 10) {
                    Text(index == 0 ? "Today" : dayName(day.date)).font(.system(size: 12.5, weight: index == 0 ? .semibold : .regular)).frame(width: 52, alignment: .leading)
                    Image(systemName: WeatherCode.describe(day.code).symbol).symbolRenderingMode(.multicolor).frame(width: 22)
                    Text(day.rainChance.map { $0 >= 20 ? "\($0)%" : "" } ?? "").font(.system(size: 11)).foregroundStyle(Color(nsColor: .systemBlue)).frame(width: 34, alignment: .leading)
                    Text("\(Int(day.low.rounded()))°").font(.system(size: 12)).foregroundStyle(.secondary).frame(width: 34, alignment: .trailing)
                    GeometryReader { geo in
                        let span = max(high - low, 1)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(LinearGradient(colors: [Color(nsColor: .systemTeal), Color(nsColor: .systemYellow), Color(nsColor: .systemOrange)], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(8, geo.size.width * (day.high - day.low) / span))
                                .offset(x: geo.size.width * (day.low - low) / span)
                        }
                    }
                    .frame(height: 6)
                    Text("\(Int(day.high.rounded()))°").font(.system(size: 12, weight: .semibold)).frame(width: 34, alignment: .leading)
                }
            }
        }
    }

    private func dayName(_ text: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: text) else { return text }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}
#endif
