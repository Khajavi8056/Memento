//+------------------------------------------------------------------+
//|                                                      Memento.mq5 |
//|                                      Copyright 2025, hipoalgoritm |
//|                                     Version 7.1 (Refactored Code) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "7.1" // بازنویسی و ساده‌سازی ساختار کد
#property description "اکسپرت معاملاتی پیشرفته ممنتو بر اساس استراتژی کراس سه گانه ایچیموکو"

#include <Trade\Trade.mqh>
#include <Object.mqh>

// --- کتابخانه‌های اصلی پروژه ---
#include "set.mqh"
#include "IchimokuLogic.mqh"
#include "VisualManager.mqh"
#include "TrailingStopManager.mqh"
#include "MarketRegimeDetector.mqh"
#include "licensed.mqh"

//--- متغیرهای سراسری ---
SSettings               g_settings;
string                  g_symbols_array[];
CStrategyManager* g_symbol_managers[];
CTrailingStopManager    g_trailing_stop;
CMarketRegimeEngine     g_regime_engine;
bool                    g_dashboard_needs_update = true;

//--- توابع کمکی برای مرتب‌سازی کد ---
void LoadSettings();
bool InitializeModules();

//+------------------------------------------------------------------+
//| تابع اصلی راه‌اندازی اکسپرت (OnInit)                              |
//+------------------------------------------------------------------+
int OnInit()
{
    // گام ۱: بارگذاری تمام تنظیمات ورودی در ساختار g_settings
    LoadSettings();

    // گام ۲: راه‌اندازی تمام ماژول‌های اصلی (مدیرهای نماد، فیلتر رژیم و...)
    if (!InitializeModules())
    {
        return INIT_FAILED;
    }

    // گام ۳: فعال‌سازی تایمر اصلی برای اجرای منطق در OnTimer
    EventSetTimer(1);
    
    Print("اکسپرت Memento با موفقیت راه‌اندازی شد.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع پایان کار اکسپرت (OnDeinit)                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    
    // پاکسازی مدیرهای استراتژی
    for (int i = 0; i < ArraySize(g_symbol_managers); i++)
    {
        if (CheckPointer(g_symbol_managers[i]) == POINTER_DYNAMIC)
        {
            delete g_symbol_managers[i];
        }
    }
    ArrayFree(g_symbol_managers);

    // پاک کردن تمام اشیاء گرافیکی با پیشوند صحیح
    ObjectsDeleteAll(0, "MEMENTO_UI_");
    ChartRedraw();
    Print("اکسپرت Memento با موفقیت غیرفعال شد. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| تابع تیک - فقط برای چک کردن لایسنس                                |
//+------------------------------------------------------------------+
void OnTick(void)
{
    if (CheckLicenseExpiry() == false)
    {
        ExpertRemove();
        return;
    }
}

//+------------------------------------------------------------------+
//| تابع تایمر - حلقه اصلی منطق اکسپرت                                |
//+------------------------------------------------------------------+
void OnTimer()
{
    // --- فاز ۱: تحلیل کلی بازار ---
    if (g_settings.enable_regime_filter)
    {
        g_regime_engine.ProcessNewBar();
    }

    // --- فاز ۲: مدیریت معاملات باز ---
    g_trailing_stop.Process();
    
    // --- فاز ۳: جستجوی سیگنال‌های جدید ---
    for (int i = 0; i < ArraySize(g_symbol_managers); i++)
    {
        if (g_symbol_managers[i] != NULL)
        {
            g_symbol_managers[i].ProcessNewBar();
        }
    }

    // --- فاز ۴: به‌روزرسانی داشبورد (فقط در صورت نیاز) ---
    if (g_dashboard_needs_update)
    {
        for (int i = 0; i < ArraySize(g_symbol_managers); i++)
        {
            if (g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol)
            {
                g_symbol_managers[i].UpdateMyDashboard();
                if (g_settings.enable_logging) Print("داشبورد به دلیل رویداد معاملاتی آپدیت شد.");
                break;
            }
        }
        g_dashboard_needs_update = false;
    }
}

//+------------------------------------------------------------------+
//| تابع رویدادهای معاملاتی (OnTradeTransaction)                     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    // فقط به رویداد اضافه شدن یک معامله به تاریخچه (deal) اهمیت می‌دهیم
    if (trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal <= 0)
    {
        return;
    }

    // اطمینان از اینکه معامله مربوط به همین اکسپرت است
    if (HistoryDealSelect(trans.deal) && HistoryDealGetInteger(trans.deal, DEAL_MAGIC) == (long)g_settings.magic_number)
    {
        // اگر معامله از نوع خروج از پوزیشن (بسته شدن) بود، کش داشبورد را آپدیت می‌کنیم
        if (HistoryDealGetInteger(trans.deal, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
            string deal_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
            for (int i = 0; i < ArraySize(g_symbol_managers); i++)
            {
                if (g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == deal_symbol)
                {
                    CVisualManager *visual_manager = g_symbol_managers[i].GetVisualManager();
                    if (visual_manager != NULL)
                    {
                        int symbol_index = visual_manager.GetSymbolIndex(deal_symbol);
                        if (symbol_index != -1)
                        {
                            visual_manager.UpdateDashboardCache(symbol_index, 
                                                                HistoryDealGetDouble(trans.deal, DEAL_PROFIT),
                                                                HistoryDealGetDouble(trans.deal, DEAL_COMMISSION),
                                                                HistoryDealGetDouble(trans.deal, DEAL_SWAP));
                        }
                    }
                    break;
                }
            }
        }
        // در هر صورت (چه باز شدن و چه بسته شدن) پرچم آپدیت داشبورد را فعال می‌کنیم
        g_dashboard_needs_update = true;
    }
}

//+------------------------------------------------------------------+
//| تابع رویدادهای چارت (OnChartEvent)                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        for (int i = 0; i < ArraySize(g_symbol_managers); i++)
        {
            if (g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol)
            {
                g_symbol_managers[i].GetVisualManager().OnChartEvent(id, lparam, dparam, sparam);
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| توابع کمکی (Helper Functions)                                   |
//+------------------------------------------------------------------+

// این تابع تمام تنظیمات ورودی را در ساختار g_settings بارگذاری می‌کند
void LoadSettings()
{
    // 1. عمومی
    g_settings.enable_dashboard = Inp_Enable_Dashboard;
    g_settings.symbols_list = Inp_Symbols_List;
    g_settings.magic_number = Inp_Magic_Number;
    g_settings.enable_logging = Inp_Enable_Logging;
    // 2. ایچیموکو
    g_settings.ichimoku_timeframe = Inp_Ichimoku_Timeframe;
    g_settings.tenkan_period = Inp_Tenkan_Period;
    g_settings.kijun_period = Inp_Kijun_Period;
    g_settings.senkou_period = Inp_Senkou_Period;
    g_settings.chikou_period = Inp_Chikou_Period;
    // 3. سیگنال و تاییدیه
    g_settings.signal_mode = Inp_Signal_Mode;
    g_settings.confirmation_type = Inp_Confirmation_Type;
    g_settings.grace_period_candles = Inp_Grace_Period_Candles;
    g_settings.talaqi_calculation_mode = Inp_Talaqi_Calculation_Mode;
    g_settings.talaqi_atr_multiplier = Inp_Talaqi_ATR_Multiplier;
    g_settings.talaqi_distance_in_points = Inp_Talaqi_Distance_in_Points;
    g_settings.talaqi_kumo_factor = Inp_Talaqi_Kumo_Factor;
    // 4. حد ضرر
    g_settings.stoploss_type = Inp_StopLoss_Type;
    g_settings.sl_atr_multiplier = Inp_SL_ATR_Multiplier;
    g_settings.sl_lookback_period = Inp_SL_Lookback_Period;
    g_settings.sl_buffer_multiplier = Inp_SL_Buffer_Multiplier;
    g_settings.flat_kijun_period = Inp_Flat_Kijun_Period;
    g_settings.flat_kijun_min_length = Inp_Flat_Kijun_Min_Length;
    g_settings.pivot_lookback = Inp_Pivot_Lookback;
    g_settings.enable_sl_vol_regime = Inp_Enable_SL_Vol_Regime;
    g_settings.sl_vol_regime_atr_period = Inp_SL_Vol_Regime_ATR_Period;
    g_settings.sl_vol_regime_ema_period = Inp_SL_Vol_Regime_EMA_Period;
    g_settings.sl_high_vol_multiplier = Inp_SL_High_Vol_Multiplier;
    g_settings.sl_low_vol_multiplier = Inp_SL_Low_Vol_Multiplier;
    // 5. مدیریت سرمایه
    g_settings.risk_percent_per_trade = Inp_Risk_Percent_Per_Trade;
    g_settings.take_profit_ratio = Inp_Take_Profit_Ratio;
    g_settings.max_trades_per_symbol = Inp_Max_Trades_Per_Symbol;
    g_settings.max_total_trades = Inp_Max_Total_Trades;
    // 6. گرافیکی
    g_settings.object_size_multiplier = Inp_Object_Size_Multiplier;
    g_settings.bullish_color = Inp_Bullish_Color;
    g_settings.bearish_color = Inp_Bearish_Color;
    // 7. فیلترهای ورود
    g_settings.enable_regime_filter = Inp_Enable_Regime_Filter;
    g_settings.enable_kumo_filter = Inp_Enable_Kumo_Filter;
}

// این تابع تمام ماژول‌ها را راه‌اندازی می‌کند و در صورت بروز خطا، false برمی‌گرداند
bool InitializeModules()
{
    // راه‌اندازی مدیرهای استراتژی برای هر نماد
    int symbols_count = StringSplit(g_settings.symbols_list, ',', g_symbols_array);
    if (symbols_count == 0)
    {
        Print("خطا: هیچ نمادی برای معامله مشخص نشده است.");
        return false;
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
            Print("مقداردهی اولیه مدیر استراتژی برای نماد ", sym, " با خطا مواجه شد.");
            // پاکسازی در صورت خطا
            for (int j = 0; j <= i; j++)
            {
                if (CheckPointer(g_symbol_managers[j]) == POINTER_DYNAMIC) delete g_symbol_managers[j];
            }
            ArrayFree(g_symbol_managers);
            return false;
        }
    }
    Print("مدیرهای استراتژی برای نمادهای زیر با موفقیت راه‌اندازی شدند: ", g_settings.symbols_list);

    // راه‌اندازی موتور رژیم بازار
    if (g_settings.enable_regime_filter)
    {
        if (!g_regime_engine.Initialize(_Symbol, g_settings.enable_logging))
        {
            Print("هشدار: راه‌اندازی موتور تشخیص رژیم بازار ناموفق بود! فیلتر غیرفعال می‌شود.");
            g_settings.enable_regime_filter = false;
        }
    }

    // راه‌اندازی مدیر تریلینگ استاپ
    g_trailing_stop.Init(g_settings.magic_number);

    return true;
}

//+------------------------------------------------------------------+
//| توابع بهینه‌سازی (Optimization Functions)                        |
//| این بخش برای حفظ کارکرد بدون تغییر باقی مانده است                 |
//+------------------------------------------------------------------+
input group "  تنظیمات بهینه‌سازی سفارشی";
input int InpMinTradesPerYear = 30;
input int InpMaxAcceptableDrawdown = 15;

double OnTester()
{
   // --- 1. گرفتن تمام آمارهای استاندارد مورد نیاز ---
   double total_trades         = TesterStatistics(STAT_TRADES);
   double net_profit           = TesterStatistics(STAT_PROFIT);
   double profit_factor        = TesterStatistics(STAT_PROFIT_FACTOR);
   double sharpe_ratio         = TesterStatistics(STAT_SHARPE_RATIO);
   double max_balance_drawdown_percent = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);

   // --- 2. محاسبه حداقل تعداد معاملات مورد نیاز (بدون تغییر) ---
   datetime startDate = 0, endDate = 0;
   if(HistoryDealsTotal() > 0)
     {
      startDate = (datetime)HistoryDealGetInteger(0, DEAL_TIME);
      endDate   = (datetime)HistoryDealGetInteger(HistoryDealsTotal() - 1, DEAL_TIME);
     }
   double duration_days = (endDate > startDate) ? double(endDate - startDate) / (24.0 * 3600.0) : 1.0;
   double required_min_trades = floor((duration_days / 365.0) * InpMinTradesPerYear);
   if(required_min_trades < 10) required_min_trades = 10;

   // --- 3. فیلترهای ورودی نهایی (بدون تغییر) ---
   if(total_trades < required_min_trades || profit_factor < 1.1 || sharpe_ratio <= 0 || net_profit <= 0)
     {
      return 0.0;
     }

   // --- 4. محاسبه معیارهای پیشرفته (بدون تغییر) ---
   double r_squared = 0, downside_consistency = 0;
   CalculateAdvancedMetrics(r_squared, downside_consistency);

   // --- 5. *** مهندسی امتیاز: محاسبه "ضریب مجازات" با منحنی کسینوسی *** ---
   double drawdown_penalty_factor = 0.0;
   if (max_balance_drawdown_percent < InpMaxAcceptableDrawdown && InpMaxAcceptableDrawdown > 0)
   {
      double angle = (max_balance_drawdown_percent / InpMaxAcceptableDrawdown) * (M_PI / 2.0);
      drawdown_penalty_factor = cos(angle);
   }
   
   // --- 6. محاسبه امتیاز نهایی جامع با فرمول جدید و پیوسته ---
   double final_score = 0.0;
   if(drawdown_penalty_factor > 0)
   {
      double trades_factor = log(total_trades + 1);
      double net_profit_factor = log(net_profit + 1);
      final_score = (profit_factor * sharpe_ratio * r_squared * downside_consistency * trades_factor * net_profit_factor)
                     * drawdown_penalty_factor;
   }

   // --- 7. چاپ نتیجه برای دیباگ ---
   PrintFormat("نتیجه: Trades=%d, PF=%.2f, Sharpe=%.2f, R²=%.3f, BalDD=%.2f%%, Penalty=%.2f -> امتیاز: %.4f",
               (int)total_trades, profit_factor, sharpe_ratio, r_squared, max_balance_drawdown_percent, drawdown_penalty_factor, final_score);

   return final_score;
}

struct EquityPoint { datetime time; double balance; };
struct MonthlyTrades { int year; int month; int count; };
void CalculateAdvancedMetrics(double &r_squared, double &downside_consistency)
{
   r_squared = 0;
   downside_consistency = 1.0;
   if(!HistorySelect(0, TimeCurrent())) return;
   uint total_deals = HistoryDealsTotal();
   if(total_deals < 5) return;
   EquityPoint equity_curve[];
   ArrayResize(equity_curve, (int)total_deals + 2);
   double final_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double net_profit = TesterStatistics(STAT_PROFIT);
   double initial_balance = final_balance - net_profit;
   double current_balance = initial_balance;
   equity_curve[0].time = (datetime)HistoryDealGetInteger(0, DEAL_TIME) - 1;
   equity_curve[0].balance = current_balance;
   int equity_points = 1;
   for(uint i = 0; i < total_deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
         current_balance += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP);
         equity_curve[equity_points].time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         equity_curve[equity_points].balance = current_balance;
         equity_points++;
        }
     }
   ArrayResize(equity_curve, equity_points);
   if(equity_points < 3) return;
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0;
   for(int i = 0; i < equity_points; i++)
     {
      double x = i + 1.0; double y = equity_curve[i].balance;
      sum_x += x; sum_y += y; sum_xy += x * y; sum_x2 += x*x; sum_y2 += y*y;
     }
   double n = equity_points;
   double den_part1 = (n*sum_x2) - (sum_x*sum_x);
   double den_part2 = (n*sum_y2) - (sum_y*sum_y);
   if(den_part1 > 0 && den_part2 > 0)
     {
      double r = ((n*sum_xy) - (sum_x*sum_y)) / sqrt(den_part1 * den_part2);
      r_squared = r*r;
     }
   MonthlyTrades monthly_counts[];
   int total_months = 0;
   for(uint i=0; i<total_deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
         datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         MqlDateTime dt;
         TimeToStruct(deal_time, dt);
         int month_idx = -1;
         for(int j=0; j<total_months; j++)
           {
            if(monthly_counts[j].year == dt.year && monthly_counts[j].month == dt.mon)
              {
               month_idx = j;
               break;
              }
           }
         if(month_idx == -1)
           {
            ArrayResize(monthly_counts, total_months + 1);
            monthly_counts[total_months].year = dt.year;
            monthly_counts[total_months].month = dt.mon;
            monthly_counts[total_months].count = 1;
            total_months++;
           }
         else
           {
            monthly_counts[month_idx].count++;
           }
        }
     }
   if(total_months <= 1)
     {
      downside_consistency = 1.0;
      return;
     }
   double target_trades_per_month = InpMinTradesPerYear / 12.0;
   if (target_trades_per_month < 1) target_trades_per_month = 1;
   double sum_of_squared_downside_dev = 0;
   for(int i = 0; i < total_months; i++)
     {
      if(monthly_counts[i].count < target_trades_per_month)
        {
         double deviation = target_trades_per_month - monthly_counts[i].count;
         sum_of_squared_downside_dev += deviation * deviation;
        }
     }
   double downside_variance = sum_of_squared_downside_dev / total_months;
   double downside_deviation = sqrt(downside_variance);
   downside_consistency = 1.0 / (1.0 + downside_deviation);
}
