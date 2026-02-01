# Agent Guidelines for binancePump

This document provides essential information for agentic coding assistants working on this repository.

## Project Overview
Binance Pump/Dump Detector - Creates a websocket to listen for trades, aggregates information, and detects anomalies that may indicate pump or dump activity. Outputs most traded, price changed, and volume changed symbols at regular intervals.

## Setup & Commands

### Installation
```bash
pip3 install -r requirements.txt
# Additional dependencies (used but not in requirements.txt):
pip3 install dateparser pytz python-binance pyTelegramBotAPI tqdm
```

### Running the Application
```bash
python3 binancePump.py
```

### Code Formatting
```bash
black .
```

### Testing
```bash
pytest                          # Run all tests
pytest tests/test_specific.py   # Run specific test file
pytest tests/test_specific.py::test_function_name  # Run single test
pytest -v                       # Verbose output
```

### Linting/Type Checking
No linting tools are currently configured in this project. When adding new code, consider:
- Running `black` for formatting
- Using `mypy` or `ruff` for type checking and linting if needed

## Code Style Guidelines

### Imports
Order: Standard library → Third-party → Local modules
```python
import json
import datetime as dt
from typing import Dict, List

import pandas as pd
import numpy as np

from binance import ThreadedWebsocketManager
from binance.enums import *
from pricechange import *
```

### Type Hints
- Use explicit type hints for function parameters and returns
- Import from `typing` module: `Dict`, `List`, `Union`, etc.
- For Python 3.7+, use `from __future__ import annotations` to enable postponed evaluation

### Data Structures
- Prefer `@dataclass` for data containers
- Use `@property` decorators for computed attributes
- Include `__repr__` for debug-friendly output

```python
from dataclasses import dataclass
from typing import Dict

@dataclass
class PriceChange:
    symbol: str
    price: float
    volume: float
    
    @property
    def price_change_perc(self) -> float:
        return ((self.price - self.prev_price) / self.prev_price) * 100
```

### Naming Conventions
- **Variables/Functions**: `snake_case`
- **Classes**: `PascalCase`
- **Constants**: `UPPER_SNAKE_CASE` (module-level configuration)
- **Private members**: `_leading_underscore`

```python
show_only_pair = "USDT"      # Config variable
min_perc = 0.05              # Config variable

def process_message(tickers):  # Function
    pass

class PriceGroup:             # Class
    pass
```

### Error Handling
- Handle division by zero with explicit checks
- Use try-except for API calls and file operations
- Provide meaningful error messages

```python
if self.prev_price == 0:
    return 0.0
return (self.price_change / self.prev_price) * 100
```

### Docstrings
- Use simple format for functions
- Include parameter and return type descriptions
- Keep docstrings concise

```python
def binanceDataFrame(klines):
    """Convert klines to pandas DataFrame with proper column names and datetime conversion."""
    df = pd.DataFrame(klines.reshape(-1,12), dtype=float, columns=('Open Time', 'Open', ...))
    return df
```

### String Formatting
- Use f-strings for all string formatting
- Format floats with precision: `f"{value:.2f}"`
- Use `!r` for repr of objects in debug strings

```python
print(f"Symbol:{self.symbol}\tTime:{self.last_event_time}\tPrice:{self.last_price:.2f}")
```

### Configuration
- Store API keys in `api_config.json` (already in .gitignore)
- Module-level config variables at top of files

```json
{
    "api_key": "",
    "api_secret": ""
}
```

### Signal Handling
- Handle SIGINT and SIGTERM for graceful shutdown
- Use `threading.Event` for stop coordination

```python
import signal
import threading

stop_event = threading.Event()

def handle_exit(signum, frame):
    print("\nShutting down...")
    stop_event.set()
    twm.stop()

signal.signal(signal.SIGINT, handle_exit)
signal.signal(signal.SIGTERM, handle_exit)
```

## File Organization
- `binancePump.py` - Main entry point, websocket handling, core logic
- `binanceHelper.py` - Binance API helper functions, data conversion utilities
- `pricechange.py` - `PriceChange` dataclass for tracking individual price movements
- `pricegroup.py` - `PriceGroup` dataclass for aggregating tick data
- `api_config.json` - API credentials (not committed)
- `requirements.txt` - Python dependencies

## Key Patterns
- Use `filter()` and `operator.attrgetter()` for sorting/filtering lists of objects
- Thread-safe global state with module-level dictionaries and lists
- Periodic processing triggered by websocket messages
- Multiple sorting criteria for ranked outputs (ticks, price change, volume change)

## Testing Notes
Currently no test suite exists. When adding tests, use pytest and place test files in a `tests/` directory with names matching `test_*.py`.
