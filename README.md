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
