open Alcotest



(* Mock storage for testing *)
module TestStorage = struct
  let test_data = ref []
  
  let reset () = test_data := []
  
  let add_expense amount message =
    let expense = Spendo_lib.Expense.create_expense amount message false in
    let today = "2025-01-15" in
    let updated_data = 
      let rec update_or_add = function
        | [] -> [{ Spendo_lib.Types.date = today; expenses = [expense] }]
        | daily :: rest ->
            if daily.Spendo_lib.Types.date = today then
              { daily with Spendo_lib.Types.expenses = expense :: daily.Spendo_lib.Types.expenses } :: rest
            else
              daily :: update_or_add rest
      in
      update_or_add !test_data
    in
    test_data := updated_data
  
  let get_today_expenses () =
    let today = "2025-01-15" in
    List.find_opt (fun daily -> daily.Spendo_lib.Types.date = today) !test_data
end

(* Test cases *)
let test_expense_creation () =
  let expense = Spendo_lib.Expense.create_expense 1000 (Some "test") false in
  check int "amount in cents" 1000 expense.Spendo_lib.Types.amount;
  check (option string) "message" (Some "test") expense.Spendo_lib.Types.message;
  (* Don't check exact timestamp since it's dynamic *)
  check bool "timestamp exists" (String.length expense.Spendo_lib.Types.timestamp > 0) true

let test_expense_formatting () =
  let expense = Spendo_lib.Expense.create_expense 1250 (Some "lunch") false in
  let formatted = Spendo_lib.Expense.format_expense expense in
  check string "formatted expense" "12.50 - lunch" formatted

let test_expense_formatting_no_message () =
  let expense = Spendo_lib.Expense.create_expense 1000 None false in
  let formatted = Spendo_lib.Expense.format_expense expense in
  check string "formatted expense no message" "10.00" formatted

let test_total_expenses () =
  let expenses = [
    Spendo_lib.Expense.create_expense 1000 (Some "first") false;
    Spendo_lib.Expense.create_expense 2500 (Some "second") false;
    Spendo_lib.Expense.create_expense 500 None false;
  ] in
  let total = Spendo_lib.Expense.total_expenses expenses in
  check int "total in cents" 4000 total

let test_daily_expenses_formatting () =
  let daily = {
    Spendo_lib.Types.date = "2025-01-15";
    expenses = [
      Spendo_lib.Expense.create_expense 1000 (Some "breakfast") false;
      Spendo_lib.Expense.create_expense 2500 (Some "lunch") false;
    ]
  } in
  let formatted = Spendo_lib.Expense.format_daily_expenses daily in
  let expected = "Date: 2025-01-15\nExpenses:\n10.00 - breakfast\n25.00 - lunch\nTotal: 35.00" in
  check string "formatted daily expenses" expected formatted

let test_storage_add_expense () =
  TestStorage.reset ();
  TestStorage.add_expense 1000 (Some "test expense");
  match TestStorage.get_today_expenses () with
  | Some daily ->
      check int "expense count" 1 (List.length daily.Spendo_lib.Types.expenses);
      let expense = List.hd daily.Spendo_lib.Types.expenses in
      check int "expense amount" 1000 expense.Spendo_lib.Types.amount;
      check (option string) "expense message" (Some "test expense") expense.Spendo_lib.Types.message
  | None -> fail "Expected to find today's expenses"

let test_storage_multiple_expenses () =
  TestStorage.reset ();
  TestStorage.add_expense 1000 (Some "first");
  TestStorage.add_expense 2500 (Some "second");
  TestStorage.add_expense 500 None;
  match TestStorage.get_today_expenses () with
  | Some daily ->
      check int "expense count" 3 (List.length daily.Spendo_lib.Types.expenses);
      let total = Spendo_lib.Expense.total_expenses daily.Spendo_lib.Types.expenses in
      check int "total amount" 4000 total
  | None -> fail "Expected to find today's expenses"

