//+------------------------------------------------------------------+
//|                                                      Memento.mq5 |
//|                                  Copyright 2025,hipoalgoritm |
//|                                                  Final & Bulletproof |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025,hipoalgoritm" // حقوق کپی‌رایت اکسپرت
#property link      "https://www.mql5.com" // لینک مرتبط
#property version   "1.7" // نسخه نهایی و کاملا اصلاح شده
#property description "اکسپرت معاملاتی پیشرفته ممنتو بر اساس استراتژی کراس سه گانه ایچیموکو" // توضیح اکسپرت


#include <Trade\Trade.mqh> // کتابخانه ترید
#include <Object.mqh> // کتابخانه اشیاء
#include "IchimokuLogic.mqh" // منطق ایچیموکو
#include "VisualManager.mqh" // مدیریت گرافیک
#include "TrailingStopManager.mqh" // مدیریت تریلینگ استاپ

#include  "licensed.mqh" // لایسنس

//--- متغیرهای سراسری
SSettings            g_settings; // ساختار تنظیمات
string               g_symbols_array[]; // آرایه نمادها
CStrategyManager* g_symbol_managers[]; // آرایه مدیران استراتژی
bool              g_dashboard_needs_update = true; // پرچم برای آپدیت داشبورد
CTrailingStopManager TrailingStop; // مدیر تریلینگ استاپ



