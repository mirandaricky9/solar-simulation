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

## Scale modes
The renderer supports two visual scale modes. Enhanced scale keeps the existing
educational body exaggeration so planets, moons, and small bodies remain readable.
True Scale uses physical radii converted to AU with a uniform radius multiplier, so
relative size differences are preserved and planets may be tiny unless the camera is
zoomed in.

## Rotation and object facts
Planet spin, axial tilt, day, and year metadata use NASA/JPL Solar System Dynamics and
NASA Planetary Fact Sheet style values. Moon spin is modeled as synchronous rotation
where that is a safe approximation. Dwarf planet, asteroid, and comet spin is only
applied where the project has an approximate known value; otherwise the object remains
non-spinning rather than presenting invented facts.

Selected-object details now live in the expandable right-hand info sidebar. The sidebar
groups orbit, rotation, physical facts, notes, and Wikipedia links when a page mapping
is available.

## Visual-only distant object fields
The asteroid belt, Kuiper Belt, and Oort Cloud layers are visual-only fields. They are
not `CelestialBody` objects, do not participate in N-body physics, do not store trails,
and are rendered from reusable Metal instance buffers.

The Kuiper Belt layer represents an icy trans-Neptunian disk from roughly 30 to 55 AU.
The Oort Cloud layer represents a theoretical distant spherical shell from roughly
5,000 to 100,000 AU. In Enhanced scale the Oort Cloud is visually compressed so it can
be inspected; in True Scale it remains extremely distant from the planetary system.
