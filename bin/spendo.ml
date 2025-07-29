open Cmdliner

(* CLI functions *)
let add_expense amount message date_offset =
  try
    let amount_float = float_of_string amount in
    let amount_cents = int_of_float (amount_float *. 100.0) in
    Spendo_lib.Storage.add_expense amount_cents message date_offset;
    let target_date = Spendo_lib.Storage.get_date_offset date_offset in
    Printf.printf "Today's date: %s\nAdded expense: %.2f" target_date amount_float;
    (match message with
     | Some msg -> Printf.printf " (%s)" msg
     | None -> ());
    (match date_offset with
     | 0 -> ()
     | n when n < 0 -> Printf.printf " (%d days ago)" (-n)
     | n -> Printf.printf " (%d days from now)" n);
    print_endline ""
  with
  | Failure _ -> 
      print_endline "Error: Invalid amount"

let list_expenses days =
  if days = 1 then
    match Spendo_lib.Storage.get_today_expenses () with
    | Some daily ->
        print_endline (Spendo_lib.Expense.format_daily_expenses daily)
    | None ->
        print_endline "No expenses recorded for today"
  else
    let expenses = Spendo_lib.Storage.get_expenses_for_last_n_days days in
    match expenses with
    | [] ->
        print_endline "No expenses for the last days"
    | daily_list ->
        List.iter (fun daily ->
          if List.length daily.Spendo_lib.Types.expenses = 0 then
            Printf.printf "Date: %s\nNo expenses recorded for this day\n" daily.Spendo_lib.Types.date
          else
            print_endline (Spendo_lib.Expense.format_daily_expenses daily);
          print_endline ""
        ) daily_list

(* Command line arguments *)
let amount_arg =
  let doc = "Amount to add as expense" in
  Arg.(value & pos 0 (some string) None & info [] ~docv:"AMOUNT" ~doc)

let message_arg =
  let doc = "Optional message describing the expense" in
  Arg.(value & opt (some string) None & info ["m"; "message"] ~docv:"MESSAGE" ~doc)

let date_offset_arg =
  let doc = "Date offset in days (0=today, 1=yesterday, etc.)" in
  Arg.(value & opt int 0 & info ["d"; "date"] ~docv:"DAYS" ~doc)

let list_flag =
  let doc = "List today's expenses" in
  Arg.(value & flag & info ["l"; "list"] ~doc)

let days_arg =
  let doc = "Number of days to show (default: 1)" in
  Arg.(value & opt int 1 & info ["n"] ~docv:"DAYS" ~doc)

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
  let term = Term.(const (fun amount message date_offset list days ->
    match (amount, list) with
    | (None, _) -> list_expenses days
    | (Some amt, false) -> add_expense amt message (-1*date_offset)
    | (Some _, true) -> list_expenses days
    (* | (None, false) -> print_endline "Error: Amount is required"; print_endline "Try 'spendo --help' for more information" *)
    ) 
    $ amount_arg $ message_arg $ date_offset_arg $ list_flag $ days_arg) in
  Cmd.v (Cmd.info "spendo" ~version:"1.0.0" ~doc ~man) term

(* Main function *)
let () = Stdlib.exit @@ Cmd.eval cmd 