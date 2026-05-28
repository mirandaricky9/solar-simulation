import SwiftUI

struct SelectedObjectInfoPanel: View {
    let info: SelectedObjectInfo
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.headline)
                    Text(info.kind.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    onClose()
                }
                .buttonStyle(.borderless)
            }

            Divider()

            if let dateText = info.dateText {
                infoRow("Date", dateText)
            }

            if let parentName = info.parentName {
                infoRow("Parent", parentName)
            }

            infoRow("Apsis", info.apsisPhase.rawValue)

            if let distanceToSunMeters = info.distanceToSunMeters {
                infoRow("Distance to Sun", formatSunDistance(distanceToSunMeters))
            }

            if let distanceToParentMeters = info.distanceToParentMeters {
                infoRow("Distance to Parent", formatKilometers(distanceToParentMeters))
            }

            if let massKg = info.massKg {
                infoRow("Mass", formatMass(massKg))
            }

            if let radiusMeters = info.radiusMeters {
                infoRow("Radius", formatKilometers(radiusMeters))
            }

            if let circumferenceMeters = info.circumferenceMeters {
                infoRow("Circumference", formatKilometers(circumferenceMeters))
            }

            if let orbitalPeriodSeconds = info.orbitalPeriodSeconds {
                infoRow("Orbital Period", formatPeriod(orbitalPeriodSeconds))
            }

            if let speedMetersPerSecond = info.speedMetersPerSecond {
                infoRow("Speed", formatSpeed(speedMetersPerSecond))
            }

            if let notes = info.notes {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(width: 330, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 8)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .leading)

            Text(value)
                .font(.caption)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func formatSpeed(_ metersPerSecond: Double) -> String {
        String(format: "%.2f km/s", metersPerSecond / 1_000)
    }
}
