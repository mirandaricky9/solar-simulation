# solar-simulation
A macOS-based application of a solar system simulation, built using Swift. 
The goal is to familiarize myself with AI and agentic workflows using ChatGPT,
codex and local models on Ollama via Opencode.
The project is inspired by my interest in physics and the N-body problem.



## To-Do
- Add all major moons in the solar system.
- Create an asteroid belt with many more bodies that do not count towards the calculation
of the n-body problem. Purely aesthetic. There are over a million comets that we see.
- Map Halley's comet and other comets that we see on Earth. Map apophis as well.
- Create camera presets that move the camera that centers on the planet, based on what is selected.
- Attach a true-time to simulate period on the system such that the date shown in the simulation is
roughly what position the planets will be in at the time.
- After implementing the previous bullet point, add a mechanic to be able to see when solar eclipses
and lunar eclipses occur, along with their dates.
- Implement time jumps between periods to get the estimated position of the celestial objects in our system.
- Instead of simulating indefinitely, simulate for hundreds or potentially thousands of years and
store the data somehow to avoid recalculations.


## Things to Fix
- Comets do not have live trails enabled. Implement live trails for them.
- Live trails are limited to a certain disance, instead of having it length limited, 
change it to specific lengths for all planets


## Ephemeris and orbit paths
Initial solar-system positions are loaded from bundled NASA/JPL Horizons vector snapshots.
The app uses 12:00:00 UTC for each preset date and displays the simulation date in UTC.
Pretraced planet orbit paths are generated from NASA/JPL Horizons sampled positions.
Live trails are local simulation history and may diverge from the reference paths if the
simplified integrator or timestep drifts. Planet spin, axial tilt, day, and year metadata
use NASA/JPL Solar System Dynamics and NASA Planetary Fact Sheet style values.

To regenerate the bundled data, run:

```bash
python3 Tools/generate_ephemeris_snapshots.py
python3 Tools/generate_orbit_paths.py
```

If the local Python certificate store cannot verify JPL's certificate chain, use:

```bash
python3 Tools/generate_ephemeris_snapshots.py --insecure
python3 Tools/generate_orbit_paths.py --insecure
```

Snapshots are written to `Solar Simulation/Resources/EphemerisSnapshots/` and bundled with the app.
Orbit paths are written to `Solar Simulation/Resources/OrbitPaths/` and bundled with the app.
The simulation integrates forward from the selected snapshot, so long runs can drift from
NASA/JPL ephemerides until refreshed by jumping to another bundled snapshot. A future
accuracy upgrade would use SPICE/SPK interpolation for arbitrary-date positions.

## Texture assets
Planet texture maps live in `Solar Simulation/Resources/Textures/Planets/`.
The bundled Sun, planet, Moon, and Ceres maps are from Solar System Scope textures:
https://www.solarsystemscope.com/textures/

Solar System Scope textures are distributed under Creative Commons Attribution 4.0
International. The Pluto map is from NASA/Wikimedia Commons public-domain imagery.
Recommended public/free sources for future texture updates include NASA 3D Resources,
NASA Solar System Treks, USGS Astrogeology planetary maps, and Solar System Scope
textures under CC BY 4.0.
