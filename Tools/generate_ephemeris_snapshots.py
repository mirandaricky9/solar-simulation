#!/usr/bin/env python3
"""Generate bundled ephemeris snapshots from NASA/JPL Horizons.

The app does not query Horizons at runtime. Run this script offline to refresh
the JSON files under Resources/EphemerisSnapshots.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path


HORIZONS_API_URL = "https://ssd.jpl.nasa.gov/api/horizons.api"
KM_TO_METERS = 1_000.0
SSL_CONTEXT: ssl.SSLContext | None = None


@dataclass(frozen=True)
class Preset:
    id: str
    title: str
    iso_date: str
    notes: str


@dataclass(frozen=True)
class Target:
    name: str
    command: str
    kind: str
    parent_name: str | None
    is_physics_body: bool


PRESETS = [
    Preset("halley_1986", "Halley 1986 Visit", "1986-02-09", "Historic Halley apparition epoch."),
    Preset("j2000", "J2000 Reference", "2000-01-01", "Useful modern reference epoch."),
    Preset("modern_2010", "Modern Solar System 2010", "2010-01-01", "Modern comparison epoch."),
    Preset("modern_2020", "Modern Solar System 2020", "2020-01-01", "Modern comparison epoch."),
    Preset("eclipse_2024", "April 2024 Alignment", "2024-04-08", "Useful Earth/Moon/Sun alignment preset."),
    Preset("current_2026", "Current Project Epoch", "2026-05-28", "Current project reference date."),
    Preset("future_2030", "Near Future 2030", "2030-01-01", "Near-future comparison epoch."),
    Preset("future_2040", "Future 2040", "2040-01-01", "Future comparison epoch."),
    Preset("halley_2061", "Halley 2061 Return Window", "2061-07-28", "Future Halley return window."),
    Preset("future_2100", "Future 2100", "2100-01-01", "Far-future comparison epoch."),
]


TARGETS = [
    Target("Sun", "10", "Star", None, True),
    Target("Mercury", "199", "Planet", None, True),
    Target("Venus", "299", "Planet", None, True),
    Target("Earth", "399", "Planet", None, True),
    Target("Mars", "499", "Planet", None, True),
    Target("Jupiter", "599", "Planet", None, True),
    Target("Saturn", "699", "Planet", None, True),
    Target("Uranus", "799", "Planet", None, True),
    Target("Neptune", "899", "Planet", None, True),
    Target("Moon", "301", "Moon", "Earth", True),
    Target("Phobos", "401", "Moon", "Mars", True),
    Target("Deimos", "402", "Moon", "Mars", True),
    Target("Io", "501", "Moon", "Jupiter", True),
    Target("Europa", "502", "Moon", "Jupiter", True),
    Target("Ganymede", "503", "Moon", "Jupiter", True),
    Target("Callisto", "504", "Moon", "Jupiter", True),
    Target("Mimas", "601", "Moon", "Saturn", True),
    Target("Enceladus", "602", "Moon", "Saturn", True),
    Target("Tethys", "603", "Moon", "Saturn", True),
    Target("Dione", "604", "Moon", "Saturn", True),
    Target("Rhea", "605", "Moon", "Saturn", True),
    Target("Titan", "606", "Moon", "Saturn", True),
    Target("Hyperion", "607", "Moon", "Saturn", True),
    Target("Iapetus", "608", "Moon", "Saturn", True),
    Target("Phoebe", "609", "Moon", "Saturn", True),
    Target("Janus", "610", "Moon", "Saturn", True),
    Target("Epimetheus", "611", "Moon", "Saturn", True),
    Target("Ariel", "701", "Moon", "Uranus", True),
    Target("Umbriel", "702", "Moon", "Uranus", True),
    Target("Titania", "703", "Moon", "Uranus", True),
    Target("Oberon", "704", "Moon", "Uranus", True),
    Target("Miranda", "705", "Moon", "Uranus", True),
    Target("Triton", "801", "Moon", "Neptune", True),
    Target("Nereid", "802", "Moon", "Neptune", True),
    Target("Naiad", "803", "Moon", "Neptune", True),
    Target("Thalassa", "804", "Moon", "Neptune", True),
    Target("Despina", "805", "Moon", "Neptune", True),
    Target("Galatea", "806", "Moon", "Neptune", True),
    Target("Larissa", "807", "Moon", "Neptune", True),
    Target("Proteus", "808", "Moon", "Neptune", True),
    Target("Pluto", "999", "Dwarf Planet", None, True),
    Target("Charon", "901", "Moon", "Pluto", True),
    Target("Nix", "902", "Moon", "Pluto", True),
    Target("Hydra", "903", "Moon", "Pluto", True),
    Target("Kerberos", "904", "Moon", "Pluto", True),
    Target("Styx", "905", "Moon", "Pluto", True),
    Target("Ceres", "1;", "Dwarf Planet", None, False),
    Target("Vesta", "4;", "Asteroid", None, False),
    Target("Pallas", "2;", "Asteroid", None, False),
    Target("Hygiea", "10;", "Asteroid", None, False),
    Target("1P/Halley", "DES=1P;CAP;NOFRAG", "Comet", None, False),
    Target("2P/Encke", "DES=2P;CAP;NOFRAG", "Comet", None, False),
    Target("109P/Swift-Tuttle", "DES=109P;CAP;NOFRAG", "Comet", None, False),
]


def horizons_calendar_time(iso_date: str) -> str:
    year, month, day = iso_date.split("-")
    month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return f"{year}-{month_names[int(month) - 1]}-{day} 12:00"


def query_horizons(target: Target, preset: Preset) -> dict[str, list[float]]:
    if target.name == "Sun":
        return {
            "position_m": [0.0, 0.0, 0.0],
            "velocity_mps": [0.0, 0.0, 0.0],
        }

    start_time = horizons_calendar_time(preset.iso_date)
    params = {
        "format": "json",
        "COMMAND": f"'{target.command}'",
        "OBJ_DATA": "NO",
        "MAKE_EPHEM": "YES",
        "EPHEM_TYPE": "VECTORS",
        "CENTER": "500@10",
        "START_TIME": f"'{start_time}'",
        "STOP_TIME": f"'{start_time[:-5]}12:01'",
        "STEP_SIZE": "'1 m'",
        "REF_SYSTEM": "ICRF",
        "REF_PLANE": "ECLIPTIC",
        "OUT_UNITS": "KM-S",
        "VEC_TABLE": "2",
        "VEC_CORR": "NONE",
        "CSV_FORMAT": "YES",
        "TIME_DIGITS": "SECONDS",
    }
    url = f"{HORIZONS_API_URL}?{urllib.parse.urlencode(params)}"

    with urllib.request.urlopen(url, timeout=30, context=SSL_CONTEXT) as response:
        payload = json.load(response)

    if "error" in payload:
        raise RuntimeError(payload["error"])

    result = payload.get("result", "")
    return parse_vector_result(result)


def parse_vector_result(result: str) -> dict[str, list[float]]:
    try:
        section = result.split("$$SOE", 1)[1].split("$$EOE", 1)[0]
    except IndexError as error:
        preview = "\n".join(result.splitlines()[:12])
        raise RuntimeError(f"No vector section found in Horizons result:\n{preview}") from error

    for row in csv.reader(line for line in section.splitlines() if line.strip()):
        if len(row) >= 8:
            try:
                values = [float(row[index]) for index in range(2, 8)]
            except ValueError:
                continue

            return {
                "position_m": [values[0] * KM_TO_METERS, values[1] * KM_TO_METERS, values[2] * KM_TO_METERS],
                "velocity_mps": [values[3] * KM_TO_METERS, values[4] * KM_TO_METERS, values[5] * KM_TO_METERS],
            }

    patterns = {
        "position_m": r"X\\s*=\\s*([+-]?\\d+\\.\\d+E[+-]\\d+)\\s+Y\\s*=\\s*([+-]?\\d+\\.\\d+E[+-]\\d+)\\s+Z\\s*=\\s*([+-]?\\d+\\.\\d+E[+-]\\d+)",
        "velocity_mps": r"VX\\s*=\\s*([+-]?\\d+\\.\\d+E[+-]\\d+)\\s+VY\\s*=\\s*([+-]?\\d+\\.\\d+E[+-]\\d+)\\s+VZ\\s*=\\s*([+-]?\\d+\\.\\d+E[+-]\\d+)",
    }
    parsed: dict[str, list[float]] = {}
    for key, pattern in patterns.items():
        match = re.search(pattern, section)
        if not match:
            continue
        parsed[key] = [float(value) * KM_TO_METERS for value in match.groups()]

    if "position_m" in parsed and "velocity_mps" in parsed:
        return parsed

    raise RuntimeError("Could not parse x/y/z/vx/vy/vz from Horizons result.")


def write_snapshot(output_dir: Path, preset: Preset, states: list[dict]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    snapshot = {
        "presetID": preset.id,
        "isoDate": preset.iso_date,
        "internalTimestampUTC": f"{preset.iso_date} 12:00:00",
        "source": "NASA/JPL Horizons API, EPHEM_TYPE=VECTORS, CENTER=500@10, REF_SYSTEM=ICRF, REF_PLANE=ECLIPTIC, VEC_CORR=NONE",
        "center": "500@10",
        "units": "meters and meters/second converted from Horizons KM-S vectors",
        "states": states,
    }
    output_path = output_dir / f"ephemeris_{preset.id}.json"
    output_path.write_text(json.dumps(snapshot, indent=2, sort_keys=False) + "\n", encoding="utf-8")
    print(f"Wrote {output_path} ({len(states)} states)")


def generate(output_dir: Path, delay_seconds: float, physics_only: bool) -> None:
    targets = [target for target in TARGETS if target.is_physics_body] if physics_only else TARGETS

    for preset in PRESETS:
        states = []
        print(f"\nGenerating {preset.id} at {preset.iso_date} 12:00 UTC")
        for target in targets:
            try:
                vectors = query_horizons(target, preset)
            except Exception as error:
                print(f"  FAILED {target.name} ({target.command}): {error}", file=sys.stderr)
                continue

            states.append(
                {
                    "name": target.name,
                    "horizonsCommand": target.command,
                    "kind": target.kind,
                    "parentName": target.parent_name,
                    "positionMeters": vectors["position_m"],
                    "velocityMetersPerSecond": vectors["velocity_mps"],
                }
            )
            print(f"  {target.name}")
            if delay_seconds > 0:
                time.sleep(delay_seconds)

        write_snapshot(output_dir, preset, states)


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    default_output = repo_root / "Solar Simulation" / "Resources" / "EphemerisSnapshots"

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=default_output)
    parser.add_argument("--delay", type=float, default=0.05, help="Delay between Horizons requests.")
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Disable TLS certificate verification if the local Python certificate store is broken.",
    )
    parser.add_argument(
        "--physics-only",
        action="store_true",
        help="Generate only Sun/planets/moons/Pluto physics states. Useful for quick validation.",
    )
    args = parser.parse_args()

    global SSL_CONTEXT
    if args.insecure:
        SSL_CONTEXT = ssl._create_unverified_context()

    generate(args.output_dir, args.delay, args.physics_only)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
