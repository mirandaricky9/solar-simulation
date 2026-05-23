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

            Text("Speed")

            Slider(value: $viewModel.timeStepMultiplier, in: 1...500, step: 1)
                .frame(width: 220)

            Text("\(Int(viewModel.timeStepMultiplier))x")
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
