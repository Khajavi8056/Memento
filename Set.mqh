//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: set.mqh (EA Settings)                   |
//|                    Version: 8.0 (HTF & Advanced Grace Period)    |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "8.0" // افزوده شدن تایم فریم اصلی قابل تنظیم و حالت‌های پیشرفته مهلت سیگنال

// --- انواع شمارشی برای خوانایی بهتر کد ---

enum E_Entry_Confirmation_Mode
{
    CONFIRM_CURRENT_TIMEFRAME, // روش فعلی: تاییدیه بر اساس کندل در تایم فریم اصلی
    CONFIRM_LOWER_TIMEFRAME    // روش جدید: تاییدیه بر اساس شکست ساختار (CHoCH) در تایم فریم پایین
};

// ✅✅✅ [جدید] نوع مهلت برای انقضای سیگنال در حالت انتظار ✅✅✅
enum E_Grace_Period_Mode
{
    GRACE_BY_CANDLES,          // انقضا بر اساس تعداد کندل (روش ساده)
    GRACE_BY_STRUCTURE         // انقضا بر اساس شکست ساختار قیمت (روش هوشمند)
};

enum E_Confirmation_Mode { MODE_CLOSE_ONLY, MODE_OPEN_AND_CLOSE };

enum E_SL_Mode
{
    MODE_COMPLEX,         // بهینه (انتخاب نزدیک‌ترین گزینه منطقی)
    MODE_SIMPLE,          // ساده (بر اساس رنگ مخالف کندل)
    MODE_ATR              // پویا (مبتنی بر ATR)
};

enum E_Signal_Mode { MODE_REPLACE_SIGNAL, MODE_SIGNAL_CONTEST };

enum E_Talaqi_Mode
{
    TALAQI_MODE_MANUAL,     // دستی (بر اساس پوینت)
    TALAQI_MODE_KUMO,       // هوشمند (بر اساس ضخامت کومو)
    TALAQI_MODE_ATR,        // پویا (مبتنی بر ATR)
};


//+------------------------------------------------------------------+
//|                      تنظیمات ورودی اکسپرت                         |
//+------------------------------------------------------------------+

// ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---
input group           "          ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---";
input bool            Inp_Enable_Dashboard  = true;                   // ✅ فعال/غیرفعال کردن داشبورد اطلاعاتی
input string          Inp_Symbols_List      = "EURUSD,GBPUSD,XAUUSD"; // لیست نمادها (جدا شده با کاما)
input int             Inp_Magic_Number      = 12345;                  // شماره جادویی معاملات
input bool            Inp_Enable_Logging    = true;                   // فعال/غیرفعال کردن لاگ‌ها

// ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku Baseline) 📈 ===---
input group           "      ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku) 📈 ===---";
// ✅✅✅ [جدید] ورودی برای تایم فریم اصلی ✅✅✅
input ENUM_TIMEFRAMES Inp_Ichimoku_Timeframe = PERIOD_H1;                // تایم فریم اصلی برای تحلیل ایچیموکو
input int             Inp_Tenkan_Period     = 10;                     // دوره تنکان-سن (بهینه شده)
input int             Inp_Kijun_Period      = 28;                     // دوره کیجون-سن (بهینه شده)
input int             Inp_Senkou_Period     = 55;                     // دوره سنکو اسپن بی (بهینه شده)
input int             Inp_Chikou_Period     = 26;                     // دوره چیکو اسپن (نقطه مرجع)

// ---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---
input group           "---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---";
input E_Signal_Mode   Inp_Signal_Mode         = MODE_SIGNAL_CONTEST;  // روش مدیریت سیگنال

input group           "         --- تاییدیه نهایی ورود (Final Confirmation) ---";
input E_Entry_Confirmation_Mode Inp_Entry_Confirmation_Mode = CONFIRM_CURRENT_TIMEFRAME; // نوع تاییدیه ورود

// ✅✅✅ [بخش جدید] تنظیمات مهلت سیگنال ✅✅✅
input group           "         --- مهلت سیگنال در حالت انتظار (Grace Period) ---";
input E_Grace_Period_Mode Inp_Grace_Period_Mode = GRACE_BY_CANDLES;   // نوع انقضای سیگنال
input int             Inp_Grace_Period_Candles= 4;                      // [حالت کندلی] تعداد کندل مهلت برای تاییدیه
// نکته: در حالت ساختاری، سطح ابطال به صورت خودکار پیدا می‌شود.

