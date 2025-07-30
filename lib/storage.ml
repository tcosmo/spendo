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

let get_settings_file () =
  get_data_dir () ^ "/spendo_settings.json"

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

let get_date_offset days_offset =
  let open Unix in
  let now = time () in
  let offset_seconds = days_offset * 24 * 60 * 60 in
  let target_time = now +. float_of_int offset_seconds in
  let tm = localtime target_time in
  Printf.sprintf "%04d-%02d-%02d" 
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday

let get_today_date () = get_date_offset 0

let add_expense amount message date_offset =
  let target_date = get_date_offset date_offset in
  let data = load () in
  let expense = Expense.create_expense amount message in
  
  let updated_data = 
    let rec update_or_add = function
      | [] -> [{ Types.date = target_date; expenses = [expense] }]
      | daily :: rest ->
          if daily.Types.date = target_date then
            { daily with Types.expenses = expense :: daily.Types.expenses } :: rest
          else
            daily :: update_or_add rest
    in
    update_or_add data
  in
  
  save updated_data

let get_expenses_for_date date_offset =
  let target_date = get_date_offset date_offset in
  let data = load () in
  List.find_opt (fun daily -> daily.Types.date = target_date) data

let get_expenses_for_last_n_days n =
  let rec get_dates acc days_back =
    if days_back >= n then acc
    else
      let date = get_date_offset (-days_back) in
      get_dates (date :: acc) (days_back + 1)
  in
  let target_dates = get_dates [] 0 in
  let data = load () in
  let rec find_expenses_for_dates dates data =
    match dates with
    | [] -> []
    | date :: rest ->
        let daily_expenses = List.find_opt (fun daily -> daily.Types.date = date) data in
        match daily_expenses with
        | Some expenses -> expenses :: find_expenses_for_dates rest data
        | None -> 
            (* Create empty daily expenses for dates with no data *)
            { Types.date = date; expenses = [] } :: find_expenses_for_dates rest data
  in
  find_expenses_for_dates target_dates data

let get_today_expenses () = get_expenses_for_date 0 

(* Settings functions *)
type settings = {
  monthly_budget: int option;
  budget_start_day: int option;
}

let default_settings = {
  monthly_budget = None;
  budget_start_day = None;
}

