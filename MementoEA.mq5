//+------------------------------------------------------------------+
//|                                                      Memento.mq5 |
//|                                  Copyright 2025,hipoalgoritm |
//|                                                  Final & Bulletproof |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025,hipoalgoritm
#property link      "https://www.mql5.com"
#property version   "1.6" // نسخه نهایی و کاملا اصلاح شده
#property description "اکسپرت معاملاتی پیشرفته ممنتو بر اساس استراتژی کراس سه گانه ایچیموکو"

#include <Trade\Trade.mqh>
#include <Object.mqh>
#include "IchimokuLogic.mqh"
#include "VisualManager.mqh"


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
    g_settings.flat_kijun_period            = Inp_Flat_Kijun_Period;
    g_settings.flat_kijun_min_length        = Inp_Flat_Kijun_Min_Length;
    g_settings.pivot_lookback               = Inp_Pivot_Lookback;

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
        if (!g_symbol_managers[i].Init())
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
            g_symbol_managers[i].ProcessNewBar();
        }
    }
}
