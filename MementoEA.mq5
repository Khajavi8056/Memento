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

#include  "licensed.mqh"

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
int OnInit() {
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
   if (symbols_count == 0) {
      Print("خطا: هیچ نمادی برای معامله مشخص نشده است.");
      return INIT_FAILED;
   }

   ArrayResize(g_symbol_managers, symbols_count);
   for (int i = 0; i < symbols_count; i++) {
      string sym = g_symbols_array[i];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      g_symbol_managers[i] = new CStrategyManager(sym, g_settings);
      if (g_symbol_managers[i].Init() == false) {
         Print("مقداردهی اولیه نماد ", sym, " با خطا مواجه شد. عملیات متوقف می‌شود.");

         // === بخش حیاتی پاکسازی برای جلوگیری از نشت حافظه ===
         // تمام مدیرهایی که تا این لحظه (قبل از خطا) با موفقیت ساخته شده‌اند را حذف کن
         for (int j = 0; j <= i; j++) {
            if (g_symbol_managers[j] != NULL) {
               delete g_symbol_managers[j];
               g_symbol_managers[j] = NULL;
            }
         }
         ArrayFree(g_symbol_managers); // آرایه سراسری را هم آزاد کن
         // === پایان بخش پاکسازی ===

         return INIT_FAILED;
      }
   }
//=

   Print("اکسپرت Memento با موفقیت برای نمادهای زیر مقداردهی اولیه شد: ", g_settings.symbols_list);
   TrailingStop.Init(Inp_Magic_Number);

//--- راه‌اندازی تایمر برای اجرای مداوم
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| تابع پایان اکسپرت (پاکسازی)                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
//--- پاکسازی شیءها
   for (int i = 0; i < ArraySize(g_symbol_managers); i++) {
      if (g_symbol_managers[i] != NULL) {
         delete g_symbol_managers[i];
         g_symbol_managers[i] = NULL;
      }
   }
   ArrayFree(g_symbol_managers);


//--- پاک کردن تمام اشیاء گرافیکی با پیشوند صحیح
   ObjectsDeleteAll(0, "MEMENTO_UI_");
   ChartRedraw();

}
void OnTick(void)
      {
       if(CheckLicenseExpiry()==false)
{
ExpertRemove();
//return(INIT_FAILED);
}
      }
