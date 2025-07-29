(* Core types for the spendo expense tracker *)

type expense = {
  amount: int; (* Amount in cents *)
  message: string option;
  timestamp: string;
}

type daily_expenses = {
  date: string;
  expenses: expense list;
} 