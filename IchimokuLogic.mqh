//+------------------------------------------------------------------+
//|                                     IchimokuLogic.mqh            |
//|                          © 2025, hipoalgoritm              |
//+------------------------------------------------------------------+
#property copyright "© 2025,hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "1.03" // نسخه نهایی و کاملا اصلاح شده
#include "set.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Object.mqh>
#include "VisualManager.mqh"

//--- تعریف ساختار سیگنال
struct SPotentialSignal
{
    datetime        time;
    bool            is_buy;
    int             grace_candle_count;
};
/*struct SSettings
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
*/
//+------------------------------------------------------------------+
//| کلاس مدیریت استراتژی برای یک نماد خاص                             |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
    string              m_symbol;
    SSettings           m_settings;
    CTrade              m_trade;
   
    datetime            m_last_bar_time;
    
    int                 m_ichimoku_handle;
    double              m_tenkan_buffer[];
    double              m_kijun_buffer[];
    double              m_chikou_buffer[];
    
    SPotentialSignal    m_signal;
    bool                m_is_waiting;
    
    CVisualManager* m_visual_manager;

    //--- توابع کمکی
    void Log(string message);
    bool CheckTripleCross(bool& is_buy);
    bool CheckFinalConfirmation(bool is_buy);
    
    //--- محاسبه استاپ لاس
    double CalculateStopLoss(bool is_buy, double entry_price);
    
    double GetTalaqiTolerance(int reference_shift);      // <<-- این خط رو اضافه کن
    double CalculateDynamicTolerance(int reference_shift); // <<-- این خط رو هم اضافه کن
  
    double FindFlatKijun();
    double FindPivotKijun(bool is_buy);
    double FindPivotTenkan(bool is_buy);
    double FindBackupStopLoss(bool is_buy, double buffer);
    
    //--- مدیریت معاملات
    int CountSymbolTrades();
    int CountTotalTrades();
    void OpenTrade(bool is_buy);

public:
    CStrategyManager(string symbol,   SSettings &settings);
    bool Init();
    void ProcessNewBar();
    
    ~CStrategyManager();
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
    m_ichimoku_handle = INVALID_HANDLE;
    m_visual_manager = new CVisualManager(m_symbol, m_settings);

}