//+------------------------------------------------------------------+
//| تابع تایمر (بررسی مداوم کندل‌ها و سیگنال‌ها)                      |
//+------------------------------------------------------------------+
void OnTimer() {



   TrailingStop.Process();
//--- اجرای منطق برای تمام نمادهای تحت مدیریت
   for (int i = 0; i < ArraySize(g_symbol_managers); i++) {
      if (g_symbol_managers[i] != NULL) {
         g_symbol_managers[i].ProcessNewBar();
      }
   }

//--- آپدیت هوشمند داشبورد فقط در صورت نیاز
   if (g_dashboard_needs_update) {
      // پیدا کردن نمونه‌ای از منیجر که مسئول چارت اصلی است
      for (int i = 0; i < ArraySize(g_symbol_managers); i++) {
         if (g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol) {
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
                        const MqlTradeResult &result) {
// ما فقط به رویدادهایی که یک معامله به تاریخچه اضافه می‌کنند علاقه داریم
   if (trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0) {
      // اطلاعات معامله را از تاریخچه می‌گیریم
      ulong deal_ticket = trans.deal;
      if(HistoryDealSelect(deal_ticket)) {
         // چک می‌کنیم معامله مربوط به همین اکسپرت باشه
         if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == (long)g_settings.magic_number) {
            // اگر معامله از نوع خروج از پوزیشن بود (بسته شدن)
            if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
               string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL);

               // مدیر استراتژی مربوط به این نماد را پیدا می‌کنیم
               for(int i = 0; i < ArraySize(g_symbol_managers); i++) {
                  if(g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == deal_symbol) {
                     // مدیر گرافیک آن را می‌گیریم
                     CVisualManager *visual_manager = g_symbol_managers[i].GetVisualManager();
                     if(visual_manager != NULL) {
                        // ایندکس نماد را در داشبورد پیدا می‌کنیم
                        int symbol_index = visual_manager.GetSymbolIndex(deal_symbol);
                        if(symbol_index != -1) {
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
                  const string &sparam) {
// اگر رویداد از نوع کلیک روی یک آبجکت بود
   if(id == CHARTEVENT_OBJECT_CLICK) {
      // مدیر استراتژی مربوط به چارت فعلی را پیدا کن
      for(int i = 0; i < ArraySize(g_symbol_managers); i++) {
         if(g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol) {
            // رویداد را برای پردازش به مدیر گرافیک ارسال کن
            g_symbol_managers[i].GetVisualManager().OnChartEvent(id, lparam, dparam, sparam);
            break; // کار تمام است، از حلقه خارج شو
         }
      }
   }
}
//+------------------------------------------------------------------+



//--- گروه: تنظیمات بهینه‌سازی سفارشی ---
input group "  تنظیمات بهینه‌سازی سفارشی";
input int InpMinTradesPerYear = 30; // حداقل تعداد معاملات قابل قبول در یک سال
input int InpMaxAcceptableDrawdown = 15;


//+------------------------------------------------------------------+
//| تابع اصلی رویداد تستر که امتیاز نهایی را محاسبه می‌کند.          |
//+------------------------------------------------------------------+
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
      // دراودان رو به یک زاویه بین 0 تا 90 درجه (π/2 رادیان) تبدیل می‌کنیم
      double angle = (max_balance_drawdown_percent / InpMaxAcceptableDrawdown) * (M_PI / 2.0);
      
      // ضریب مجازات، کسینوس اون زاویه است. هرچی زاویه (دراودان) بیشتر، کسینوس (امتیاز) کمتر
      drawdown_penalty_factor = cos(angle);
   }
   // اگر دراودان بیشتر از حد مجاز باشه، ضریب صفر می‌مونه و کل پاس رد میشه

   // --- 6. محاسبه امتیاز نهایی جامع با فرمول جدید و پیوسته ---
   double final_score = 0.0;
   if(drawdown_penalty_factor > 0)
   {
      // استفاده از log برای نرمال‌سازی و جلوگیری از تاثیر بیش از حد اعداد بزرگ
      double trades_factor = log(total_trades + 1); // +1 برای جلوگیری از log(0)
      double net_profit_factor = log(net_profit + 1);

      final_score = (profit_factor * sharpe_ratio * r_squared * downside_consistency * trades_factor * net_profit_factor) 
                     * drawdown_penalty_factor; // ضرب در ضریب مجازات جدید و هوشمند
   }

   // --- 7. چاپ نتیجه برای دیباگ ---
   PrintFormat("نتیجه: Trades=%d, PF=%.2f, Sharpe=%.2f, R²=%.3f, BalDD=%.2f%%, Penalty=%.2f -> امتیاز: %.4f",
               (int)total_trades, profit_factor, sharpe_ratio, r_squared, max_balance_drawdown_percent, drawdown_penalty_factor, final_score);

   return final_score;
}

// تابع CalculateAdvancedMetrics بدون هیچ تغییری باقی می‌ماند
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
   equity_curve[0].time      = (datetime)HistoryDealGetInteger(0, DEAL_TIME) - 1;
   equity_curve[0].balance   = current_balance;

   int equity_points = 1;
   for(uint i = 0; i < total_deals; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
        {
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
           {
            current_balance += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP);
            equity_curve[equity_points].time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            equity_curve[equity_points].balance = current_balance;
            equity_points++;
           }
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
         for(int j=0; j<total_months; j++) {
            if(monthly_counts[j].year == dt.year && monthly_counts[j].month == dt.mon) {
               month_idx = j;
               break;
            }
         }
         
         if(month_idx == -1) {
            ArrayResize(monthly_counts, total_months + 1);
            monthly_counts[total_months].year = dt.year;
            monthly_counts[total_months].month = dt.mon;
            monthly_counts[total_months].count = 1;
            total_months++;
         } else {
            monthly_counts[month_idx].count++;
         }
        }
     }

   if(total_months <= 1) {
      downside_consistency = 1.0;
      return;
   }

   double target_trades_per_month = InpMinTradesPerYear / 12.0;
   if (target_trades_per_month < 1) target_trades_per_month = 1;


   double sum_of_squared_downside_dev = 0;
   for(int i = 0; i < total_months; i++) {
      if(monthly_counts[i].count < target_trades_per_month) {
         double deviation = target_trades_per_month - monthly_counts[i].count;
         sum_of_squared_downside_dev += deviation * deviation;
      }
   }

   double downside_variance = sum_of_squared_downside_dev / total_months;
   double downside_deviation = sqrt(downside_variance);

   downside_consistency = 1.0 / (1.0 + downside_deviation);
}



//+------------------------------------------------------------------+
//|    بخش بهینه‌سازی سفارشی (Custom Optimization) نسخه 10.0 - نهایی   |
//|      با "منحنی مجازات دراوداون پیوسته" (Continuous Penalty Curve)     |
//+------------------------------------------------------------------+

//--- ساختارهای کمکی (بدون تغییر)
struct EquityPoint
{
   datetime time;
   double   balance;
};
struct MonthlyTrades
{
   int      year;
   int      month;
   int      count;
};
