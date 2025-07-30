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
  if days = 1 then (
    match Spendo_lib.Storage.get_today_expenses () with
    | Some daily ->
        print_endline (Spendo_lib.Expense.format_daily_expenses daily);
        (* Show budget information *)
        let (remaining_budget, remaining_days) = Spendo_lib.Storage.get_remaining_budget_per_day () in
        if remaining_days > 0 then
          let budget_per_day = float_of_int remaining_budget /. float_of_int remaining_days /. 100.0 in
          Printf.printf "Remaining Day's budget: %.2f (%d days left)\n" budget_per_day remaining_days
        else if remaining_budget <> 0 then
          let budget_float = float_of_int remaining_budget /. 100.0 in
          Printf.printf "Budget period ended. Remaining: %.2f\n" budget_float
    | None ->
        print_endline "No expenses recorded for today";
        (* Show budget information even when no expenses *)
        let (remaining_budget, remaining_days) = Spendo_lib.Storage.get_remaining_budget_per_day () in
        if remaining_days > 0 then
          let budget_per_day = float_of_int remaining_budget /. float_of_int remaining_days /. 100.0 in
          Printf.printf "Remaining Day's budget: %.2f (%d days left)\n" budget_per_day remaining_days
  )
  else
    try
      let expenses = Spendo_lib.Storage.get_expenses_for_last_n_days days in
      match expenses with
      | [] ->
          print_endline "No expenses for the last days";
          (* Show budget information even when no expenses *)
          let (remaining_budget, remaining_days) = Spendo_lib.Storage.get_remaining_budget_per_day () in
          if remaining_days > 0 then
            let budget_per_day = float_of_int remaining_budget /. float_of_int remaining_days /. 100.0 in
            Printf.printf "Remaining Day's budget: %.2f (%d days left)\n" budget_per_day remaining_days
        | daily_list ->
            List.iter (fun daily ->
              if List.length daily.Spendo_lib.Types.expenses = 0 then
                Printf.printf "Date: %s\nNo expenses recorded for this day\n" daily.Spendo_lib.Types.date
              else
                print_endline (Spendo_lib.Expense.format_daily_expenses daily);
              
              (* Show budget information for this specific day *)
              let open Unix in
              let date_parts = String.split_on_char '-' daily.Spendo_lib.Types.date in
              (match date_parts with
               | [year_str; month_str; day_str] ->
                   (try
                     let year = int_of_string year_str in
                     let month = int_of_string month_str - 1 in
                     let day = int_of_string day_str in
                     let tm = { 
                       tm_sec = 0; tm_min = 0; tm_hour = 0; tm_mday = day; 
                       tm_mon = month; tm_year = year - 1900; tm_wday = 0; 
                       tm_yday = 0; tm_isdst = false 
                     } in
                     let date_time = fst (mktime tm) in
                     let (remaining_budget, remaining_days) = Spendo_lib.Storage.get_remaining_budget_per_day_for_date date_time in
                     if remaining_days > 0 then
                       let budget_per_day = float_of_int remaining_budget /. float_of_int remaining_days /. 100.0 in
                       Printf.printf "Day's budget: %.2f (%d days left)\n" budget_per_day remaining_days
                     else if remaining_budget <> 0 then
                       let budget_float = float_of_int remaining_budget /. 100.0 in
                       Printf.printf "Budget period ended. Remaining: %.2f\n" budget_float
                   with _ -> ())
               | _ -> ());
              print_endline ""
            ) daily_list;
    with
    | e ->
        Printf.printf "DEBUG: Exception caught: %s\n" (Printexc.to_string e);
        print_endline "Error occurred while getting expenses"

let set_monthly_budget budget =
  try
    let budget_float = float_of_string budget in
    let budget_cents = int_of_float (budget_float *. 100.0) in
    let _ = Spendo_lib.Storage.update_settings ~monthly_budget:budget_cents () in
    Printf.printf "Monthly budget set to: %.2f\n" budget_float
  with
  | Failure _ ->
      print_endline "Error: Invalid budget amount"

let set_budget_start_day day =
  try
    let day_int = int_of_string day in
    if day_int < 1 || day_int > 31 then
      print_endline "Error: Day must be between 1 and 31"
    else
      let _ = Spendo_lib.Storage.update_settings ~budget_start_day:day_int () in
      Printf.printf "Budget start day set to: %d\n" day_int
  with
  | Failure _ ->
      print_endline "Error: Invalid day number"

let show_settings () =
  let settings = Spendo_lib.Storage.load_settings () in
  print_endline "Current settings:";
  (match settings.monthly_budget with
   | Some budget -> 
       let budget_float = float_of_int budget /. 100.0 in
       Printf.printf "  Monthly budget: %.2f\n" budget_float
   | None -> 
       print_endline "  Monthly budget: Not set");
  (match settings.budget_start_day with
   | Some day -> 
       Printf.printf "  Budget start day: %d\n" day
   | None -> 
       print_endline "  Budget start day: Not set")

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

let budget_arg =
  let doc = "Set monthly budget (e.g., 800.00)" in
  Arg.(value & opt (some string) None & info ["b"; "budget"] ~docv:"BUDGET" ~doc)

let budget_start_day_arg =
  let doc = "Set the day of the month to start the budget (1-31)" in
  Arg.(value & opt (some string) None & info ["s"; "start-day"] ~docv:"DAY" ~doc)

let settings_flag =
  let doc = "Show current settings" in
  Arg.(value & flag & info ["c"; "settings"] ~doc)

(* Main command *)
let cmd =
  let doc = "A simple CLI utility for tracking daily expenses with budget tracking" in
  let man = [
    `S Manpage.s_description;
    `P "Spendo is a command-line tool for tracking daily expenses with monthly budget tracking.";
    `S Manpage.s_examples;
    `P "spendo 25.4";
    `P "spendo 25.4 -m \"food\"";
    `P "spendo -l";
    `P "spendo -b 800.00";
    `P "spendo -s 25";
    `P "spendo -c";
  ] in
  let term = Term.(const (fun amount message date_offset list days budget budget_start_day settings ->
    if budget <> None then
      set_monthly_budget (Option.get budget)
    else if budget_start_day <> None then
      set_budget_start_day (Option.get budget_start_day)
    else if settings then
      show_settings ()
    else if list || (amount = None && days > 1) then
      list_expenses days
    else if amount <> None then
      add_expense (Option.get amount) message (-1*date_offset)
    else
      list_expenses days
    ) 
    $ amount_arg $ message_arg $ date_offset_arg $ list_flag $ days_arg $ budget_arg $ budget_start_day_arg $ settings_flag) in
  Cmd.v (Cmd.info "spendo" ~version:"1.0.0" ~doc ~man) term

(* Main function *)
let () = Stdlib.exit @@ Cmd.eval cmd 