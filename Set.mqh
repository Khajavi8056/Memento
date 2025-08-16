//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: set.mqh (EA Settings)                   |
//|                    Version: 8.3 (Fully Commented)                |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "8.3" // نسخه کامل با تمام کامنت‌های توضیحی

// --- نوع شمارشی برای انتخاب منبع تایم فریم ---
enum E_MTF_Source
{
    MTF_ICHIMOKU,     // استفاده از تایم فریم اصلی ایچیموکو (تایم بالا)
    MTF_CONFIRMATION  // استفاده از تایم فریم تاییدیه (تایم پایین)
};

// --- انواع شمارشی دیگر ---
enum E_Entry_Confirmation_Mode { CONFIRM_CURRENT_TIMEFRAME, CONFIRM_LOWER_TIMEFRAME };
enum E_Grace_Period_Mode { GRACE_BY_CANDLES, GRACE_BY_STRUCTURE };
enum E_Confirmation_Mode { MODE_CLOSE_ONLY, MODE_OPEN_AND_CLOSE };
enum E_SL_Mode { MODE_COMPLEX, MODE_SIMPLE, MODE_ATR };
enum E_Signal_Mode { MODE_REPLACE_SIGNAL, MODE_SIGNAL_CONTEST };
enum E_Talaqi_Mode { TALAQI_MODE_MANUAL, TALAQI_MODE_KUMO, TALAQI_MODE_ATR };


//+------------------------------------------------------------------+
//|                      تنظیمات ورودی اکسپرت                         |
//+------------------------------------------------------------------+

// ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---
input group           "          ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---";
input bool            Inp_Enable_Dashboard  = true;                   // فعال/غیرفعال کردن داشبورد گرافیکی روی چارت
input string          Inp_Symbols_List      = "EURUSD,GBPUSD,XAUUSD"; // لیست نمادهایی که اکسپرت روی آنها کار می‌کند (جدا شده با کاما)
input int             Inp_Magic_Number      = 12345;                  // شماره منحصر به فرد برای شناسایی معاملات این اکسپرت
input bool            Inp_Enable_Logging    = true;                   // فعال/غیرفعال کردن ثبت گزارش عملکرد در تب Experts

// ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku Baseline) 📈 ===---
input group           "      ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku) 📈 ===---";
input ENUM_TIMEFRAMES Inp_Ichimoku_Timeframe = PERIOD_H1;                // تایم فریم اصلی که استراتژی ایچیموکو روی آن تحلیل می‌شود
input int             Inp_Tenkan_Period     = 10;                     // دوره زمانی برای محاسبه خط تنکان-سن
input int             Inp_Kijun_Period      = 28;                     // دوره زمانی برای محاسبه خط کیجون-سن
input int             Inp_Senkou_Period     = 55;                     // دوره زمانی برای محاسبه سنکو اسپن بی (ابر کومو)
input int             Inp_Chikou_Period     = 26;                     // میزان شیفت به عقب چیکو اسپن (برای تایید سیگنال)

// ---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---
input group           "---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---";
input E_Signal_Mode   Inp_Signal_Mode         = MODE_SIGNAL_CONTEST;    // روش مدیریت سیگنال‌های پیدا شده (جایگزینی یا مسابقه‌ای)
input group           "         --- تاییدیه نهایی ورود (Final Confirmation) ---";
input E_Entry_Confirmation_Mode Inp_Entry_Confirmation_Mode = CONFIRM_LOWER_TIMEFRAME; // نوع تاییدیه نهایی برای ورود به معامله
input group           "         --- مهلت سیگنال در حالت انتظار (Grace Period) ---";
input E_Grace_Period_Mode Inp_Grace_Period_Mode = GRACE_BY_STRUCTURE;   // نوع انقضای سیگنال در حالت انتظار
input int             Inp_Grace_Period_Candles= 4;                      // [اگر حالت کندلی فعال باشد] تعداد کندل مهلت برای تاییدیه
input group           "         --- تنظیمات تاییدیه تایم فریم پایین (LTF) ---";
input ENUM_TIMEFRAMES Inp_LTF_Timeframe = PERIOD_M5;                      // تایم فریم پایین برای گرفتن تاییدیه شکست ساختار (CHoCH)
input E_Confirmation_Mode Inp_Confirmation_Type = MODE_CLOSE_ONLY;    // [اگر تاییدیه بر اساس تایم فریم فعلی باشد] نوع تایید کندل
input group           "         --- تنظیمات تلاقی (Confluence) ---";
input E_Talaqi_Mode   Inp_Talaqi_Calculation_Mode = TALAQI_MODE_ATR;    // روش محاسبه فاصله مجاز بین تنکان و کیجون برای سیگنال تلاقی
input double          Inp_Talaqi_ATR_Multiplier     = 0.28;             // [اگر حالت ATR فعال باشد] ضریب ATR برای محاسبه فاصله تلاقی
input double          Inp_Talaqi_Distance_in_Points = 3.0;              // [اگر حالت دستی فعال باشد] فاصله تلاقی به پوینت
input double          Inp_Talaqi_Kumo_Factor      = 0.2;              // [اگر حالت کومو فعال باشد] ضریب ضخامت ابر کومو برای تلاقی

// ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---
input group           "       ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---";
input E_SL_Mode       Inp_StopLoss_Type       = MODE_COMPLEX;           // روش کلی محاسبه حد ضرر (ساده، ATR یا پیچیده)
input E_MTF_Source    Inp_SL_Timeframe_Source = MTF_ICHIMOKU;           // منبع تایم فریم برای محاسبه SL (تایم بالا یا تایم پایین)
input double          Inp_SL_ATR_Multiplier   = 2.2;                    // [اگر حالت ATR فعال باشد] ضریب ATR برای محاسبه فاصله حد ضرر
input int             Inp_SL_Lookback_Period  = 15;                     // [اگر حالت ساده فعال باشد] تعداد کندل برای جستجوی سقف/کف
input double          Inp_SL_Buffer_Multiplier = 3.0;                   // ضریب فاصله اضافی (بافر) برای قرار دادن SL پشت سقف/کف
input int             Inp_Flat_Kijun_Period   = 50;                     // [اگر حالت پیچیده فعال باشد] تعداد کندل برای جستجوی کیجون فلت
input int             Inp_Flat_Kijun_Min_Length = 5;                    // [اگر حالت پیچیده فعال باشد] حداقل طول کیجون فلت
input int             Inp_Pivot_Lookback      = 30;                     // [اگر حالت پیچیده فعال باشد] تعداد کندل برای جستجوی پیوت
input group           "    --- SL پویا بر اساس نوسان ---";
input bool            Inp_Enable_SL_Vol_Regime = false;                 // فعال/غیرفعال کردن SL پویا بر اساس رژیم نوسان بازار
input int             Inp_SL_Vol_Regime_ATR_Period = 14;                // [اگر SL پویا فعال باشد] دوره ATR برای تشخیص نوسان
input int             Inp_SL_Vol_Regime_EMA_Period = 20;                // [اگر SL پویا فعال باشد] دوره EMA برای خط آستانه نوسان
input double          Inp_SL_High_Vol_Multiplier = 2.2;                 // [اگر SL پویا فعال باشد] ضریب ATR در نوسان بالا
input double          Inp_SL_Low_Vol_Multiplier = 1.5;                  // [اگر SL پویا فعال باشد] ضریب ATR در نوسان پایین

// ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---
input group           " ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---";
input double          Inp_Risk_Percent_Per_Trade = 0.7;                 // درصد ریسک از بالانس حساب در هر معامله
input double          Inp_Take_Profit_Ratio   = 1.9;                    // نسبت ریسک به ریوارد برای تعیین حد سود
input int             Inp_Max_Trades_Per_Symbol = 1;                    // حداکثر تعداد معاملات همزمان باز برای یک نماد
input int             Inp_Max_Total_Trades    = 5;                      // حداکثر کل معاملات همزمان باز در تمام نمادها

// ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---
input group           "        ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---";
input double          Inp_Object_Size_Multiplier = 1.0;                 // ضریب بزرگنمایی برای اشکال گرافیکی روی چارت
input color           Inp_Bullish_Color       = clrLimeGreen;           // رنگ برای سیگنال‌ها و اشیاء مربوط به معاملات خرید
input color           Inp_Bearish_Color       = clrRed;                 // رنگ برای سیگنال‌ها و اشیاء مربوط به معاملات فروش

