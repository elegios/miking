open Bigarray
let a1 l = Array1.of_array float64 c_layout (Array.of_list l)
let g2 r c l =
  let g = Genarray.create float64 c_layout [|r;c|] in
  List.iteri (fun i v -> Genarray.set g [| i/c; i mod c |] v) l; g
let show1 v = String.concat " " (List.init (Array1.dim v) (fun i -> Printf.sprintf "%.6g" v.{i}))
let show2 g =
  let d = Genarray.dims g in
  String.concat " " (List.init (d.(0)*d.(1)) (fun i -> Printf.sprintf "%.6g" (Genarray.get g [|i/d.(1); i mod d.(1)|])))
let p n s = Printf.printf "%-26s %s\n" n s
let () =
  let open Mi_stats in
  print_endline "=== matrix-ext (2-D genarray) ===";
  let m3 = g2 3 3 [4.;2.;0.; 1.;4.;1.; 1.;1.;4.] in
  p "matrix_exp 3x3" (show2 (matrix_exp m3));
  p "  owl expm row0" "147.867 183.765 71.797";
  let a = g2 2 2 [1.;2.;3.;4.] and b = g2 2 2 [5.;6.;7.;8.] in
  p "matrix_mul (expect 19 22 43 50)" (show2 (matrix_mul a b));
  p "matrix_transpose (1 3 2 4)" (show2 (matrix_transpose a));
  p "matrix_mul_float 2 (2 4 6 8)" (show2 (matrix_mul_float 2.0 a));
  p "matrix_elem_mul (5 12 21 32)" (show2 (matrix_elem_mul a b));
  p "matrix_elem_add (6 8 10 12)" (show2 (matrix_elem_add a b));
  print_endline "=== mat-ext (flat array1 + m,n) ===";
  let src = a1 [1.;2.;3.; 4.;5.;6.] in
  let dst = a1 [0.;0.;0.; 0.;0.;0.] in
  mat_transpose 2 3 src dst; p "mat_transpose 2x3 -> 3x2" (show1 dst);
  let e = a1 [0.;0.;0.;0.] in
  mat_elem_exp 2 2 (a1 [0.;1.;2.;3.]) e; p "mat_elem_exp" (show1 e);
  mat_elem_log 2 2 (a1 [1.;2.718281828459045;10.;100.]) e; p "mat_elem_log" (show1 e);
  mat_elem_mul 2 2 (a1 [1.;2.;3.;4.]) (a1 [5.;6.;7.;8.]) e;
  p "mat_elem_mul (5 12 21 32)" (show1 e);
  p "mat_exp 3x3 row0" (show1 (mat_exp 3 3 (a1 [4.;2.;0.; 1.;4.;1.; 1.;1.;4.])));
  print_endline "=== cblas-ext ===";
  let x = a1 [1.;2.;3.;4.] and y = a1 [10.;20.;30.;40.] in
  cblas_copy 4 x 1 y 1; p "copy (1 2 3 4)" (show1 y);
  let y2 = a1 [10.;20.;30.;40.] in
  cblas_axpy 4 2.0 x 1 y2 1; p "axpy a=2 (12 24 36 48)" (show1 y2);
  let s = a1 [1.;2.;3.;4.] in
  cblas_scal 4 3.0 s 1; p "scal 3 (3 6 9 12)" (show1 s);
  let xs = a1 [1.;9.;2.;9.;3.;9.] and ys = a1 [0.;0.;0.] in
  cblas_copy 3 xs 2 ys 1; p "copy strided incx=2 (1 2 3)" (show1 ys);
  let am = a1 [1.;2.;3.;4.] in
  let xv = a1 [1.;1.] and yv = a1 [0.;0.] in
  cblas_gemv cblas_row_major cblas_no_trans 2 2 1.0 am 2 xv 1 0.0 yv 1;
  p "gemv row-major (3 7)" (show1 yv);
  let yv2 = a1 [0.;0.] in
  cblas_gemv cblas_row_major cblas_trans 2 2 1.0 am 2 xv 1 0.0 yv2 1;
  p "gemv row-major trans (4 6)" (show1 yv2);
  let yv3 = a1 [0.;0.] in
  cblas_gemv cblas_col_major cblas_no_trans 2 2 1.0 (a1 [1.;3.;2.;4.]) 2 xv 1 0.0 yv3 1;
  p "gemv col-major (3 7)" (show1 yv3);
  let bm = a1 [5.;6.;7.;8.] and cm = a1 [0.;0.;0.;0.] in
  cblas_gemm cblas_row_major cblas_no_trans cblas_no_trans 2 2 2 1.0 am 2 bm 2 0.0 cm 2;
  p "gemm row-major (19 22 43 50)" (show1 cm);
  let cm2 = a1 [0.;0.;0.;0.] in
  cblas_gemm cblas_row_major cblas_trans cblas_no_trans 2 2 2 1.0 am 2 bm 2 0.0 cm2 2;
  p "gemm transA (26 30 38 44)" (show1 cm2);
  let cm3 = a1 [0.;0.;0.;0.] in
  cblas_gemm cblas_col_major cblas_no_trans cblas_no_trans 2 2 2 1.0
    (a1 [1.;3.;2.;4.]) 2 (a1 [5.;7.;6.;8.]) 2 0.0 cm3 2;
  p "gemm col-major (19 43 22 50)" (show1 cm3);
  let cm4 = a1 [1.;1.;1.;1.] in
  cblas_gemm cblas_row_major cblas_no_trans cblas_no_trans 2 2 2 1.0 am 2 bm 2 10.0 cm4 2;
  p "gemm beta=10 (29 32 53 60)" (show1 cm4)
