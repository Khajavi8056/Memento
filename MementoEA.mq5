//+------------------------------------------------------------------+
//|                                                      Memento.mq5 |
//|                                  Copyright 2025, Mohammad & Gemini |
//|                                                  Final & Bulletproof |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Mohammad & Gemini"
#property link      "https://www.mql5.com"
#property version   "6.6" // نسخه نهایی و کاملا اصلاح شده
#property description "اکسپرت معاملاتی پیشرفته ممنتو بر اساس استراتژی کراس سه گانه ایچیموکو"

#include <Trade\Trade.mqh>
#include <Object.mqh>
#include "IchimokuLogic.mqh"
#include "VisualManager.mqh"

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
};

//--- متغیرهای سراسری
SSettings            g_settings;
string               g_symbols_array[];
CStrategyManager* g_symbol_managers[];

//+------------------------------------------------------------------+
//| تابع شروع اکسپرت (مقداردهی اولیه)                                |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- مقداردهی اولیه ساختار تنظیمات از ورودی‌های کاربر
    g_settings.symbols_list                 = Inp_Symbols_List;
    g_settings.magic_number                 = Inp_Magic_Number;
    g_settings.enable_logging               = Inp_Enable_Logging;
    g_settings.tenkan_period                = Inp_Tenkan_Period;
    g_settings.kijun_period                 = Inp_Kijun_Period;
    g_settings.senkou_period                = Inp_Senkou_Period;
    g_settings.chikou_period                = Inp_Chikou_Period;
    g_settings.confirmation_type            = Inp_Confirmation_Type;
    g_settings.grace_period_candles         = Inp_Grace_Period_Candles;
    g_settings.talaqi_distance_in_points    = Inp_Talaqi_Distance_in_Points;
    g_settings.stoploss_type                = Inp_StopLoss_Type;
    g_settings.sl_lookback_period           = Inp_SL_Lookback_Period;
    g_settings.sl_buffer_multiplier         = Inp_SL_Buffer_Multiplier;
    g_settings.risk_percent_per_trade       = Inp_Risk_Percent_Per_Trade;
    g_settings.take_profit_ratio            = Inp_Take_Profit_Ratio;
    g_settings.max_trades_per_symbol        = Inp_Max_Trades_Per_Symbol;
    g_settings.max_total_trades             = Inp_Max_Total_Trades;
    g_settings.object_size_multiplier       = Inp_Object_Size_Multiplier;
    g_settings.bullish_color                = Inp_Bullish_Color;
    g_settings.bearish_color                = Inp_Bearish_Color;

    //--- تقسیم رشته نمادها و ایجاد شیء مدیریت برای هر نماد
    int symbols_count = StringSplit(g_settings.symbols_list, ',', g_symbols_array);
    if (symbols_count == 0)
    {
        Print("خطا: هیچ نمادی برای معامله مشخص نشده است.");
        return INIT_FAILED;
    }
    
    ArrayResize(g_symbol_managers, symbols_count);
    for (int i = 0; i < symbols_count; i++)
    {
        string sym = g_symbols_array[i];
        StringTrimLeft(sym);
        StringTrimRight(sym);
        g_symbol_managers[i] = new CStrategyManager(sym, g_settings);
        if (!g_symbol_managers[i]->Init())
        {
            Print("مقداردهی اولیه نماد ", sym, " با خطا مواجه شد.");
            return INIT_FAILED;
        }
    }

    Print("اکسپرت Memento با موفقیت برای نمادهای زیر مقداردهی اولیه شد: ", g_settings.symbols_list);
    
    //--- راه‌اندازی تایمر برای اجرای مداوم
    EventSetTimer(1);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع پایان اکسپرت (پاکسازی)                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    //--- پاکسازی شیءها
    for (int i = 0; i < ArraySize(g_symbol_managers); i++)
    {
        if (g_symbol_managers[i] != NULL)
        {
            delete g_symbol_managers[i];
            g_symbol_managers[i] = NULL;
        }
    }
    ArrayFree(g_symbol_managers);
    //--- پاک کردن تمام اشیاء گرافیکی
    //--- از VisualManager برای پاک کردن اشیا استفاده میکنیم
    ObjectsDeleteAll(0, g_settings.symbols_list);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| تابع تایمر (بررسی مداوم کندل‌ها و سیگنال‌ها)                      |
//+------------------------------------------------------------------+
void OnTimer()
{
    //--- اجرای منطق برای تمام نمادهای تحت مدیریت
    for (int i = 0; i < ArraySize(g_symbol_managers); i++)
    {
        if (g_symbol_managers[i] != NULL)
        {
            g_symbol_managers[i]->ProcessNewBar();
        }
    }
}