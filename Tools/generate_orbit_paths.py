#!/usr/bin/env python3
"""Generate NASA/JPL Horizons-sampled planet orbit paths.

The output is bundled with the app and used for pre-traced planet paths.
"""

from __future__ import annotations

import argparse
import csv
import json
import ssl
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path


HORIZONS_API_URL = "https://ssd.jpl.nasa.gov/api/horizons.api"
SSL_CONTEXT: ssl.SSLContext | None = None


@dataclass(frozen=True)
class PlanetPathTarget:
    name: str
    command: str
    orbital_period_years: float
    samples: int


PLANETS = [
    PlanetPathTarget("Mercury", "199", 0.2408467, 720),
    PlanetPathTarget("Venus", "299", 0.61519726, 720),
    PlanetPathTarget("Earth", "399", 1.0000174, 720),
    PlanetPathTarget("Mars", "499", 1.8808476, 720),
    PlanetPathTarget("Jupiter", "599", 11.862615, 1440),
    PlanetPathTarget("Saturn", "699", 29.447498, 1440),
    PlanetPathTarget("Uranus", "799", 84.016846, 1440),
    PlanetPathTarget("Neptune", "899", 164.79132, 1440),
]


def horizons_time(value: datetime) -> str:
    return value.strftime("%Y-%b-%d %H:%M")


def query_planet_path(target: PlanetPathTarget, epoch: datetime) -> list[list[float]]:
    stop_time = epoch + timedelta(days=target.orbital_period_years * 365.25)
    params = {
        "format": "json",
        "COMMAND": f"'{target.command}'",
        "OBJ_DATA": "NO",
        "MAKE_EPHEM": "YES",
        "EPHEM_TYPE": "VECTORS",
        "CENTER": "500@10",
        "START_TIME": f"'{horizons_time(epoch)}'",
        "STOP_TIME": f"'{horizons_time(stop_time)}'",
        "STEP_SIZE": f"'{target.samples}'",
        "REF_SYSTEM": "ICRF",
        "REF_PLANE": "ECLIPTIC",
        "OUT_UNITS": "AU-D",
        "VEC_TABLE": "2",
        "VEC_CORR": "NONE",
        "CSV_FORMAT": "YES",
        "TIME_DIGITS": "SECONDS",
    }
    url = f"{HORIZONS_API_URL}?{urllib.parse.urlencode(params)}"

    with urllib.request.urlopen(url, timeout=60, context=SSL_CONTEXT) as response:
        payload = json.load(response)

    if "error" in payload:
        raise RuntimeError(payload["error"])

    result = payload.get("result", "")
    return parse_positions_au(result)


def parse_positions_au(result: str) -> list[list[float]]:
    try:
        section = result.split("$$SOE", 1)[1].split("$$EOE", 1)[0]
    except IndexError as error:
        preview = "\n".join(result.splitlines()[:12])
        raise RuntimeError(f"No vector section found in Horizons result:\n{preview}") from error

    points: list[list[float]] = []
    for row in csv.reader(line for line in section.splitlines() if line.strip()):
        if len(row) < 5:
            continue

        try:
            points.append([float(row[2]), float(row[3]), float(row[4])])
        except ValueError:
            continue

    if len(points) < 2:
        raise RuntimeError("Could not parse enough orbit path points from Horizons result.")

    return points


def generate(output_path: Path, epoch: datetime) -> None:
    paths = []
    for planet in PLANETS:
        print(f"Generating {planet.name} path ({planet.samples} samples)")
        points = query_planet_path(planet, epoch)
        paths.append(
            {
                "objectName": planet.name,
                "kind": "Planet",
                "pointsAU": points,
            }
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(paths, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output_path}")


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    default_output = repo_root / "Solar Simulation" / "Resources" / "OrbitPaths" / "planet_orbit_paths.json"

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=default_output)
    parser.add_argument("--epoch", default="2026-05-28", help="Reference epoch date, interpreted at 12:00 UTC.")
    parser.add_argument(
        "--insecure",
        action="store_true",
        help="Disable TLS certificate verification if the local Python certificate store is broken.",
    )
    args = parser.parse_args()

    global SSL_CONTEXT
    if args.insecure:
        SSL_CONTEXT = ssl._create_unverified_context()

    epoch = datetime.strptime(args.epoch + " 12:00", "%Y-%m-%d %H:%M")
    generate(args.output, epoch)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
