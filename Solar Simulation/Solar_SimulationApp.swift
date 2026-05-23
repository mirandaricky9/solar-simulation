//
//  Solar_SimulationApp.swift
//  Solar Simulation
//
//  Created by Ricardo Miranda on 5/23/26.
//

import SwiftUI

@main
struct SolarSimulationApp: App {
    @StateObject private var viewModel = SimulationViewModel()

    var body: some Scene {
        WindowGroup {
            SolarSystemView(viewModel: viewModel)
        }
    }
}
