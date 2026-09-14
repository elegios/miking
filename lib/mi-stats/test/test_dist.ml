let p n v = Printf.printf "%-22s %s\n" n (Printf.sprintf "%.15g" v)
let () =
  let open Mi_stats in
  p "chi2_lpdf(0.5,3)" (chi2_lpdf 0.5 3.0);
  p "chi2_cdf(2.3659,3)" (chi2_cdf 2.3659 3.0);
  p "chi2_ppf(0.5,3)" (chi2_ppf 0.5 3.0);
  p "gamma_lpdf(2,2,3)" (gamma_lpdf 2.0 2.0 3.0);
  p "gamma_cdf(2,2,3)" (gamma_cdf 2.0 2.0 3.0);
  p "gamma_ppf(0.5,2,3)" (gamma_ppf 0.5 2.0 3.0);
  p "beta_lpdf(0.3,2,5)" (beta_lpdf 0.3 2.0 5.0);
  p "normal_lpdf(0.5,0,1)" (normal_lpdf 0.5 0.0 1.0);
  p "binom_lpmf(3,0.5,10)" (binomial_lpmf 3 0.5 10);
  p "lomax_lpdf(1,2,3)" (lomax_lpdf 1.0 2.0 3.0);
  p "lomax_lpdf(4,2,3)" (lomax_lpdf 4.0 2.0 3.0);
  p "lgamma(4.5)" (log_gamma 4.5);
  p "log_combination(10,3)" (log_combination 10 3);
  p "multinom_lpmf" (multinomial_lpmf [|2;3;5|] [|0.2;0.3;0.5|]);
  p "dirichlet_lpdf" (dirichlet_lpdf [|0.2;0.3;0.5|] [|1.0;2.0;3.0|]);
  print_endline "--- out-of-support: expect neg_infinity ---";
  p "gamma_lpdf(-1,2,3)" (gamma_lpdf (-1.0) 2.0 3.0);
  p "beta_lpdf(1.5,2,5)" (beta_lpdf 1.5 2.0 5.0);
  p "chi2_lpdf(-1,3)" (chi2_lpdf (-1.0) 3.0);
  print_endline "--- invalid parameter: expect Invalid_argument ---";
  List.iter (fun (n, f) ->
      match f () with
      | v -> Printf.printf "%-22s NO RAISE (%g)\n" n v
      | exception Invalid_argument m -> Printf.printf "%-22s raised: %s\n" n m)
    [ "normal_lpdf(0,0,-1)", (fun () -> normal_lpdf 0.0 0.0 (-1.0));
      "gamma_lpdf(1,-2,3)",  (fun () -> gamma_lpdf 1.0 (-2.0) 3.0);
      "chi2_ppf(1.5,3)",     (fun () -> chi2_ppf 1.5 3.0) ];
  (match dirichlet_lpdf [|0.2;0.3;0.5|] [|1.0;-2.0;3.0|] with
   | v -> Printf.printf "dirichlet bad alpha    NO RAISE (%g)\n" v
   | exception Invalid_argument m -> Printf.printf "dirichlet bad alpha    raised: %s\n" m);
  print_endline "--- samplers, seeded ---";
  set_seed 42;
  p "normal_sample" (normal_sample 0.0 1.0);
  p "gamma_sample(2,1)" (gamma_sample 2.0 1.0);
  Printf.printf "%-22s %d\n" "binomial_sample" (binomial_sample 0.5 10);
  Printf.printf "%-22s %d\n" "categorical_sample" (categorical_sample [|0.2;0.3;0.5|]);
  Printf.printf "%-22s %d\n" "uniform_int_sample" (uniform_int_sample 3 7);
  Printf.printf "%-22s [|%s|]\n" "multinomial_sample"
    (String.concat ";" (Array.to_list (Array.map string_of_int (multinomial_sample 10 [|0.2;0.3;0.5|]))));
  Printf.printf "%-22s [|%s|]\n" "dirichlet_sample"
    (String.concat ";" (Array.to_list (Array.map (Printf.sprintf "%.4f") (dirichlet_sample [|1.0;2.0;3.0|]))));
  print_endline "--- set_seed reproducibility ---";
  set_seed 7; let a = normal_sample 0.0 1.0 in
  set_seed 7; let b = normal_sample 0.0 1.0 in
  Printf.printf "same seed -> same draw: %b (%.15g)\n" (a = b) a
