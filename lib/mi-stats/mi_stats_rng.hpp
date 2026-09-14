// The one generator mi-stats owns.
#ifndef MI_STATS_RNG_HPP
#define MI_STATS_RNG_HPP

#include <boost/random/mersenne_twister.hpp>

#include <chrono>
#include <random>

namespace mi {

// owl's externalSetSeed reached into four generators -- Random.init,
// Owl_base_stats_prng.init, Owl_stats_prng.sfmt_seed and ziggurat_init -- and
// a caller had no way to know which of them a given distribution used. Stan's
// *_rng functions all take an engine by reference, so there is exactly one
// here and mi_set_seed reseeds it. `Random.init` on the OCaml side stays the
// caller's business; dist-ext.mc's setSeed drives both.
//
// Self-initialisation matters as much as seeding does. owl_stats.ml ran
// `Owl_stats_prng.self_init ()` at *module load*, so simply linking owl
// time-seeded the generator, and CorePPL depends on that: runtime-common.mc
// calls setSeed only when PPL_SEED or --seed is given, and `cppl --help`
// promises the seed is "Initialized randomly if option is omitted". A fixed
// default seed here would silently make every unseeded inference run produce
// byte-identical output -- so the engine is seeded nondeterministically on
// first use, and mi_set_seed overrides that deterministically.
inline boost::random::mt19937::result_type nondeterministic_seed() {
  // std::random_device reads a real entropy source on the platforms we build
  // for, but it is permitted to be deterministic, so a high-resolution clock
  // reading is mixed in rather than relied on alone.
  std::random_device rd;
  const auto now = std::chrono::high_resolution_clock::now()
                       .time_since_epoch()
                       .count();
  return static_cast<boost::random::mt19937::result_type>(
      rd() ^ static_cast<unsigned long long>(now));
}

// Not thread-safe, which matches the semantics Miking had before: a single
// global stream, reseeded by setSeed.
inline boost::random::mt19937 &engine() {
  static boost::random::mt19937 e{nondeterministic_seed()};
  return e;
}

}  // namespace mi

#endif
