//+------------------------------------------------------------------+
//|                                     set.mqh     تنضیمات       |
//|                          © 2025, hipoalgoritm              |
//+------------------------------------------------------------------+
//--- تنظیمات عمومی
input group "1. General Settings"
input string Inp_Symbols_List      = "EURUSD,XAUUSD,GBPUSD"; // لیست نمادها به صورت جدا شده با کاما
input int    Inp_Magic_Number      = 12345;                 // شماره جادویی برای معاملات
input bool   Inp_Enable_Logging    = true;                  // فعال‌سازی لاگ‌های دقیق

//--- تنظیمات ایچیموکو
input group "2. Ichimoku Settings"
input int Inp_Tenkan_Period     = 9;          // دوره تنکان-سن
input int Inp_Kijun_Period      = 26;         // دوره کیجون-سن
input int Inp_Senkou_Period     = 52;         // دوره سنکو اسپن بی
input int Inp_Chikou_Period     = 26;         // دوره چیکو اسپن (نقطه مرجع اصلی)

//--- پارامترهای سیگنال و تأیید
input group "3. Signal & Confirmation"
enum E_Confirmation_Mode { MODE_CLOSE_ONLY, MODE_OPEN_AND_CLOSE };
input E_Confirmation_Mode Inp_Confirmation_Type     = MODE_OPEN_AND_CLOSE; // نوع تأیید قیمت
input int Inp_Grace_Period_Candles  = 5;          // دوره مهلت تأیید (تعداد کندل‌ها)
input double Inp_Talaqi_Distance_in_Points = 3.0; // فاصله تلاقی (بر اساس پوینت نماد)

//--- تنظیمات استاپ لاس
input group "4. Stop Loss Settings"
enum E_SL_Mode { MODE_COMPLEX, MODE_SIMPLE };
input E_SL_Mode Inp_StopLoss_Type       = MODE_COMPLEX;     // روش محاسبه استاپ لاس
input int Inp_SL_Lookback_Period  = 15;         // دوره نگاه به عقب برای استاپ لاس
input double Inp_SL_Buffer_Multiplier    = 3.0;      // ضریب بافر استاپ لاس (بر اساس پوینت نماد)
input int Inp_Flat_Kijun_Period = 50;         // تعداد کندل برای جستجوی کیجون فلت
input int Inp_Flat_Kijun_Min_Length = 5;      // حداقل طول کیجون فلت
input int Inp_Pivot_Lookback      = 30;         // تعداد کندل برای جستجوی پیوت
//--- مدیریت مالی و معاملات
input group "5. Money & Trade Management"
input double Inp_Risk_Percent_Per_Trade  = 1.0;      // درصد ریسک در هر معامله
input double Inp_Take_Profit_Ratio       = 1.5;      // نسبت ریسک به پاداش برای حد سود
input int    Inp_Max_Trades_Per_Symbol   = 1;          // حداکثر معاملات باز برای هر نماد
input int    Inp_Max_Total_Trades      = 5;          // حداکثر کل معاملات باز

//--- تنظیمات گرافیکی
input group "6. Graphical Settings"
input double Inp_Object_Size_Multiplier = 1.0;      // ضریب اندازه اشیاء گرافیکی
input color Inp_Bullish_Color            = clrLimeGreen; // رنگ سیگنال خرید
input color Inp_Bearish_Color            = clrRed;      // رنگ سیگنال فروش

//+------------------------------------------------------------------+
//| ساختار اصلی برای نگهداری تمام تنظیمات ورودی                       |
//+------------------------------------------------------------------+




struct SSettings
{
    string              symbols_list;
    int                 magic_number;
    bool                enable_logging;

    int                 tenkan_period;
    int                 kijun_period;
    int                 senkou_period;
    int                 chikou_period;

    E_Confirmation_Mode confirmation_type;
    int                 grace_period_candles;
    double              talaqi_distance_in_points;

    E_SL_Mode           stoploss_type;
    int                 sl_lookback_period;
    double              sl_buffer_multiplier;

    double              risk_percent_per_trade;
    double              take_profit_ratio;
    int                 max_trades_per_symbol;
    int                 max_total_trades;

    double              object_size_multiplier;
    color               bullish_color;
    color               bearish_color;
      int                 flat_kijun_period;
    int                 flat_kijun_min_length;
    int                 pivot_lookback;

};
