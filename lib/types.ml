(* Core types for the spendo expense tracker *)

type expense = {
  amount: int; (* Amount in cents *)
  message: string option;
  timestamp: string;
  savings: bool; (* Whether this expense is paid by savings *)
}

type daily_expenses = {
  date: string;
  expenses: expense list;
}

type settings = {
  monthly_budget: int option; (* Monthly budget in cents *)
  budget_start_day: int option; (* Day of month when budget period starts (1-31) *)
} 