input group           "         --- تنظیمات تاییدیه تایم فریم پایین (LTF) ---";
input ENUM_TIMEFRAMES Inp_LTF_Timeframe = PERIOD_M5;                      // [روش LTF] تایم فریم برای تاییدیه ورود
input E_Confirmation_Mode Inp_Confirmation_Type = MODE_CLOSE_ONLY;    // [روش تایم فریم فعلی] نوع تایید کندل


// --- زیرگروه تنظیمات تلاقی (Confluence) ---
input group           "         --- تنظیمات تلاقی (Confluence) ---";
input E_Talaqi_Mode   Inp_Talaqi_Calculation_Mode = TALAQI_MODE_ATR;    // روش محاسبه فاصله تلاقی (بهینه شده)
input double          Inp_Talaqi_ATR_Multiplier     = 0.28;             // [ATR Mode] ضریب ATR برای تلاقی (بهینه شده)
input double          Inp_Talaqi_Distance_in_Points = 3.0;              // [MANUAL Mode] فاصله تلاقی (بر اساس پوینت)
input double          Inp_Talaqi_Kumo_Factor      = 0.2;              // [KUMO Mode] ضریب تلاقی (درصد ضخامت کومو)


// ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---
input group           "       ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---";
input E_SL_Mode       Inp_StopLoss_Type       = MODE_COMPLEX;           // روش محاسبه استاپ لاس
input double          Inp_SL_ATR_Multiplier   = 2.2;                    // [ATR Mode] ضریب ATR برای حد ضرر (بهینه شده)
input int             Inp_SL_Lookback_Period  = 15;                     // [SIMPLE] دوره نگاه به عقب برای یافتن سقف/کف
input double          Inp_SL_Buffer_Multiplier = 3.0;                   // [SIMPLE/COMPLEX] ضریب بافر
input int             Inp_Flat_Kijun_Period   = 50;                     // [COMPLEX] تعداد کندل برای جستجوی کیجون فلت
input int             Inp_Flat_Kijun_Min_Length = 5;                    // [COMPLEX] حداقل طول کیجون فلت
input int             Inp_Pivot_Lookback      = 30;                     // [COMPLEX] تعداد کندل برای جستجوی پیوت

input group           "    --- SL پویا بر اساس نوسان ---";
input bool            Inp_Enable_SL_Vol_Regime = false;                 // فعال سازی SL پویا با رژیم نوسان
input int             Inp_SL_Vol_Regime_ATR_Period = 14;                // [پویا] دوره ATR برای محاسبه نوسان
input int             Inp_SL_Vol_Regime_EMA_Period = 20;                // [پویا] دوره EMA برای تعریف خط رژیم نوسان
input double          Inp_SL_High_Vol_Multiplier = 2.2;                 // [پویا] ضریب ATR در رژیم نوسان بالا
input double          Inp_SL_Low_Vol_Multiplier = 1.5;                  // [پویا] ضریب ATR در رژیم نوسان پایین


// ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---
input group           " ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---";
input double          Inp_Risk_Percent_Per_Trade = 0.7;                 // درصد ریسک در هر معامله (بهینه شده)
input double          Inp_Take_Profit_Ratio   = 1.9;                    // نسبت ریسک به ریوارد برای حد سود (بهینه شده)
input int             Inp_Max_Trades_Per_Symbol = 1;                    // حداکثر معاملات باز برای هر نماد
input int             Inp_Max_Total_Trades    = 5;                      // حداکثر کل معاملات باز

// ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---
input group           "        ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---";
input double          Inp_Object_Size_Multiplier = 1.0;                 // ضریب اندازه اشیاء گرافیکی
input color           Inp_Bullish_Color       = clrLimeGreen;           // رنگ سیگنال و اشیاء خرید
input color           Inp_Bearish_Color       = clrRed;                 // رنگ سیگنال و اشیاء فروش

