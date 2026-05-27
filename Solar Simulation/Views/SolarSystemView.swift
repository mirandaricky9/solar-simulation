import SwiftUI

struct SolarSystemView: View {
    @ObservedObject var viewModel: SimulationViewModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                SimulationViewContainer(viewModel: viewModel)

                if let info = viewModel.selectedObjectInfo {
                    SelectedObjectInfoPanel(info: info) {
                        viewModel.clearSelection()
                    }
                    .padding()
                }
            }
            .frame(minWidth: 900, minHeight: 650)

            Divider()

            ControlPanel(viewModel: viewModel)
        }
    }
}
