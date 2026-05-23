import SwiftUI

struct SolarSystemView: View {
    @ObservedObject var viewModel: SimulationViewModel

    var body: some View {
        VStack(spacing: 0) {
            SimulationViewContainer(viewModel: viewModel)
                .frame(minWidth: 900, minHeight: 650)

            Divider()

            ControlPanel(viewModel: viewModel)
        }
    }
}
