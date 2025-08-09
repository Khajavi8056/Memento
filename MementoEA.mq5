//+------------------------------------------------------------------+
//|                                                      Memento.mq5 |
//|                                  Copyright 2025,hipoalgoritm |
//|                                                  Final & Bulletproof |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025,hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "1.7" // نسخه نهایی و کاملا اصلاح شده
#property description "اکسپرت معاملاتی پیشرفته ممنتو بر اساس استراتژی کراس سه گانه ایچیموکو"


#include <Trade\Trade.mqh>
#include <Object.mqh>
#include "IchimokuLogic.mqh"
#include "VisualManager.mqh"
#include "TrailingStopManager.mqh"



//--- متغیرهای سراسری
SSettings            g_settings;
string               g_symbols_array[];
CStrategyManager* g_symbol_managers[];
bool              g_dashboard_needs_update = true; // پرچم برای آپدیت هوشمند داشبورد
   CTrailingStopManager TrailingStop;
//+------------------------------------------------------------------+
//| تابع شروع اکسپرت (مقداردهی اولیه)                                |
//+------------------------------------------------------------------+
////+------------------------------------------------------------------+
//| تابع شروع اکسپرت (مقداردهی اولیه)                                |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- ✅✅✅ بخش مقداردهی اولیه تنظیمات (نسخه کامل و هماهنگ با فاز ۱) ✅✅✅ ---
    
    // 1. تنظیمات عمومی
    g_settings.enable_dashboard           = Inp_Enable_Dashboard;
    g_settings.symbols_list                 = Inp_Symbols_List;
    g_settings.magic_number                 = Inp_Magic_Number;
    g_settings.enable_logging               = Inp_Enable_Logging;
    
    // 2. تنظیمات ایچیموکو
    g_settings.tenkan_period                = Inp_Tenkan_Period;
    g_settings.kijun_period                 = Inp_Kijun_Period;
    g_settings.senkou_period                = Inp_Senkou_Period;
    g_settings.chikou_period                = Inp_Chikou_Period;
    
    // 3. تنظیمات سیگنال و تاییدیه
    g_settings.signal_mode                  = Inp_Signal_Mode;
    g_settings.confirmation_type            = Inp_Confirmation_Type;
    g_settings.grace_period_candles         = Inp_Grace_Period_Candles;
    
    // 3.1. تنظیمات تلاقی (با ورودی‌های جدید)
    g_settings.talaqi_calculation_mode      = Inp_Talaqi_Calculation_Mode;
    g_settings.talaqi_atr_multiplier        = Inp_Talaqi_ATR_Multiplier;
    g_settings.talaqi_distance_in_points    = Inp_Talaqi_Distance_in_Points;
    g_settings.talaqi_kumo_factor           = Inp_Talaqi_Kumo_Factor;
  
    // 4. تنظیمات حد ضرر (با ورودی‌های جدید)
    g_settings.stoploss_type                = Inp_StopLoss_Type;
    g_settings.sl_atr_multiplier            = Inp_SL_ATR_Multiplier;
    g_settings.flat_kijun_period            = Inp_Flat_Kijun_Period;
    g_settings.flat_kijun_min_length        = Inp_Flat_Kijun_Min_Length;
    g_settings.pivot_lookback               = Inp_Pivot_Lookback;
    g_settings.sl_lookback_period           = Inp_SL_Lookback_Period;
    g_settings.sl_buffer_multiplier         = Inp_SL_Buffer_Multiplier;
    
    // 5. تنظیمات مدیریت سرمایه
    g_settings.risk_percent_per_trade       = Inp_Risk_Percent_Per_Trade;
    g_settings.take_profit_ratio            = Inp_Take_Profit_Ratio;
    g_settings.max_trades_per_symbol        = Inp_Max_Trades_Per_Symbol;
    g_settings.max_total_trades             = Inp_Max_Total_Trades;
    
    // 6. تنظیمات گرافیکی
    g_settings.object_size_multiplier       = Inp_Object_Size_Multiplier;
    g_settings.bullish_color                = Inp_Bullish_Color;
    g_settings.bearish_color                = Inp_Bearish_Color;

    //--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---

    //--- تقسیم رشته نمادها و ایجاد شیء مدیریت برای هر نماد (بدون تغییر)
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
    TrailingStop.Init(Inp_Magic_Number);

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