int OnInit() {
    //--- ✅✅✅ بخش مقداردهی اولیه تنظیمات (نسخه کاملاً اصلاح شده و هماهنگ) ✅✅✅ ---

    // 1. تنظیمات عمومی
    g_settings.enable_dashboard           = Inp_Enable_Dashboard; // کپی فعال کردن داشبورد
    g_settings.symbols_list                 = Inp_Symbols_List; // کپی لیست نمادها
    g_settings.magic_number                 = Inp_Magic_Number; // کپی مجیک نامبر
    g_settings.enable_logging               = Inp_Enable_Logging; // کپی فعال کردن لاگ

    // 2. تنظیمات ایچیموکو
    g_settings.ichimoku_timeframe           = Inp_Ichimoku_Timeframe; // ✅ اضافه شد
    g_settings.tenkan_period                = Inp_Tenkan_Period; // کپی دوره تنکان
    g_settings.kijun_period                 = Inp_Kijun_Period; // کپی دوره کیجون
    g_settings.senkou_period                = Inp_Senkou_Period; // کپی دوره سنکو
    g_settings.chikou_period                = Inp_Chikou_Period; // کپی دوره چیکو

    // 3. تنظیمات سیگنال و تاییدیه
    g_settings.primary_strategy             = Inp_Primary_Strategy; // <<<< اضافه شود
    g_settings.signal_mode                  = Inp_Signal_Mode; // کپی حالت سیگنال
    g_settings.entry_confirmation_mode      = Inp_Entry_Confirmation_Mode; // ✅ اضافه شد
    g_settings.grace_period_mode            = Inp_Grace_Period_Mode; // ✅ اضافه شد
    g_settings.grace_period_candles         = Inp_Grace_Period_Candles; // کپی تعداد کندل مهلت
    g_settings.confirmation_type            = Inp_Confirmation_Type; // کپی نوع تایید
    g_settings.ltf_timeframe                = Inp_LTF_Timeframe; // ✅ اضافه شد
    g_settings.talaqi_calculation_mode      = Inp_Talaqi_Calculation_Mode; // کپی حالت تلاقی
    g_settings.talaqi_atr_multiplier        = Inp_Talaqi_ATR_Multiplier; // کپی ضریب ATR تلاقی
    g_settings.talaqi_distance_in_points    = Inp_Talaqi_Distance_in_Points; // کپی فاصله دستی تلاقی
    g_settings.talaqi_kumo_factor           = Inp_Talaqi_Kumo_Factor; // کپی ضریب کومو تلاقی

    // 4. تنظیمات حد ضرر
    g_settings.sl_timeframe                 = Inp_SL_Timeframe; // <<<< این خط اضافه شود
    g_settings.stoploss_type                = Inp_StopLoss_Type; // کپی نوع SL
    g_settings.sl_atr_multiplier            = Inp_SL_ATR_Multiplier; // کپی ضریب ATR SL
    g_settings.flat_kijun_period            = Inp_Flat_Kijun_Period; // کپی دوره فلت کیجون
    g_settings.flat_kijun_min_length        = Inp_Flat_Kijun_Min_Length; // کپی حداقل طول فلت
    g_settings.pivot_lookback               = Inp_Pivot_Lookback; // کپی دوره پیوت
    g_settings.sl_lookback_period           = Inp_SL_Lookback_Period; // کپی دوره نگاه به عقب
    g_settings.sl_buffer_multiplier         = Inp_SL_Buffer_Multiplier; // کپی ضریب بافر
    
    // 4.1. <<< بخش اضافه شده برای SL پویا >>>
    g_settings.enable_sl_vol_regime         = Inp_Enable_SL_Vol_Regime; // کپی فعال کردن SL پویا
    g_settings.sl_vol_regime_atr_period     = Inp_SL_Vol_Regime_ATR_Period; // کپی دوره ATR پویا
    g_settings.sl_vol_regime_ema_period     = Inp_SL_Vol_Regime_EMA_Period; // کپی دوره EMA پویا
    g_settings.sl_high_vol_multiplier       = Inp_SL_High_Vol_Multiplier; // کپی ضریب بالا نوسان
    g_settings.sl_low_vol_multiplier        = Inp_SL_Low_Vol_Multiplier; // کپی ضریب پایین نوسان

    // 5. تنظیمات مدیریت سرمایه
    g_settings.risk_percent_per_trade       = Inp_Risk_Percent_Per_Trade; // کپی درصد ریسک
    g_settings.take_profit_ratio            = Inp_Take_Profit_Ratio; // کپی نسبت TP
    g_settings.max_trades_per_symbol        = Inp_Max_Trades_Per_Symbol; // کپی حداکثر معاملات نماد
    g_settings.max_total_trades             = Inp_Max_Total_Trades; // کپی حداکثر معاملات کل

    // 6. تنظیمات گرافیکی
    g_settings.object_size_multiplier       = Inp_Object_Size_Multiplier; // کپی ضریب اندازه اشیاء
    g_settings.bullish_color                = Inp_Bullish_Color; // کپی رنگ خرید
    g_settings.bearish_color                = Inp_Bearish_Color; // کپی رنگ فروش
    
    // 7. <<< بخش اضافه شده برای فیلترها >>>
    g_settings.filter_context               = Inp_Filter_Context; // <<<< این خط اضافه شود
    g_settings.enable_kumo_filter           = Inp_Enable_Kumo_Filter; // کپی فعال کردن کومو
    g_settings.enable_atr_filter            = Inp_Enable_ATR_Filter; // کپی فعال کردن ATR
    g_settings.atr_filter_period            = Inp_ATR_Filter_Period; // کپی دوره ATR فیلتر
    g_settings.atr_filter_min_value_pips    = Inp_ATR_Filter_Min_Value_pips; // کپی حداقل ATR
    g_settings.enable_adx_filter            = Inp_Enable_ADX_Filter; // کپی فعال کردن ADX
    g_settings.adx_period                   = Inp_ADX_Period; // کپی دوره ADX
    g_settings.adx_threshold                = Inp_ADX_Threshold; // کپی آستانه ADX

    g_settings.enable_kijun_slope_filter    = Inp_Enable_KijunSlope_Filter;    // <<<< اضافه شود
    g_settings.enable_kumo_expansion_filter = Inp_Enable_KumoExpansion_Filter; // <<<< اضافه شود
    g_settings.enable_chikou_space_filter   = Inp_Enable_ChikouSpace_Filter;   // <<<< اضافه شود

    // 8. <<< بخش اضافه شده برای خروج زودرس >>>
    g_settings.enable_early_exit            = Inp_Enable_Early_Exit; // کپی فعال کردن خروج زودرس
    g_settings.early_exit_rsi_period        = Inp_Early_Exit_RSI_Period; // کپی دوره RSI خروج
    g_settings.early_exit_rsi_overbought    = Inp_Early_Exit_RSI_Overbought; // کپی سطح اشباع خرید
    g_settings.early_exit_rsi_oversold      = Inp_Early_Exit_RSI_Oversold; // کپی سطح اشباع فروش


    //--- بقیه تابع OnInit بدون تغییر ...
    int symbols_count = StringSplit(g_settings.symbols_list, ',', g_symbols_array); // جداسازی نمادها
    if (symbols_count == 0) { // چک خطای نمادها
        Print("خطا: هیچ نمادی برای معامله مشخص نشده است.");
        return INIT_FAILED;
    }

    ArrayResize(g_symbol_managers, symbols_count); // تغییر اندازه آرایه مدیران
    for (int i = 0; i < symbols_count; i++) { // حلقه برای هر نماد
        string sym = g_symbols_array[i];
        StringTrimLeft(sym);
        StringTrimRight(sym);
        g_symbol_managers[i] = new CStrategyManager(sym, g_settings); // ایجاد مدیر استراتژی
        if (!g_symbol_managers[i].Init()) { // چک اولیه
            Print("مقداردهی اولیه نماد ", sym, " با خطا مواجه شد. عملیات متوقف می‌شود.");
            for (int j = 0; j <= i; j++) { // پاکسازی
                if (g_symbol_managers[j] != NULL) {
                    delete g_symbol_managers[j];
                    g_symbol_managers[j] = NULL;
                }
            }
            ArrayFree(g_symbol_managers); // آزاد کردن آرایه
            return INIT_FAILED;
        }
    }

    Print("اکسپرت Memento با موفقیت برای نمادهای زیر مقداردهی اولیه شد: ", g_settings.symbols_list); // لاگ موفقیت
    TrailingStop.Init(Inp_Magic_Number); // اولیه تریلینگ استاپ

    EventSetTimer(1); // تنظیم تایمر
    return(INIT_SUCCEEDED); // بازگشت موفقیت
}




