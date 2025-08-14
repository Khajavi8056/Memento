//+------------------------------------------------------------------+
//|                                     IchimokuLogic.mqh            |
//|                          © 2025, hipoalgoritm                   |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "2.2" 
#include "set.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Object.mqh>
#include "VisualManager.mqh"
#include <MovingAverages.mqh>
// این خط رو در بالای فایل اضافه کن
#include "MarketRegimeDetector.mqh"

//+++ NEW: تعریف موتور رژیم بازار +++
//extern CMarketRegimeEngine g_regime_engine;

//--- تعریف ساختار سیگنال
struct SPotentialSignal
{
    datetime        time;
    bool            is_buy;
    int             grace_candle_count;
    
    // سازنده کپی
    SPotentialSignal(const SPotentialSignal &other)
    {
        time = other.time;
        is_buy = other.is_buy;
        grace_candle_count = other.grace_candle_count;
    }
    // سازنده پیش‌فرض
    SPotentialSignal()
    {
       // خالی می‌مونه
    }
};

//+------------------------------------------------------------------+
//| کلاس مدیریت استراتژی برای یک نماد خاص                           |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
    string              m_symbol;
    SSettings           m_settings;
    CTrade              m_trade;
   
    datetime            m_last_bar_time;
    
    // --- هندل های اندیکاتور ---
    int                 m_ichimoku_handle;
    int                 m_atr_handle;      

    // --- بافرهای داده ---
    double              m_tenkan_buffer[];
    double              m_kijun_buffer[];
    double              m_high_buffer[];
    double              m_low_buffer[];
    
    // --- مدیریت سیگنال ---
    SPotentialSignal    m_signal;
    bool                m_is_waiting;
    SPotentialSignal    m_potential_signals[];
    CVisualManager*     m_visual_manager;
    // این خط جدید رو اضافه کن
    CMarketRegimeEngine* m_regime_engine;

    //--- توابع کمکی ---
    void Log(string message);
    
    // --- منطق اصلی سیگنال ---
    void AddOrUpdatePotentialSignal(bool is_buy);
    bool CheckTripleCross(bool& is_buy);
    bool CheckFinalConfirmation(bool is_buy);
    
    // --- فیلترهای ورود ---
    bool AreAllFiltersPassed(bool is_buy);
    bool CheckKumoFilter();

    //--- محاسبه استاپ لاس ---
    double CalculateStopLoss(bool is_buy, double entry_price);
    double CalculateAtrStopLoss(bool is_buy, double entry_price);
    double GetTalaqiTolerance(int reference_shift);
    double CalculateAtrTolerance(int reference_shift);
    double CalculateDynamicTolerance(int reference_shift);
    double FindFlatKijun();
    double FindPivotKijun(bool is_buy);
    double FindPivotTenkan(bool is_buy);
    double FindBackupStopLoss(bool is_buy, double buffer);
    
    //--- مدیریت معاملات ---
    int CountSymbolTrades();
    int CountTotalTrades();
    void OpenTrade(bool is_buy);

public:
    CStrategyManager(string symbol, SSettings &settings);
    ~CStrategyManager();
    bool Init();
    void ProcessNewBar();
    string GetSymbol() const { return m_symbol; }
    void UpdateMyDashboard();
    CVisualManager* GetVisualManager() { return m_visual_manager; }
};

//+------------------------------------------------------------------+
//| کانستراکتور کلاس                                                |
//+------------------------------------------------------------------+
CStrategyManager::CStrategyManager(string symbol, SSettings &settings)
{
    m_symbol = symbol;
    m_settings = settings;
    m_last_bar_time = 0;
    m_is_waiting = false;
    ArrayFree(m_potential_signals);
    m_ichimoku_handle = INVALID_HANDLE;
    m_atr_handle = INVALID_HANDLE;
    m_visual_manager = new CVisualManager(m_symbol, m_settings);
    // این خط جدید رو اضافه کن
    m_regime_engine = NULL;

}

//+------------------------------------------------------------------+
//| دیستراکتور کلاس                                                 |
//+------------------------------------------------------------------+
CStrategyManager::~CStrategyManager()
{
// این قطعه کد رو در ابتدای این تابع اضافه کن
if (m_regime_engine != NULL)
{
    delete m_regime_engine;
    m_regime_engine = NULL;
}

    if (m_visual_manager != NULL)
    {
        delete m_visual_manager;
        m_visual_manager = NULL;
    }

    if(m_ichimoku_handle != INVALID_HANDLE)
        IndicatorRelease(m_ichimoku_handle);
        
    if(m_atr_handle != INVALID_HANDLE)
        IndicatorRelease(m_atr_handle);
}

