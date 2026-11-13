/// Low-level pure-Dart port of the core of Astronomy Engine v2.1.19
/// (Don Cross, MIT): time scales, Earth orientation, VSOP87 planets, the Pluto
/// integrator, the Moon, geocentric and ecliptic positions, and eclipse search.
///
/// Names follow Astronomy Engine in lowerCamelCase. Note that [Body] here is
/// Astronomy Engine's body enum, not the one from `astro_ephemeris.dart`.
library;

export 'src/astronomy/astronomy.dart';
