# Wastage Tracking - New Batch Auto-Detection

## What Changed

Added automatic detection for new stock batches to handle wastage tracking properly when stock is completely restocked.

## The Problem

**Before:**
- Yesterday: 0 kg beef remaining, 5 kg in wastage bag
- Today: Buy 10 kg new beef
- Tonight: Enter 7 kg wastage bag (5 kg old + 2 kg new)
- System calculates: 7 - 5 = 2 kg wastage ❌ (mixes old and new batch)

**After:**
- System detects: Yesterday 0 kg + Today has new stock = NEW BATCH
- Tonight: 7 kg entered as BASELINE (no delta calculation)
- Shows: "New batch — baseline recorded"
- Tomorrow: Normal delta tracking resumes from tonight's baseline ✓

## How It Works

### Auto-Detection Logic

The system automatically detects a new batch when:
```
IF yesterday's remaining stock = 0 kg (completely wiped out)
AND today has stock additions (new purchase)
THEN tonight = baseline for new batch (no wastage calculation)
```

### What Happens in Each Scenario

#### Scenario 1: Complete Stock Turnover (Your Case)
```
Yesterday: 0 kg remaining ✓
Today: Buy 10 kg beef ✓
→ Auto-detected as NEW BATCH
→ Tonight's wastage bag = baseline
→ UI shows: "New batch detected — baseline recorded, tracking starts tomorrow"
→ No delta calculation tonight
→ Tomorrow onwards: normal tracking
```

#### Scenario 2: Partial Restock (Mixed Stock)
```
Yesterday: 3 kg remaining
Today: Buy 10 kg more
→ NOT a new batch (continuous stock)
→ Normal delta calculation: tonight's bag - yesterday's bag
→ Mixed wastage tracked (acceptable for small operations)
```

#### Scenario 3: No Restock
```
Yesterday: 5 kg remaining
Today: No purchases
→ Normal tracking continues
→ Delta calculated as usual
```

## UI Changes

### In Stock Entry Section:
**New Batch Detected:**
```
Wastage bag weight tonight: [___] kg
Helper text: "New batch detected — baseline recorded, tracking starts tomorrow"
```

**Normal Tracking:**
```
Wastage bag weight tonight: [___] kg
Helper text: "Last night: 5.00 kg"
```

### In Review Section:
**New Batch Shows:**
```
🔄 New batch — baseline recorded
(Green info box)
```

**Day 1 Shows:**
```
ℹ️ Wastage tracking starts tomorrow
(Blue info box)
```

**Normal Tracking Shows:**
```
Actual wastage: 2.3 kg
Buffer: 0.2 kg
Accountable sold: 9.5 kg
```

## Technical Implementation

### Files Changed:
- `lib/screens/nightly_entry/nightly_entry_screen.dart`

### Key Changes:

1. **Detection Logic (Lines ~90-105):**
   - Fetches yesterday's remaining stock per product
   - Compares with today's stock additions
   - Builds `isNewBatch` map per product

2. **Wastage Calculation (Lines ~198-210):**
   - Checks `isNewBatch` flag before calculating delta
   - Returns `null` for new batches (no wastage calculated)

3. **UI Updates:**
   - Helper text shows new batch message
   - Review card shows green "New batch" indicator
   - Prevents confusing wastage numbers

## Benefits

✅ **Automatic** - No manual intervention needed
✅ **Accurate** - Separates old and new batch wastage
✅ **Clear** - UI shows exactly what's happening
✅ **Flexible** - Handles both complete turnover and partial restocks
✅ **Preserves History** - No need to edit past records

## Tonight's Entry (April 22)

When you do tonight's nightly entry:

1. **Opening Stock:** 0 kg (from yesterday's remaining) ✓
2. **Stock Added:** Your new beef purchase ✓
3. **System detects:** NEW BATCH automatically ✓
4. **Wastage bag field shows:** "New batch detected — baseline recorded"
5. **Enter:** Current bag weight (whatever is in there now)
6. **Result:** No wastage calculation tonight, starts fresh tomorrow

Tomorrow (April 23):
- Opens with today's remaining as opening
- Wastage delta: tomorrow's bag - tonight's baseline
- Clean tracking for new batch

## Testing

Run the app and do tonight's nightly entry:
```bash
flutter run
```

You should see the "New batch detected" message for beef (or any product that was 0 yesterday and has stock today).

---

Branch: `add_wastage_tracking`
Status: ✅ Implemented and ready to test
