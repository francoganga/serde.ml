open Serde

let ( let* ) = Result.bind

let print_err err =
  match err with
  | `De (`Unimplemented msg) ->
      print_string ("unimplemented: " ^ msg);
      print_newline ();
      false
  | `De (`Invalid_field_index _) ->
      print_string "invalid_field_idx";
      print_newline ();
      false
  | `De (`Unknown_field s) ->
      print_string ("Unknown_field: " ^ s);
      print_newline ();
      false
  | `De (`Invalid_variant_index _) ->
      print_string "invalid_va_idx";
      print_newline ();
      false
  | `De (`Unknown_variant s) ->
      print_string ("Unknown_variant: " ^ s);
      print_newline ();
      false
  | `De (`Duplicate_field _) ->
      print_string "Duplicate_field";
      print_newline ();
      false
  | `De (`Missing_field _) ->
      print_string "Missing_field";
      print_newline ();
      false
  | `De (`Message msg) ->
      print_string ("msg: " ^ msg);
      print_newline ();
      false
  | `De (`Unexpected_exception exn) ->
      print_string ("exn: " ^ Printexc.to_string exn);
      print_newline ();
      false
  | `Ser _ ->
      print_string "error serializing";
      print_newline ();
      false
  | `De (`Invalid_value_at_pos _) ->
      print_string "invalid_value_at_pos";
      print_newline ();
      false

let parse_sexpr eq fn s t =
  match Serde_sexpr.of_string fn s |> Result.map_error (fun x -> `De x) with
  | Ok t' -> eq t t'
  | Error err -> print_err err

module Type_alias = struct
  type alias = int [@@deriving eq, serializer, deserializer]

  let parse_sexpr = parse_sexpr Int.equal deserialize_alias
  let%test _ = parse_sexpr "1" 1
end

(*
module Type_abstract = struct
  type abstract [@@deriving serializer, deserializer]
end
*)

module Type_tuple = struct
  type tuple = int * Type_alias.alias * bool [@@deriving eq, deserializer]

  let parse_sexpr = parse_sexpr equal_tuple deserialize_tuple
  let%test _ = parse_sexpr "(21 12 true)" (21, 12, true)
end

module Type_record = struct
  type record = {
    r_name : string;
    r_favorite_number : int;
    r_location : string;
  }
  [@@deriving eq, serializer, deserializer]

  let parse_sexpr = parse_sexpr equal_record deserialize_record

  let%test _ =
    parse_sexpr {|("Benjamin Sisko" 9 "Bajor")|}
      { r_name = "Benjamin Sisko"; r_favorite_number = 9; r_location = "Bajor" }
end

module Type_variant = struct
  type variant =
    | Hello
    | Tuple1 of string
    | Tuple2 of string * Type_alias.alias
    | Record3 of { name : string; favorite_number : int; location : string }
  [@@deriving eq, serializer, deserializer]

  let parse_sexpr = parse_sexpr equal_variant deserialize_variant
  let%test _ = parse_sexpr ":Hello" Hello

  let%test _ =
    parse_sexpr {|(:Tuple1 ("this is a tuple"))|} (Tuple1 "this is a tuple")

  let%test _ =
    parse_sexpr {|(:Tuple2 ("this is a tuple"  1))|}
      (Tuple2 ("this is a tuple", 1))

  let%test _ =
    parse_sexpr {|(:Record3 ("Benjamin Sisko" 9 "Bajor"))|}
      (Record3
         { name = "Benjamin Sisko"; favorite_number = 9; location = "Bajor" })
end

(*
module Type_generics_applied = struct
  type 'value pair = 'value * 'value [@@deriving eq]
  type v2f = float pair [@@deriving eq, serializer, deserializer]

  let parse_sexpr = parse_sexpr equal_v2f deserialize_v2f

  let%test _ = parse_sexpr "(1.2 2.3)" (1.2, 2.3)
end
*)