// ---=== 🚦 7. فیلترهای ورود (Entry Filters) 🚦 ===---
input group           "   ---=== 🚦 7. فیلترهای ورود (Entry Filters) 🚦 ===---";
input E_MTF_Source    Inp_Filter_Timeframe_Source = MTF_ICHIMOKU;       // منبع تایم فریم برای محاسبات فیلترها (تایم بالا یا تایم پایین)
input bool            Inp_Enable_Kumo_Filter = true;                    // فعال/غیرفعال کردن فیلتر ابر کومو
input bool            Inp_Enable_ATR_Filter  = true;                    // فعال/غیرفعال کردن فیلتر حداقل نوسان ATR
input int             Inp_ATR_Filter_Period  = 14;                      // [اگر فیلتر ATR فعال باشد] دوره زمانی ATR
input double          Inp_ATR_Filter_Min_Value_pips = 9.0;              // [اگر فیلتر ATR فعال باشد] حداقل مقدار ATR به پیپ برای اجازه ورود
input bool            Inp_Enable_ADX_Filter = false;                    // فعال/غیرفعال کردن فیلتر قدرت و جهت روند ADX
input int             Inp_ADX_Period = 14;                              // [اگر فیلتر ADX فعال باشد] دوره زمانی ADX
input double          Inp_ADX_Threshold = 25.0;                         // [اگر فیلتر ADX فعال باشد] حداقل قدرت روند برای اجازه ورود

// ---=== 🎯 8. منطق خروج (Exit Logic) 🎯 ===---
input group "       ---=== 🎯 8. منطق خروج (Exit Logic) 🎯 ===---";
input bool            Inp_Enable_Early_Exit = false;                    // فعال/غیرفعال کردن خروج زودرس از معامله
input int             Inp_Early_Exit_RSI_Period = 14;                   // [اگر خروج زودرس فعال باشد] دوره زمانی RSI
input int             Inp_Early_Exit_RSI_Overbought = 70;               // [اگر خروج زودرس فعال باشد] سطح اشباع خرید RSI برای خروج از فروش
input int             Inp_Early_Exit_RSI_Oversold = 30;                 // [اگر خروج زودرس فعال باشد] سطح اشباع فروش RSI برای خروج از خرید

//+------------------------------------------------------------------+
//|     ساختار اصلی برای نگهداری تمام تنظیمات (هماهنگ شده با نام‌های قدیمی) |
//+------------------------------------------------------------------+
struct SSettings
{
    // 1. General
    bool                enable_dashboard;
    string              symbols_list;
    int                 magic_number;
    bool                enable_logging;
    
    // 2. Ichimoku
    ENUM_TIMEFRAMES     ichimoku_timeframe;
    int                 tenkan;                  // هماهنگ شده
    int                 kijun;                   // هماهنگ شده
    int                 senkou;                  // هماهنگ شده
    int                 chikou;                  // هماهنگ شده
    
    // 3. Signal & Confirmation
    E_Signal_Mode       signal_mode;
    E_Entry_Confirmation_Mode entry_confirmation_mode;
    E_Grace_Period_Mode grace_mode;              // هماهنگ شده
    int                 grace_candles;           // هماهنگ شده
    E_Confirmation_Mode confirmation_type;
    ENUM_TIMEFRAMES     ltf_timeframe;
    
    // 3.1. Talaqi
    E_Talaqi_Mode       talaqi_calculation_mode;
    double              talaqi_distance_in_points;
    double              talaqi_kumo_factor;
    double              talaqi_atr_multiplier;
    
    // 4. Stop Loss
    E_SL_Mode           stoploss_type;
    E_MTF_Source        sl_timeframe_source;
    double              sl_atr_multiplier;
    int                 sl_lookback;             // هماهنگ شده
    double              sl_buffer_multiplier;
    int                 flat_kijun;              // هماهنگ شده
    int                 flat_kijun_min_length;
    int                 pivot_lookback;
    
    bool                enable_sl_vol_regime;
    int                 sl_vol_regime_atr;       // هماهنگ شده
    int                 sl_vol_regime_ema;       // هماهنگ شده
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
    E_MTF_Source        filter_timeframe_source;
    bool                enable_kumo_filter;
    bool                enable_atr_filter;
    int                 atr_filter;              // هماهنگ شده
    double              atr_filter_min_value_pips;

    bool                enable_adx_filter;
    int                 adx;                     // هماهنگ شده
    double              adx_threshold;

    // 8. Exit Logic
    bool                enable_early_exit;
    int                 early_exit_rsi;          // هماهنگ شده
    int                 early_exit_rsi_overbought;
    int                 early_exit_rsi_oversold;
};
