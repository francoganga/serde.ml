open Serde

let ( let* ) = Result.bind

let print_err err =
  match err with
  | `De (`Unimplemented msg) ->
      print_string ("unimplemented: " ^ msg);
      false
  | `De (`Invalid_field_index _) ->
      print_string "invalid_field_idx";
      false
  | `De (`Unknown_field s) ->
      print_string ("Unknown_field: " ^ s);
      false
  | `De (`Invalid_variant_index _) ->
      print_string "invalid_va_idx";
      false
  | `De (`Unknown_variant s) ->
      print_string ("Unknown_variant: " ^ s);
      false
  | `De (`Duplicate_field _) ->
      print_string "Duplicate_field";
      false
  | `De (`Missing_field _) ->
      print_string "Missing_field";
      false
  | `De (`Message msg) ->
      print_string ("msg: " ^ msg);
      false
  | `De (`Unexpected_exception exn) ->
      print_string ("exn: " ^ Printexc.to_string exn);
      false
  | `Ser _ ->
      print_string "error serializing";
      false
  | `De (`Invalid_value_at_pos _) ->
      false

let parse_json eq fn s t =
  match Serde_json.of_string fn s |> Result.map_error (fun x -> `De x) with
  | Ok t' -> eq t t'
  | Error err -> print_err err

module Type_alias = struct
  type alias = int [@@deriving eq, serializer, deserializer]

  let parse_json = parse_json Int.equal deserialize_alias
  let%test _ = parse_json "     1  " 1
  let%test _ = parse_json "-1012" (-1012)
end

(*
module Type_abstract = struct
  type abstract [@@deriving serializer, deserializer]
end
*)

module Type_tuple = struct
  type tuple = int * Type_alias.alias * bool [@@deriving eq, deserializer]

  let parse_json = parse_json equal_tuple deserialize_tuple

  let%test _ = parse_json {|


  [
    21,
    12,
    true
  ]|} (21, 12, true)
end

module Type_record = struct
  type record = {
    r_name : string;
    r_favorite_number : int;
    r_location : string;
  }
  [@@deriving eq, serializer, deserializer]

  let parse_json = parse_json equal_record deserialize_record

  let%test "parse packed json representation" =
    parse_json {| [ "Benjamin Sisko", 9, "Bajor", ] |}
      { r_name = "Benjamin Sisko"; r_favorite_number = 9; r_location = "Bajor" }

  let%test "parse object json representation" =
    parse_json
      {|
  { "r_name": "Benjamin Sisko",
    "r_favorite_number": 9,
    "r_location": "Bajor"
  }
  |}
      { r_name = "Benjamin Sisko"; r_favorite_number = 9; r_location = "Bajor" }
end

module Type_record_optional = struct
  type record = {
    r_name : string;
    r_favorite_number : int;
    r_location : string option;
  }
  [@@deriving eq, deserializer]

  let parse_json = parse_json equal_record deserialize_record

  let%test "parse packed json representation" =
    parse_json {| [ "Benjamin Sisko", 9, "Bajor", ] |}
      {
        r_name = "Benjamin Sisko";
        r_favorite_number = 9;
        r_location = Some "Bajor";
      }

  let%test "parse object json representation" =
    parse_json
      {|
  { "r_name": "Benjamin Sisko",
    "r_favorite_number": 9,
    "r_location": "Bajor"
  }
  |}
      {
        r_name = "Benjamin Sisko";
        r_favorite_number = 9;
        r_location = Some "Bajor";
      }

  let%test "parse object json representation missing value" =
    parse_json
      {|
  { "r_name": "Benjamin Sisko",
    "r_favorite_number": 9
  }
  |}
      { r_name = "Benjamin Sisko"; r_favorite_number = 9; r_location = None }

  let%test "parse object json representation explicit null" =
    parse_json
      {|
  { "r_name": "Benjamin Sisko",
    "r_favorite_number": 9,
    "r_location": null
  }
  |}
      { r_name = "Benjamin Sisko"; r_favorite_number = 9; r_location = None }
end

module Type_record_complex_optional = struct
  type name = { r_first : string; r_last : string }
  [@@deriving eq, deserializer]

  type record = {
    r_name : name option;
    r_favorite_number : int;
    r_location : string option;
  }
  [@@deriving eq, deserializer]

  let parse_json = parse_json equal_record deserialize_record

  let%test "parse packed json representation" =
    parse_json {| [ [ "Benjamin", "Sisko" ], 9, "Bajor", ] |}
      {
        r_name = Some { r_first = "Benjamin"; r_last = "Sisko" };
        r_favorite_number = 9;
        r_location = Some "Bajor";
      }

  let%test "parse object json representation" =
    parse_json
      {|
  { "r_name": {
      "r_first": "Benjamin",
      "r_last": "Sisko"
    },
    "r_favorite_number": 9,
    "r_location": "Bajor"
  }
  |}
      {
        r_name = Some { r_first = "Benjamin"; r_last = "Sisko" };
        r_favorite_number = 9;
        r_location = Some "Bajor";
      }

  let%test "parse object json representation missing values" =
    parse_json {|
  { "r_favorite_number": 9
  }
  |}
      { r_name = None; r_favorite_number = 9; r_location = None }

  let%test "parse object json representation explicit nulls" =
    parse_json
      {|
  { "r_name": null,
    "r_favorite_number": 9,
    "r_location": null
  }
  |}
      { r_name = None; r_favorite_number = 9; r_location = None }
end

module Type_variant = struct
  type name = { first : string; last : string }
  [@@deriving eq, serializer, deserializer]

  type variant =
    | Hello
    | Tuple1 of string
    | Tuple2 of string * Type_alias.alias
    | Record3 of { name : name; favorite_number : int; location : string }
  [@@deriving eq, serializer, deserializer]

  let parse_json = parse_json equal_variant deserialize_variant
  let%test _ = parse_json {|"Hello"|} Hello

  let%test _ =
    parse_json {|{ "Tuple1": ["this is a tuple"] }|} (Tuple1 "this is a tuple")

  let%test _ =
    parse_json {|{ "Tuple2": ["this is a tuple", 1] }|}
      (Tuple2 ("this is a tuple", 1))

  let%test _ =
    parse_json {|{ "Record3": [ ["Benjamin", "Sisko"], 9, "Bajor"] }|}
      (Record3
         {
           name = { first = "Benjamin"; last = "Sisko" };
           favorite_number = 9;
           location = "Bajor";
         })

  let%test _ =
    parse_json
      {|{
    "Record3": {
      "name": {
        "first": "Benjamin",
        "last": "Sisko",
      },
      "favorite_number": 9,
      "location": "Bajor"
    }
  }|}
      (Record3
         {
           name = { first = "Benjamin"; last = "Sisko" };
           favorite_number = 9;
           location = "Bajor";
         })



end

module Example = struct

  type person = { name : string; age : int } [@@deriving eq, serializer, deserializer]

  let res () = let v = Serde_json.of_string deserialize_person {|{ "name": "Test", "age": "a" }|} in
    match v with
    | Error `Invalid_value_at_pos _ -> true
    | Ok _ -> false
    | Error _ -> false

  let%test _ = res ()



end

(*
module Type_generics_applied = struct
  type 'value pair = 'value * 'value [@@deriving eq]
  type v2f = float pair [@@deriving eq, serializer, deserializer]

  let parse_sexpr = parse_sexpr equal_v2f deserialize_v2f

  let%test _ = parse_sexpr "(1.2 2.3)" (1.2, 2.3)
end
*)