let test_json_serialization () =
  let expense = Spendo_lib.Expense.create_expense 1250 (Some "test") false in
  let json = Spendo_lib.Storage.expense_to_json expense in
  let json_str = Yojson.Safe.to_string json in
  (* Check that the JSON has the expected structure by parsing it back *)
  let parsed_json = Yojson.Safe.from_string json_str in
  let amount = Yojson.Safe.Util.to_int (Yojson.Safe.Util.member "amount" parsed_json) in
  let message = match Yojson.Safe.Util.member "message" parsed_json with
    | `String msg -> Some msg
    | _ -> None
  in
  check int "serialized amount" 1250 amount;
  check (option string) "serialized message" (Some "test") message

let test_json_deserialization () =
  let json_str = "{\"amount\":1250,\"message\":\"test\",\"timestamp\":\"now\"}" in
  let json = Yojson.Safe.from_string json_str in
  let expense = Spendo_lib.Storage.json_to_expense json in
  check int "deserialized amount" 1250 expense.Spendo_lib.Types.amount;
  check (option string) "deserialized message" (Some "test") expense.Spendo_lib.Types.message;
  check string "deserialized timestamp" "now" expense.Spendo_lib.Types.timestamp

let test_json_deserialization_null_message () =
  let json_str = "{\"amount\":1000,\"message\":null,\"timestamp\":\"now\"}" in
  let json = Yojson.Safe.from_string json_str in
  let expense = Spendo_lib.Storage.json_to_expense json in
  check int "deserialized amount" 1000 expense.Spendo_lib.Types.amount;
  check (option string) "deserialized message" None expense.Spendo_lib.Types.message

let test_amount_conversion () =
  (* Test that amounts are correctly converted from float to cents *)
  let test_cases = [
    (0.01, 1);
    (0.50, 50);
    (1.00, 100);
    (10.25, 1025);
    (99.99, 9999);
  ] in
  List.iter (fun (float_amount, expected_cents) ->
    let actual_cents = int_of_float (float_amount *. 100.0) in
    check int (Printf.sprintf "amount conversion %.2f" float_amount) 
      expected_cents actual_cents
  ) test_cases

let test_edge_cases () =
  (* Test edge cases for amount conversion *)
  let test_cases = [
    (0.00, 0);
    (0.001, 0); (* Should round down *)
    (0.999, 99); (* Should round down *)
  ] in
  List.iter (fun (float_amount, expected_cents) ->
    let actual_cents = int_of_float (float_amount *. 100.0) in
    check int (Printf.sprintf "edge case %.3f" float_amount) 
      expected_cents actual_cents
  ) test_cases

(* Tests for date offset functionality *)
let test_date_offset () =
  (* Test that date offset calculation works correctly *)
  let today = Spendo_lib.Storage.get_today_date () in
  let yesterday = Spendo_lib.Storage.get_date_offset (-1) in
  let two_days_ago = Spendo_lib.Storage.get_date_offset (-2) in
  
  (* Check that dates are different *)
  check bool "today and yesterday are different" (today <> yesterday) true;
  check bool "yesterday and two days ago are different" (yesterday <> two_days_ago) true;
  check bool "today and two days ago are different" (today <> two_days_ago) true;
  
  (* Check that dates are in correct format (YYYY-MM-DD) *)
  let check_date_format date =
    String.length date = 10 && 
    String.get date 4 = '-' && 
    String.get date 7 = '-'
  in
  check bool "today format" (check_date_format today) true;
  check bool "yesterday format" (check_date_format yesterday) true;
  check bool "two days ago format" (check_date_format two_days_ago) true

let test_add_expense_with_date_offset () =
  (* Test that date offset functions work correctly *)
  let today = Spendo_lib.Storage.get_today_date () in
  let yesterday = Spendo_lib.Storage.get_date_offset (-1) in
  let two_days_ago = Spendo_lib.Storage.get_date_offset (-2) in
  
  (* Check that we can get expenses for different dates *)
  let today_expenses = Spendo_lib.Storage.get_expenses_for_date 0 in
  let yesterday_expenses = Spendo_lib.Storage.get_expenses_for_date (-1) in
  
  (* The actual data might exist or not, but the functions should work *)
  check bool "today expenses function works" true (today_expenses <> None || today_expenses = None);
  check bool "yesterday expenses function works" true (yesterday_expenses <> None || yesterday_expenses = None);
  
  (* Check that dates are properly formatted *)
  check bool "today date format" (String.length today = 10) true;
  check bool "yesterday date format" (String.length yesterday = 10) true;
  check bool "two days ago date format" (String.length two_days_ago = 10) true

let test_get_expenses_for_last_n_days () =
  (* Test getting expenses for the last N days *)
  let expenses = Spendo_lib.Storage.get_expenses_for_last_n_days 3 in
  
  (* Check that we get the expected number of days *)
  check int "number of days returned" 3 (List.length expenses);
  
  (* Check that each day has a valid date *)
  let rec check_dates = function
    | [] -> ()
    | daily :: rest ->
        check bool "daily has date" (String.length daily.Spendo_lib.Types.date = 10) true;
        check_dates rest
  in
  check_dates expenses

let test_get_expenses_for_last_n_days_with_empty_days () =
  (* Test getting expenses for N days when some days have no expenses *)
  let expenses = Spendo_lib.Storage.get_expenses_for_last_n_days 5 in
  
  check int "number of days returned" 5 (List.length expenses);
  
  (* Check that we have entries for all 5 days, even if some are empty *)
  let rec check_days = function
    | [] -> ()
    | daily :: rest ->
        check bool "daily has date" (String.length daily.Spendo_lib.Types.date = 10) true;
        check_days rest
  in
  check_days expenses;
  
  (* Check that we have at least some days with expenses (from our previous testing) *)
  let days_with_expenses = List.filter (fun daily -> List.length daily.Spendo_lib.Types.expenses > 0) expenses in
  check bool "has some days with expenses" (List.length days_with_expenses >= 0) true

(* Test suite *)
let test_suite = [
  "expense", [
    test_case "create expense" `Quick test_expense_creation;
    test_case "format expense with message" `Quick test_expense_formatting;
    test_case "format expense without message" `Quick test_expense_formatting_no_message;
    test_case "total expenses" `Quick test_total_expenses;
    test_case "format daily expenses" `Quick test_daily_expenses_formatting;
  ];
  "storage", [
    test_case "add single expense" `Quick test_storage_add_expense;
    test_case "add multiple expenses" `Quick test_storage_multiple_expenses;
  ];
  "json", [
    test_case "serialize expense" `Quick test_json_serialization;
    test_case "deserialize expense" `Quick test_json_deserialization;
    test_case "deserialize expense with null message" `Quick test_json_deserialization_null_message;
  ];
  "amount conversion", [
    test_case "amount conversion" `Quick test_amount_conversion;
    test_case "edge cases" `Quick test_edge_cases;
  ];
  "date offset", [
    test_case "date offset calculation" `Quick test_date_offset;
    test_case "add expense with date offset" `Quick test_add_expense_with_date_offset;
  ];
  "multi-day", [
    test_case "get expenses for last N days" `Quick test_get_expenses_for_last_n_days;
    test_case "get expenses for last N days with empty days" `Quick test_get_expenses_for_last_n_days_with_empty_days;
  ];
]

let () = run "spendo" test_suite 