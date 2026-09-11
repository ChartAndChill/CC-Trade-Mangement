# CC Trading Management

A risk-management and execution panel for MetaTrader 5 with a TradingView-style
position tool, session boxes, Camarilla, POC/VWAP and the Hooman level ladder.

**Free forever.** The only thing asked in return is a subscribe on YouTube:
**[youtube.com/@ChartAndChill](https://www.youtube.com/@ChartAndChill)**

---

## Install

1. Copy `CC_TradingManagement.mq5` into `MQL5/Experts/` of your terminal data folder
   (MetaTrader 5 → File → Open Data Folder).
2. Open it in MetaEditor and press **F7** to compile.
3. Drag the EA onto a chart and enable **Algo Trading**.

A welcome card appears once per install; it disappears by itself after 30
seconds (`InpWelcomeSec = 0` turns it off).

## Panel

Light navy body with a darker navy header by default. Both are inputs
(`InpPanelBody`, `InpPanelHead`, `InpPanelAccent`); text colours are derived
automatically so they stay readable on whatever colours you pick.

| Block | Contents |
|---|---|
| Header | Drag it to move the panel · `-` collapses · a light is green only when an order can be sent (hover it for the reason when red) |
| Account | Balance, Equity, Floating P/L, Today P/L (closed + open) |
| Money management | Risk % / Stop loss / R:R steppers, real risk amount, computed lot, exposure bar |
| Position tool | LONG / SHORT / CLEAR, then Entry, Stop (−% and money), Target (+% and money), R:R and lot |
| Execution | Lot field (**empty = auto**), BUY / SELL, Limit field (**empty = auto**), BUY LMT / SELL LMT |
| Manage open risk | Close 25% / 50% / all, break even, delete pending |
| Tools | Camarilla, Sessions, POC, VWAP, Hooman, HM RESET |

Panel position and collapsed state persist between restarts.

## Position tool (TradingView style)

Press **LONG** or **SHORT**. Two coloured boxes appear at the current price with
the stepper's stop distance and R:R: a green profit box from entry to **Target**
and a red loss box from entry to **Stop**, with crisp edge lines and a dashed
entry line. Labels inside the boxes read like TradingView's:
`Target 1.23456 (+0.85%) 170 pts Amount +120.00 USD`,
`Stop 1.23400 (-0.42%) 85 pts Amount -60.00 USD`, and on the entry
`LONG 0.50 lot @ 1.23456 Risk/Reward 2.00` (plus live P/L once attached).

The boxes are the handles — every part can be moved or resized:

| Grab | Effect |
|---|---|
| a box (its body) | the whole tool moves |
| the outer corner of the green box | Target resizes |
| the outer corner of the red box | Stop resizes |
| the entry corner of either box | Entry moves (planner only) |
| any corner sideways | the box reaches further or shorter in time |

Lines and labels follow the mouse while you drag. A Stop or Target cannot be
dropped on the wrong side of the entry — the box snaps back. The box is kept
ahead of the current bar automatically.

- **BUY / SELL** use the tool's levels and its lot (or the typed lot). **BUY LMT
  / SELL LMT** use the tool's entry as the limit price.
- The moment a position with the panel's magic number exists, the tool
  **attaches to it**: entry becomes the real fill (and stays fixed), and moving
  Stop / Target — by corner or by dragging the whole box — **modifies the real
  position**. If the position is changed elsewhere the lines
  follow. When it closes the tool clears itself.
- The panel's Stop / Target rows show the same −% / +% and money, in red and
  green.

Colours and zone opacity: `InpTpColor`, `InpSlColor`, `InpEntryColor`,
`InpToolOpacity`, zone width in bars `InpToolBars`.

## Hooman levels

Yesterday's range as a ladder of 12.5% steps, extended from yesterday into today:

| Level | Style |
|---|---|
| 0% (low) and 100% (high) | yellow, solid |
| 50% | green, solid |
| 25% and 75% | yellow, dashed |
| 12.5%, 37.5%, 62.5%, 87.5% | white, dashed |

Each line is labelled with its percentage and price at the right edge. **Drag any
line and the whole ladder moves with it**; **HM RESET** puts it back. The ladder
recomputes on each new day. Colours: `InpHmHiLo`, `InpHmMid`, `InpHmQuarter`,
`InpHmEighth`.

## Other chart tools

- **Camarilla** — R4…R1 / PP / S1…S4 from the previous daily bar as a green →
  grey → red ladder, S3/R3 solid and thicker, recomputed daily.
- **Sessions** — Asia (blue), London (violet), New York (orange) translucent boxes
  labelled with their name, from each session's own high/low. Hours are GMT
  inputs converted to broker time. MT5 objects have no alpha channel, so the fill
  is the session colour mixed into the chart background and drawn behind the
  candles (`InpSessOpacity`, `InpSessBorder`).
- **POC + Value Area** — rolling volume profile, POC in deep pink with a softer
  70% value area.
- **VWAP** — session anchored, deep gold, plotted as a curve.

## When a trade button does nothing

The panel never fails silently. A rejected order writes the reason in red into
the status line at the bottom and into the **Experts** tab with the prefix
`[CC]`; every button press is logged so it is obvious whether the click arrived.
Before sending, the usual blockers are named: AutoTrading off, EA not allowed
to trade, investor login, broker-side algo block, symbol disabled / close only,
no price, not enough margin. An unsupported filling mode (10030) is retried
through FOK → IOC → RETURN and a requote with a fresh price.

## Position sizing

The money value of a stop comes from `OrderCalcProfit()` — the broker's own
contract specification — not from the tick value / tick size identity, which is
wrong on several metals and indices and understated the risk on XAUUSD by
about 26x in an earlier version. One trade can never risk more than 3% of
capital, and risk is measured against the smaller of balance and equity.

## Strategy Tester / MQL5 Market validation

A manual panel cannot trade in the Strategy Tester (`OnChartEvent` never fires
there), so the validator rejects it with "there are no trading operations". The
EA carries a small EMA-cross strategy that runs **only** when
`MQLInfoInteger(MQL_TESTER)` is true: one position at a time, reversed on the
opposite signal, ATR stop floored at the stops level / 5× spread / 10 points,
0.5% risk per trade, at most 5% of free margin per order, and it stops opening
below 50% of starting equity — so a test can never end in a stop out. It never
runs on a live or demo chart. The per-second timer is not started and the GUI
is built only in visual mode, so validation stays fast.

## Performance

- VWAP is drawn incrementally: closed bars never change, so only the live
  segment moves and only new segments are created (the previous version moved
  hundreds of objects on every bar, which made the chart lag).
- One throttled refresh path (300 ms) serves both ticks and the 500 ms timer;
  heavy chart tools refresh on a new bar or every 5 s; labels are only written
  when their text actually changes; one `ChartRedraw` per refresh.
- Buttons and inputs sit on a higher Z-order than the panel body, so a click is
  never swallowed by the background.

## Inputs

| Group | Inputs |
|---|---|
| Risk & Execution | `InpRiskPct`, `InpRR`, `InpSLPts`, `InpLimitDist`, `InpDeviation`, `InpMagic`, `InpTrailOn`, `InpTrailStart`, `InpTrailStep` |
| Tools on start | `InpCamOn`, `InpSessOn`, `InpPocOn`, `InpVwapOn`, `InpHoomanOn` |
| Tool settings | `InpPOCBars`, `InpPOCBins`, `InpPOCValueArea`, `InpVwapMaxBars`, `InpSessDays`, `InpConflPts` |
| Session hours (GMT) | `InpAsiaOpen` … `InpNyClose` |
| Panel colors | `InpPanelBody`, `InpPanelHead`, `InpPanelAccent`, `InpWelcomeSec` |
| Chart colors | `InpCamBuy`, `InpCamSell`, `InpPocColor`, `InpVwapColor`, `InpAsiaColor`, `InpLonColor`, `InpNyColor`, `InpSessOpacity`, `InpSessBorder` |
| Position tool | `InpTpColor`, `InpSlColor`, `InpEntryColor`, `InpToolOpacity`, `InpToolBars` |
| Hooman levels | `InpHmHiLo`, `InpHmMid`, `InpHmQuarter`, `InpHmEighth` |
| Strategy Tester only | `InpTesterAuto`, `InpAutoFast`, `InpAutoSlow`, `InpAutoAtrSL` |

---

## راهنمای کوتاه (فارسی)

- **پنل** آبی سرمه‌ای کم‌رنگ با هدر سرمه‌ای؛ رنگ‌ها از ورودی‌های `InpPanelBody` و
  `InpPanelHead` قابل تغییرند و رنگ نوشته‌ها خودکار طوری انتخاب می‌شود که خوانا بماند.
  نوار عنوان را بگیرید و بکشید تا پنل جابه‌جا شود.
- **ابزار پوزیشن (مدل تریدینگ‌ویو):** دکمه LONG یا SHORT را بزنید؛ باکس سبز سود
  (ورود تا تارگت) و باکس قرمز ضرر (ورود تا استاپ) با برچسب قیمت/درصد/پوینت/مبلغ
  روی چارت می‌آید. خودِ باکس‌ها دستگیره‌اند: بدنه‌ی باکس را بکشید کل ابزار جابه‌جا
  می‌شود؛ گوشه‌ی بیرونی باکس سبز = تغییر سایز تارگت، گوشه‌ی بیرونی باکس قرمز =
  تغییر سایز استاپ، گوشه‌ی سمت ورود = جابه‌جایی ورود، و کشیدن گوشه به چپ/راست =
  تغییر طول باکس. خط‌ها و برچسب‌ها همزمان با ماوس حرکت می‌کنند. BUY/SELL از همین
  سطوح استفاده می‌کند؛ وقتی پوزیشن باز شد، ابزار به پوزیشن واقعی می‌چسبد و جابه‌جایی
  استاپ/تارگت همان پوزیشن را تغییر می‌دهد.
- **ابزار هومن:** سقف و کف دیروز (زرد)، ۵۰٪ (سبز)، ۲۵/۷۵٪ (زرد خط‌چین) و
  ۱۲.۵/۳۷.۵/۶۲.۵/۸۷.۵٪ (سفید خط‌چین)، از دیروز تا امروز امتداد دارند؛ هر خط را
  بکشید کل نردبان یک‌جا جابه‌جا می‌شود، HM RESET برمی‌گرداند.
- **لَگ و دکمه‌ها:** رسم VWAP افزایشی شد (فقط قطعه‌ی آخر حرکت می‌کند)، رفرش پنل
  یکی و محدود شد، و دکمه‌ها بالای بدنه‌ی پنل قرار گرفتند تا کلیک هیچ‌وقت خورده نشود.
- این ابزار برای همیشه رایگان است؛ فقط کانال **@ChartAndChill** را ساب کنید.
