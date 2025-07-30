(* Expense creation and formatting functions *)

let iso8601_of_timestamp (timestamp : float) : string =
  let tm = Unix.gmtime timestamp in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ"
    (tm.Unix.tm_year + 1900)
    (tm.Unix.tm_mon + 1)
    tm.Unix.tm_mday
    tm.Unix.tm_hour
    tm.Unix.tm_min
    tm.Unix.tm_sec

let iso8601_of_timestamp_local (timestamp : float) : string =
  let open Unix in
  let tm = localtime timestamp in
  let offset_seconds =
    let local_sec = fst (mktime tm) in
    let gmt_sec = fst (mktime (gmtime timestamp)) in
    int_of_float (local_sec -. gmt_sec)
  in
  let sign = if offset_seconds >= 0 then '+' else '-' in
  let abs_offset = abs offset_seconds in
  let hours = abs_offset / 3600 in
  let minutes = (abs_offset mod 3600) / 60 in
  Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02d%c%02d:%02d"
    (tm.tm_year + 1900)
    (tm.tm_mon + 1)
    tm.tm_mday
    tm.tm_hour
    tm.tm_min
    tm.tm_sec
    sign
    hours
    minutes

let create_expense amount message savings =
  let timestamp = iso8601_of_timestamp_local (Unix.gettimeofday ()) in
  { Types.amount; message; timestamp; savings }

let total_expenses expenses =
  List.fold_left (fun acc exp -> acc + exp.Types.amount) 0 expenses

let format_expense expense =
  let amount_str = Printf.sprintf "%.2f" (float_of_int expense.Types.amount /. 100.0) in
  let message_str = match expense.Types.message with
    | Some msg -> " - " ^ msg
    | None -> ""
  in
  let savings_str = if expense.Types.savings then " [SAVINGS]" else "" in
  Printf.sprintf "%s%s%s" amount_str message_str savings_str

let format_daily_expenses daily =
  let total = total_expenses daily.Types.expenses in
  let expenses_str = List.map format_expense daily.Types.expenses in
  let expenses_list = String.concat "\n" expenses_str in
  
  (* Calculate total excluding savings *)
  let non_savings_expenses = List.filter (fun exp -> not exp.Types.savings) daily.Types.expenses in
  let total_excl_savings = total_expenses non_savings_expenses in
  
  let base_output = Printf.sprintf "Date: %s\nExpenses:\n%s\nTotal: %.2f" 
    daily.Types.date expenses_list (float_of_int total /. 100.0) in
  
  (* Add savings-excluded total if there are savings expenses *)
  let has_savings = List.exists (fun exp -> exp.Types.savings) daily.Types.expenses in
  if has_savings then
    base_output ^ Printf.sprintf "\nTotal (excl. savings): %.2f" (float_of_int total_excl_savings /. 100.0)
  else
    base_output 