//+------------------------------------------------------------------+
//| دیستراکتور کلاس                                                  |
//+------------------------------------------------------------------+
CStrategyManager::~CStrategyManager()
{
    if (m_visual_manager != NULL)
    {
        delete m_visual_manager;
        m_visual_manager = NULL;
    }
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه                                                   |
//+------------------------------------------------------------------+
bool CStrategyManager::Init()
{
    m_trade.SetExpertMagicNumber(m_settings.magic_number);
    m_trade.SetTypeFillingBySymbol(m_symbol);
    
    m_ichimoku_handle = iIchimoku(m_symbol, _Period, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period);
    if (m_ichimoku_handle == INVALID_HANDLE)
    {
        Log("خطا در ایجاد اندیکاتور Ichimoku.");
        return false;
    }
    
    ArraySetAsSeries(m_tenkan_buffer, true);
    ArraySetAsSeries(m_kijun_buffer, true);
    ArraySetAsSeries(m_chikou_buffer, true);
    
    if (!m_visual_manager.Init())
    {
        Log("خطا در مقداردهی اولیه VisualManager.");
        return false;
    }
    
    Log("با موفقیت مقداردهی اولیه شد.");
    return true;
}

//+------------------------------------------------------------------+
//| تابع اصلی پردازش کندل جدید                                       |
//+------------------------------------------------------------------+
void CStrategyManager::ProcessNewBar()
{
    datetime current_bar_time = iTime(m_symbol, _Period, 0);
    if (current_bar_time == m_last_bar_time)
        return;
    m_last_bar_time = current_bar_time;

    bool is_buy_signal = false;

    if (!m_is_waiting && CheckTripleCross(is_buy_signal))
    {
        m_is_waiting = true;
        m_signal.time = iTime(m_symbol, _Period, m_settings.chikou_period);
        m_signal.is_buy = is_buy_signal;
        m_signal.grace_candle_count = 0;
        
        Log("سیگنال اولیه " + (is_buy_signal ? "خرید" : "فروش") + " در کندل " + TimeToString(m_signal.time) + " پیدا شد.");
        m_visual_manager.DrawTripleCrossRectangle(m_signal.is_buy, m_settings.chikou_period);
    }
    
    if (m_is_waiting)
    {
        m_visual_manager.DrawScanningArea(m_signal.is_buy, m_settings.chikou_period, m_signal.grace_candle_count);
        
        if (m_signal.grace_candle_count >= m_settings.grace_period_candles)
        {
            m_is_waiting = false;
            m_visual_manager.ClearGraphics();
            Log("زمان تأیید سیگنال " + (m_signal.is_buy ? "خرید" : "فروش") + " به پایان رسید و سیگنال رد شد.");
        }
        else if (CheckFinalConfirmation(m_signal.is_buy))
        {
            m_is_waiting = false;
            m_visual_manager.ClearGraphics();
            m_visual_manager.DrawConfirmationArrow(m_signal.is_buy, 1);
            Log("سیگنال " + (m_signal.is_buy ? "خرید" : "فروش") + " تأیید نهایی شد. در حال باز کردن معامله.");
            OpenTrade(m_signal.is_buy);
        }
        else
        {
            m_signal.grace_candle_count++;
        }
    }
}
//+------------------------------------------------------------------+
//| منطق فاز ۱: چک کردن کراس سه گانه (کاملاً اصلاح شده بر اساس منطق صحیح) |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckTripleCross(bool& is_buy)
{
    int shift = m_settings.chikou_period;
    if (iBars(m_symbol, _Period) < shift + 2) return false;

    //--- خواندن Tenkan و Kijun از بافر اندیکاتور در کندل مرجع (۲۶ کندل قبل)
    CopyBuffer(m_ichimoku_handle, 0, shift, 2, m_tenkan_buffer);
    CopyBuffer(m_ichimoku_handle, 1, shift, 2, m_kijun_buffer);
    
    //--- مقادیر تنکان و کیجون در نقطه مرجع
    double tenkan_at_shift = m_tenkan_buffer[0]; // مقدار در کندل ۲۶
    double kijun_at_shift = m_kijun_buffer[0];  // مقدار در کندل ۲۶

    //--- خواندن قیمت فعلی و قبلی که نقش چیکو اسپن را برای نقطه مرجع بازی می‌کنند
    double chikou_now  = iClose(m_symbol, _Period, 1); // قیمت Close کندل فعلی
    double chikou_prev = iClose(m_symbol, _Period, 2); // قیمت Close کندل قبلی

        //--- بررسی تلاقی یا کراس تنکان و کیجون در گذشته
    double tolerance = GetTalaqiTolerance(shift); // گرفتن حد مجاز از مدیر کل!
    
    double current_distance = MathAbs(tenkan_at_shift - kijun_at_shift);
    bool is_confluence = (tolerance > 0) ? (current_distance <= tolerance) : false;


    bool tenkan_crossover = m_tenkan_buffer[1] < m_kijun_buffer[1] && tenkan_at_shift > kijun_at_shift;
    bool tenkan_crossunder = m_tenkan_buffer[1] > m_kijun_buffer[1] && tenkan_at_shift < kijun_at_shift;

    // --- شرط خرید: کراس صعودی تنکان/کیجون در گذشته و کراس قیمت فعلی (چیکو) از آنها
    if (tenkan_crossover || (is_confluence && tenkan_at_shift > kijun_at_shift))
    {
        //--- آیا قیمت فعلی (چیکو) از خطوط تنکان و کیجون در نقطه مرجع عبور کرده؟
        bool chikou_crosses_up = (chikou_prev < tenkan_at_shift && chikou_now > tenkan_at_shift) && 
                                 (chikou_prev < kijun_at_shift && chikou_now > kijun_at_shift);
      
        if (chikou_crosses_up)
        {
            is_buy = true;
            return true;
        }
    }
    
    // --- شرط فروش: کراس نزولی تنکان/کیجون در گذشته و کراس قیمت فعلی (چیکو) از آنها
    if (tenkan_crossunder || (is_confluence && tenkan_at_shift < kijun_at_shift))
    {
        //--- آیا قیمت فعلی (چیکو) از خطوط تنکان و کیجون در نقطه مرجع عبور کرده؟
        bool chikou_crosses_down = (chikou_prev > tenkan_at_shift && chikou_now < tenkan_at_shift) && 
                                   (chikou_prev > kijun_at_shift && chikou_now < kijun_at_shift);
        if (chikou_crosses_down)
        {
            is_buy = false;
            return true;
        }
    }
    
    return false;
}



//+------------------------------------------------------------------+
//| منطق فاز ۲: چک کردن تأیید نهایی در کندل شماره یک (اصلاح شده)      |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckFinalConfirmation(bool is_buy)
{
    if (iBars(m_symbol, _Period) < 2) return false;

    CopyBuffer(m_ichimoku_handle, 0, 1, 1, m_tenkan_buffer);
    CopyBuffer(m_ichimoku_handle, 1, 1, 1, m_kijun_buffer);
    
    double tenkan_at_1 = m_tenkan_buffer[0];
    double kijun_at_1 = m_kijun_buffer[0];
    double open_at_1 = iOpen(m_symbol, _Period, 1);
    double close_at_1 = iClose(m_symbol, _Period, 1);
    
    if (is_buy)
    {
        if (tenkan_at_1 <= kijun_at_1) return false;
        if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE)
        {
           // برای خرید
          // برای خرید
        if (open_at_1 < tenkan_at_1 || open_at_1 < kijun_at_1 || close_at_1 < tenkan_at_1 || close_at_1 < kijun_at_1) return false;


        }
        else // MODE_CLOSE_ONLY
        {
            if (close_at_1 < tenkan_at_1 ||
            close_at_1 < kijun_at_1) return false;
        }
        return true;
    }
    else // is_sell
    {
        if (tenkan_at_1 >= kijun_at_1) return false;
        if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE)
        {
            if (open_at_1 > tenkan_at_1 || open_at_1 > kijun_at_1 || close_at_1 > tenkan_at_1 || close_at_1 > kijun_at_1) return false;
        }
        else // MODE_CLOSE_ONLY
        {
            if (close_at_1 > tenkan_at_1 || close_at_1 > kijun_at_1) return false;
        }
        return true;
    
    }
}


