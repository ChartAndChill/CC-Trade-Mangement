# CC Trading Management

A risk-management and execution panel for MetaTrader 5 with a TradingView-style
position tool, session boxes, POC/VWAP and the Hooman level ladder.

**Free forever.** The only thing asked in return is a subscribe on YouTube:
**[youtube.com/@ChartAndChill](https://www.youtube.com/@ChartAndChill)**

English | [فارسی](#فارسی)

---

## What it does

- One panel on the chart for account figures, position sizing by risk %,
  market and limit orders, and managing open risk.
- A TradingView-style long/short position tool driven by the mouse, which
  attaches to the real position and modifies it.
- Chart tools: session boxes (Asia, London, New York), a rolling volume profile
  with POC and value area, VWAP, and the Hooman level ladder.
- An optional trailing stop for positions with the panel's magic number.
- A small EMA-cross strategy that runs only in the Strategy Tester, so the EA
  passes MQL5 Market validation.

### Panel

Light navy body with a darker navy header by default. Both are inputs
(`InpPanelBody`, `InpPanelHead`, `InpPanelAccent`); text colours are derived
automatically so they stay readable on whatever colours you pick.

| Block | Contents |
|---|---|
| Header | Drag it to move the panel · `-` collapses · a light is green only when an order can be sent (hover it for the reason when red) |
| Account | Balance, Equity, Floating P/L, Today P/L (closed + open) |
| Money management | Risk % / Stop loss / R:R steppers, real risk amount, computed lot, exposure bar |
| TP / SL tool | Entry, Stop (−% and money), Target (+% and money), R:R and lot for the tool on the chart |
| Execution | Lot field (**empty = auto**), BUY / SELL, Limit field (**empty = auto**), BUY LMT / SELL LMT |
| Manage open risk | Close 25% / 50% / all, break even, delete pending |
| Tools | Sessions, POC, VWAP, Hooman, HM RESET, TP/SL — only Sessions is on by default |

Panel position and collapsed state persist between restarts.

### Position tool (TradingView style)

The **TP/SL** button in TOOLS cycles **off → LONG → SHORT → off** (it works like
the SESSIONS and HOOMAN toggles). Two coloured boxes appear at the current price,
sized from the visible chart range (about 12% of it for the stop, R:R for the
target) so the tool opens at a normal size on any symbol or zoom: a green profit
box from entry to **Target** and a red loss box from entry to **Stop**, with
nothing else drawn over the chart. The labels are TradingView's filled pills,
centred in the box: a green `Target: 1.23456 (0.85%) 170, Amount: 120.00` at the
top, a red `Stop: 1.23400 (0.42%) 85, Amount: 60.00` at the bottom, and a grey
two-line pill on the entry with `Open P&L: +12.30, Qty: 0.50` and
`Risk/Reward Ratio: 2.00`. Open P&L is the tool's result at the current price
(the real position's profit once attached).

The mouse is handled by the EA itself, not by MetaTrader's object selection:
nothing has to be selected first, there are no handles, and the whole tool is
recomputed from the cursor on every mouse move, so it sticks to the pointer.
The chart stops panning while the cursor is over the tool.

| Grab | Effect |
|---|---|
| anywhere inside the tool, or the grey **Open P&L** pill | the whole tool moves, in price and in time |
| the **Target** edge, or the green Target pill | Target resizes |
| the **Stop** edge, or the red Stop pill | Stop resizes |
| the thin **entry line** between the boxes | only the entry moves; Stop and Target stay |
| the left or right side | the box gets wider or narrower |
| **Target (or Stop) pulled across the entry** | the tool **flips** LONG ↔ SHORT the moment it crosses; colours swap, the other level mirrors |
| the **FLIP** button in the top-right corner | flips LONG ↔ SHORT in place, mirroring Stop and Target around the entry |

A level can never be closer to the entry than the broker's minimum stop
distance — it is clamped, not rejected. The box is kept ahead of the current
bar automatically. While a position is open the button reads **LIVE**, toggles
the overlay on and off, the entry stays at the fill, dragging the body shifts
Stop and Target together, and flipping is disabled.

- **BUY / SELL** use the tool's levels and its lot (or the typed lot). **BUY LMT
  / SELL LMT** use the tool's entry as the limit price.
- The moment a position with the panel's magic number exists, the tool
  **attaches to it**: entry becomes the real fill (and stays fixed), and moving
  the Stop / Target lines **modifies the real position**. If the position is
  changed elsewhere the lines follow. When it closes the tool clears itself.
- The panel's Stop / Target rows show the same −% / +% and money, in red and
  green.

Colours and zone opacity: `InpTpColor`, `InpSlColor`, `InpEntryColor`,
`InpToolOpacity`, zone width in bars `InpToolBars`.

### Hooman levels

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

### Other chart tools

- **Sessions** — Asia (blue), London (violet), New York (orange) as soft
  translucent boxes over each session's own high/low, with dotted high/low edges
  and a small name pill in the corner showing the session's range in points.
  Hours are GMT inputs converted to broker time using `TimeTradeServer()`, a
  live clock, so the offset is right on weekends too (the last-tick time is days
  old on a Saturday). The bar that *ends* at the close is the last one counted —
  the first bar after the close no longer leaks into the range. Drawn on H1 and
  below. MT5 objects have no alpha channel, so the fill is the session colour
  mixed into the chart background and drawn behind the candles
  (`InpSessOpacity`, `InpSessEdges`).
- **POC + Value Area** — rolling volume profile, POC in deep pink with a softer
  70% value area.
- **VWAP** — anchored to the start of the current trading day (the D1 bar),
  deep gold, plotted as a curve.
- **POC / VWAP confluence** — when POC and VWAP are both on and lie within
  `InpConflPts` points of each other, a violet dot marks their midpoint on the
  current bar.

### Trailing stop

Off by default (`InpTrailOn`). When on, a position on the chart's symbol with
the panel's magic number gets its stop moved once it is `InpTrailStart` points
in profit, to `InpTrailStep` points behind the current price. The stop only
moves in the trade's favour and respects the broker's minimum stop distance.

### When a trade button does nothing

The panel never fails silently. A rejected order writes the reason in red into
the status line at the bottom and into the **Experts** tab with the prefix
`[CC]`; every button press is logged so it is obvious whether the click arrived.
Before sending, the usual blockers are named: AutoTrading off, EA not allowed
to trade, investor login, broker-side algo block, symbol disabled / close only,
no price, not enough margin. An unsupported filling mode (10030) is retried
through FOK → IOC → RETURN and a requote with a fresh price.

### Position sizing

The money value of a stop comes from `OrderCalcProfit()` — the broker's own
contract specification — not from the tick value / tick size identity, which is
wrong on several metals and indices and understated the risk on XAUUSD by
about 26x in an earlier version. One trade can never risk more than 3% of
capital, and risk is measured against the smaller of balance and equity.

### Strategy Tester / MQL5 Market validation

A manual panel cannot trade in the Strategy Tester (`OnChartEvent` never fires
there), so the validator rejects it with "there are no trading operations". The
EA carries a small EMA-cross strategy that runs **only** when
`MQLInfoInteger(MQL_TESTER)` is true: one position at a time, reversed on the
opposite signal, ATR stop floored at the stops level / 5× spread / 10 points,
0.5% risk per trade, at most 5% of free margin per order, and it stops opening
below 50% of starting equity — so a test can never end in a stop out. It never
runs on a live or demo chart. The 500 ms timer is not started and the GUI is
built only in visual mode, so validation stays fast.

### Performance

- VWAP is drawn incrementally: closed bars never change, so only the live
  segment moves and only new segments are created (the previous version moved
  hundreds of objects on every bar, which made the chart lag).
- One throttled refresh path (300 ms) serves both ticks and the 500 ms timer;
  heavy chart tools refresh on a new bar or every 5 s; labels are only written
  when their text actually changes; one `ChartRedraw` per refresh.
- Buttons and inputs sit on a higher Z-order than the panel body, so a click is
  never swallowed by the background.

### Inputs

| Group | Inputs |
|---|---|
| Risk & Execution | `InpRiskPct`, `InpRR`, `InpSLPts`, `InpLimitDist`, `InpDeviation`, `InpMagic`, `InpTrailOn`, `InpTrailStart`, `InpTrailStep` |
| Tools on start | `InpSessOn`, `InpPocOn`, `InpVwapOn`, `InpHoomanOn`, `InpToolOn` |
| Tool settings | `InpPOCBars`, `InpPOCBins`, `InpPOCValueArea`, `InpVwapMaxBars`, `InpSessDays`, `InpConflPts` |
| Session hours (GMT) | `InpAsiaOpen` … `InpNyClose` |
| Panel colors | `InpPanelBody`, `InpPanelHead`, `InpPanelAccent`, `InpWelcomeSec` |
| Chart colors | `InpPocColor`, `InpVwapColor`, `InpAsiaColor`, `InpLonColor`, `InpNyColor`, `InpSessOpacity`, `InpSessEdges` |
| Position tool | `InpTpColor`, `InpSlColor`, `InpEntryColor`, `InpToolOpacity`, `InpToolBars` |
| Hooman levels | `InpHmHiLo`, `InpHmMid`, `InpHmQuarter`, `InpHmEighth` |
| Strategy Tester only | `InpTesterAuto`, `InpAutoFast`, `InpAutoSlow`, `InpAutoAtrSL` |

## Tech stack

- MQL5: one Expert Advisor source file.
- MetaTrader 5 standard library: `Trade\Trade.mqh` (`CTrade`).
- The interface is built from MetaTrader chart objects. No DLLs, no web
  requests, no external dependencies.

## Requirements

- MetaTrader 5 desktop terminal with MetaEditor (installed together with
  MetaTrader 5).
- A trading account that is allowed to trade: **Algo Trading** on in the
  terminal, algo trading not blocked by the broker, and not an investor
  (read-only) login.
- Session boxes are drawn on H1 and lower timeframes.

## Install, build and run

1. Copy `CC_TradingManagement.mq5` into `MQL5/Experts/` of your terminal data
   folder (MetaTrader 5 → File → Open Data Folder).
2. Open it in MetaEditor and press **F7** to compile. This writes
   `CC_TradingManagement.ex5` next to the source (compiled files are not kept
   in git).
3. Drag the EA onto a chart and enable **Algo Trading**.

A welcome card appears once per install; it disappears by itself after 30
seconds (`InpWelcomeSec = 0` turns it off).

To try it without a live chart, run the EA in the Strategy Tester; there only
the built-in EMA-cross strategy trades (see above).

This repository has no automated build or test: an MQL5 compiler is only
available inside MetaTrader 5.

## Project structure

| Path | Contents |
|---|---|
| `CC_TradingManagement.mq5` | The whole Expert Advisor: inputs, panel, position tool, chart tools, order handling, tester-only strategy |
| `README.md` | This file |
| `LICENSE` | License terms |
| `SECURITY.md` | How to report a security problem |
| `.github/` | Issue and pull request templates |

## Status

Public. In active development; current version **4.90** (`#property version`
in the source). Changes are listed in the commit history.

## License

Proprietary. Copyright (c) 2026 ChartAndChill. All rights reserved. See
[LICENSE](LICENSE).

---

<div dir="rtl">

## فارسی

**CC Trading Management** یک پنل مدیریت ریسک و اجرای معامله برای متاتریدر ۵ است،
همراه با ابزار پوزیشن به سبک تریدینگ‌ویو، باکس سشن‌ها، POC/VWAP و نردبان سطوح هومن.

**برای همیشه رایگان.** تنها چیزی که در عوض خواسته می‌شود، سابسکرایب کانال یوتیوب است:
**[youtube.com/@ChartAndChill](https://www.youtube.com/@ChartAndChill)**

### چه کاری انجام می‌دهد

- یک پنل روی چارت برای اطلاعات حساب، محاسبه‌ی حجم بر اساس درصد ریسک، سفارش‌های
  مارکت و لیمیت، و مدیریت ریسک پوزیشن‌های باز.
- ابزار پوزیشن خرید/فروش به سبک تریدینگ‌ویو که با خودِ ماوس کار می‌کند، به پوزیشن
  واقعی وصل می‌شود و همان را تغییر می‌دهد.
- ابزارهای چارت: باکس سشن‌ها (آسیا، لندن، نیویورک)، پروفایل حجم غلتان با POC و
  ناحیه‌ی ارزش، VWAP و نردبان سطوح هومن.
- حد ضرر متحرک (تریلینگ استاپ) اختیاری برای پوزیشن‌هایی که مجیک‌نامبر پنل را دارند.
- یک استراتژی کوچک تقاطع EMA که فقط در استراتژی تستر اجرا می‌شود تا اکسپرت از
  اعتبارسنجی مارکت MQL5 رد شود.

### پنل

بدنه‌ی پنل به‌طور پیش‌فرض آبی سرمه‌ای روشن و هدر آن سرمه‌ای تیره‌تر است. هر دو از
ورودی‌ها قابل تغییرند (`InpPanelBody`، `InpPanelHead`، `InpPanelAccent`) و رنگ
نوشته‌ها خودکار طوری انتخاب می‌شود که روی هر رنگی که انتخاب کنید خوانا بماند.

| بخش | محتوا |
|---|---|
| هدر | با کشیدن آن پنل جابه‌جا می‌شود · دکمه‌ی `-` پنل را جمع می‌کند · چراغ فقط وقتی سبز است که بتوان سفارش فرستاد (وقتی قرمز است، ماوس را رویش نگه دارید تا دلیلش را ببینید) |
| حساب | بالانس، اکوئیتی، سود/زیان شناور، سود/زیان امروز (بسته‌شده + باز) |
| مدیریت سرمایه | دکمه‌های کم و زیاد برای درصد ریسک / حد ضرر / نسبت R:R، مبلغ واقعی ریسک، لات محاسبه‌شده، نوار اکسپوژر |
| ابزار TP / SL | ورود، استاپ (−٪ و مبلغ)، تارگت (+٪ و مبلغ)، R:R و لات برای ابزار روی چارت |
| اجرا | فیلد لات (**خالی = خودکار**)، BUY / SELL، فیلد لیمیت (**خالی = خودکار**)، BUY LMT / SELL LMT |
| مدیریت ریسک باز | بستن ۲۵٪ / ۵۰٪ / همه، سربه‌سر کردن (بریک‌ایون)، حذف سفارش معلق |
| ابزارها | Sessions، POC، VWAP، Hooman، HM RESET، TP/SL — فقط Sessions به‌طور پیش‌فرض روشن است |

جای پنل و جمع یا باز بودن آن بعد از اجرای دوباره‌ی اکسپرت حفظ می‌شود.

### ابزار پوزیشن (به سبک تریدینگ‌ویو)

دکمه‌ی **TP/SL** در بخش TOOLS بین سه حالت می‌چرخد: خاموش، سپس **LONG**، سپس
**SHORT** و دوباره خاموش (مثل دکمه‌های SESSIONS و HOOMAN). دو باکس رنگی روی قیمت
فعلی ظاهر می‌شود که اندازه‌شان از محدوده‌ی قابل‌مشاهده‌ی چارت گرفته می‌شود (حدود ۱۲٪
آن برای استاپ و به نسبت R:R برای تارگت) تا ابزار روی هر نماد و هر بزرگ‌نمایی با
اندازه‌ی معقول باز شود: باکس سبز سود از ورود تا **تارگت** و باکس قرمز ضرر از ورود تا
**استاپ**، و هیچ چیز دیگری روی چارت کشیده نمی‌شود. برچسب‌ها همان برچسب‌های توپر
تریدینگ‌ویو هستند و وسط باکس قرار می‌گیرند: در بالا برچسب سبز
`Target: 1.23456 (0.85%) 170, Amount: 120.00`، در پایین برچسب قرمز
`Stop: 1.23400 (0.42%) 85, Amount: 60.00`، و روی خط ورود یک برچسب خاکستری دوخطی با
`Open P&L: +12.30, Qty: 0.50` و `Risk/Reward Ratio: 2.00`. مقدار Open P&L نتیجه‌ی
ابزار با قیمت فعلی است (و بعد از وصل شدن به پوزیشن، سود واقعی همان پوزیشن).

ماوس را خودِ اکسپرت مدیریت می‌کند، نه سیستم انتخاب آبجکت متاتریدر: لازم نیست اول
چیزی را انتخاب کنید، دستگیره‌ای وجود ندارد و کل ابزار با هر حرکت ماوس از روی مکان‌نما
دوباره محاسبه می‌شود، پس دقیقاً به نشانگر می‌چسبد. وقتی مکان‌نما روی ابزار است، چارت
جابه‌جا نمی‌شود.

| کجا را بگیرید | نتیجه |
|---|---|
| هر جای داخل ابزار، یا برچسب خاکستری **Open P&L** | کل ابزار در قیمت و زمان جابه‌جا می‌شود |
| لبه‌ی **تارگت** یا برچسب سبز تارگت | اندازه‌ی تارگت تغییر می‌کند |
| لبه‌ی **استاپ** یا برچسب قرمز استاپ | اندازه‌ی استاپ تغییر می‌کند |
| **خط باریک ورود** بین دو باکس | فقط ورود جابه‌جا می‌شود و استاپ و تارگت سر جایشان می‌مانند |
| سمت چپ یا راست باکس | باکس پهن‌تر یا باریک‌تر می‌شود |
| **کشیدن تارگت (یا استاپ) به آن طرف خط ورود** | ابزار همان لحظه‌ای که از ورود رد شود بین LONG و SHORT **برعکس** می‌شود؛ رنگ‌ها جابه‌جا می‌شوند و سطح دیگر قرینه می‌شود |
| دکمه‌ی **FLIP** در گوشه‌ی بالا سمت راست | ابزار را در همان‌جا بین LONG و SHORT برعکس می‌کند و استاپ و تارگت را نسبت به ورود قرینه می‌کند |

هیچ سطحی نمی‌تواند از حداقل فاصله‌ی استاپ بروکر به ورود نزدیک‌تر شود؛ به همان حد
محدود می‌شود، نه اینکه رد شود. باکس به‌طور خودکار جلوتر از کندل فعلی نگه داشته
می‌شود. وقتی پوزیشن باز است، روی دکمه **LIVE** نوشته می‌شود و فقط نمایش ابزار را
روشن و خاموش می‌کند؛ ورود روی قیمت پر شدن ثابت می‌ماند، کشیدن بدنه استاپ و تارگت را
با هم جابه‌جا می‌کند و برعکس کردن غیرفعال است.

- **BUY / SELL** از سطوح ابزار و لات آن (یا لاتی که تایپ کرده‌اید) استفاده می‌کنند.
  **BUY LMT / SELL LMT** ورود ابزار را به‌عنوان قیمت لیمیت به کار می‌برند.
- به محض اینکه پوزیشنی با مجیک‌نامبر پنل وجود داشته باشد، ابزار **به آن وصل
  می‌شود**: ورود همان قیمت واقعی پر شدن می‌شود (و ثابت می‌ماند) و جابه‌جا کردن
  خط‌های استاپ / تارگت **پوزیشن واقعی را تغییر می‌دهد**. اگر پوزیشن از جای دیگری
  تغییر کند، خط‌ها همراهش می‌آیند. وقتی پوزیشن بسته شود، ابزار خودش پاک می‌شود.
- ردیف‌های استاپ / تارگت در پنل همان −٪ / +٪ و مبلغ را با رنگ قرمز و سبز نشان
  می‌دهند.

رنگ‌ها و شفافیت ناحیه‌ها: `InpTpColor`، `InpSlColor`، `InpEntryColor`،
`InpToolOpacity`؛ پهنای ناحیه به تعداد کندل: `InpToolBars`.

### سطوح هومن

محدوده‌ی دیروز به شکل نردبانی با گام‌های ۱۲.۵٪ که از دیروز تا امروز امتداد دارد:

| سطح | سبک |
|---|---|
| ۰٪ (کف) و ۱۰۰٪ (سقف) | زرد، خط ممتد |
| ۵۰٪ | سبز، خط ممتد |
| ۲۵٪ و ۷۵٪ | زرد، خط‌چین |
| ۱۲.۵٪، ۳۷.۵٪، ۶۲.۵٪، ۸۷.۵٪ | سفید، خط‌چین |

کنار هر خط در لبه‌ی راست چارت درصد و قیمت آن نوشته می‌شود. **هر خطی را بکشید، کل
نردبان همراهش جابه‌جا می‌شود**؛ **HM RESET** آن را به جای اول برمی‌گرداند. نردبان با
شروع هر روز جدید دوباره محاسبه می‌شود. رنگ‌ها: `InpHmHiLo`، `InpHmMid`،
`InpHmQuarter`، `InpHmEighth`.

### ابزارهای دیگر چارت

- **سشن‌ها**: آسیا (آبی)، لندن (بنفش) و نیویورک (نارنجی) به شکل باکس‌های نیمه‌شفاف
  ملایم روی سقف و کفِ خودِ هر سشن، با لبه‌های نقطه‌چین در سقف و کف و یک برچسب کوچک
  با نام سشن در گوشه که دامنه‌ی سشن را به پوینت نشان می‌دهد. ساعت‌ها به وقت GMT وارد
  می‌شوند و با `TimeTradeServer()` که یک ساعت زنده است به ساعت بروکر تبدیل می‌شوند،
  پس اختلاف ساعت در آخر هفته هم درست است (روز شنبه زمان آخرین تیک چند روز قدیمی است).
  آخرین کندلی که شمرده می‌شود کندلی است که دقیقاً *روی* زمان بسته شدن سشن تمام
  می‌شود؛ اولین کندل بعد از بسته شدن دیگر وارد دامنه نمی‌شود. فقط روی H1 و
  تایم‌فریم‌های پایین‌تر رسم می‌شود. آبجکت‌های MT5 شفافیت (کانال آلفا) ندارند،
  به همین دلیل رنگ داخل باکس از ترکیب رنگ سشن با پس‌زمینه‌ی چارت ساخته می‌شود و
  پشت کندل‌ها کشیده می‌شود (`InpSessOpacity`، `InpSessEdges`).
- **POC + ناحیه‌ی ارزش**: پروفایل حجم غلتان؛ POC به رنگ صورتی تیره با ناحیه‌ی ارزش
  ۷۰٪ که رنگ ملایم‌تری دارد.
- **VWAP**: از شروع روز معاملاتی جاری (کندل D1) محاسبه می‌شود، به رنگ طلایی تیره و
  به شکل منحنی رسم می‌شود.
- **هم‌پوشانی POC و VWAP**: وقتی هر دو روشن باشند و فاصله‌شان حداکثر `InpConflPts`
  پوینت باشد، یک نقطه‌ی بنفش وسط آن دو روی کندل فعلی نشان داده می‌شود.

### حد ضرر متحرک (تریلینگ استاپ)

به‌طور پیش‌فرض خاموش است (`InpTrailOn`). وقتی روشن باشد، برای پوزیشن‌های نماد همین
چارت که مجیک‌نامبر پنل را دارند، بعد از اینکه پوزیشن `InpTrailStart` پوینت در سود
باشد، استاپ به فاصله‌ی `InpTrailStep` پوینت پشت قیمت فعلی منتقل می‌شود. استاپ فقط
در جهت سود معامله جابه‌جا می‌شود و حداقل فاصله‌ی استاپ بروکر را رعایت می‌کند.

### وقتی دکمه‌ی معامله کاری نمی‌کند

پنل هیچ‌وقت بی‌صدا شکست نمی‌خورد. وقتی سفارشی رد شود، دلیلش با رنگ قرمز در خط وضعیت
پایین پنل و در زبانه‌ی **Experts** با پیشوند `[CC]` نوشته می‌شود؛ هر کلیک روی دکمه‌ها
هم ثبت می‌شود تا معلوم باشد کلیک رسیده یا نه. پیش از ارسال، موانع رایج با نام گفته
می‌شوند: AutoTrading خاموش است، اکسپرت اجازه‌ی معامله ندارد، ورود با رمز investor،
مسدود بودن معاملات الگوریتمی از سمت بروکر، نماد غیرفعال یا فقط‌بستن، نبودن قیمت و
کافی نبودن مارجین. اگر حالت پر شدن سفارش پشتیبانی نشود (خطای 10030)، سفارش به ترتیب
با FOK، سپس IOC و سپس RETURN دوباره فرستاده می‌شود، و در صورت ری‌کوت با قیمت تازه
دوباره امتحان می‌شود.

### محاسبه‌ی حجم پوزیشن

ارزش پولی استاپ از `OrderCalcProfit()` گرفته می‌شود، یعنی از مشخصات قرارداد خودِ
بروکر، نه از رابطه‌ی tick value / tick size که روی چند فلز و شاخص اشتباه است و در
یکی از نسخه‌های قبلی ریسک XAUUSD را حدود ۲۶ برابر کمتر از مقدار واقعی نشان می‌داد.
ریسک یک معامله هرگز نمی‌تواند از ۳٪ سرمایه بیشتر شود و ریسک نسبت به کمترینِ بالانس و
اکوئیتی سنجیده می‌شود.

### استراتژی تستر و اعتبارسنجی مارکت MQL5

یک پنل دستی در استراتژی تستر نمی‌تواند معامله کند (`OnChartEvent` آنجا هیچ‌وقت اجرا
نمی‌شود)، برای همین اعتبارسنج مارکت آن را با پیام "there are no trading operations"
رد می‌کند. اکسپرت یک استراتژی کوچک تقاطع EMA دارد که **فقط** وقتی
`MQLInfoInteger(MQL_TESTER)` برقرار باشد اجرا می‌شود: هر بار فقط یک پوزیشن، با
سیگنال مخالف برعکس می‌شود، استاپ بر پایه‌ی ATR که از سطح استاپ بروکر، ۵ برابر اسپرد
و ۱۰ پوینت کمتر نمی‌شود، ریسک ۰.۵٪ در هر معامله، حداکثر ۵٪ مارجین آزاد برای هر
سفارش، و وقتی اکوئیتی زیر ۵۰٪ مقدار اولیه برود دیگر پوزیشن جدید باز نمی‌کند؛ پس
تست هیچ‌وقت به استاپ‌اوت ختم نمی‌شود. این استراتژی هرگز روی چارت واقعی یا دمو اجرا
نمی‌شود. تایمر ۵۰۰ میلی‌ثانیه‌ای شروع نمی‌شود و رابط گرافیکی فقط در حالت ویژوال ساخته
می‌شود تا اعتبارسنجی سریع بماند.

### کارایی

- VWAP به‌صورت افزایشی رسم می‌شود: کندل‌های بسته‌شده دیگر تغییر نمی‌کنند، پس فقط
  قطعه‌ی زنده حرکت می‌کند و فقط قطعه‌های جدید ساخته می‌شوند (نسخه‌ی قبلی با هر کندل
  صدها آبجکت را جابه‌جا می‌کرد و چارت را کند می‌کرد).
- یک مسیر رفرش محدودشده (۳۰۰ میلی‌ثانیه) هم به تیک‌ها و هم به تایمر ۵۰۰ میلی‌ثانیه‌ای
  پاسخ می‌دهد؛ ابزارهای سنگین چارت با هر کندل جدید یا هر ۵ ثانیه رفرش می‌شوند؛
  برچسب‌ها فقط وقتی متنشان واقعاً عوض شود نوشته می‌شوند؛ و در هر رفرش فقط یک
  `ChartRedraw` انجام می‌شود.
- دکمه‌ها و فیلدها در لایه‌ای بالاتر از بدنه‌ی پنل قرار دارند، پس کلیک هیچ‌وقت در
  پس‌زمینه گم نمی‌شود.

### ورودی‌ها

| گروه | ورودی‌ها |
|---|---|
| ریسک و اجرا | `InpRiskPct`، `InpRR`، `InpSLPts`، `InpLimitDist`، `InpDeviation`، `InpMagic`، `InpTrailOn`، `InpTrailStart`، `InpTrailStep` |
| ابزارهای روشن در شروع | `InpSessOn`، `InpPocOn`، `InpVwapOn`، `InpHoomanOn`، `InpToolOn` |
| تنظیمات ابزارها | `InpPOCBars`، `InpPOCBins`، `InpPOCValueArea`، `InpVwapMaxBars`، `InpSessDays`، `InpConflPts` |
| ساعت سشن‌ها (GMT) | `InpAsiaOpen` تا `InpNyClose` |
| رنگ‌های پنل | `InpPanelBody`، `InpPanelHead`، `InpPanelAccent`، `InpWelcomeSec` |
| رنگ‌های چارت | `InpPocColor`، `InpVwapColor`، `InpAsiaColor`، `InpLonColor`، `InpNyColor`، `InpSessOpacity`، `InpSessEdges` |
| ابزار پوزیشن | `InpTpColor`، `InpSlColor`، `InpEntryColor`، `InpToolOpacity`، `InpToolBars` |
| سطوح هومن | `InpHmHiLo`، `InpHmMid`، `InpHmQuarter`، `InpHmEighth` |
| فقط استراتژی تستر | `InpTesterAuto`، `InpAutoFast`، `InpAutoSlow`، `InpAutoAtrSL` |

### فناوری‌ها

- MQL5: یک فایل سورس اکسپرت.
- کتابخانه‌ی استاندارد متاتریدر ۵: `Trade\Trade.mqh` (کلاس `CTrade`).
- رابط کاربری با آبجکت‌های چارت متاتریدر ساخته شده است. بدون DLL، بدون درخواست
  اینترنتی و بدون وابستگی خارجی.

### پیش‌نیازها

- ترمینال دسکتاپ متاتریدر ۵ همراه با MetaEditor (که با خود متاتریدر ۵ نصب می‌شود).
- حسابی که اجازه‌ی معامله دارد: **Algo Trading** در ترمینال روشن باشد، معاملات
  الگوریتمی از سمت بروکر مسدود نباشد و ورود با رمز investor (فقط‌خواندنی) نباشد.
- باکس سشن‌ها فقط روی H1 و تایم‌فریم‌های پایین‌تر رسم می‌شوند.

### نصب، کامپایل و اجرا

1. فایل `CC_TradingManagement.mq5` را در پوشه‌ی `MQL5/Experts/` از پوشه‌ی داده‌های
   ترمینال کپی کنید (در متاتریدر ۵ از منوی File گزینه‌ی Open Data Folder).
2. فایل را در MetaEditor باز کنید و برای کامپایل **F7** را بزنید. فایل
   `CC_TradingManagement.ex5` کنار سورس ساخته می‌شود (فایل‌های کامپایل‌شده در گیت
   نگه داشته نمی‌شوند).
3. اکسپرت را روی چارت بکشید و **Algo Trading** را روشن کنید.

در هر نصب یک بار کارت خوش‌آمد نمایش داده می‌شود و بعد از ۳۰ ثانیه خودش بسته می‌شود
(با `InpWelcomeSec = 0` خاموش می‌شود).

برای امتحان بدون چارت واقعی، اکسپرت را در استراتژی تستر اجرا کنید؛ آنجا فقط
استراتژی داخلی تقاطع EMA معامله می‌کند (توضیحش در بالا آمده است).

این مخزن ساخت یا تست خودکار ندارد، چون کامپایلر MQL5 فقط داخل متاتریدر ۵ در دسترس
است.

### ساختار پروژه

| مسیر | محتوا |
|---|---|
| `CC_TradingManagement.mq5` | کل اکسپرت: ورودی‌ها، پنل، ابزار پوزیشن، ابزارهای چارت، ارسال سفارش و استراتژی مخصوص تستر |
| `README.md` | همین فایل |
| `LICENSE` | شرایط مجوز |
| `SECURITY.md` | روش گزارش مشکل امنیتی |
| `.github/` | قالب‌های issue و pull request |

### وضعیت

عمومی. در حال توسعه؛ نسخه‌ی فعلی **4.90** (`#property version` در سورس). تغییرات در
تاریخچه‌ی کامیت‌ها ثبت شده است.

### مجوز

انحصاری (Proprietary). Copyright (c) 2026 ChartAndChill. همه‌ی حقوق محفوظ است. فایل
[LICENSE](LICENSE) را ببینید.

</div>
