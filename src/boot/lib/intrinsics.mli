open Ustring.Op

module Mseq : sig
  type 'a t

  val make : int -> (int -> 'a) -> 'a t
  val empty : 'a t
  val length : 'a t -> int
  val concat : 'a t -> 'a t -> 'a t
  val get : 'a t -> int -> 'a
  val set : 'a t -> int -> 'a -> 'a t
  val cons : 'a -> 'a t -> 'a t
  val snoc : 'a t -> 'a -> 'a t
  val reverse : 'a t -> 'a t
  val split_at : 'a t -> int -> 'a t * 'a t

  module Helpers : sig
    val of_list : 'a list -> 'a t
    val to_list : 'a t -> 'a list
    val of_array : 'a array -> 'a t
    val to_array : 'a t -> 'a array
    val of_ustring : ustring -> int t
    val to_ustring : int t -> ustring
    val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool
    val map : ('a -> 'b) -> 'a t -> 'b t
    val fold_right : ('a -> 'acc -> 'acc) -> 'a t -> 'acc -> 'acc
    val combine : 'a t -> 'b t -> ('a * 'b) t
    val fold_right2 : ('a -> 'b -> 'acc -> 'acc) -> 'a t -> 'b t -> 'acc -> 'acc
  end
end

module Symb : sig
  type t

  val gensym : unit -> t
  val eqsym : t -> t -> bool

  module Helpers : sig
    val nosym : t
    val ustring_of_sym : t -> ustring
    val string_of_sym : t -> string
    val hash :  t -> int
  end
end