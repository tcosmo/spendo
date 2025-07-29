(* JSON Storage functions *)

open Yojson.Safe

let get_data_dir () =
  let home = Unix.getenv "HOME" in
  let spendo_dir = home ^ "/.spendo" in
  (* Create directory if it doesn't exist *)
  (try Unix.mkdir spendo_dir 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> ());
  spendo_dir

let get_data_file () =
  get_data_dir () ^ "/spendo_data.json"

let expense_to_json expense =
  let message_json = match expense.Types.message with
    | Some msg -> `String msg
    | None -> `Null
  in
  `Assoc [
    ("amount", `Int expense.Types.amount);
    ("message", message_json);
    ("timestamp", `String expense.Types.timestamp)
  ]

let daily_expenses_to_json daily =
  let expense_jsons = List.map expense_to_json daily.Types.expenses in
  `Assoc [
    ("date", `String daily.Types.date);
    ("expenses", `List expense_jsons)
  ]

let json_to_expense json =
  let amount = Util.to_int (Util.member "amount" json) in
  let message = match Util.member "message" json with
    | `String msg -> Some msg
    | _ -> None
  in
  let timestamp = Util.to_string (Util.member "timestamp" json) in
  { Types.amount; message; timestamp }

let json_to_daily_expenses json =
  let date = Util.to_string (Util.member "date" json) in
  let expenses_json = Util.to_list (Util.member "expenses" json) in
  let expenses = List.map json_to_expense expenses_json in
  { Types.date; expenses }

let load () =
  try
    let data_file = get_data_file () in
    let ic = open_in data_file in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    let json = from_string content in
    let daily_list = Util.to_list json in
    List.map json_to_daily_expenses daily_list
  with
  | _ -> []

let save data =
  let data_file = get_data_file () in
  let json = `List (List.map daily_expenses_to_json data) in
  let oc = open_out data_file in
  output_string oc (to_string json);
  close_out oc

let get_today_date () =
  let open Unix in
  let tm = localtime (time ()) in
  Printf.sprintf "%04d-%02d-%02d" 
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday

let add_expense amount message =
  let today = get_today_date () in
  let data = load () in
  let expense = Expense.create_expense amount message in
  
  let updated_data = 
    let rec update_or_add = function
      | [] -> [{ Types.date = today; expenses = [expense] }]
      | daily :: rest ->
          if daily.Types.date = today then
            { daily with Types.expenses = expense :: daily.Types.expenses } :: rest
          else
            daily :: update_or_add rest
    in
    update_or_add data
  in
  
  save updated_data

let get_today_expenses () =
  let today = get_today_date () in
  let data = load () in
  List.find_opt (fun daily -> daily.Types.date = today) data 