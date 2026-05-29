import SwiftUI

struct ObjectInfoSidebar: View {
    let info: SelectedObjectInfo?
    let onClearSelection: () -> Void
    let onHide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Object Info")
                    .font(.headline)

                Spacer()

                Button {
                    onHide()
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .help("Hide info sidebar")
            }

            Divider()

            if let info {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header(info)
                        orbitSection(info)
                        rotationSection(info)
                        physicalSection(info)
                        notesSection(info)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Select an object to view details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(.separator),
            alignment: .leading
        )
    }

    private func header(_ info: SelectedObjectInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.headline)
                    Text(info.kind.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear") {
                    onClearSelection()
                }
                .buttonStyle(.borderless)
            }

            if let parentName = info.parentName {
                infoRow("Parent", parentName)
            }

            if let dateText = info.dateText {
                infoRow("Date", dateText)
            }

            if let wikipediaURLString = info.wikipediaURLString,
               let url = URL(string: wikipediaURLString) {
                Link("Open Wikipedia", destination: url)
                    .font(.caption)
            }
        }
    }

    private func orbitSection(_ info: SelectedObjectInfo) -> some View {
        infoSection("Orbit") {
            infoRow("Apsis", info.apsisPhase.rawValue)

            if let distanceToSunMeters = info.distanceToSunMeters {
                infoRow("Distance to Sun", formatSunDistance(distanceToSunMeters))
            }

            if let distanceToParentMeters = info.distanceToParentMeters {
                infoRow("Distance to Parent", formatKilometers(distanceToParentMeters))
            }

            if let orbitalPeriodSeconds = info.orbitalPeriodSeconds {
                infoRow("Orbital Period", formatPeriod(orbitalPeriodSeconds))
            }

            if let orbitalPeriodYears = info.orbitalPeriodYears {
                infoRow("Year", formatYear(orbitalPeriodYears))
            }

            if let speedMetersPerSecond = info.speedMetersPerSecond {
                infoRow("Speed", formatSpeed(speedMetersPerSecond))
            }
        }
    }

    private func rotationSection(_ info: SelectedObjectInfo) -> some View {
        infoSection("Rotation") {
            if let lengthOfDayHours = info.lengthOfDayHours {
                infoRow("Day", formatDay(hours: lengthOfDayHours, earthDays: info.lengthOfDayEarthDays))
            }

            if let rotationPeriodHours = info.rotationPeriodHours {
                infoRow("Sidereal Rotation", formatHours(rotationPeriodHours))
            }

            if let rotationDirection = info.rotationDirection {
                infoRow("Rotation", rotationDirection)
            }

            if let axialTiltDegrees = info.axialTiltDegrees {
                infoRow("Axial Tilt", String(format: "%.2f deg", axialTiltDegrees))
            }
        }
    }

    private func physicalSection(_ info: SelectedObjectInfo) -> some View {
        infoSection("Physical") {
            if let massKg = info.massKg {
                infoRow("Mass", formatMass(massKg))
            }

            if let radiusMeters = info.radiusMeters {
                infoRow("Radius", formatKilometers(radiusMeters))
            }

            if let circumferenceMeters = info.circumferenceMeters {
                infoRow("Circumference", formatKilometers(circumferenceMeters))
            }

            if let surfaceAreaSquareKilometers = info.surfaceAreaSquareKilometers {
                infoRow("Surface Area", formatArea(surfaceAreaSquareKilometers))
            }

            if let bodyClass = info.bodyClass {
                infoRow("Class", bodyClass)
            }

            if let primaryComposition = info.primaryComposition {
                infoRow("Composition", primaryComposition)
            }
        }
    }

    private func notesSection(_ info: SelectedObjectInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if let notes = info.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No additional notes available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func infoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)

            Text(value)
                .font(.caption)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formatSunDistance(_ meters: Double) -> String {
        let au = meters / SolarSystemConstants.astronomicalUnit
        let kilometers = meters / 1_000

        if au >= 0.01 {
            return String(format: "%.3f AU (%.0fM km)", au, kilometers / 1_000_000)
        }

        return String(format: "%.0f km", kilometers)
    }

    private func formatKilometers(_ meters: Double) -> String {
        let kilometers = meters / 1_000

        if kilometers >= 1_000_000 {
            return String(format: "%.2fM km", kilometers / 1_000_000)
        }

        return String(format: "%.0f km", kilometers)
    }

    private func formatArea(_ squareKilometers: Double) -> String {
        if squareKilometers >= 1_000_000_000 {
            return String(format: "%.2fB km2", squareKilometers / 1_000_000_000)
        }

        if squareKilometers >= 1_000_000 {
            return String(format: "%.2fM km2", squareKilometers / 1_000_000)
        }

        return String(format: "%.0f km2", squareKilometers)
    }

    private func formatMass(_ kilograms: Double) -> String {
        String(format: "%.3e kg", kilograms)
    }

    private func formatPeriod(_ seconds: Double) -> String {
        let days = seconds / 86_400
        let years = seconds / SolarSystemConstants.secondsPerJulianYear

        if years >= 2 {
            return String(format: "%.2f years", years)
        }

        if years >= 1 {
            return String(format: "%.2f days (%.3f years)", days, years)
        }

        return String(format: "%.2f days", days)
    }

    private func formatYear(_ years: Double) -> String {
        let days = years * 365.25
        return String(format: "%.3f years (%.2f Earth days)", years, days)
    }

    private func formatDay(hours: Double, earthDays: Double?) -> String {
        if let earthDays {
            return String(format: "%.4g hours (%.2f Earth days)", abs(hours), earthDays)
        }

        return formatHours(hours)
    }

    private func formatHours(_ hours: Double) -> String {
        String(format: "%.4g hours", abs(hours))
    }

    private func formatSpeed(_ metersPerSecond: Double) -> String {
        String(format: "%.2f km/s", metersPerSecond / 1_000)
    }
}
