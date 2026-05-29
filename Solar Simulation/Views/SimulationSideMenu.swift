import SwiftUI

struct SimulationSideMenu: View {
    @ObservedObject var viewModel: SimulationViewModel
    let onClose: () -> Void

    @State private var showDateControls = true
    @State private var showCameraControls = true
    @State private var showPlanetControls = true
    @State private var showOrbitControls = true
    @State private var showObjectControls = true
    @State private var showInfoControls = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Display")
                    .font(.headline)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(.borderless)
                .help("Hide side menu")
            }

            Divider()

            DisclosureGroup("Date / Ephemeris", isExpanded: $showDateControls) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Initial Date", selection: $viewModel.selectedEphemerisPresetID) {
                        ForEach(viewModel.ephemerisPresets) { preset in
                            Text(preset.displayTitle).tag(preset.id)
                        }
                    }
                    .labelsHidden()

                    Button("Jump to Selected Date") {
                        viewModel.jumpToEphemerisPreset(id: viewModel.selectedEphemerisPresetID)
                    }

                    Text("Positions are initialized from bundled NASA/JPL Horizons snapshots.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let error = viewModel.ephemerisLoadError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 8)
                .padding(.top, 6)
            }

            DisclosureGroup("Camera", isExpanded: $showCameraControls) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lock Onto")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker(
                        "Lock Onto",
                        selection: Binding<String>(
                            get: { viewModel.cameraLockTargetName ?? "None" },
                            set: { newValue in
                                if newValue == "None" {
                                    viewModel.clearCameraLock()
                                } else {
                                    viewModel.lockCamera(to: newValue)
                                }
                            }
                        )
                    ) {
                        Text("None").tag("None")

                        ForEach(viewModel.cameraLockTargets) { target in
                            Text("\(target.name) (\(target.kind.rawValue))")
                                .tag(target.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Button("Clear Camera Lock") {
                        viewModel.clearCameraLock()
                    }
                    .disabled(viewModel.cameraLockTargetName == nil)

                    Divider()

                    Button("Top Down 2D") {
                        viewModel.requestCameraPreset(.topDown2D)
                    }

                    Button("Angled 45°") {
                        viewModel.requestCameraPreset(.angled45)
                    }

                    Button("Flat 0°") {
                        viewModel.requestCameraPreset(.flat0)
                    }
                }
                .padding(.leading, 8)
                .padding(.top, 6)
            }

            DisclosureGroup("Planets", isExpanded: $showPlanetControls) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(PlanetFactCatalog.planetNames, id: \.self) { planetName in
                        HStack {
                            Toggle(
                                planetName,
                                isOn: Binding(
                                    get: { viewModel.visiblePlanetNames.contains(planetName) },
                                    set: { viewModel.setPlanetVisible(planetName, isVisible: $0) }
                                )
                            )

                            Spacer()

                            Button {
                                viewModel.centerCameraOnObject(named: planetName)
                            } label: {
                                Image(systemName: "scope")
                            }
                            .buttonStyle(.borderless)
                            .help("Center camera on \(planetName)")
                        }
                    }
                }
                .padding(.leading, 8)
                .padding(.top, 6)
            }

            DisclosureGroup("Orbital Paths", isExpanded: $showOrbitControls) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Pre-traced Orbit Paths", isOn: $viewModel.showPretracedOrbitPaths)
                    Toggle("Live Trails", isOn: $viewModel.showLiveTrails)
                }
                .padding(.leading, 8)
                .padding(.top, 6)
            }

            DisclosureGroup("Objects", isExpanded: $showObjectControls) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Asteroid Belt", isOn: $viewModel.showAsteroidBelt)
                        .onChange(of: viewModel.showAsteroidBelt) { _, _ in
                            viewModel.reset()
                        }

                    Toggle("Dwarf Planets", isOn: $viewModel.showDwarfPlanets)
                    Toggle("Notable Asteroids", isOn: $viewModel.showNotableAsteroids)
                    Toggle("Comets", isOn: $viewModel.showComets)
                }
                .padding(.leading, 8)
                .padding(.top, 6)
            }

            DisclosureGroup("Labels & Info", isExpanded: $showInfoControls) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Click a body to show information.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 8)
                .padding(.top, 6)
            }

            Spacer()
        }
        .padding(14)
        .frame(width: 260)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(.separator),
            alignment: .trailing
        )
    }
}
