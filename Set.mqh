//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: set.mqh (EA Settings)                   |
//|                    Version: 3.1 (Final Fixed)                    |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "1.2"

//--- انواع شمارشی برای خوانایی بهتر کد
enum E_Confirmation_Mode { MODE_CLOSE_ONLY, MODE_OPEN_AND_CLOSE };
enum E_SL_Mode           { MODE_COMPLEX, MODE_SIMPLE };
enum E_Signal_Mode     { MODE_REPLACE_SIGNAL, MODE_SIGNAL_CONTEST };
//+------------------------------------------------------------------+
//|                      تنظیمات ورودی اکسپرت                         |
//+------------------------------------------------------------------+

// ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---
input group           "          ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---"
input bool            Inp_Enable_Dashboard  = true;                   // ✅ فعال/غیرفعال کردن داشبورد اطلاعاتی
input string          Inp_Symbols_List      = "EURUSD,XAUUSD,GBPUSD"; // لیست نمادها (جدا شده با کاما)
input int             Inp_Magic_Number      = 12345;                  // شماره جادویی معاملات
input bool            Inp_Enable_Logging    = true;                   // فعال/غیرفعال کردن لاگ‌ها

// ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku) 📈 ===---
input group           "      ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku) 📈 ===---"
input int             Inp_Tenkan_Period     = 9;                      // دوره تنکان-سن
input int             Inp_Kijun_Period      = 26;                     // دوره کیجون-سن
input int             Inp_Senkou_Period     = 52;                     // دوره سنکو اسپن بی
input int             Inp_Chikou_Period     = 26;                     // دوره چیکو اسپن (نقطه مرجع)

// ---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---
input group           "---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---"
input E_Signal_Mode   Inp_Signal_Mode         = MODE_SIGNAL_CONTEST;  // ✅ این وش مدیریت سیگنال
input E_Confirmation_Mode Inp_Confirmation_Type = MODE_OPEN_AND_CLOSE;  // نوع تایید قیمت نهایی
// ... بقیه ورودی‌ها

input int             Inp_Grace_Period_Candles= 5;                      // تعداد کندل مهلت برای تاییدیه

// --- زیرگروه تنظیمات تلاقی (Confluence)
input group           "         --- تنظیمات تلاقی (Confluence) ---"
input bool            Inp_Talaqi_Auto_Mode    = true;                   // ✅ فعالسازی حالت اتوماتیک برای فاصله تلاقی
input double          Inp_Talaqi_Distance_in_Points = 3.0;              // [MANUAL] فاصله تلاقی (بر اساس پوینت)
input int             Inp_Talaqi_Lookback_Period  = 10;                 // [AUTO] دوره نگاه به عقب برای محاسبه فاصله تاریخی
input double          Inp_Talaqi_Hist_Multiplier = 0.5;                // [AUTO] ضریب تلاقی (مثلا 0.5 یعنی 50% فاصله تاریخی)

// ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---
input group           "       ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---"
input E_SL_Mode       Inp_StopLoss_Type       = MODE_COMPLEX;           // روش محاسبه استاپ لاس
input int             Inp_Flat_Kijun_Period   = 50;                     // [COMPLEX] تعداد کندل برای جستجوی کیجون فلت
input int             Inp_Flat_Kijun_Min_Length = 5;                    // [COMPLEX] حداقل طول کیجون فلت
input int             Inp_Pivot_Lookback      = 30;                     // [COMPLEX] تعداد کندل برای جستجوی پیوت
input int             Inp_SL_Lookback_Period  = 15;                     // [SIMPLE] دوره نگاه به عقب برای یافتن سقف/کف
input double          Inp_SL_Buffer_Multiplier = 3.0;                   // ضریب بافر برای فاصله از سقف/کف

// ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---
input group           " ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---"
input double          Inp_Risk_Percent_Per_Trade = 1.0;                 // درصد ریسک در هر معامله
input double          Inp_Take_Profit_Ratio   = 1.5;                    // نسبت ریسک به ریوارد برای حد سود
input int             Inp_Max_Trades_Per_Symbol = 1;                    // حداکثر معاملات باز برای هر نماد
input int             Inp_Max_Total_Trades    = 5;                      // حداکثر کل معاملات باز

// ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---
input group           "        ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---"
input double          Inp_Object_Size_Multiplier = 1.0;                 // ضریب اندازه اشیاء گرافیکی
input color           Inp_Bullish_Color       = clrLimeGreen;           // رنگ سیگنال و اشیاء خرید
input color           Inp_Bearish_Color       = clrRed;                 // رنگ سیگنال و اشیاء فروش


//+------------------------------------------------------------------+
//|     ساختار اصلی برای نگهداری تمام تنظیمات ورودی (SSettings)       |
//+------------------------------------------------------------------+
struct SSettings
{
    // 1. General
    bool                enable_dashboard;
    string              symbols_list;
    int                 magic_number;
    bool                enable_logging;
    // 2. Ichimoku
    int                 tenkan_period, kijun_period, senkou_period, chikou_period;
// 3. Signal & Confirmation
    E_Signal_Mode       signal_mode; // ✅ این خط را اضافه کن
    E_Confirmation_Mode confirmation_type;
    int                 grace_period_candles;
    // 3.1. Talaqi
    bool                talaqi_auto_mode;
    double              talaqi_distance_in_points;
    int                 talaqi_lookback_period;
    double              talaqi_hist_multiplier;
    // 4. Stop Loss
    E_SL_Mode           stoploss_type;
    int                 flat_kijun_period, flat_kijun_min_length, pivot_lookback, sl_lookback_period;
    double              sl_buffer_multiplier;
    // 5. Money Management
    double              risk_percent_per_trade, take_profit_ratio;
    int                 max_trades_per_symbol, max_total_trades;
    // 6. Visuals
    double              object_size_multiplier;
    color               bullish_color, bearish_color;
};
