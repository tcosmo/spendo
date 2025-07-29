(* CLI functions *)

let add_expense_cli amount message =
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

let list_expenses_cli () =
  match Spendo_lib.Storage.get_today_expenses () with
  | Some daily ->
      print_endline (Spendo_lib.Expense.format_daily_expenses daily)
  | None ->
      print_endline "No expenses for today"

let print_usage () =
  print_endline "Usage:";
  print_endline "  spendo <amount> [-m <message>]  Add an expense";
  print_endline "  spendo -l                       List today's expenses";
  print_endline "";
  print_endline "Examples:";
  print_endline "  spendo 25.4";
  print_endline "  spendo 25.4 -m \"food\"";
  print_endline "  spendo -l"

(* Main function *)
let () =
  let args = Array.to_list Sys.argv in
  match args with
  | [_; "-l"] | [_; "--list"] ->
      list_expenses_cli ()
  | [_; amount] ->
      add_expense_cli amount None
  | [_; amount; "-m"; message] | [_; amount; "--message"; message] ->
      add_expense_cli amount (Some message)
  | [_] ->
      print_usage ()
  | _ ->
      print_endline "Error: Invalid arguments";
      print_usage () 