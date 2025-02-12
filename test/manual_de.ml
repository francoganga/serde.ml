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

let parse_json eq fn s t =
  match Serde_json.of_string fn s |> Result.map_error (fun x -> `De x) with
  | Ok t' -> eq t t'
  | Error err -> print_err err

let parse_sexpr eq fn s t =
  match Serde_sexpr.of_string fn s |> Result.map_error (fun x -> `De x) with
  | Ok t' -> eq t t'
  | Error err -> print_err err

module Type_alias = struct
  type alias = int [@@deriving eq]

  module Serde_deserialize_alias = struct
    let name = "alias"

    let deserialize_alias :
        type de_state.
        de_state Serde.De.Deserializer.t ->
        (alias, 'error Serde.De.de_error) result =
     fun de -> Serde.De.deserialize_int de (module Serde.De.Impls.Int_visitor)
  end

  include Serde_deserialize_alias

  let parse_sexpr = parse_sexpr Int.equal deserialize_alias
  let%test _ = parse_sexpr "1" 1
end

module Type_record = struct
  type record = {
    r_name : string;
    r_favorite_number : int;
    r_location : string;
  }
  [@@deriving eq]

  module Serde_deserialize_record = struct
    let name = "record"
    let fields = [ "r_name"; "r_favorite_number"; "r_location" ]

    type fields = Field_r_name | Field_r_favorite_number | Field_r_location

    module Field_visitor_for_record = Serde.De.Visitor.Make (struct
      include Serde.De.Visitor.Unimplemented

      type value = fields
      type tag = unit

      let visit_int idx =
        match idx with
        | 0 -> Ok Field_r_name
        | 1 -> Ok Field_r_favorite_number
        | 2 -> Ok Field_r_location
        | _ -> Serde.De.Error.invalid_field_index ~idx

      let visit_string str =
        match str with
        | "r_name" -> Ok Field_r_name
        | "r_favorite_number" -> Ok Field_r_favorite_number
        | "r_location" -> Ok Field_r_location
        | _ -> Serde.De.Error.unknown_field str

      let _ = visit_string
    end)

    module Visitor_for_record :
      Serde.De.Visitor.Intf with type value = record and type tag = fields =
    Serde.De.Visitor.Make (struct
      open Serde.De
      include Visitor.Unimplemented

      type value = record
      type tag = fields

      let visit_map :
          type de_state.
          value Visitor.t ->
          de_state Deserializer.t ->
          (value, 'error) Map_access.t ->
          (value, 'error Error.de_error) result =
       fun (module Self) (module De) map_access ->
        let f0 = ref None in
        let f1 = ref None in
        let f2 = ref None in

        let rec fill () =
          let* key =
            Map_access.next_key map_access ~deser_key:(fun () ->
                Serde.De.deserialize_string
                  (module De)
                  (module Field_visitor_for_record))
          in
          match key with
          | None -> Ok ()
          | Some f ->
              let* () =
                match f with
                | Field_r_name ->
                    let* value =
                      Map_access.next_value map_access ~deser_value:(fun () ->
                          Serde.De.deserialize_string
                            (module De)
                            (module Serde.De.Impls.String_visitor))
                    in
                    Ok (f0 := value)
                | Field_r_favorite_number ->
                    let* value =
                      Map_access.next_value map_access ~deser_value:(fun () ->
                          Serde.De.deserialize_int
                            (module De)
                            (module Serde.De.Impls.Int_visitor))
                    in
                    Ok (f1 := value)
                | Field_r_location ->
                    let* value =
                      Map_access.next_value map_access ~deser_value:(fun () ->
                          Serde.De.deserialize_string
                            (module De)
                            (module Serde.De.Impls.String_visitor))
                    in
                    Ok (f2 := value)
              in
              fill ()
        in
        let* () = fill () in

        let* f0 =
          match !f0 with
          | Some f0 -> Ok f0
          | None -> Error.missing_field "r_name"
        in

        let* f1 =
          match !f1 with
          | Some f1 -> Ok f1
          | None -> Error.missing_field "r_favorite_number"
        in

        let* f2 =
          match !f2 with
          | Some f2 -> Ok f2
          | None -> Error.missing_field "r_location"
        in

        Ok { r_name = f0; r_favorite_number = f1; r_location = f2 }

      let visit_seq :
          type de_state.
          value Visitor.t ->
          de_state Deserializer.t ->
          (value, 'error) Sequence_access.t ->
          (value, 'error Error.de_error) result =
       fun (module Self) (module De) seq_access ->
        let open Serde.De.Impls in
        let* f0 =
          let deser_element () =
            Serde.De.deserialize_string (module De) (module String_visitor)
          in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "record needs 3 argument")
          | Some f0 -> Ok f0
        in

        let* f1 =
          let deser_element () =
            Serde.De.deserialize_int (module De) (module Int_visitor)
          in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "record needs 3 argument")
          | Some f1 -> Ok f1
        in

        let* f2 =
          let deser_element () =
            Serde.De.deserialize_string (module De) (module String_visitor)
          in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "record needs 3 argument")
          | Some f2 -> Ok f2
        in

        Ok { r_name = f0; r_favorite_number = f1; r_location = f2 }
    end)

    let deserialize_record :
        type de_state.
        de_state Serde.De.Deserializer.t ->
        (record, 'error Serde.De.de_error) result =
     fun de ->
      Serde.De.deserialize_record de
        (module Visitor_for_record)
        (module Field_visitor_for_record)
        ~name ~fields
  end

  include Serde_deserialize_record

  let parse_sexpr = parse_sexpr equal_record deserialize_record
  let parse_json = parse_json equal_record deserialize_record

  let%test _ =
    parse_sexpr {|(:record "Benjamin Sisko" 9 "Bajor")|}
      { r_name = "Benjamin Sisko"; r_favorite_number = 9; r_location = "Bajor" }

  let%test "parse_sexpr packed json representation" =
    parse_json
      {|
  [
    "Benjamin Sisko",
    9,
    "Bajor",
  ]
  |}
      { r_name = "Benjamin Sisko"; r_favorite_number = 9; r_location = "Bajor" }

  let%test "parse_sexpr object json representation" =
    parse_json
      {|
  {
    "r_name": "Chief Miles O'Brien",
    "r_favorite_number": 7,
    "r_location": "Jeffries Tubes",
  }
  |}
      {
        r_name = "Chief Miles O'Brien";
        r_favorite_number = 7;
        r_location = "Jeffries Tubes";
      }
end

module Type_tuple = struct
  type tuple = int * Type_alias.alias [@@deriving eq]

  module Serde_deserialize_tuple = struct
    let name = "tuple"

    module Visitor_for_tuple : Serde.De.Visitor.Intf with type value = tuple =
    Serde.De.Visitor.Make (struct
      open Serde.De
      include Visitor.Unimplemented

      type value = tuple
      type tag = unit

      let visit_seq :
          type de_state.
          (module Visitor.Intf with type value = 'value) ->
          (module Deserializer with type state = de_state) ->
          (value, 'error) Sequence_access.t ->
          (value, 'error) result =
       fun _self (module De) seq_access ->
        let* f0 =
          let deser_element () =
            Serde.De.deserialize_int
              (module De)
              (module Serde.De.Impls.Int_visitor)
          in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "tuple needs 2 argument")
          | Some f0 -> Ok f0
        in

        let* f1 =
          let deser_element () = Type_alias.deserialize_alias (module De) in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "tuple needs 2 argument")
          | Some f1 -> Ok f1
        in

        Ok (f0, f1)
    end)

    let deserialize_tuple :
        type de_state.
        (module Serde.De.Deserializer with type state = de_state) ->
        (tuple, 'error Serde.De.de_error) result =
     fun (module De) ->
      Serde.De.deserialize_seq (module De) (module Visitor_for_tuple)
  end

  include Serde_deserialize_tuple

  let parse_sexpr = parse_sexpr equal_tuple deserialize_tuple
  let%test _ = parse_sexpr "(21 12)" (21, 12)
end

module Type_variant = struct
  type t =
    | Hello
    | Tuple1 of string
    | Tuple2 of string * bool
    | Record3 of { name : string; favorite_number : int; location : string }
  [@@deriving serializer]

  module Serde_deserialize_t = struct
    let name = "t"
    let variants = [ "Hello"; "Tuple1"; "Salute" ]

    type variants = Field_Hello | Field_Tuple1 | Field_Tuple2 | Field_Record3

    module Tag_visitor_for_t = Serde.De.Visitor.Make (struct
      include Serde.De.Visitor.Unimplemented

      type value = variants
      type tag = unit

      let visit_int idx =
        match idx with
        | 0 -> Ok Field_Hello
        | 1 -> Ok Field_Tuple1
        | 2 -> Ok Field_Tuple2
        | _ -> Serde.De.Error.invalid_variant_index ~idx

      let visit_string str =
        match str with
        | "Hello" -> Ok Field_Hello
        | "Tuple1" -> Ok Field_Tuple1
        | "Tuple2" -> Ok Field_Tuple2
        | "Record3" -> Ok Field_Record3
        | _ -> Serde.De.Error.unknown_variant str

      let _ = visit_string
    end)

    module Variant_visitor_for_Tuple1 :
      Serde.De.Visitor.Intf with type value = t = Serde.De.Visitor.Make (struct
      open Serde.De
      include Visitor.Unimplemented

      type value = t
      type tag = unit

      let visit_seq :
          type de_state.
          (module Visitor.Intf with type value = value) ->
          (module Deserializer with type state = de_state) ->
          (value, 'error) Sequence_access.t ->
          (value, 'error Error.de_error) result =
       fun (module Self) (module De) seq_access ->
        let open Serde.De.Impls in
        let* f0 =
          let deser_element () =
            Serde.De.deserialize_string (module De) (module String_visitor)
          in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "t.Tuple2 needs 2 argument")
          | Some f0 -> Ok f0
        in
        Ok (Tuple1 f0)
    end)

    module Variant_visitor_for_Tuple2 :
      Serde.De.Visitor.Intf with type value = t = Serde.De.Visitor.Make (struct
      open Serde.De
      include Visitor.Unimplemented

      type value = t
      type tag = unit

      let visit_seq :
          type de_state.
          (module Visitor.Intf with type value = value) ->
          (module Deserializer with type state = de_state) ->
          (value, 'error) Sequence_access.t ->
          (value, 'error Error.de_error) result =
       fun (module Self) (module De) seq_access ->
        let open Serde.De.Impls in
        let* f0 =
          let deser_element () =
            Serde.De.deserialize_string (module De) (module String_visitor)
          in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "t.Tuple2 needs 2 argument")
          | Some f0 -> Ok f0
        in

        let* f1 =
          let deser_element () =
            Serde.De.deserialize_bool (module De) (module Bool_visitor)
          in
          let* r = Sequence_access.next_element seq_access ~deser_element in
          match r with
          | None -> Error.message (Printf.sprintf "t.Tuple2 needs 2 argument")
          | Some f1 -> Ok f1
        in

        Ok (Tuple2 (f0, f1))
    end)

    let _ = name
    let _fields_Record3 = [ "name"; "favorite_number"; "location" ]
    let _ = _fields_Record3

    type nonrec _fields_Record3 =
      | Field_name
      | Field_favorite_number
      | Field_location

    module Field_visitor_for_Record3 = Serde.De.Visitor.Make (struct
      include Serde.De.Visitor.Unimplemented

      type value = _fields_Record3
      type tag = unit

      let visit_int idx =
        match idx with
        | 0 -> Ok Field_name
        | 1 -> Ok Field_favorite_number
        | 2 -> Ok Field_location
        | _ -> Serde.De.Error.invalid_variant_index ~idx

      let _ = visit_int

      let visit_string str =
        match str with
        | "name" -> Ok Field_name
        | "favorite_number" -> Ok Field_favorite_number
        | "location" -> Ok Field_location
        | _ -> Serde.De.Error.unknown_variant str

      let _ = visit_string
    end)

    module Variant_visitor_for_Record3 :
      Serde.De.Visitor.Intf with type value = t and type tag = _fields_Record3 =
    Serde.De.Visitor.Make (struct
      include Serde.De.Visitor.Unimplemented

      type value = t
      type tag = _fields_Record3

      let visit_seq :
          type de_state.
          (module Serde.De.Visitor.Intf with type value = value) ->
          (module Serde.De.Deserializer with type state = de_state) ->
          (value, 'error) Serde.De.Sequence_access.t ->
          (value, 'error Serde.De.Error.de_error) result =
       fun (module Self) (module De) seq_access ->
        let* f_0 =
          let deser_element () =
            Serde.De.deserialize_string
              (module De)
              (module Serde.De.Impls.String_visitor)
          in
          let* r =
            Serde.De.Sequence_access.next_element seq_access ~deser_element
          in
          match r with
          | None ->
              Serde.De.Error.message (Printf.sprintf "Record3 needs 3 argument")
          | Some f0 -> Ok f0
        in
        let* f_1 =
          let deser_element () =
            Serde.De.deserialize_int
              (module De)
              (module Serde.De.Impls.Int_visitor)
          in
          let* r =
            Serde.De.Sequence_access.next_element seq_access ~deser_element
          in
          match r with
          | None ->
              Serde.De.Error.message (Printf.sprintf "Record3 needs 3 argument")
          | Some f0 -> Ok f0
        in
        let* f_2 =
          let deser_element () =
            Serde.De.deserialize_string
              (module De)
              (module Serde.De.Impls.String_visitor)
          in
          let* r =
            Serde.De.Sequence_access.next_element seq_access ~deser_element
          in
          match r with
          | None ->
              Serde.De.Error.message (Printf.sprintf "Record3 needs 3 argument")
          | Some f0 -> Ok f0
        in
        Ok (Record3 { name = f_0; favorite_number = f_1; location = f_2 })

      let _ = visit_seq

      let visit_map :
          type de_state.
          value Serde.De.Visitor.t ->
          de_state Serde.De.Deserializer.t ->
          (value, 'error) Serde.De.Map_access.t ->
          (value, 'error Serde.De.Error.de_error) result =
       fun (module Self) (module De) map_access ->
        let f_0 = ref None in
        let f_1 = ref None in
        let f_2 = ref None in
        let deser_key () =
          Serde.De.deserialize_identifier
            (module De)
            (module Field_visitor_for_Record3)
        in
        let rec fill () =
          let* key = Serde.De.Map_access.next_key map_access ~deser_key in
          match key with
          | None -> Ok ()
          | Some f ->
              let* () =
                match f with
                | Field_name ->
                    let* value =
                      Serde.De.Map_access.next_value map_access
                        ~deser_value:(fun () ->
                          Serde.De.deserialize_string
                            (module De)
                            (module Serde.De.Impls.String_visitor))
                    in
                    Ok (f_0 := value)
                | Field_favorite_number ->
                    let* value =
                      Serde.De.Map_access.next_value map_access
                        ~deser_value:(fun () ->
                          Serde.De.deserialize_int
                            (module De)
                            (module Serde.De.Impls.Int_visitor))
                    in
                    Ok (f_1 := value)
                | Field_location ->
                    let* value =
                      Serde.De.Map_access.next_value map_access
                        ~deser_value:(fun () ->
                          Serde.De.deserialize_string
                            (module De)
                            (module Serde.De.Impls.String_visitor))
                    in
                    Ok (f_2 := value)
              in
              fill ()
        in
        let* () = fill () in
        let* f_0 =
          match !f_0 with
          | Some value -> Ok value
          | None -> Serde.De.Error.missing_field "name"
        in
        let* f_1 =
          match !f_1 with
          | Some value -> Ok value
          | None -> Serde.De.Error.missing_field "favorite_number"
        in
        let* f_2 =
          match !f_2 with
          | Some value -> Ok value
          | None -> Serde.De.Error.missing_field "location"
        in
        Ok (Record3 { name = f_0; favorite_number = f_1; location = f_2 })

      let _ = visit_map
    end)

    module Visitor_for_t :
      Serde.De.Visitor.Intf with type value = t and type tag = variants =
    Serde.De.Visitor.Make (struct
      open Serde.De
      include Visitor.Unimplemented

      type value = t
      type tag = variants

      let visit_variant va =
        let* tag = Variant_access.tag va in
        match tag with
        | Field_Hello ->
            let* () = Variant_access.unit_variant va in
            Ok Hello
        | Field_Tuple1 ->
            Variant_access.tuple_variant va (module Variant_visitor_for_Tuple1)
        | Field_Tuple2 ->
            Variant_access.tuple_variant va (module Variant_visitor_for_Tuple2)
        | Field_Record3 ->
            Variant_access.record_variant va ~fields:_fields_Record3
              (module Variant_visitor_for_Record3)
              (module Field_visitor_for_Record3)
    end)

    let deserialize_t :
        type de_state.
        (module Serde.De.Deserializer with type state = de_state) ->
        (t, 'error Serde.De.de_error) result =
     fun (module De) ->
      Serde.De.deserialize_variant ~name ~variants
        (module De)
        (module Visitor_for_t)
        (module Tag_visitor_for_t)
  end

  include Serde_deserialize_t

  let round_trip str =
    let* t =
      str
      |> Serde_sexpr.of_string deserialize_t
      |> Result.map_error (fun e -> `De e)
    in
    let* sexpr =
      t
      |> Serde_sexpr.to_string_pretty serialize_t
      |> Result.map_error (fun e -> `Ser_sexpr e)
    in
    let* json =
      t
      |> Serde_json.to_string_pretty serialize_t
      |> Result.map_error (fun e -> `Ser_json e)
    in
    Ok (sexpr, json)

  let print str =
    match round_trip str with
    | Ok (sexpr, json) ->
        Printf.printf "from: %s\nto (sexpr): %s\nto (json): %s\n\n" str sexpr
          json;
        String.equal sexpr str
    | Error (`De (`Unimplemented msg)) ->
        print_string ("unimplemented: " ^ msg);
        print_newline ();
        false
    | Error (`De (`Invalid_variant_index _)) ->
        print_string "invalid_va_idx";
        print_newline ();
        false
    | Error (`De (`Unknown_variant s)) ->
        print_string ("Unknown_variant: " ^ s);
        print_newline ();
        false
    | Error (`De (`Duplicate_field _)) ->
        print_string "Duplicate_field";
        print_newline ();
        false
    | Error (`De (`Missing_field _)) ->
        print_string "Missing_field";
        print_newline ();
        false
    | Error (`De (`Message msg)) ->
        print_string ("msg: " ^ msg);
        print_newline ();
        false
    | Error (`Ser _) ->
        print_string "error serializing";
        print_newline ();
        false
    | _ ->
        print_string "other";
        print_newline ();
        false

  let%test "Deserialize unit variant Hello" = print ":Hello"

  (* TODO(@ostera): reenable this after we figure out how to make Sexplib print out string correctly
     let%test "Deserialize tuple variant Tuple1(string)" =
       print "(:Tuple1 (\"asdf\"))"
  *)

  let%test "Deserialize tuple variant Tuple1(string) with spaces" =
    print {|(:Tuple1 ("a string with spaces"))|}

  let%test "Deserialize tuple variant Tuple2(string, bool) with spaces" =
    print {|(:Tuple2 ("a string with spaces" true))|}

  let%test "Deserialize tuple variant Tuple2(string, bool) with spaces" =
    print {|(:Tuple2 ("a string with spaces" false))|}

  let%test "Deserialize tuple variant Record3({ name : string; favorite_number \
            : int; location : string }) with spaces" =
    print {|(:Record3 ("Benjamin Sisko" 9 "Deep Space 9"))|}
end
