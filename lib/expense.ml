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

let create_expense amount message =
  let timestamp = iso8601_of_timestamp (Unix.gettimeofday ()) in
  { Types.amount; message; timestamp }

let total_expenses expenses =
  List.fold_left (fun acc exp -> acc + exp.Types.amount) 0 expenses

let format_expense expense =
  let amount_str = Printf.sprintf "%.2f" (float_of_int expense.Types.amount /. 100.0) in
  let message_str = match expense.Types.message with
    | Some msg -> " - " ^ msg
    | None -> ""
  in
  Printf.sprintf "%s%s" amount_str message_str

let format_daily_expenses daily =
  let total = total_expenses daily.Types.expenses in
  let expenses_str = List.map format_expense daily.Types.expenses in
  let expenses_list = String.concat "\n" expenses_str in
  Printf.sprintf "Date: %s\nExpenses:\n%s\nTotal: %.2f" 
    daily.Types.date expenses_list (float_of_int total /. 100.0) 