let settings_to_json settings =
  let budget_json = match settings.monthly_budget with
    | Some budget -> `Int budget
    | None -> `Null
  in
  let start_day_json = match settings.budget_start_day with
    | Some day -> `Int day
    | None -> `Null
  in
  `Assoc [
    ("monthly_budget", budget_json);
    ("budget_start_day", start_day_json)
  ]

let json_to_settings json =
  let monthly_budget = match Util.member "monthly_budget" json with
    | `Int budget -> Some budget
    | _ -> None
  in
  let budget_start_day = match Util.member "budget_start_day" json with
    | `Int day -> Some day
    | _ -> None
  in
  { monthly_budget; budget_start_day }

let load_settings () =
  try
    let settings_file = get_settings_file () in
    let ic = open_in settings_file in
    let content = really_input_string ic (in_channel_length ic) in
    close_in ic;
    let json = from_string content in
    json_to_settings json
  with
  | _ -> default_settings

let save_settings settings =
  let settings_file = get_settings_file () in
  let json = settings_to_json settings in
  let oc = open_out settings_file in
  output_string oc (to_string json);
  close_out oc

let update_settings ?monthly_budget ?budget_start_day () =
  let current_settings = load_settings () in
  let new_settings = {
    monthly_budget = (match monthly_budget with Some _ -> monthly_budget | None -> current_settings.monthly_budget);
    budget_start_day = (match budget_start_day with Some _ -> budget_start_day | None -> current_settings.budget_start_day);
  } in
  save_settings new_settings;
  new_settings

(* Budget tracking functions *)
let get_budget_period_start_date () =
  let settings = load_settings () in
  match settings.budget_start_day with
  | Some start_day ->
      let open Unix in
      let now = time () in
      let tm = localtime now in
      let current_day = tm.tm_mday in
      let current_month = tm.tm_mon in
      let current_year = tm.tm_year + 1900 in
      
      (* Calculate the start of current budget period *)
      let budget_start_month = 
        if current_day >= start_day then current_month 
        else if current_month = 0 then 11 else current_month - 1 in
      let budget_start_year = 
        if current_day >= start_day then current_year 
        else if current_month = 0 then current_year - 1 else current_year in
      
      let budget_start_tm = {
        tm with
        tm_mday = start_day;
        tm_mon = budget_start_month;
        tm_year = budget_start_year - 1900; (* Convert back to Unix year *)
      } in
      let budget_start_time = mktime budget_start_tm in
      fst budget_start_time
  | None -> 0.0

let get_budget_period_end_date () =
  let start_time = get_budget_period_start_date () in
  if start_time = 0.0 then 0.0 else
    let open Unix in
    let start_tm = localtime start_time in
    let end_month = if start_tm.tm_mon = 11 then 0 else start_tm.tm_mon + 1 in
    let end_year = if start_tm.tm_mon = 11 then start_tm.tm_year + 1 else start_tm.tm_year in
    let end_tm = {
      start_tm with
      tm_mon = end_month;
      tm_year = end_year;
    } in
    let end_time = mktime end_tm in
    fst end_time

let get_expenses_in_budget_period () =
  let start_date = get_budget_period_start_date () in
  let end_date = get_budget_period_end_date () in
  
  if start_date = 0.0 || end_date = 0.0 then 0 else
    let data = load () in
    let total = ref 0 in
    
    List.iter (fun daily ->
      let open Unix in
      let date_parts = String.split_on_char '-' daily.Types.date in
      match date_parts with
      | [year_str; month_str; day_str] ->
          (try
            let year = int_of_string year_str in
            let month = int_of_string month_str - 1 in (* Unix months are 0-based *)
            let day = int_of_string day_str in
            let tm = { 
              tm_sec = 0; tm_min = 0; tm_hour = 0; tm_mday = day; 
              tm_mon = month; tm_year = year - 1900; tm_wday = 0; 
              tm_yday = 0; tm_isdst = false 
            } in
            let date_time = fst (mktime tm) in
            if date_time >= start_date && date_time < end_date then
              List.iter (fun expense -> total := !total + expense.Types.amount) daily.Types.expenses
          with _ -> ())
      | _ -> ()
    ) data;
    !total

let get_remaining_budget_per_day () =
  let settings = load_settings () in
  match settings.monthly_budget with
  | Some total_budget ->
      let expenses_in_period = get_expenses_in_budget_period () in
      let remaining_budget = total_budget - expenses_in_period in
      
      (* Calculate remaining days in budget period *)
      let open Unix in
      let now = time () in
      let end_date = get_budget_period_end_date () in
      let remaining_seconds = end_date -. now in
      let remaining_days = int_of_float (remaining_seconds /. (24.0 *. 60.0 *. 60.0)) in
      
      if remaining_days <= 0 then
        (remaining_budget, 0)
      else
        (remaining_budget, remaining_days)
  | None -> (0, 0)

(* Calculate remaining budget per day for a specific date *)
let get_remaining_budget_per_day_for_date target_date =
  let settings = load_settings () in
  match settings.monthly_budget, settings.budget_start_day with
  | Some total_budget, Some start_day ->
      (* Calculate budget period start and end for the target date *)
      let open Unix in
      let target_tm = localtime target_date in
      let target_day = target_tm.tm_mday in
      let target_month = target_tm.tm_mon in
      let target_year = target_tm.tm_year + 1900 in
      
      (* Calculate the start of budget period for the target date *)
      let budget_start_month = 
        if target_day >= start_day then target_month 
        else if target_month = 0 then 11 else target_month - 1 in
      let budget_start_year = 
        if target_day >= start_day then target_year 
        else if target_month = 0 then target_year - 1 else target_year in
      
      let budget_start_tm = {
        target_tm with
        tm_mday = start_day;
        tm_mon = budget_start_month;
        tm_year = budget_start_year - 1900;
      } in
      let budget_start_time = fst (mktime budget_start_tm) in
      
      (* Calculate budget period end using the same logic as get_budget_period_end_date *)
      let end_month = if budget_start_month = 11 then 0 else budget_start_month + 1 in
      let end_year = if budget_start_month = 11 then budget_start_year + 1 else budget_start_year in
      let end_tm = {
        target_tm with
        tm_mday = start_day;
        tm_mon = end_month;
        tm_year = end_year - 1900;
      } in
      let end_time = fst (mktime end_tm) in
      
      (* Calculate expenses up to the target date *)
      let data = load () in
      let total = ref 0 in
      
      List.iter (fun daily ->
        let date_parts = String.split_on_char '-' daily.Types.date in
        match date_parts with
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
              if date_time >= budget_start_time && date_time <= target_date then
                List.iter (fun expense -> total := !total + expense.Types.amount) daily.Types.expenses
            with _ -> ())
        | _ -> ()
      ) data;
      
      let remaining_budget = total_budget - !total in
      let remaining_seconds = end_time -. target_date in
      let remaining_days = int_of_float (remaining_seconds /. (24.0 *. 60.0 *. 60.0)) in
      
      if remaining_days <= 0 then
        (remaining_budget, 0)
      else
        (remaining_budget, remaining_days)
  | _, _ -> (0, 0) 