// ---=== 🚦 7. فیلترهای ورود (Entry Filters) 🚦 ===---
input group           "   ---=== 🚦 7. فیلترهای ورود (Entry Filters) 🚦 ===---";
input bool            Inp_Enable_Kumo_Filter = true;                    // ✅ [فیلتر کومو]: فعال/غیرفعال
input bool            Inp_Enable_ATR_Filter  = true;                    // ✅ [فیلتر ATR]: فعال/غیرفعال
input int             Inp_ATR_Filter_Period  = 14;                      // [فیلتر ATR]: دوره محاسبه ATR
input double          Inp_ATR_Filter_Min_Value_pips = 9.0;              // [فیلتر ATR]: حداقل مقدار ATR به پیپ (بهینه شده)
input bool            Inp_Enable_ADX_Filter = false;                    // فعال سازی فیلتر قدرت و جهت روند ADX
input int             Inp_ADX_Period = 14;                              // [ADX] دوره محاسبه
input double          Inp_ADX_Threshold = 25.0;                         // [ADX] حداقل قدرت روند برای ورود

// ---=== 🎯 8. منطق خروج (Exit Logic) 🎯 ===---
input group "       ---=== 🎯 8. منطق خروج (Exit Logic) 🎯 ===---";
input bool            Inp_Enable_Early_Exit = false;                    // فعال سازی خروج زودرس با کراس چیکو و تایید RSI
input int             Inp_Early_Exit_RSI_Period = 14;                   // [خروج زودرس] دوره RSI
input int             Inp_Early_Exit_RSI_Overbought = 70;               // [خروج زودرس] سطح اشباع خرید برای خروج از فروش
input int             Inp_Early_Exit_RSI_Oversold = 30;                 // [خروج زودرس] سطح اشباع فروش برای خروج از خرید


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
    // ✅✅✅ [بخش اصلاح شده] متغیرهای ایچیموکو ✅✅✅
    ENUM_TIMEFRAMES     ichimoku_timeframe;      // تایم فریم اصلی تحلیل
    int                 tenkan_period;
    int                 kijun_period;
    int                 senkou_period;
    int                 chikou_period;
    
    // 3. Signal & Confirmation
    E_Signal_Mode       signal_mode;
    
    // ✅✅✅ [بخش اصلاح شده] متغیرهای تاییدیه و مهلت ✅✅✅
    E_Entry_Confirmation_Mode entry_confirmation_mode; // نوع تاییدیه ورود
    E_Grace_Period_Mode grace_period_mode;           // نوع مهلت سیگنال
    int                 grace_period_candles;        // [حالت کندلی] تعداد کندل مهلت
    E_Confirmation_Mode confirmation_type;           // [حالت تایم فریم فعلی] نوع تایید کندل
    ENUM_TIMEFRAMES     ltf_timeframe;               // [حالت LTF] تایم فریم برای تاییدیه
    
    // 3.1. Talaqi
    E_Talaqi_Mode       talaqi_calculation_mode;
    double              talaqi_distance_in_points;
    double              talaqi_kumo_factor;
    double              talaqi_atr_multiplier;
    
    // 4. Stop Loss
    E_SL_Mode           stoploss_type;
    double              sl_atr_multiplier;
    int                 sl_lookback_period;
    double              sl_buffer_multiplier;
    int                 flat_kijun_period;
    int                 flat_kijun_min_length;
    int                 pivot_lookback;
    
    bool                enable_sl_vol_regime;
    int                 sl_vol_regime_atr_period;
    int                 sl_vol_regime_ema_period;
    double              sl_high_vol_multiplier;
    double              sl_low_vol_multiplier;

    // 5. Money Management
    double              risk_percent_per_trade;
    double              take_profit_ratio;
    int                 max_trades_per_symbol;
    int                 max_total_trades;
    
    // 6. Visuals
    double              object_size_multiplier;
    color               bullish_color;
    color               bearish_color;
    
    // 7. Entry Filters
    bool                enable_kumo_filter;
    bool                enable_atr_filter;
    int                 atr_filter_period;
    double              atr_filter_min_value_pips;

    bool                enable_adx_filter;
    int                 adx_period;
    double              adx_threshold;

    // 8. Exit Logic
    bool                enable_early_exit;
    int                 early_exit_rsi_period;
    int                 early_exit_rsi_overbought;
    int                 early_exit_rsi_oversold;
};
