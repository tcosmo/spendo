# Spendo - Daily Expense Tracker

A simple OCaml CLI utility for tracking daily expenses.

## Features

- Add expenses with optional messages
- List today's expenses with total
- Simple text-based storage

## Usage

```bash
# Add an expense
spendo 25.4

# Add an expense with a message
spendo 25.4 -m "food"

# Add an expense for a previous day
spendo 25.4 -m "yesterday's lunch" -d 1

# List today's expenses
spendo -l

# List expenses for the last 4 days
spendo -n 4
```

## Building

```bash
# Install dependencies
opam install dune

# Build the project
dune build

# Run the binary
_build/default/bin/spendo.exe

# Or install system-wide
./install.sh
```

## Data Storage

Expenses are stored in `spendo_data.json` in the current directory using a standard JSON format:

```json
[
  {
    "date": "2025-07-29",
    "expenses": [
      {
        "amount": 525,
        "message": "coffee",
        "timestamp": "now"
      },
      {
        "amount": 1250,
        "message": "lunch",
        "timestamp": "now"
      }
    ]
  }
]
```

## Current Implementation

The current implementation is organized into modules with clear responsibilities:

- **`lib/types.ml`**: Core data structures (`expense`, `daily_expenses`)
- **`lib/expense.ml`**: Expense creation, formatting, and calculation functions
- **`lib/storage.ml`**: JSON persistence and data management
- **`bin/spendo.ml`**: CLI interface using `cmdliner` for robust argument parsing

Features:
- **Robust command-line parsing** using the `cmdliner` library
- **Automatic help generation** with `--help` and `-h` flags
- **JSON-based storage** using the `yojson` library
- **Integer-based amounts** (stored in cents) to avoid floating-point precision errors
- **Daily expense tracking** with optional messages
- **Total calculation** for each day
- **Interoperable data format** that can be easily parsed by other tools

## Amount Storage

Amounts are stored as integers representing cents to avoid floating-point precision issues. For example:
- `$5.25` is stored as `525`
- `$0.01` is stored as `1`
- `$15.99` is stored as `1599`

This ensures exact precision for currency calculations.

## Examples

```bash
$ spendo 15.50 -m "coffee"
Added expense: 15.50 (coffee)

$ spendo 25.00 -m "lunch"
Added expense: 25.00 (lunch)

$ spendo 12.75 -m "yesterday's dinner" -d 1
Added expense: 12.75 (yesterday's dinner) (1 days ago)

$ spendo -l
Date: 2024-01-15
Expenses:
25.00 - lunch
15.50 - coffee
Total: 40.50

$ spendo -n 3
Date: 2024-01-13
Expenses:
12.75 - yesterday's dinner
Total: 12.75

Date: 2024-01-14
Expenses:
15.50 - coffee
Total: 15.50

Date: 2024-01-15
Expenses:
25.00 - lunch
Total: 25.00
``` 