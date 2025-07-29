open Cmdliner

(* CLI functions *)
let add_expense amount message =
  try
    let amount_float = float_of_string amount in
    let amount_cents = int_of_float (amount_float *. 100.0) in
    Spendo_lib.Storage.add_expense amount_cents message;
    Printf.printf "Added expense: %.2f" amount_float;
    (match message with
     | Some msg -> Printf.printf " (%s)" msg
     | None -> ());
    print_endline ""
  with
  | Failure _ -> 
      print_endline "Error: Invalid amount"

let list_expenses () =
  match Spendo_lib.Storage.get_today_expenses () with
  | Some daily ->
      print_endline (Spendo_lib.Expense.format_daily_expenses daily)
  | None ->
      print_endline "No expenses for today"

(* Command line arguments *)
let amount_arg =
  let doc = "Amount to add as expense" in
  Arg.(value & pos 0 (some string) None & info [] ~docv:"AMOUNT" ~doc)

let message_arg =
  let doc = "Optional message describing the expense" in
  Arg.(value & opt (some string) None & info ["m"; "message"] ~docv:"MESSAGE" ~doc)

let list_flag =
  let doc = "List today's expenses" in
  Arg.(value & flag & info ["l"; "list"] ~doc)

(* Main command *)
let cmd =
  let doc = "A simple CLI utility for tracking daily expenses" in
  let man = [
    `S Manpage.s_description;
    `P "Spendo is a command-line tool for tracking daily expenses.";
    `S Manpage.s_examples;
    `P "spendo 25.4";
    `P "spendo 25.4 -m \"food\"";
    `P "spendo -l";
  ] in
  let term = Term.(const (fun amount message list ->
    match (amount, list) with
    | (None, _) -> list_expenses ()
    | (Some amt, false) -> add_expense amt message
    | (Some _, true) -> list_expenses ()
    (* | _ -> print_endline "Try 'spendo --help' for more information" *)
    ) 
    $ amount_arg $ message_arg $ list_flag) in
  Cmd.v (Cmd.info "spendo" ~version:"1.0.0" ~doc ~man) term

(* Main function *)
let () = Stdlib.exit @@ Cmd.eval cmd 