//+------------------------------------------------------------------+
//| تابع پایان اکسپرت (پاکسازی)                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer(); // خاموش کردن تایمر
//--- پاکسازی شیءها
   for (int i = 0; i < ArraySize(g_symbol_managers); i++) { // حلقه پاکسازی مدیران
      if (g_symbol_managers[i] != NULL) {
         delete g_symbol_managers[i];
         g_symbol_managers[i] = NULL;
      }
   }
   ArrayFree(g_symbol_managers); // آزاد کردن آرایه


//--- پاک کردن تمام اشیاء گرافیکی با پیشوند صحیح
   ObjectsDeleteAll(0, "MEMENTO_UI_"); // حذف اشیاء
   ChartRedraw(); // بازسازی چارت

}
void OnTick(void)
      {
       if(CheckLicenseExpiry()==false) // چک لایسنس
{
ExpertRemove();
//return(INIT_FAILED);
}
      }
//+------------------------------------------------------------------+
//| تابع تایمر (مرکز فرماندهی جدید)                                  |
//+------------------------------------------------------------------+
void OnTimer() 
{
   // 1. اجرای تریلینگ استاپ (مثل قبل)
   TrailingStop.Process(); // پردازش تریلینگ استاپ

   // 2. اجرای منطق اصلی برای هر نماد از طریق یک تابع واحد
   for (int i = 0; i < ArraySize(g_symbol_managers); i++)  // حلقه برای هر مدیر
   {
      if (g_symbol_managers[i] != NULL) 
      {
         g_symbol_managers[i].OnTimerTick(); // <<<< نام تابع از ProcessNewBar به OnTimerTick تغییر می‌کند
      }
   }

   // 3. آپدیت هوشمند داشبورد (مثل قبل)
   if (g_dashboard_needs_update)  // چک نیاز به آپدیت
   {
      // پیدا کردن نمونه‌ای از منیجر که مسئول چارت اصلی است
      for (int i = 0; i < ArraySize(g_symbol_managers); i++)  // حلقه جستجو
      {
         if (g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol)  // چک نماد
         {
            g_symbol_managers[i].UpdateMyDashboard(); // آپدیت داشبورد
            Print("داشبورد به دلیل رویداد معاملاتی آپدیت شد."); // لاگ آپدیت
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
   if (trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0) { // چک نوع تراکنش
      // اطلاعات معامله را از تاریخچه می‌گیریم
      ulong deal_ticket = trans.deal; // تیکت معامله
      if(HistoryDealSelect(deal_ticket)) { // انتخاب معامله
         // چک می‌کنیم معامله مربوط به همین اکسپرت باشه
         if(HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) == (long)g_settings.magic_number) { // چک مجیک
            // اگر معامله از نوع خروج از پوزیشن بود (بسته شدن)
            if(HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) { // چک ورود/خروج
               string deal_symbol = HistoryDealGetString(deal_ticket, DEAL_SYMBOL); // نماد معامله

               // مدیر استراتژی مربوط به این نماد را پیدا می‌کنیم
               for(int i = 0; i < ArraySize(g_symbol_managers); i++) { // حلقه مدیران
                  if(g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == deal_symbol) { // چک نماد
                     // مدیر گرافیک آن را می‌گیریم
                     CVisualManager *visual_manager = g_symbol_managers[i].GetVisualManager(); // گرفتن مدیر گرافیک
                     if(visual_manager != NULL) { // چک وجود
                        // ایندکس نماد را در داشبورد پیدا می‌کنیم
                        int symbol_index = visual_manager.GetSymbolIndex(deal_symbol); // گرفتن ایندکس
                        if(symbol_index != -1) { // چک ایندکس
                           // اطلاعات سود و زیان را می‌گیریم
                           double p = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT); // سود
                           double c = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION); // کمیسیون
                           double s = HistoryDealGetDouble(deal_ticket, DEAL_SWAP); // سواپ

                           // و دفترچه حسابداری را آپدیت می‌کنیم
                           visual_manager.UpdateDashboardCache(symbol_index, p, c, s); // آپدیت کش
                        }
                     }
                     break; // مدیر پیدا شد، از حلقه خارج شو
                  }
               }
            }

            // در هر صورت (چه باز شدن و چه بسته شدن) داشبورد نیاز به آپدیت دارد
            g_dashboard_needs_update = true; // تنظیم پرچم آپدیت
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
   if(id == CHARTEVENT_OBJECT_CLICK) { // چک نوع رویداد
      // مدیر استراتژی مربوط به چارت فعلی را پیدا کن
      for(int i = 0; i < ArraySize(g_symbol_managers); i++) { // حلقه مدیران
         if(g_symbol_managers[i] != NULL && g_symbol_managers[i].GetSymbol() == _Symbol) { // چک نماد
            // رویداد را برای پردازش به مدیر گرافیک ارسال کن
            g_symbol_managers[i].GetVisualManager().OnChartEvent(id, lparam, dparam, sparam); // ارسال رویداد
            break; // کار تمام است، از حلقه خارج شو
         }
      }
   }
}
//+------------------------------------------------------------------+



//--- گروه: تنظیمات بهینه‌سازی سفارشی ---
input group "  تنظیمات بهینه‌سازی سفارشی"; // گروه بهینه‌سازی
input int InpMinTradesPerYear = 30; // حداقل تعداد معاملات قابل قبول در یک سال
input int InpMaxAcceptableDrawdown = 15; // حداکثر دراوداون قابل قبول


//+------------------------------------------------------------------+
//| تابع اصلی رویداد تستر که امتیاز نهایی را محاسبه می‌کند.          |
//+------------------------------------------------------------------+
double OnTester()
{
   // --- 1. گرفتن تمام آمارهای استاندارد مورد نیاز ---
   double total_trades         = TesterStatistics(STAT_TRADES); // تعداد معاملات
   double net_profit           = TesterStatistics(STAT_PROFIT); // سود خالص
   double profit_factor        = TesterStatistics(STAT_PROFIT_FACTOR); // فاکتور سود
   double sharpe_ratio         = TesterStatistics(STAT_SHARPE_RATIO); // شارپ ریتو
   double max_balance_drawdown_percent = TesterStatistics(STAT_BALANCE_DDREL_PERCENT); // حداکثر دراوداون

   // --- 2. محاسبه حداقل تعداد معاملات مورد نیاز (بدون تغییر) ---
   datetime startDate = 0, endDate = 0; // تاریخ شروع و پایان
   if(HistoryDealsTotal() > 0) // چک معاملات
     {
      startDate = (datetime)HistoryDealGetInteger(0, DEAL_TIME); // تاریخ شروع
      endDate   = (datetime)HistoryDealGetInteger(HistoryDealsTotal() - 1, DEAL_TIME); // تاریخ پایان
     }
   double duration_days = (endDate > startDate) ? double(endDate - startDate) / (24.0 * 3600.0) : 1.0; // محاسبه روزها
   double required_min_trades = floor((duration_days / 365.0) * InpMinTradesPerYear); // حداقل معاملات
   if(required_min_trades < 10) required_min_trades = 10; // حداقل 10

   // --- 3. فیلترهای ورودی نهایی (بدون تغییر) ---
   if(total_trades < required_min_trades || profit_factor < 1.1 || sharpe_ratio <= 0 || net_profit <= 0) // چک فیلترها
     {
      return 0.0; // بازگشت صفر
     }

   // --- 4. محاسبه معیارهای پیشرفته (بدون تغییر) ---
   double r_squared = 0, downside_consistency = 0; // متغیرهای پیشرفته
   CalculateAdvancedMetrics(r_squared, downside_consistency); // محاسبه پیشرفته

   // --- 5. *** مهندسی امتیاز: محاسبه "ضریب مجازات" با منحنی کسینوسی *** ---
   double drawdown_penalty_factor = 0.0; // ضریب مجازات
   if (max_balance_drawdown_percent < InpMaxAcceptableDrawdown && InpMaxAcceptableDrawdown > 0)  // چک دراوداون
   {
      // دراودان رو به یک زاویه بین 0 تا 90 درجه (π/2 رادیان) تبدیل می‌کنیم
      double angle = (max_balance_drawdown_percent / InpMaxAcceptableDrawdown) * (M_PI / 2.0); // محاسبه زاویه
      
      // ضریب مجازات، کسینوس اون زاویه است. هرچی زاویه (دراودان) بیشتر، کسینوس (امتیاز) کمتر
      drawdown_penalty_factor = cos(angle); // محاسبه کسینوس
   }
   // اگر دراودان بیشتر از حد مجاز باشه، ضریب صفر می‌مونه و کل پاس رد میشه

   // --- 6. محاسبه امتیاز نهایی جامع با فرمول جدید و پیوسته ---
   double final_score = 0.0; // امتیاز نهایی
   if(drawdown_penalty_factor > 0) // چک مجازات
   {
      // استفاده از log برای نرمال‌سازی و جلوگیری از تاثیر بیش از حد اعداد بزرگ
      double trades_factor = log(total_trades + 1); // +1 برای جلوگیری از log(0)
      double net_profit_factor = log(net_profit + 1); // فاکتور سود خالص

      final_score = (profit_factor * sharpe_ratio * r_squared * downside_consistency * trades_factor * net_profit_factor) 
                     * drawdown_penalty_factor; // ضرب در ضریب مجازات جدید و هوشمند
   }

   // --- 7. چاپ نتیجه برای دیباگ ---
   PrintFormat("نتیجه: Trades=%d, PF=%.2f, Sharpe=%.2f, R²=%.3f, BalDD=%.2f%%, Penalty=%.2f -> امتیاز: %.4f",
               (int)total_trades, profit_factor, sharpe_ratio, r_squared, max_balance_drawdown_percent, drawdown_penalty_factor, final_score); // لاگ نتیجه

   return final_score; // بازگشت امتیاز
}

// تابع CalculateAdvancedMetrics بدون هیچ تغییری باقی می‌ماند
void CalculateAdvancedMetrics(double &r_squared, double &downside_consistency)
{
   r_squared = 0; // اولیه r_squared
   downside_consistency = 1.0; // اولیه ثبات

   if(!HistorySelect(0, TimeCurrent())) return; // انتخاب تاریخچه
   uint total_deals = HistoryDealsTotal(); // تعداد معاملات
   if(total_deals < 5) return; // چک حداقل معاملات

   EquityPoint equity_curve[]; // آرایه منحنی اکویتی
   ArrayResize(equity_curve, (int)total_deals + 2); // تغییر اندازه

   double final_balance = AccountInfoDouble(ACCOUNT_BALANCE); // بالانس نهایی
   double net_profit = TesterStatistics(STAT_PROFIT); // سود خالص
   double initial_balance = final_balance - net_profit; // بالانس اولیه
   
   double current_balance = initial_balance; // بالانس فعلی
   equity_curve[0].time      = (datetime)HistoryDealGetInteger(0, DEAL_TIME) - 1; // زمان اولیه
   equity_curve[0].balance   = current_balance; // بالانس اولیه

   int equity_points = 1; // شمارنده نقاط
   for(uint i = 0; i < total_deals; i++) // حلقه معاملات
     {
      ulong ticket = HistoryDealGetTicket(i); // تیکت معامله
      if(ticket > 0) // چک تیکت
        {
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) // چک خروج
           {
            current_balance += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_COMMISSION) + HistoryDealGetDouble(ticket, DEAL_SWAP); // آپدیت بالانس
            equity_curve[equity_points].time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME); // زمان نقطه
            equity_curve[equity_points].balance = current_balance; // بالانس نقطه
            equity_points++; // افزایش شمارنده
           }
        }
     }
   ArrayResize(equity_curve, equity_points); // تغییر اندازه نهایی
   if(equity_points < 3) return; // چک حداقل نقاط
   
   double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0, sum_y2 = 0; // متغیرهای محاسباتی
   for(int i = 0; i < equity_points; i++) // حلقه نقاط
     {
      double x = i + 1.0; double y = equity_curve[i].balance; // x و y
      sum_x += x; sum_y += y; sum_xy += x * y; sum_x2 += x*x; sum_y2 += y*y; // جمع‌ها
     }
   double n = equity_points; // تعداد نقاط
   double den_part1 = (n*sum_x2) - (sum_x*sum_x); // محاسبه دنومیناتور 1
   double den_part2 = (n*sum_y2) - (sum_y*sum_y); // محاسبه دنومیناتور 2
   if(den_part1 > 0 && den_part2 > 0) // چک مثبت بودن
     {
      double r = ((n*sum_xy) - (sum_x*sum_y)) / sqrt(den_part1 * den_part2); // محاسبه r
      r_squared = r*r; // محاسبه r_squared
     }

   MonthlyTrades monthly_counts[]; // آرایه ماهانه
   int total_months = 0; // شمارنده ماه‌ها
   
   for(uint i=0; i<total_deals; i++) // حلقه معاملات
     {
      ulong ticket = HistoryDealGetTicket(i); // تیکت
      if(ticket > 0 && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) // چک خروج
        {
         datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME); // زمان معامله
         MqlDateTime dt; // ساختار زمان
         TimeToStruct(deal_time, dt); // تبدیل زمان
         
         int month_idx = -1; // ایندکس ماه
         for(int j=0; j<total_months; j++) { // جستجو ماه
            if(monthly_counts[j].year == dt.year && monthly_counts[j].month == dt.mon) { // چک ماه و سال
               month_idx = j;
               break;
            }
         }
         
         if(month_idx == -1) { // اگر جدید
            ArrayResize(monthly_counts, total_months + 1); // تغییر اندازه
            monthly_counts[total_months].year = dt.year; // سال
            monthly_counts[total_months].month = dt.mon; // ماه
            monthly_counts[total_months].count = 1; // شمارنده
            total_months++; // افزایش
         } else { // افزایش شمارنده
            monthly_counts[month_idx].count++;
         }
        }
     }

   if(total_months <= 1) { // چک حداقل ماه‌ها
      downside_consistency = 1.0; // مقدار پیش‌فرض
      return;
   }

   double target_trades_per_month = InpMinTradesPerYear / 12.0; // هدف ماهانه
   if (target_trades_per_month < 1) target_trades_per_month = 1; // حداقل 1


   double sum_of_squared_downside_dev = 0; // جمع مربعات انحراف
   for(int i = 0; i < total_months; i++) { // حلقه ماه‌ها
      if(monthly_counts[i].count < target_trades_per_month) { // چک کمتر از هدف
         double deviation = target_trades_per_month - monthly_counts[i].count; // انحراف
         sum_of_squared_downside_dev += deviation * deviation; // جمع مربعات
      }
   }

   double downside_variance = sum_of_squared_downside_dev / total_months; // واریانس
   double downside_deviation = sqrt(downside_variance); // انحراف استاندارد

   downside_consistency = 1.0 / (1.0 + downside_deviation); // محاسبه ثبات
}



//+------------------------------------------------------------------+
//|    بخش بهینه‌سازی سفارشی (Custom Optimization) نسخه 10.0 - نهایی   |
//|      با "منحنی مجازات دراوداون پیوسته" (Continuous Penalty Curve)     |
//+------------------------------------------------------------------+

//--- ساختارهای کمکی (بدون تغییر)
struct EquityPoint
{
   datetime time; // زمان نقطه
   double   balance; // بالانس نقطه
};
struct MonthlyTrades
{
   int      year; // سال
   int      month; // ماه
   int      count; // شمارنده
};