//+------------------------------------------------------------------+
//| تابع محاسبه استاپ لاس (همراه با روش نهایی)                       |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateStopLoss(bool is_buy, double entry_price)
{
    double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double sl_price = 0;

    if (m_settings.stoploss_type == MODE_COMPLEX)
    {
        sl_price = FindFlatKijun();
        if (sl_price != 0) return is_buy ? sl_price - buffer : sl_price + buffer;
        
        sl_price = FindPivotKijun(is_buy);
        if (sl_price != 0) return is_buy ? sl_price - buffer : sl_price + buffer;
        
        sl_price = FindPivotTenkan(is_buy);
        if (sl_price != 0) return is_buy ? sl_price - buffer : sl_price + buffer;
    }
    
    return FindBackupStopLoss(is_buy, buffer);
}

//+------------------------------------------------------------------+
//| تابع نهایی محاسبه استاپ لاس (اصلاح شده)                           |
//+------------------------------------------------------------------+
double CStrategyManager::FindBackupStopLoss(bool is_buy, double buffer)
{
    double sl_price = 0;
    int bars_to_check = m_settings.sl_lookback_period + 1;
    if (iBars(m_symbol, _Period) < bars_to_check) return 0;
    
    if (is_buy)
    {
        double min_low = iLow(m_symbol, _Period, 1);
        for (int i = 1; i < bars_to_check; i++)
        {
            if (iLow(m_symbol, _Period, i) < min_low)
            {
                min_low = iLow(m_symbol, _Period, i);
            }
        }
        sl_price = min_low - buffer;
    }
    else // is_sell
    {
        double max_high = iHigh(m_symbol, _Period, 1);
        for (int i = 1; i < bars_to_check; i++)
        {
            if (iHigh(m_symbol, _Period, i) > max_high)
            {
                max_high = iHigh(m_symbol, _Period, i);
            }
        }
        sl_price = max_high + buffer;
    }
    
    return sl_price;
}


//+------------------------------------------------------------------+
//| توابع کمکی دیگر                                                  |
//+------------------------------------------------------------------+
void CStrategyManager::Log(string message)
{
    if (m_settings.enable_logging)
    {
        Print(m_symbol, ": ", message);
    }
}

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

void CStrategyManager::OpenTrade(bool is_buy)
{
    if (CountTotalTrades() >= m_settings.max_total_trades || CountSymbolTrades() >= m_settings.max_trades_per_symbol)
    {
        Log("رسیدن به حد مجاز معاملات. معامله جدید باز نشد.");
        return;
    }

    double entry_price = is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
    double sl = CalculateStopLoss(is_buy, entry_price);

    if (sl == 0)
    {
        Log("خطا در محاسبه استاپ لاس. معامله باز نشد.");
        return;
    }

    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double sl_distance_points = MathAbs(entry_price - sl) / point;
    if (sl_distance_points < 1)
    {
        Log("فاصله استاپ لاس بسیار کم است. معامله باز نشد.");
        return;
    }

    double risk_amount = AccountInfoDouble(ACCOUNT_BALANCE) * (m_settings.risk_percent_per_trade / 100.0);
    double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE_PROFIT);
    if (tick_value <= 0)
    {
        Log("مقدار Tick Value برای نماد نامعتبر است. معامله باز نشد.");
        return;
    }
    
    double lot_size = risk_amount / (sl_distance_points * tick_value);

    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, NormalizeDouble(lot_size, 2)));
    lot_size = MathRound(lot_size / lot_step) * lot_step;

    double tp_distance_points = sl_distance_points * m_settings.take_profit_ratio;
    double tp = is_buy ? entry_price + tp_distance_points * point : entry_price - tp_distance_points * point;
    
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    if (is_buy)
    {
        if (!m_trade.Buy(lot_size, m_symbol, 0, sl, tp, "Memento Buy"))
        {
            Log("خطا در باز کردن معامله خرید: " + (string)m_trade.ResultRetcode());
        }
        else
        {
            Log("معامله خرید با لات " + DoubleToString(lot_size, 2) + " باز شد.");
        }
    }
    else
    {
        if (!m_trade.Sell(lot_size, m_symbol, 0, sl, tp, "Memento Sell"))
        {
            Log("خطا در باز کردن معامله فروش: " + (string)m_trade.ResultRetcode());
        }
        else
        {
            Log("معامله فروش با لات " + DoubleToString(lot_size, 2) + " باز شد.");
        }
    }
}

