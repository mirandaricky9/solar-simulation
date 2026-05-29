import SwiftUI

struct SolarSystemView: View {
    @ObservedObject var viewModel: SimulationViewModel
    @State private var isSideMenuVisible = true
    @State private var isRightInfoSidebarVisible = true

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

                    overlayControls
                }

                if isRightInfoSidebarVisible {
                    ObjectInfoSidebar(
                        info: viewModel.selectedObjectInfo,
                        onClearSelection: {
                            viewModel.clearSelection()
                        },
                        onHide: {
                            isRightInfoSidebarVisible = false
                        }
                    )
                    .transition(.move(edge: .trailing))
                }
            }
            .frame(minWidth: 900, minHeight: 650)

            Divider()

            ControlPanel(viewModel: viewModel)
        }
    }

    private var overlayControls: some View {
        VStack {
            HStack {
                if !isSideMenuVisible {
                    Button {
                        isSideMenuVisible = true
                    } label: {
                        Label("Show Menu", systemImage: "sidebar.left")
                    }
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .help("Show side menu")
                }

                Spacer()

                if !isRightInfoSidebarVisible {
                    Button {
                        isRightInfoSidebarVisible = true
                    } label: {
                        Label("Show Info", systemImage: "sidebar.right")
                    }
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .help("Show object info")
                }
            }

            Spacer()
        }
        .padding()
    }
}
