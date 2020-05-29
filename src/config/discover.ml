let split_ws str = String.(split_on_char ' ' str |> List.filter ((<>) ""))

let option_value_map ~default ~f x = 
  match x with 
  | Some x -> f x
  | None -> default

let () =
  let module C = Configurator.V1 in
  let open C.Pkg_config in
  C.main ~name:"lacaml" (fun c ->
    let cflags =
      match Caml.Sys.getenv_opt "LACAML_CFLAGS" with
      | Some alt_cflags -> split_ws alt_cflags
      | None -> []
    in
    let libs, libs_override =
      match Caml.Sys.getenv_opt "LACAML_LIBS" with
      | Some alt_libs -> split_ws alt_libs, true
      | None -> ["-lblas"; "-llapack"], false
    in
    let conf =
      (* [exp10] is a GNU compiler extension so we have to provide our own
         external implementation by default unless we know that our platform is
         using the GNU compiler. *)
      let default =
        { cflags = "-DEXTERNAL_EXP10" :: "-std=c99" :: cflags; libs } in
      option_value_map (C.ocaml_config_var c "system") ~default ~f:(function
        | "linux" | "linux_elf" -> { cflags = "-std=gnu99" :: cflags; libs }
        | "macosx" when not libs_override ->
            { default with libs = "-framework" :: "Accelerate" :: libs }
        | "mingw64" -> { cflags = "-DWIN32" :: default.cflags; libs }
        | _ -> default)
        
    in
    C.Flags.write_sexp "c_flags.sexp" conf.cflags;
    C.Flags.write_sexp "c_library_flags.sexp" conf.libs)