//+------------------------------------------------------------------+
//| پیدا کردن سطح کیجون سن فلت (صاف)                                  |
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
                return kijun_values[i]; // سطح فلت پیدا شد
            }
        }
        else
        {
            flat_count = 1; // ریست کردن شمارنده
        }
    }

    return 0.0; // هیچ سطح فلتی پیدا نشد
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت (نقطه چرخش) روی کیجون سن                          |
//+------------------------------------------------------------------+
double CStrategyManager::FindPivotKijun(bool is_buy)
{
    double kijun_values[];
    if (CopyBuffer(m_ichimoku_handle, 1, 1, m_settings.pivot_lookback, kijun_values) < m_settings.pivot_lookback)
        return 0.0;

    ArraySetAsSeries(kijun_values, true);

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++)
    {
        // برای معامله خرید، دنبال یک دره (پیوت کف) می‌گردیم
        if (is_buy && kijun_values[i] < kijun_values[i - 1] && kijun_values[i] < kijun_values[i + 1])
        {
            return kijun_values[i];
        }
        // برای معامله فروش، دنبال یک قله (پیوت سقف) می‌گردیم
        if (!is_buy && kijun_values[i] > kijun_values[i - 1] && kijun_values[i] > kijun_values[i + 1])
        {
            return kijun_values[i];
        }
    }

    return 0.0; // هیچ پیوتی پیدا نشد
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت (نقطه چرخش) روی تنکان سن                          |
//+------------------------------------------------------------------+
double CStrategyManager::FindPivotTenkan(bool is_buy)
{
    double tenkan_values[];
    if (CopyBuffer(m_ichimoku_handle, 0, 1, m_settings.pivot_lookback, tenkan_values) < m_settings.pivot_lookback)
        return 0.0;

    ArraySetAsSeries(tenkan_values, true);

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++)
    {
        // برای معامله خرید، دنبال یک دره (پیوت کف) می‌گردیم
        if (is_buy && tenkan_values[i] < tenkan_values[i - 1] && tenkan_values[i] < tenkan_values[i + 1])
        {
            return tenkan_values[i];
        }
        // برای معامله فروش، دنبال یک قله (پیوت سقف) می‌گردیم
        if (!is_buy && tenkan_values[i] > tenkan_values[i - 1] && tenkan_values[i] > tenkan_values[i + 1])
        {
            return tenkan_values[i];
        }
    }

    return 0.0; // هیچ پیوتی پیدا نشد
}
//+------------------------------------------------------------------+
//| (اتوماتیک) محاسبه حد مجاز تلاقی بر اساس تاریخچه بازار               |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateDynamicTolerance(int reference_shift)
{
    double total_distance = 0;
    int lookback = m_settings.talaqi_lookback_period;
    if(lookback <= 0) return 0.0;

    double past_tenkan[], past_kijun[];
    if(CopyBuffer(m_ichimoku_handle, 0, reference_shift, lookback, past_tenkan) < lookback || 
       CopyBuffer(m_ichimoku_handle, 1, reference_shift, lookback, past_kijun) < lookback)
    {
       Log("داده کافی برای محاسبه فاصله تاریخی تلاقی وجود ندارد.");
       return 0.0;
    }
    
    for(int i = 0; i < lookback; i++)
    {
        total_distance += MathAbs(past_tenkan[i] - past_kijun[i]);
    }
    
    double average_historical_distance = total_distance / lookback;
    double tolerance = average_historical_distance * m_settings.talaqi_hist_multiplier;
    
    return tolerance;
}

//+------------------------------------------------------------------+
//| (مدیر کل) گرفتن حد مجاز تلاقی بر اساس حالت انتخابی (اتو/دستی)     |
//+------------------------------------------------------------------+
double CStrategyManager::GetTalaqiTolerance(int reference_shift)
{
    // اگر حالت اتوماتیک روشن بود
    if(m_settings.talaqi_auto_mode)
    {
        // برو از روش هوشمند (تاریخی) حساب کن
        return CalculateDynamicTolerance(reference_shift);
    }
    // اگر حالت اتوماتیک خاموش بود
    else
    {
        // برو از روش ساده (دستی) حساب کن
        return m_settings.talaqi_distance_in_points * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    }
}




