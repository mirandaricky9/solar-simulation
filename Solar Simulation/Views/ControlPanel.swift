import SwiftUI

struct ControlPanel: View {
    @ObservedObject var viewModel: SimulationViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button(viewModel.isRunning ? "Pause" : "Start") {
                viewModel.toggleSimulation()
            }

            Button("Step") {
                viewModel.simulateStep()
            }

            Button("Reset") {
                viewModel.reset()
            }

            Toggle("Asteroid Belt", isOn: $viewModel.showAsteroidBelt)
                .onChange(of: viewModel.showAsteroidBelt) { _ in
                    viewModel.reset()
                }

            Toggle("Comets", isOn: $viewModel.showComets)

            Toggle("Live Trails", isOn: $viewModel.showLiveTrails)

            Toggle("Orbit Paths", isOn: $viewModel.showPretracedOrbitPaths)

            Text("Speed")

            Slider(value: $viewModel.simulatedDaysPerSecond, in: 0.25...100, step: 0.25)
                .frame(width: 220)

            Text("\(viewModel.simulatedDaysPerSecond, specifier: "%.2g") days/s")
                .monospacedDigit()
                .frame(width: 80, alignment: .leading)

            Text("dt")

            Slider(value: $viewModel.directTimeStepMultiplier, in: 1...500, step: 1)
                .frame(width: 160)

            Text("\(Int(viewModel.directTimeStepMultiplier))x")
                .monospacedDigit()
                .frame(width: 48, alignment: .leading)

            Text("Camera")

            Slider(value: $viewModel.cameraSensitivity, in: 0.05...1, step: 0.05)
                .frame(width: 160)

            Text("\(viewModel.cameraSensitivity, specifier: "%.2g")x")
                .monospacedDigit()
                .frame(width: 48, alignment: .leading)

            Spacer()

            Text("Bodies: \(viewModel.bodies.count)")
                .monospacedDigit()

            Text("Days: \(Int(viewModel.currentTime / 86_400))")
                .monospacedDigit()
        }
        .padding()
    }
}
