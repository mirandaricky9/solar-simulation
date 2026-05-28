import SwiftUI

struct SolarSystemView: View {
    @ObservedObject var viewModel: SimulationViewModel
    @State private var isSideMenuVisible = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if isSideMenuVisible {
                    SimulationSideMenu(viewModel: viewModel) {
                        isSideMenuVisible = false
                    }
                    .transition(.move(edge: .leading))
                }

                ZStack(alignment: .topTrailing) {
                    SimulationViewContainer(viewModel: viewModel)

                    if !isSideMenuVisible {
                        VStack {
                            HStack {
                                Button {
                                    isSideMenuVisible = true
                                } label: {
                                    Label("Show Menu", systemImage: "sidebar.left")
                                }
                                .padding(8)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .help("Show side menu")

                                Spacer()
                            }

                            Spacer()
                        }
                        .padding()
                    }

                    if let info = viewModel.selectedObjectInfo {
                        SelectedObjectInfoPanel(info: info) {
                            viewModel.clearSelection()
                        }
                        .padding()
                    }
                }
            }
            .frame(minWidth: 900, minHeight: 650)

            Divider()

            ControlPanel(viewModel: viewModel)
        }
    }
}