//+------------------------------------------------------------------+
//| آپدیت کردن داشبورد                                              |
//+------------------------------------------------------------------+
void CStrategyManager::UpdateMyDashboard() 
{ 
    if (m_visual_manager != NULL)
    {
        m_visual_manager.UpdateDashboard();
    }
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه                                                  |
//+------------------------------------------------------------------+
bool CStrategyManager::Init()
{
    // همگام‌سازی تاریخچه با تایم‌فریم انتخابی
    int attempts = 0;
    while(iBars(m_symbol, m_settings.ichimoku_timeframe) < 200 && attempts < 100)
    {
        Sleep(100);
        MqlRates rates[];
        CopyRates(m_symbol, m_settings.ichimoku_timeframe, 0, 1, rates); 
        attempts++;
    }
    if (iBars(m_symbol, m_settings.ichimoku_timeframe) < 200)
    {
        Log("خطای بحرانی: پس از تلاش‌های مکرر، داده‌های کافی برای نماد " + m_symbol + " بارگذاری نشد.");
        return false;
    }

    m_trade.SetExpertMagicNumber(m_settings.magic_number);
    m_trade.SetTypeFillingBySymbol(m_symbol);
    
    // ساخت هندل ایچیموکو با تایم‌فریم انتخابی
    m_ichimoku_handle = iIchimoku(m_symbol, m_settings.ichimoku_timeframe, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period);
    if (m_ichimoku_handle == INVALID_HANDLE)
    {
        Log("خطا در ایجاد اندیکاتور Ichimoku.");
        return false;
    }

    // ساخت هندل ATR برای محاسبات SL و تلاقی
    int atr_period_for_handle = (m_settings.enable_sl_vol_regime) ? m_settings.sl_vol_regime_atr_period : 14;
    m_atr_handle = iATR(m_symbol, m_settings.ichimoku_timeframe, atr_period_for_handle);
    if (m_atr_handle == INVALID_HANDLE)
    {
        Log("خطا در ایجاد اندیکاتور ATR برای محاسبات SL و تلاقی.");
        return false;
    }
    // این قطعه کد جدید رو اینجا اضافه کن
if (m_settings.enable_regime_filter)
{
    m_regime_engine = new CMarketRegimeEngine();
    if (m_regime_engine == NULL || !m_regime_engine.Initialize(m_symbol, m_settings.ichimoku_timeframe, m_settings.enable_logging))
    {
        Log("خطا در راه اندازی موتور رژیم برای نماد " + m_symbol + ". فیلتر برای این نماد غیرفعال می‌شود.");
        m_settings.enable_regime_filter = false; 
        if(m_regime_engine != NULL) delete m_regime_engine;
        m_regime_engine = NULL;
    }
    else
    {
        Log("موتور تحلیل رژیم بازار برای نماد " + m_symbol + " با موفقیت راه‌اندازی شد.");
    }
}

    ArraySetAsSeries(m_tenkan_buffer, true);
    ArraySetAsSeries(m_kijun_buffer, true);
    ArraySetAsSeries(m_high_buffer, true);
    ArraySetAsSeries(m_low_buffer, true); 
    if (!m_visual_manager.Init())
    {
        Log("خطا در مقداردهی اولیه VisualManager.");
        return false;
    }

    if(m_symbol == _Symbol)
    {
        Print("--- DEBUG 1: Master instance found for '", m_symbol, "'. Calling InitDashboard...");
        m_visual_manager.InitDashboard();
    }
    
    Log("با موفقیت مقداردهی اولیه شد.");
    return true;
}

//+------------------------------------------------------------------+
//| تابع اصلی پردازش کندل جدید                                      |
//+------------------------------------------------------------------+
void CStrategyManager::ProcessNewBar()
{
    // --- گام ۰: آماده‌سازی و بررسی اولیه ---
    datetime current_bar_time = iTime(m_symbol, m_settings.ichimoku_timeframe, 0);
    
    if (current_bar_time == m_last_bar_time) 
        return; 
    
    m_last_bar_time = current_bar_time;
    
    // این قطعه کد جدید رو اینجا اضافه کن
if (m_settings.enable_regime_filter && m_regime_engine != NULL)
{
    m_regime_engine.ProcessNewBar();
}

  
// با این قطعه کد جایگزین کن
if(m_settings.enable_regime_filter && m_regime_engine != NULL)
{
    RegimeResult regime = m_regime_engine.GetLastResult();
    if(regime.regime == REGIME_RANGE_CONSOLIDATION || regime.regime == REGIME_VOLATILITY_SQUEEZE)
    {
        Log("معامله فیلتر شد. دلیل برای نماد " + m_symbol + ": رژیم بازار " + EnumToString(regime.regime));
        return; // از پردازش این کندل خارج شو، چون بازار رنج است
    }
}


    if(m_symbol == _Symbol && m_visual_manager != NULL)
    {
        m_visual_manager.CleanupOldObjects(200, m_settings.ichimoku_timeframe);
    }

    // --- حالت اول: منطق جایگزینی ---
    if (m_settings.signal_mode == MODE_REPLACE_SIGNAL)
    {
        bool is_new_signal_buy = false;
        if (CheckTripleCross(is_new_signal_buy))
        {
            if (m_is_waiting)
            {
                if (is_new_signal_buy != m_signal.is_buy)
                {
                    Log("[حالت جایگزینی] سیگنال جدید و مخالف پیدا شد! سیگنال قبلی کنسل شد.");
                    m_is_waiting = false;
                }
            }
            
            if (!m_is_waiting)
            {
                m_is_waiting = true;
                m_signal.time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou_period);
                m_signal.is_buy = is_new_signal_buy;
                m_signal.grace_candle_count = 0;
                Log("[حالت جایگزینی] سیگنال اولیه " + (m_signal.is_buy ? "خرید" : "فروش") + " پیدا شد. ورود به حالت انتظار...");
                
                if(m_symbol == _Symbol && m_visual_manager != NULL) 
                    m_visual_manager.DrawTripleCrossRectangle(m_signal.is_buy, m_settings.chikou_period, m_settings.ichimoku_timeframe);
            }
        }
    
        if (m_is_waiting)
        {
            if (m_signal.grace_candle_count >= m_settings.grace_period_candles)
            {
                m_is_waiting = false;
                Log("[حالت جایگزینی] زمان تأیید سیگنال به پایان رسید و سیگنال رد شد.");
            }
            else if (CheckFinalConfirmation(m_signal.is_buy))
            {
                Log("[حالت جایگزینی] سیگنال " + (m_signal.is_buy ? "خرید" : "فروش") + " تأیید نهایی شد. بررسی فیلترها...");
                
                if (AreAllFiltersPassed(m_signal.is_buy))
                {
                    if(m_symbol == _Symbol && m_visual_manager != NULL) 
                        m_visual_manager.DrawConfirmationArrow(m_signal.is_buy, 1, m_settings.ichimoku_timeframe);
                    
                    OpenTrade(m_signal.is_buy);
                }
                else
                {
                    Log("❌ [حالت جایگزینی] معامله توسط فیلترهای نهایی رد شد.");
                }
                
                m_is_waiting = false; 
            }
            else
            {
                m_signal.grace_candle_count++;
                if(m_symbol == _Symbol && m_visual_manager != NULL) 
                    m_visual_manager.DrawScanningArea(m_signal.is_buy, m_settings.chikou_period, m_signal.grace_candle_count, m_settings.ichimoku_timeframe);
            }
        }
    }
    // --- حالت دوم: منطق مسابقه‌ای ---
    else if (m_settings.signal_mode == MODE_SIGNAL_CONTEST)
    {
        bool is_new_signal_buy = false;
        if (CheckTripleCross(is_new_signal_buy))
        {
            AddOrUpdatePotentialSignal(is_new_signal_buy);
        }

        if (ArraySize(m_potential_signals) > 0)
        {
            for (int i = ArraySize(m_potential_signals) - 1; i >= 0; i--)
            {
                if (m_potential_signals[i].grace_candle_count >= m_settings.grace_period_candles)
                {
                    Log("[حالت مسابقه‌ای] زمان نامزد " + (m_potential_signals[i].is_buy ? "خرید" : "فروش") + " به پایان رسید و از لیست حذف شد.");
                    ArrayRemove(m_potential_signals, i, 1);
                    continue;
                }
            
                if (CheckFinalConfirmation(m_potential_signals[i].is_buy))
                {
                    Log("🏆 [حالت مسابقه‌ای] برنده پیدا شد! سیگنال " + (m_potential_signals[i].is_buy ? "خرید" : "فروش") + " تأیید نهایی شد!");
                
                    if (AreAllFiltersPassed(m_potential_signals[i].is_buy))
                    {
                        if (m_symbol == _Symbol && m_visual_manager != NULL)
                            m_visual_manager.DrawConfirmationArrow(m_potential_signals[i].is_buy, 1, m_settings.ichimoku_timeframe);
                        
                        OpenTrade(m_potential_signals[i].is_buy);
                    }
                    else
                    {
                        Log("❌ [حالت مسابقه‌ای] معامله توسط فیلترهای نهایی رد شد.");
                    }
                    
                    bool winner_is_buy = m_potential_signals[i].is_buy;
                    Log("پاکسازی لیست انتظار: حذف تمام نامزدهای " + (winner_is_buy ? "خرید" : "فروش") + "...");
                    
                    for (int j = ArraySize(m_potential_signals) - 1; j >= 0; j--)
                    {
                        if (m_potential_signals[j].is_buy == winner_is_buy)
                        {
                            ArrayRemove(m_potential_signals, j, 1);
                        }
                    }
                    Log("پاکسازی انجام شد. نامزدهای خلاف جهت در لیست باقی ماندند (در صورت وجود).");
                    
                    return; 
                }
                else
                {
                    m_potential_signals[i].grace_candle_count++;
                    if (m_symbol == _Symbol && m_visual_manager != NULL)
                        m_visual_manager.DrawScanningArea(m_potential_signals[i].is_buy, m_settings.chikou_period, m_potential_signals[i].grace_candle_count, m_settings.ichimoku_timeframe);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| منطق فاز ۱: چک کردن کراس سه گانه                               |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckTripleCross(bool& is_buy)
{
    int shift = m_settings.chikou_period;
    if (iBars(m_symbol, m_settings.ichimoku_timeframe) < shift + 2) return false;

    double tk_shifted[], ks_shifted[];
    if(CopyBuffer(m_ichimoku_handle, 0, shift, 2, tk_shifted) < 2 || 
       CopyBuffer(m_ichimoku_handle, 1, shift, 2, ks_shifted) < 2)
    {
       return false;
    }
       
    double tenkan_at_shift = tk_shifted[0];
    double kijun_at_shift = ks_shifted[0];
    double tenkan_prev_shift = tk_shifted[1];
    double kijun_prev_shift = ks_shifted[1];

    bool is_cross_up = tenkan_prev_shift < kijun_prev_shift && tenkan_at_shift > kijun_at_shift;
    bool is_cross_down = tenkan_prev_shift > kijun_prev_shift && tenkan_at_shift < kijun_at_shift;
    bool is_tk_cross = is_cross_up || is_cross_down;

    double tolerance = GetTalaqiTolerance(shift);
    bool is_confluence = (tolerance > 0) ? (MathAbs(tenkan_at_shift - kijun_at_shift) <= tolerance) : false;

    if (!is_tk_cross && !is_confluence)
    {
        return false;
    }

    double chikou_now = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
    double chikou_prev = iClose(m_symbol, m_settings.ichimoku_timeframe, 2); 

    double upper_line = MathMax(tenkan_at_shift, kijun_at_shift);
    double lower_line = MathMin(tenkan_at_shift, kijun_at_shift);

    bool chikou_crosses_up = chikou_now > upper_line && chikou_prev < upper_line;
    if (chikou_crosses_up)
    {
        is_buy = true;
        return true; 
    }

    bool chikou_crosses_down = chikou_now < lower_line && chikou_prev > lower_line;
    if (chikou_crosses_down)
    {
        is_buy = false;
        return true; 
    }

    return false;
}

//+------------------------------------------------------------------+
//| منطق فاز ۲: چک کردن تأیید نهایی                                |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckFinalConfirmation(bool is_buy)
{
    if (iBars(m_symbol, m_settings.ichimoku_timeframe) < 2) return false;

    CopyBuffer(m_ichimoku_handle, 0, 1, 1, m_tenkan_buffer);
    CopyBuffer(m_ichimoku_handle, 1, 1, 1, m_kijun_buffer);
    
    double tenkan_at_1 = m_tenkan_buffer[0];
    double kijun_at_1 = m_kijun_buffer[0];
    double open_at_1 = iOpen(m_symbol, m_settings.ichimoku_timeframe, 1);
    double close_at_1 = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
    
    if (is_buy)
    {
        if (tenkan_at_1 <= kijun_at_1) return false;
        
        if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE)
        {
            if (open_at_1 > tenkan_at_1 && open_at_1 > kijun_at_1 && 
                close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
            {
                return true;
            }
        }
        else
        {
            if (close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
            {
                return true;
            }
        }
    }
    else
    {
        if (tenkan_at_1 >= kijun_at_1) return false;
        
        if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE)
        {
            if (open_at_1 < tenkan_at_1 && open_at_1 < kijun_at_1 && 
                close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
            {
                return true;
            }
        }
        else
        {
            if (close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
            {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| محاسبه استاپ لاس                                               |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateStopLoss(bool is_buy, double entry_price)
{
    double sl_price = 0;
    double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);

    switch(m_settings.stoploss_type)
    {
        case MODE_COMPLEX:
            sl_price = FindFlatKijun();
            if (sl_price != 0) return(is_buy ? sl_price - buffer : sl_price + buffer);
            
            sl_price = FindPivotKijun(is_buy);
            if (sl_price != 0) return(is_buy ? sl_price - buffer : sl_price + buffer);
            
            sl_price = FindPivotTenkan(is_buy);
            if (sl_price != 0) return(is_buy ? sl_price - buffer : sl_price + buffer);
            
            return FindBackupStopLoss(is_buy, buffer);

        case MODE_SIMPLE:
            return FindBackupStopLoss(is_buy, buffer);

        case MODE_ATR:
            sl_price = CalculateAtrStopLoss(is_buy, entry_price);
            if(sl_price == 0)
            {
                Log("محاسبه ATR SL با خطا مواجه شد. استفاده از روش پشتیبان...");
                return FindBackupStopLoss(is_buy, buffer);
            }
            return sl_price;
    }

    return 0.0;
}

//+------------------------------------------------------------------+
//| تابع استاپ لاس پشتیبان                                         |
//+------------------------------------------------------------------+
double CStrategyManager::FindBackupStopLoss(bool is_buy, double buffer)
{
    int bars_to_check = m_settings.sl_lookback_period;
    if (iBars(m_symbol, m_settings.ichimoku_timeframe) < bars_to_check + 1) return 0;
    
    for (int i = 1; i <= bars_to_check; i++)
    {
        bool is_candle_bullish = (iClose(m_symbol, m_settings.ichimoku_timeframe, i) > iOpen(m_symbol, m_settings.ichimoku_timeframe, i));
        bool is_candle_bearish = (iClose(m_symbol, m_settings.ichimoku_timeframe, i) < iOpen(m_symbol, m_settings.ichimoku_timeframe, i));

        if (is_buy)
        {
            if (is_candle_bearish)
            {
                double sl_price = iLow(m_symbol, m_settings.ichimoku_timeframe, i) - buffer;
                Log("استاپ لاس ساده: اولین کندل نزولی در شیفت " + (string)i + " پیدا شد.");
                return sl_price;
            }
        }
        else
        {
            if (is_candle_bullish)
            {
                double sl_price = iHigh(m_symbol, m_settings.ichimoku_timeframe, i) + buffer;
                Log("استاپ لاس ساده: اولین کندل صعودی در شیفت " + (string)i + " پیدا شد.");
                return sl_price;
            }
        }
    }
    
    Log("هیچ کندل رنگ مخالفی برای استاپ لاس ساده پیدا نشد. از روش سقف/کف مطلق استفاده می‌شود.");
    CopyHigh(m_symbol, m_settings.ichimoku_timeframe, 1, bars_to_check, m_high_buffer);
    CopyLow(m_symbol, m_settings.ichimoku_timeframe, 1, bars_to_check, m_low_buffer);

    if(is_buy)
    {
       int min_index = ArrayMinimum(m_low_buffer, 0, bars_to_check);
       return m_low_buffer[min_index] - buffer;
    }
    else
    {
       int max_index = ArrayMaximum(m_high_buffer, 0, bars_to_check);
       return m_high_buffer[max_index] + buffer;
    }
}

//+------------------------------------------------------------------+
//| تابع لاگ با نمایش تایم‌فریم                                   |
//+------------------------------------------------------------------+
void CStrategyManager::Log(string message)
{
    if (m_settings.enable_logging)
    {
        Print(m_symbol, " [", EnumToString(m_settings.ichimoku_timeframe), "]: ", message);
    }
}

//+------------------------------------------------------------------+
//| شمارش معاملات نماد                                             |
//+------------------------------------------------------------------+
int CStrategyManager::CountSymbolTrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| شمارش کل معاملات                                               |
//+------------------------------------------------------------------+
int CStrategyManager::CountTotalTrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| باز کردن معامله                                                |
//+------------------------------------------------------------------+
void CStrategyManager::OpenTrade(bool is_buy)
{
    if(CountTotalTrades() >= m_settings.max_total_trades || CountSymbolTrades() >= m_settings.max_trades_per_symbol)
    {
        Log("رسیدن به حد مجاز معاملات. معامله جدید باز نشد.");
        return;
    }

    double entry_price = is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double sl = CalculateStopLoss(is_buy, entry_price);

    if(sl == 0)
    {
        Log("خطا در محاسبه استاپ لاس. معامله باز نشد.");
        return;
    }
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (m_settings.risk_percent_per_trade / 100.0);

    double loss_for_one_lot = 0;
    string base_currency = AccountInfoString(ACCOUNT_CURRENCY);
    if(!OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, 1.0, entry_price, sl, loss_for_one_lot))
    {
        Log("خطا در محاسبه سود/زیان با OrderCalcProfit. کد خطا: " + (string)GetLastError());
        return;
    }
    loss_for_one_lot = MathAbs(loss_for_one_lot);

    if(loss_for_one_lot <= 0)
    {
        Log("میزان ضرر محاسبه شده برای ۱ لات معتبر نیست. معامله باز نشد.");
        return;
    }

    double lot_size = NormalizeDouble(risk_amount / loss_for_one_lot, 2);
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
    lot_size = MathRound(lot_size / lot_step) * lot_step;

    if(lot_size < min_lot)
    {
        Log("حجم محاسبه شده (" + DoubleToString(lot_size,2) + ") کمتر از حداقل لات مجاز (" + DoubleToString(min_lot,2) + ") است. معامله باز نشد.");
        return;
    }

    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double sl_distance_points = MathAbs(entry_price - sl) / point;
    double tp_distance_points = sl_distance_points * m_settings.take_profit_ratio;
    double tp = is_buy ? entry_price + tp_distance_points * point : entry_price - tp_distance_points * point;
    
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    string comment = "Memento " + (is_buy ? "Buy" : "Sell");
    MqlTradeResult result;
    
    if(is_buy)
    {
        m_trade.Buy(lot_size, m_symbol, 0, sl, tp, comment);
    }
    else
    {
        m_trade.Sell(lot_size, m_symbol, 0, sl, tp, comment);
    }
    
    if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
    {
        Log("معامله " + comment + " با لات " + DoubleToString(lot_size, 2) + " با موفقیت باز شد.");
    }
    else
    {
        Log("خطا در باز کردن معامله " + comment + ": " + (string)m_trade.ResultRetcode() + " - " + m_trade.ResultComment());
    }
}

//+------------------------------------------------------------------+
//| پیدا کردن سطح کیجون سن فلت                                    |
//+------------------------------------------------------------------+
double CStrategyManager::FindFlatKijun()
{
    double kijun_values[];
    if (CopyBuffer(m_ichimoku_handle, 1, 1, m_settings.flat_kijun_period, kijun_values) < m_settings.flat_kijun_period)
        return 0.0;

    ArraySetAsSeries(kijun_values, true);

    int flat_count = 1;
    for (int i = 1; i < m_settings.flat_kijun_period; i++)
    {
        if (kijun_values[i] == kijun_values[i - 1])
        {
            flat_count++;
            if (flat_count >= m_settings.flat_kijun_min_length)
            {
                return kijun_values[i];
            }
        }
        else
        {
            flat_count = 1;
        }
    }

    return 0.0;
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت روی کیجون سن                                   |
//+------------------------------------------------------------------+
double CStrategyManager::FindPivotKijun(bool is_buy)
{
    double kijun_values[];
    if (CopyBuffer(m_ichimoku_handle, 1, 1, m_settings.pivot_lookback, kijun_values) < m_settings.pivot_lookback)
        return 0.0;

    ArraySetAsSeries(kijun_values, true);

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++)
    {
        if (is_buy && kijun_values[i] < kijun_values[i - 1] && kijun_values[i] < kijun_values[i + 1])
        {
            return kijun_values[i];
        }
        if (!is_buy && kijun_values[i] > kijun_values[i - 1] && kijun_values[i] > kijun_values[i + 1])
        {
            return kijun_values[i];
        }
    }

    return 0.0;
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت روی تنکان سن                                   |
//+------------------------------------------------------------------+
double CStrategyManager::FindPivotTenkan(bool is_buy)
{
    double tenkan_values[];
    if (CopyBuffer(m_ichimoku_handle, 0, 1, m_settings.pivot_lookback, tenkan_values) < m_settings.pivot_lookback)
        return 0.0;

    ArraySetAsSeries(tenkan_values, true);

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++)
    {
        if (is_buy && tenkan_values[i] < tenkan_values[i - 1] && tenkan_values[i] < tenkan_values[i + 1])
        {
            return tenkan_values[i];
        }
        if (!is_buy && tenkan_values[i] > tenkan_values[i - 1] && tenkan_values[i] > tenkan_values[i + 1])
        {
            return tenkan_values[i];
        }
    }

    return 0.0;
}

//+------------------------------------------------------------------+
//| محاسبه حد مجاز تلاقی                                           |
//+------------------------------------------------------------------+
double CStrategyManager::GetTalaqiTolerance(int reference_shift)
{
    switch(m_settings.talaqi_calculation_mode)
    {
        case TALAQI_MODE_MANUAL:
            return m_settings.talaqi_distance_in_points * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        
        case TALAQI_MODE_KUMO:
            return CalculateDynamicTolerance(reference_shift);
        
        case TALAQI_MODE_ATR:
            return CalculateAtrTolerance(reference_shift);
            
        default:
            return 0.0;
    }
}

//+------------------------------------------------------------------+
//| محاسبه حد مجاز تلاقی بر اساس ضخامت ابر کومو                   |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateDynamicTolerance(int reference_shift)
{
    if(m_settings.talaqi_kumo_factor <= 0) return 0.0;

    double senkou_a_buffer[], senkou_b_buffer[];
    if(CopyBuffer(m_ichimoku_handle, 2, reference_shift, 1, senkou_a_buffer) < 1 || 
       CopyBuffer(m_ichimoku_handle, 3, reference_shift, 1, senkou_b_buffer) < 1)
    {
       Log("داده کافی برای محاسبه ضخامت کومو در گذشته وجود ندارد.");
       return 0.0;
    }

    double kumo_thickness = MathAbs(senkou_a_buffer[0] - senkou_b_buffer[0]);
    if(kumo_thickness == 0) return SymbolInfoDouble(m_symbol, SYMBOL_POINT);

    double tolerance = kumo_thickness * m_settings.talaqi_kumo_factor;
    return tolerance;
}

//+------------------------------------------------------------------+
//| اضافه کردن سیگنال جدید به لیست نامزدها                        |
//+------------------------------------------------------------------+
void CStrategyManager::AddOrUpdatePotentialSignal(bool is_buy)
{
    int total = ArraySize(m_potential_signals);
    ArrayResize(m_potential_signals, total + 1);
    
    m_potential_signals[total].time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou_period);
    m_potential_signals[total].is_buy = is_buy;
    m_potential_signals[total].grace_candle_count = 0;
    
    Log("[حالت مسابقه‌ای] سیگنال نامزد جدید " + (is_buy ? "خرید" : "فروش") + " به لیست انتظار مسابقه اضافه شد. تعداد کل نامزدها: " + (string)ArraySize(m_potential_signals));
    
    if(m_symbol == _Symbol && m_visual_manager != NULL)
        m_visual_manager.DrawTripleCrossRectangle(is_buy, m_settings.chikou_period, m_settings.ichimoku_timeframe);
}

//+------------------------------------------------------------------+
//| محاسبه حد مجاز تلاقی بر اساس ATR                               |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateAtrTolerance(int reference_shift)
{
    if(m_settings.talaqi_atr_multiplier <= 0) return 0.0;
    
    if (m_atr_handle == INVALID_HANDLE)
    {
        Log("محاسبه تلورانس ATR ممکن نیست چون هندل آن نامعتبر است.");
        return 0.0;
    }

    double atr_buffer[];
    if(CopyBuffer(m_atr_handle, 0, reference_shift, 1, atr_buffer) < 1)
    {
        Log("داده کافی برای محاسبه ATR در گذشته وجود ندارد.");
        return 0.0;
    }
    
    double tolerance = atr_buffer[0] * m_settings.talaqi_atr_multiplier;
    return tolerance;
}

//+------------------------------------------------------------------+
//| محاسبه حد ضرر ATR                                             |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateAtrStopLoss(bool is_buy, double entry_price)
{
    if (!m_settings.enable_sl_vol_regime)
    {
        if (m_atr_handle == INVALID_HANDLE)
        {
            Log("خطای بحرانی در CalculateAtrStopLoss: هندل ATR نامعتبر است!");
            return 0.0;
        }
        
        double atr_buffer[];
        if(CopyBuffer(m_atr_handle, 0, 1, 1, atr_buffer) < 1)
        {
            Log("داده ATR برای محاسبه حد ضرر ساده موجود نیست.");
            return 0.0;
        }
        
        double atr_value = atr_buffer[0];
        return is_buy ? entry_price - (atr_value * m_settings.sl_atr_multiplier) : entry_price + (atr_value * m_settings.sl_atr_multiplier);
    }

    int history_size = m_settings.sl_vol_regime_ema_period + 5;
    double atr_values[], ema_values[];

    int atr_sl_handle = iATR(m_symbol, m_settings.ichimoku_timeframe, m_settings.sl_vol_regime_atr_period);
    if (atr_sl_handle == INVALID_HANDLE || CopyBuffer(atr_sl_handle, 0, 0, history_size, atr_values) < history_size)
    {
        Log("داده کافی برای محاسبه SL پویا موجود نیست.");
        if(atr_sl_handle != INVALID_HANDLE) 
            IndicatorRelease(atr_sl_handle);
        return 0.0;
    }
    
    IndicatorRelease(atr_sl_handle);
    ArraySetAsSeries(atr_values, true); 

    if(SimpleMAOnBuffer(history_size, 0, m_settings.sl_vol_regime_ema_period, MODE_EMA, atr_values, ema_values) < 1)
    {
         Log("خطا در محاسبه EMA روی ATR.");
         return 0.0;
    }

    double current_atr = atr_values[1]; 
    double ema_atr = ema_values[1];     

    bool is_high_volatility = (current_atr > ema_atr);
    double final_multiplier = is_high_volatility ? m_settings.sl_high_vol_multiplier : m_settings.sl_low_vol_multiplier;

    Log("رژیم نوسان: " + (is_high_volatility ? "بالا" : "پایین") + ". ضریب SL نهایی: " + (string)final_multiplier);

    return is_buy ? entry_price - (current_atr * final_multiplier) : entry_price + (current_atr * final_multiplier);
}

//+------------------------------------------------------------------+
//| گیت کنترل نهایی برای فیلترها                                   |
//+------------------------------------------------------------------+
bool CStrategyManager::AreAllFiltersPassed(bool is_buy)
{
    // فیلتر رژیم بازار در ProcessNewBar چک شده است
    if(m_settings.enable_kumo_filter)
    {
        if(!CheckKumoFilter())
        {
            Log("فیلتر کومو رد شد. قیمت داخل ابر است.");
            return false;
        }
    }

    Log("✅ تمام فیلترهای فعال با موفقیت پاس شدند.");
    return true;
}

//+------------------------------------------------------------------+
//| بررسی فیلتر ابر کومو                                           |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckKumoFilter()
{
    double senkou_a[1], senkou_b[1];
    if(CopyBuffer(m_ichimoku_handle, 2, 0, 1, senkou_a) < 1 || 
       CopyBuffer(m_ichimoku_handle, 3, 0, 1, senkou_b) < 1)
    {
       Log("خطا: داده کافی برای فیلتر کومو موجود نیست.");
       return false;
    }

    double high_kumo = MathMax(senkou_a[0], senkou_b[0]);
    double low_kumo = MathMin(senkou_a[0], senkou_b[0]);
    double close_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);

    if(close_price < high_kumo && close_price > low_kumo)
    {
        return false; 
    }

    return true;
}
