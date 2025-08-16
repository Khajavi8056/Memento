//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: set.mqh (EA Settings)                   |
//|                    Version: 8.1 (Smart MTF Refactor)             |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "8.1" // بازنویسی کامل برای پشتیبانی از تایم فریم هوشمند

// --- ✅ [جدید] نوع شمارشی برای انتخاب منبع تایم فریم ---
enum E_MTF_Source
{
    MTF_ICHIMOKU,     // استفاده از تایم فریم اصلی ایچیموکو (تایم بالا)
    MTF_CONFIRMATION  // استفاده از تایم فریم تاییدیه (تایم پایین)
};

// --- انواع شمارشی دیگر (بدون تغییر) ---
enum E_Entry_Confirmation_Mode
{
    CONFIRM_CURRENT_TIMEFRAME,
    CONFIRM_LOWER_TIMEFRAME
};

enum E_Grace_Period_Mode
{
    GRACE_BY_CANDLES,
    GRACE_BY_STRUCTURE
};

enum E_Confirmation_Mode { MODE_CLOSE_ONLY, MODE_OPEN_AND_CLOSE };

enum E_SL_Mode
{
    MODE_COMPLEX,
    MODE_SIMPLE,
    MODE_ATR
};

enum E_Signal_Mode { MODE_REPLACE_SIGNAL, MODE_SIGNAL_CONTEST };

enum E_Talaqi_Mode
{
    TALAQI_MODE_MANUAL,
    TALAQI_MODE_KUMO,
    TALAQI_MODE_ATR,
};


//+------------------------------------------------------------------+
//|                      تنظیمات ورودی اکسپرت (نسخه نهایی)             |
//+------------------------------------------------------------------+

// ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---
input group           "          ---=== ⚙️ 1. تنظیمات عمومی (General) ⚙️ ===---";
input bool            Inp_Enable_Dashboard  = true;
input string          Inp_Symbols_List      = "EURUSD,GBPUSD,XAUUSD";
input int             Inp_Magic_Number      = 12345;
input bool            Inp_Enable_Logging    = true;

// ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku Baseline) 📈 ===---
input group           "      ---=== 📈 2. تنظیمات ایچیموکو (Ichimoku) 📈 ===---";
input ENUM_TIMEFRAMES Inp_Ichimoku_Timeframe = PERIOD_H1;
input int             Inp_Tenkan_Period     = 10;
input int             Inp_Kijun_Period      = 28;
input int             Inp_Senkou_Period     = 55;
input int             Inp_Chikou_Period     = 26;

// ---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---
input group           "---=== 🎯 3. سیگنال و تاییدیه (Signal & Confirmation) 🎯 ===---";
input E_Signal_Mode   Inp_Signal_Mode         = MODE_SIGNAL_CONTEST;
input group           "         --- تاییدیه نهایی ورود (Final Confirmation) ---";
input E_Entry_Confirmation_Mode Inp_Entry_Confirmation_Mode = CONFIRM_LOWER_TIMEFRAME;
input group           "         --- مهلت سیگنال در حالت انتظار (Grace Period) ---";
input E_Grace_Period_Mode Inp_Grace_Period_Mode = GRACE_BY_STRUCTURE;
input int             Inp_Grace_Period_Candles= 4;
input group           "         --- تنظیمات تاییدیه تایم فریم پایین (LTF) ---";
input ENUM_TIMEFRAMES Inp_LTF_Timeframe = PERIOD_M5;
input E_Confirmation_Mode Inp_Confirmation_Type = MODE_CLOSE_ONLY;
input group           "         --- تنظیمات تلاقی (Confluence) ---";
input E_Talaqi_Mode   Inp_Talaqi_Calculation_Mode = TALAQI_MODE_ATR;
input double          Inp_Talaqi_ATR_Multiplier     = 0.28;
input double          Inp_Talaqi_Distance_in_Points = 3.0;
input double          Inp_Talaqi_Kumo_Factor      = 0.2;


// ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---
input group           "       ---=== 🛡️ 4. مدیریت حد ضرر (Stop Loss) 🛡️ ===---";
input E_SL_Mode       Inp_StopLoss_Type       = MODE_COMPLEX;
// --- ✅ [جدید] انتخاب هوشمند تایم فریم برای استاپ لاس ---
input E_MTF_Source    Inp_SL_Timeframe_Source = MTF_ICHIMOKU; // منبع تایم فریم برای محاسبه SL
input double          Inp_SL_ATR_Multiplier   = 2.2;
input int             Inp_SL_Lookback_Period  = 15;
input double          Inp_SL_Buffer_Multiplier = 3.0;
input int             Inp_Flat_Kijun_Period   = 50;
input int             Inp_Flat_Kijun_Min_Length = 5;
input int             Inp_Pivot_Lookback      = 30;
input group           "    --- SL پویا بر اساس نوسان ---";
input bool            Inp_Enable_SL_Vol_Regime = false;
input int             Inp_SL_Vol_Regime_ATR_Period = 14;
input int             Inp_SL_Vol_Regime_EMA_Period = 20;
input double          Inp_SL_High_Vol_Multiplier = 2.2;
input double          Inp_SL_Low_Vol_Multiplier = 1.5;


// ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---
input group           " ---=== 💰 5. مدیریت سرمایه (Money Management) 💰 ===---";
input double          Inp_Risk_Percent_Per_Trade = 0.7;
input double          Inp_Take_Profit_Ratio   = 1.9;
input int             Inp_Max_Trades_Per_Symbol = 1;
input int             Inp_Max_Total_Trades    = 5;

// ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---
input group           "        ---=== 🎨 6. تنظیمات گرافیکی (Visuals) 🎨 ===---";
input double          Inp_Object_Size_Multiplier = 1.0;
input color           Inp_Bullish_Color       = clrLimeGreen;
input color           Inp_Bearish_Color       = clrRed;

// ---=== 🚦 7. فیلترهای ورود (Entry Filters) 🚦 ===---
input group           "   ---=== 🚦 7. فیلترهای ورود (Entry Filters) 🚦 ===---";
// --- ✅ [جدید] انتخاب هوشمند تایم فریم برای فیلترها ---
input E_MTF_Source    Inp_Filter_Timeframe_Source = MTF_ICHIMOKU; // منبع تایم فریم برای فیلترها
input bool            Inp_Enable_Kumo_Filter = true;
input bool            Inp_Enable_ATR_Filter  = true;
input int             Inp_ATR_Filter_Period  = 14;
input double          Inp_ATR_Filter_Min_Value_pips = 9.0;
input bool            Inp_Enable_ADX_Filter = false;
input int             Inp_ADX_Period = 14;
input double          Inp_ADX_Threshold = 25.0;

// ---=== 🎯 8. منطق خروج (Exit Logic) 🎯 ===---
input group "       ---=== 🎯 8. منطق خروج (Exit Logic) 🎯 ===---";
input bool            Inp_Enable_Early_Exit = false;
input int             Inp_Early_Exit_RSI_Period = 14;
input int             Inp_Early_Exit_RSI_Overbought = 70;
input int             Inp_Early_Exit_RSI_Oversold = 30;


//+------------------------------------------------------------------+
//|     ساختار اصلی برای نگهداری تمام تنظیمات (نسخه نهایی و هماهنگ)   |
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
    int                 tenkan_period;
    int                 kijun_period;
    int                 senkou_period;
    int                 chikou_period;
    
    // 3. Signal & Confirmation
    E_Signal_Mode       signal_mode;
    E_Entry_Confirmation_Mode entry_confirmation_mode;
    E_Grace_Period_Mode grace_period_mode;
    int                 grace_period_candles;
    E_Confirmation_Mode confirmation_type;
    ENUM_TIMEFRAMES     ltf_timeframe;
    
    // 3.1. Talaqi
    E_Talaqi_Mode       talaqi_calculation_mode;
    double              talaqi_distance_in_points;
    double              talaqi_kumo_factor;
    double              talaqi_atr_multiplier;
    
    // 4. Stop Loss
    E_SL_Mode           stoploss_type;
    E_MTF_Source        sl_timeframe_source; // ✅ آپدیت شد
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
    E_MTF_Source        filter_timeframe_source; // ✅ آپدیت شد
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
