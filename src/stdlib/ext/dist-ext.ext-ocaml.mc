

include "map.mc"
include "ocaml/ast.mc"

-- Backed by lib/mi-stats, which wraps a vendored, pared-down Stan Math. See
-- lib/README.md. Three things differ from the previous owl bindings and are
-- worth knowing when reading the types below:
--
--   * No labelled arguments. owl's signatures carried ~df, ~shape, ~scale and
--     friends; Mi_stats takes everything positionally, in the same order, so
--     each `otylabel_` has simply gone away. The MExpr-facing API in
--     dist-ext.mc is unchanged.
--   * Gamma still takes a SCALE, as owl's did. Stan's gamma functions take a
--     rate, and mi-stats converts internally, so nothing here has to.
--   * Out-of-support values still come back as -inf, matching owl. An invalid
--     *parameter* now raises Invalid_argument instead of silently producing
--     -inf, which under SMC would have become a zero-weight particle.

let impl = lam arg : { expr : String, ty : use Ast in Type }.
  { expr = arg.expr, ty = arg.ty, libraries = ["mi-stats"], cLibraries = [] }

let distExtMap =
  use OCamlTypeAst in
  mapFromSeq cmpString
  [
    -- Chi-squared
    ("externalChi2LogPdf", [
      impl { expr = "Mi_stats.chi2_lpdf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalChi2Sample", [
      impl { expr = "Mi_stats.chi2_sample",
             ty = tyarrows_ [tyfloat_, tyfloat_] }
    ]),
    ("externalChi2Cdf", [
      impl { expr = "Mi_stats.chi2_cdf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),
    -- Stan Math has no distribution quantiles; this one is Boost.Math, which
    -- lib/ vendors anyway.
    ("externalChi2Ppf", [
      impl { expr = "Mi_stats.chi2_ppf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),

    -- Exponential (rate, as before)
    ("externalExponentialSample", [
      impl { expr = "Mi_stats.exponential_sample",
             ty = tyarrows_ [tyfloat_, tyfloat_] }
    ]),

    -- Gamma (x, shape, scale)
    ("externalGammaLogPdf", [
      impl { expr = "Mi_stats.gamma_lpdf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalGammaSample", [
      impl { expr = "Mi_stats.gamma_sample",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalGammaCdf", [
      impl { expr = "Mi_stats.gamma_cdf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalGammaPpf", [
      impl { expr = "Mi_stats.gamma_ppf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_, tyfloat_] }
    ]),

    -- Binomial. owl was (k, ~p, ~n) and Stan is (k, N, theta); mi-stats keeps
    -- owl's order so this binding does not change shape.
    ("externalBinomialLogPmf", [
      impl { expr = "Mi_stats.binomial_lpmf",
             ty = tyarrows_ [tyint_, tyfloat_, tyint_, tyfloat_] }
    ]),
    ("externalBinomialSample", [
      impl { expr = "Mi_stats.binomial_sample",
             ty = tyarrows_ [tyfloat_, tyint_, tyint_] }
    ]),

    -- Beta
    ("externalBetaLogPdf", [
      impl { expr = "Mi_stats.beta_lpdf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalBetaSample", [
      impl { expr = "Mi_stats.beta_sample",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),

    -- Gaussian
    ("externalGaussianLogPdf", [
      impl { expr = "Mi_stats.normal_lpdf",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalGaussianSample", [
      impl { expr = "Mi_stats.normal_sample",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),

    -- Multinomial
    ("externalMultinomialLogPmf", [
      impl { expr = "Mi_stats.multinomial_lpmf",
             ty = tyarrows_ [otyarray_ tyint_, otyarray_ tyfloat_, tyfloat_] }
    ]),
    ("externalMultinomialSample", [
      impl { expr = "Mi_stats.multinomial_sample",
             ty = tyarrows_ [tyint_, otyarray_ tyfloat_, otyarray_ tyint_] }
    ]),

    -- Categorical. 0-based, as owl's was; Stan's own categorical_rng is
    -- 1-based and mi-stats adjusts.
    ("externalCategoricalSample", [
      impl { expr = "Mi_stats.categorical_sample",
             ty = tyarrows_ [otyarray_ tyfloat_, tyint_] }
    ]),

    -- Dirichlet
    ("externalDirichletLogPdf", [
      impl { expr = "Mi_stats.dirichlet_lpdf",
             ty = tyarrows_ [otyarray_ tyfloat_, otyarray_ tyfloat_, tyfloat_] }
    ]),
    ("externalDirichletSample", [
      impl { expr = "Mi_stats.dirichlet_sample",
             ty = tyarrows_ [otyarray_ tyfloat_, otyarray_ tyfloat_] }
    ]),

    -- Uniform
    ("externalUniformContinuousSample", [
      impl { expr = "Mi_stats.uniform_sample",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),
    ("externalUniformDiscreteSample", [
      impl { expr = "Mi_stats.uniform_int_sample",
             ty = tyarrows_ [tyint_, tyint_, tyint_] }
    ]),

    -- Lomax, i.e. Pareto Type II with mu = 0.
    --
    -- Note there is no externalLomaxLogPdf any more. owl declared one, mapped
    -- it to Owl_stats.lomax_logpdf, and never called it -- because owl's
    -- lomax_logpdf/cdf/ppf actually implement Pareto Type I (support x >=
    -- scale) while its lomax_rvs is a true Lomax, so the two disagreed.
    -- dist-ext.mc has always computed this density in MExpr instead, and that
    -- hand-written version agrees with the sampler below. Mi_stats.lomax_lpdf
    -- exists and also agrees, if the binding is ever wanted back.
    ("externalLomaxSample", [
      impl { expr = "Mi_stats.lomax_sample",
             ty = tyarrows_ [tyfloat_, tyfloat_, tyfloat_] }
    ]),

    -- Seeding. owl reached into four generators -- Random.init,
    -- Owl_base_stats_prng.init, Owl_stats_prng.sfmt_seed and ziggurat_init --
    -- and a caller could not tell which one a given distribution drew from.
    -- mi-stats owns exactly one, so there are two calls here: OCaml's own
    -- Random, and ours.
    ("externalSetSeed", [
      impl { expr = "
        fun seed -> (
          Random.init seed;
          Mi_stats.set_seed seed
        )",
        ty = tyarrows_ [tyint_, otyunit_] }
    ])
  ]