//--- پاک کردن تمام اشیاء گرافیکی با پیشوند صحیح
ObjectsDeleteAll(0, "MEMENTO_UI_");
ChartRedraw();

}

//+------------------------------------------------------------------+
//| تابع تایمر (بررسی مداوم کندل‌ها و سیگنال‌ها)                      |
//+------------------------------------------------------------------+
void OnTimer()
{
 TrailingStop.Process();
    //--- اجرای منطق برای تمام نمادهای تحت مدیریت
    for (int i = 0; i < ArraySize(g_symbol_managers); i++)
    {
        if (g_symbol_managers[i] != NULL)
        {
            g_symbol_managers[i].ProcessNewBar();
        }
    }

    //--- آپدیت هوشمند داشبورد فقط در صورت نیاز
    if (g_dashboard_needs_update)
    {
        // پیدا کردن نمونه‌ای از منیجر که مسئول چارت اصلی است
        for (int i = 0; i < ArraySize(g_symbol_managers); i++)
        {
            if (g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol)
            {
                 g_symbol_managers[i].UpdateMyDashboard();
                 Print("داشبورد به دلیل رویداد معاملاتی آپدیت شد.");
                 break; // بعد از آپدیت از حلقه خارج شو
            }
        }
        g_dashboard_needs_update = false; // پرچم را برای آپدیت بعدی ریست کن
    }
}





//+------------------------------------------------------------------+
//| تابع رویدادهای معاملاتی                                           |
//+------------------------------------------------------------------+
// 
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // ما فقط به رویدادهایی که یک معامله به تاریخچه اضافه می‌کنند علاقه داریم
    if (trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0)
    {
        // اطلاعات معامله را از تاریخچه می‌گیریم
        ulong deal_ticket = trans.deal;
        if(HistoryDealSelect(deal_ticket))
        {
            // چک می‌کنیم معامله مربوط به همین اکسپرت باشه
            if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == (long)g_settings.magic_number)
            {
                 // اگر معامله از نوع خروج از پوزیشن بود (بسته شدن)
                 if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
                 {
                      string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);
                      
                      // مدیر استراتژی مربوط به این نماد را پیدا می‌کنیم
                      for(int i = 0; i < ArraySize(g_symbol_managers); i++)
                      {
                          if(g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == deal_symbol)
                          {
                              // مدیر گرافیک آن را می‌گیریم
                              CVisualManager *visual_manager = g_symbol_managers[i].GetVisualManager();
                              if(visual_manager != NULL)
                              {
                                  // ایندکس نماد را در داشبورد پیدا می‌کنیم
                                  int symbol_index = visual_manager.GetSymbolIndex(deal_symbol);
                                  if(symbol_index != -1)
                                  {
                                      // اطلاعات سود و زیان را می‌گیریم
                                      double p = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
                                      double c = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
                                      double s = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
                                      
                                      // و دفترچه حسابداری را آپدیت می‌کنیم
                                      visual_manager.UpdateDashboardCache(symbol_index, p, c, s);
                                  }
                              }
                              break; // مدیر پیدا شد، از حلقه خارج شو
                          }
                      }
                 }
                 
                 // در هر صورت (چه باز شدن و چه بسته شدن) داشبورد نیاز به آپدیت دارد
                 g_dashboard_needs_update = true;
            }
        }
    }
}



//+------------------------------------------------------------------+
//| تابع مدیریت رویدادهای چارت (برای کلیک روی دکمه)                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // اگر رویداد از نوع کلیک روی یک آبجکت بود
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        // مدیر استراتژی مربوط به چارت فعلی را پیدا کن
        for(int i = 0; i < ArraySize(g_symbol_managers); i++)
        {
            if(g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol)
            {
                // رویداد را برای پردازش به مدیر گرافیک ارسال کن
                g_symbol_managers[i].GetVisualManager().OnChartEvent(id, lparam, dparam, sparam);
                break; // کار تمام است، از حلقه خارج شو
            }
        }
    }
}
