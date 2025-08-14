/*//+------------------------------------------------------------------+
//|                                       MarketRegimeDetector.mqh    |
//|        Project: ,هذف اصلی پروژه تعین نوع رژیم بازار هست
//|
//|
//|
 //|
              {این کتابخانه به عنوان یک ابزار برای  تشخیص خواهد بود نه یک سیستم که سیکنال نهای را بدهد}
//|
                © 2025, HipoAlgorithm & mohammad khajavi              |
//|                      Version: 2.2.1 (Final & Bug-Fixed)          |
//+------------------------------------------------------------------+*/


#property copyright "© 2025, HipoAlgorithm & khajavi"
#property link      "https://www.mql5.com"
#property version   "2.2"

//+------------------------------------------------------------------+
//| بخش ۱: تعاریف اولیه (Enums and Structs)                         |
//+------------------------------------------------------------------+

// کامنت فارسی: تعریف حالات مختلف بازار برای شناسایی رژیم‌ها
enum ENUM_MARKET_REGIME
{
    REGIME_STRONG_BULL_TREND,         // روند صعودی قوی
    REGIME_AVERAGE_BULL_TREND,        // روند صعودی متوسط
    REGIME_BULL_TREND_EXHAUSTION,     // خستگی روند صعودی
    REGIME_STRONG_BEAR_TREND,         // روند نزولی قوی
    REGIME_AVERAGE_BEAR_TREND,        // روند نزولی متوسط
    REGIME_BEAR_TREND_EXHAUSTION,     // خستگی روند نزولی
    REGIME_RANGE_CONSOLIDATION,       // بازار رنج (خنثی)
    REGIME_VOLATILITY_SQUEEZE,        // فشردگی نوسانات
    REGIME_PROBABLE_BEARISH_REVERSAL, // بازگشت نزولی احتمالی
    REGIME_PROBABLE_BULLISH_REVERSAL, // بازگشت صعودی احتمالی
    REGIME_BULLISH_BREAKOUT_CONFIRMED, // شروع روند صعودی (شکست تایید شده)
    REGIME_BEARISH_BREAKOUT_CONFIRMED, // شروع روند نزولی (شکست تایید شده)
    REGIME_PROBABLE_FAKEOUT,          // شکست کاذب احتمالی
    REGIME_UNDEFINED                  // حالت نامشخص
};

// کامنت فارسی: ساختار برای نگهداری اطلاعات نقاط چرخش
struct SwingPoint
{
    datetime time;         // زمان کندل
    double   price;        // قیمت High یا Low
    int      bar_index;    // اندیس کندل در آرایه غیر سری (از ۰ شروع می‌شود)
};

// کامنت فارسی: ساختار خروجی تحلیل رژیم بازار
struct RegimeResult
{
    ENUM_MARKET_REGIME regime;              // رژیم تشخیص داده شده
    double             confidenceScore;     // امتیاز اطمینان (0.0 تا 1.0)
    string             reasoning;           // توضیح متنی برای دیباگ
    datetime           analysisTime;        // زمان تحلیل
};

// کامنت فارسی: تعریف وضعیت ساختار بازار
enum ENUM_STRUCTURE_STATE
{
    STRUCTURE_UPTREND_BOS,          // روند صعودی با شکست ساختار
    STRUCTURE_DOWNTREND_BOS,        // روند نزولی با شکست ساختار
    STRUCTURE_BEARISH_CHoCH,        // تغییر شخصیت نزولی
    STRUCTURE_BULLISH_CHoCH,        // تغییر شخصیت صعودی
    STRUCTURE_CONSOLIDATION_RANGE,  // بازار رنج
    STRUCTURE_UNDEFINED             // نامشخص
};

// کامنت فارسی: تعریف وضعیت نوسانات بازار
enum ENUM_VOLATILITY_STATE
{
    VOLATILITY_SQUEEZE,     // فشردگی
    VOLATILITY_EXPANSION,   // انبساط
    VOLATILITY_NORMAL       // نرمال
};

// کامنت فارسی: ساختار خروجی ماژول مومنتوم
struct MomentumResult
{
    double score;               // امتیاز مومنتوم (-100 تا +100)
    bool   exhaustion_signal;   // سیگنال خستگی روند
    double hurst_exponent;      // توان هرست
    bool   is_conflicting;      // تضاد بین ADX و Hurst
};

//+------------------------------------------------------------------+
//| بخش ۲: تعریف کلاس‌ها                                            |
//+------------------------------------------------------------------+

// کامنت فارسی: کلاس برای مدیریت لاگ‌ها با قابلیت فعال/غیرفعال
class CLogManager
{
private:
    bool   m_enabled;       // وضعیت فعال بودن لاگ
    string m_symbol;        // نماد برای شناسایی در لاگ
    ENUM_TIMEFRAMES m_period; // تایم‌فریم برای شناسایی در لاگ

public:
    CLogManager() : m_enabled(false), m_symbol(""), m_period(PERIOD_CURRENT) {}
    void Initialize(const string symbol, const ENUM_TIMEFRAMES period, bool enable)
    {
        m_symbol = symbol;
        m_period = period;
        m_enabled = enable;
    }
    void Log(const string message)
    {
        if(m_enabled)
            Print(StringFormat("[MarketRegimeDetector][%s][%s] %s", m_symbol, EnumToString(m_period), message));
    }
};

// کامنت فارسی: کلاس تحلیل ساختار بازار برای شناسایی نقاط چرخش و BOS/CHoCH
class CStructureAnalyzer
{
private:
    string             m_symbol;
    ENUM_TIMEFRAMES    m_period;
    int                m_fractal_n;
    double             m_consolidation_factor;
    double             m_fractal_atr_filter_factor;
    int                m_atr_period_consolidation;
    int                m_atr_handle;
    SwingPoint         m_swing_highs[];
    SwingPoint         m_swing_lows[];
    long               m_last_processed_bar_time;
    CLogManager* m_logger;

    void FindSwingPoints(const MqlRates &rates[], const double &atr_buf[], const int bars_to_check)
    {
        if(m_last_processed_bar_time == (long)rates[0].time) return;

        ArrayFree(m_swing_highs);
        ArrayFree(m_swing_lows);

        for(int i = bars_to_check - 1 - m_fractal_n; i >= m_fractal_n; i--)
        {
            bool is_swing_high = true;
            bool is_swing_low = true;

            for(int j = 1; j <= m_fractal_n; j++)
            {
                if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high)
                    is_swing_high = false;
                if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low)
                    is_swing_low = false;
            }

            if(is_swing_high && m_fractal_atr_filter_factor > 0 && i < bars_to_check - 1 && i < ArraySize(atr_buf))
            {
                if(MathAbs(rates[i].high - rates[i+1].high) <= atr_buf[i] * m_fractal_atr_filter_factor)
                    is_swing_high = false;
            }
            if(is_swing_low && m_fractal_atr_filter_factor > 0 && i < bars_to_check - 1 && i < ArraySize(atr_buf))
            {
                if(MathAbs(rates[i].low - rates[i+1].low) <= atr_buf[i] * m_fractal_atr_filter_factor)
                    is_swing_low = false;
            }

            if(is_swing_high)
            {
                SwingPoint sh;
                sh.time = rates[i].time;
                sh.price = rates[i].high;
                sh.bar_index = i;
                int size = ArraySize(m_swing_highs);
                ArrayResize(m_swing_highs, size + 1, 100);
                m_swing_highs[size] = sh;
            }
            if(is_swing_low)
            {
                SwingPoint sl;
                sl.time = rates[i].time;
                sl.price = rates[i].low;
                sl.bar_index = i;
                int size = ArraySize(m_swing_lows);
                ArrayResize(m_swing_lows, size + 1, 100);
                m_swing_lows[size] = sl;
            }
        }
        m_last_processed_bar_time = (long)rates[0].time;
    }

public:
    CStructureAnalyzer() : m_fractal_n(2), m_consolidation_factor(4.0), m_fractal_atr_filter_factor(0.5),
                           m_atr_period_consolidation(50), m_atr_handle(INVALID_HANDLE), m_last_processed_bar_time(0), m_logger(NULL) {}
    ~CStructureAnalyzer() { if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle); }

    bool Initialize(const string symbol, const ENUM_TIMEFRAMES period, CLogManager &logger,
                    const int fractal_n=2, const double consolidation_factor=4.0,
                    const int atr_period_consolidation=50, const double fractal_atr_filter_factor=0.5)
    {
        m_symbol = symbol;
        m_period = period;
        m_fractal_n = fractal_n;
        m_consolidation_factor = consolidation_factor;
        m_atr_period_consolidation = atr_period_consolidation;
        m_fractal_atr_filter_factor = fractal_atr_filter_factor;
        m_logger = &logger;
        m_atr_handle = iATR(m_symbol, m_period, m_atr_period_consolidation);
        if(m_atr_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل ATR ناموفق");
            return false;
        }
        return true;
    }
    
    int GetAtrHandle() const { return m_atr_handle; }

    ENUM_STRUCTURE_STATE Analyze(const MqlRates &rates[], const double &atr_buf[], const int bars_to_check)
    {
        FindSwingPoints(rates, atr_buf, bars_to_check);
        int highs_count = ArraySize(m_swing_highs);
        int lows_count = ArraySize(m_swing_lows);

        if(highs_count < 2 || lows_count < 2) return STRUCTURE_UNDEFINED;

        SwingPoint last_h = m_swing_highs[0];
        SwingPoint prev_h = m_swing_highs[1];
        SwingPoint last_l = m_swing_lows[0];
        SwingPoint prev_l = m_swing_lows[1];

        double last_swing_range = MathAbs(last_h.price - last_l.price);
        double atr = atr_buf[1];
        if(atr > 0 && last_swing_range < m_consolidation_factor * atr)
        {
            return STRUCTURE_CONSOLIDATION_RANGE;
        }

        double current_close = rates[1].close;
        bool is_uptrend = (last_h.price > prev_h.price && last_l.price > prev_l.price);
        bool is_downtrend = (last_h.price < prev_h.price && last_l.price < prev_l.price);

        if(is_uptrend)
        {
            if(current_close > last_h.price) return STRUCTURE_UPTREND_BOS;
            if(current_close < last_l.price) return STRUCTURE_BEARISH_CHoCH;
            return STRUCTURE_CONSOLIDATION_RANGE;
        }
        else if(is_downtrend)
        {
            if(current_close < last_l.price) return STRUCTURE_DOWNTREND_BOS;
            if(current_close > last_h.price) return STRUCTURE_BULLISH_CHoCH;
            return STRUCTURE_CONSOLIDATION_RANGE;
        }

        return STRUCTURE_CONSOLIDATION_RANGE;
    }

    int GetSwingHighs(SwingPoint &result_array[]) const
    {
        if(ArraySize(m_swing_highs) > 0) ArrayCopy(result_array, m_swing_highs);
        return ArraySize(m_swing_highs);
    }

    int GetSwingLows(SwingPoint &result_array[]) const
    {
        if(ArraySize(m_swing_lows) > 0) ArrayCopy(result_array, m_swing_lows);
        return ArraySize(m_swing_lows);
    }
};

// کامنت فارسی: کلاس تحلیل مومنتوم و خستگی روند
class CMomentumAnalyzer
{
private:
    string             m_symbol;
    ENUM_TIMEFRAMES    m_period;
    int                m_adx_period;
    int                m_rsi_period;
    int                m_hurst_window;
    double             m_adx_threshold;
    int                m_adx_handle;
    int                m_rsi_handle;
    double             m_adx_main_buf[3];
    double             m_adx_plus_di_buf[1];
    double             m_adx_minus_di_buf[1];
    double             m_rsi_buf[];
    CStructureAnalyzer* m_structure_analyzer;
    CLogManager* m_logger;
    double             m_last_hurst;

    void CalculateAdaptiveAdxThreshold(const double &adx_buf[])
    {
        const int long_window = 500;
        if(ArraySize(adx_buf) < long_window)
        {
            m_adx_threshold = 25.0;
            return;
        }

        double sum = 0, sum_sq = 0;
        for(int i = 0; i < long_window; i++)
        {
            sum += adx_buf[i];
            sum_sq += adx_buf[i] * adx_buf[i];
        }
        double avg = sum / long_window;
        double variance = (sum_sq / long_window) - (avg * avg);
        double stddev = (variance > 0) ? MathSqrt(variance) : 0;
        double calculated_adaptive_threshold = avg + 0.5 * stddev;
        m_adx_threshold = fmax(20.0, fmin(45.0, calculated_adaptive_threshold));
    }

    double CalculateAdxScore()
    {
        double adx_value = m_adx_main_buf[0];
        double plus_di = m_adx_plus_di_buf[0];
        double minus_di = m_adx_minus_di_buf[0];
        double score = 0;
        if(adx_value > m_adx_threshold)
        {
            score = (adx_value - m_adx_threshold) / (75.0 - m_adx_threshold) * 100.0;
            score = MathMin(100, score);
        }
        if(plus_di < minus_di) score *= -1;
        return score;
    }
    
    double CalculateAdxSlope()
    {
        return m_adx_main_buf[0] - m_adx_main_buf[2];
    }

    bool DetectDivergence(const MqlRates &rates[], const double &rsi_buf[])
    {
        if(m_structure_analyzer == NULL) return false;
        SwingPoint highs[], lows[];
        int highs_count = m_structure_analyzer.GetSwingHighs(highs);
        int lows_count = m_structure_analyzer.GetSwingLows(lows);
        if(highs_count < 2 || lows_count < 2) return false;

        SwingPoint h1 = highs[0];
        SwingPoint h2 = highs[1];
        SwingPoint l1 = lows[0];
        SwingPoint l2 = lows[1];

        // Note: bar_index is from a non-series array. We need to convert it for the series array.
        int rsi_h1_idx = h1.bar_index;
        int rsi_h2_idx = h2.bar_index;
        int rsi_l1_idx = l1.bar_index;
        int rsi_l2_idx = l2.bar_index;
        
        if(h1.price > h2.price && rsi_buf[rsi_h1_idx] < rsi_buf[rsi_h2_idx]) return true;
        if(l1.price < l2.price && rsi_buf[rsi_l1_idx] > rsi_buf[rsi_l2_idx]) return true;
        return false;
    }

    double CalculateHurstExponent(const MqlRates &rates[])
    {
        if(ArraySize(rates) < m_hurst_window)
        {
            return m_last_hurst;
        }

        double log_returns[];
        ArrayResize(log_returns, m_hurst_window - 1, 100);
        for(int i = 0; i < m_hurst_window - 1; i++)
        {
            if(rates[i].close > 0 && rates[i+1].close > 0) 
                log_returns[i] = MathLog(rates[i+1].close / rates[i].close);
            else 
                log_returns[i] = 0;
        }

        int n = ArraySize(log_returns);
        if(n < 16) return m_last_hurst;

        double mean = 0;
        for(int i = 0; i < n; i++) mean += log_returns[i];
        mean /= n;

        double cum_dev = 0, max_dev = 0, min_dev = 0, std_dev_sum_sq = 0;
        for(int i = 0; i < n; i++)
        {
            double dev = log_returns[i] - mean;
            cum_dev += dev;
            max_dev = MathMax(max_dev, cum_dev);
            min_dev = MathMin(min_dev, cum_dev);
            std_dev_sum_sq += dev * dev;
        }
        double std_dev = (std_dev_sum_sq > 0) ? MathSqrt(std_dev_sum_sq / n) : 0;
        if(std_dev == 0) return 0.5;

        double rs = (max_dev - min_dev) / std_dev;
        if(rs <= 0 || n <= 1) return m_last_hurst;

        m_last_hurst = MathLog(rs) / MathLog(n);
        return m_last_hurst;
    }

public:
    CMomentumAnalyzer() : m_adx_handle(INVALID_HANDLE), m_rsi_handle(INVALID_HANDLE), m_structure_analyzer(NULL),
                          m_adx_threshold(25.0), m_logger(NULL), m_last_hurst(0.5) {}
    ~CMomentumAnalyzer()
    {
        if(m_adx_handle != INVALID_HANDLE) IndicatorRelease(m_adx_handle);
        if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
    }

    bool Initialize(const string symbol, const ENUM_TIMEFRAMES period, CStructureAnalyzer &structure_analyzer, CLogManager &logger,
                    const int adx_period=14, const int rsi_period=14, const int hurst_window=252)
    {
        m_symbol = symbol;
        m_period = period;
        m_structure_analyzer = &structure_analyzer;
        m_logger = &logger;
        m_adx_period = adx_period;
        m_rsi_period = rsi_period;
        m_hurst_window = hurst_window;

        m_adx_handle = iADX(m_symbol, m_period, m_adx_period);
        m_rsi_handle = iRSI(m_symbol, m_period, m_rsi_period, PRICE_CLOSE);
        if(m_adx_handle == INVALID_HANDLE || m_rsi_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل ADX یا RSI ناموفق");
            return false;
        }
        return true;
    }
    
    int GetAdxHandle() const { return m_adx_handle; }
    int GetRsiHandle() const { return m_rsi_handle; }

    MomentumResult Analyze(const MqlRates &rates[], const double &adx_buf[], const double &plus_di_buf[], 
                           const double &minus_di_buf[], const double &rsi_buf[])
    {
        MomentumResult result = {0, false, 0.5, false};
        if(ArraySize(adx_buf) < 3) return result;

        m_adx_main_buf[0] = adx_buf[0];
        m_adx_main_buf[1] = adx_buf[1];
        m_adx_main_buf[2] = adx_buf[2];
        m_adx_plus_di_buf[0] = plus_di_buf[0];
        m_adx_minus_di_buf[0] = minus_di_buf[0];
        
        CalculateAdaptiveAdxThreshold(adx_buf);
        double adx_score = CalculateAdxScore();
        double hurst = CalculateHurstExponent(rates);
        result.hurst_exponent = hurst;

        double hurst_factor = (hurst - 0.5) * 200.0;
        if(m_adx_plus_di_buf[0] < m_adx_minus_di_buf[0]) hurst_factor *= -1;

        result.score = (adx_score * 0.7) + (hurst_factor * 0.3); // ✅ تغییر وزن
        bool adx_exhaustion = (m_adx_main_buf[0] > 40 && CalculateAdxSlope() < 0);
        bool divergence_found = DetectDivergence(rates, rsi_buf);
        result.exhaustion_signal = adx_exhaustion || divergence_found;
        result.is_conflicting = (m_adx_main_buf[0] > m_adx_threshold) != (hurst > 0.55);

        return result;
    }
};

// کامنت فارسی: کلاس تحلیل نوسانات بازار
class CVolatilityAnalyzer
{
private:
    string             m_symbol;
    ENUM_TIMEFRAMES    m_period;
    int                m_bb_period;
    double             m_bb_deviation;
    int                m_lookback_period;
    int                m_atr_period;
    double             m_squeeze_percentile;
    double             m_expansion_percentile;
    double             m_atr_confirm_factor;
    int                m_bb_handle;
    int                m_atr_handle;
    double             m_bbw_history[];
    CLogManager* m_logger;

public:
    CVolatilityAnalyzer() : m_bb_handle(INVALID_HANDLE), m_atr_handle(INVALID_HANDLE),
                            m_squeeze_percentile(10.0), m_expansion_percentile(90.0), m_atr_confirm_factor(0.8), m_logger(NULL) {}
    ~CVolatilityAnalyzer()
    {
        if(m_bb_handle != INVALID_HANDLE) IndicatorRelease(m_bb_handle);
        if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
    }

    bool Initialize(const string symbol, const ENUM_TIMEFRAMES period, CLogManager &logger, const int bb_period=20, const double bb_dev=2.0,
                    const int lookback=252, const int atr_period=14, const double squeeze_percentile=10.0,
                    const double expansion_percentile=90.0, const double atr_confirm_factor=0.8)
    {
        m_symbol = symbol;
        m_period = period;
        m_logger = &logger;
        m_bb_period = bb_period;
        m_bb_deviation = bb_dev;
        m_lookback_period = lookback;
        m_atr_period = atr_period;
        m_squeeze_percentile = squeeze_percentile;
        m_expansion_percentile = expansion_percentile;
        m_atr_confirm_factor = atr_confirm_factor;

        m_bb_handle = iBands(m_symbol, m_period, m_bb_period, 0, m_bb_deviation, PRICE_CLOSE);
        m_atr_handle = iATR(m_symbol, m_period, m_atr_period);
        if(m_bb_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل BB یا ATR ناموفق");
            return false;
        }
        return true;
    }

    int GetBBHandle() const { return m_bb_handle; }
    int GetAtrHandle() const { return m_atr_handle; }

    ENUM_VOLATILITY_STATE Analyze(const double &upper_buf[], const double &lower_buf[], const double &middle_buf[], const double &atr_buf[])
    {
        if(ArraySize(middle_buf) < m_lookback_period) return VOLATILITY_NORMAL;

        ArrayResize(m_bbw_history, m_lookback_period, 100);
        for(int i = 0; i < m_lookback_period; i++)
        {
            m_bbw_history[i] = middle_buf[i] > 0 ? (upper_buf[i] - lower_buf[i]) / middle_buf[i] : 0;
        }

        double current_bbw = m_bbw_history[0];
        if(m_lookback_period <= 1) return VOLATILITY_NORMAL;
        
        int count_less = 0;
        for(int i = 1; i < m_lookback_period; i++)
        {
            if(m_bbw_history[i] < current_bbw) count_less++;
        }

        double percentile_rank = (double)count_less / (m_lookback_period - 1) * 100.0;
        if(ArraySize(atr_buf) < m_bb_period + 1) return VOLATILITY_NORMAL;

        double sum_atr = 0;
        for(int i = 1; i <= m_bb_period; i++) sum_atr += atr_buf[i];
        double atr_ma = sum_atr / m_bb_period;
        if(atr_ma == 0) return VOLATILITY_NORMAL;

        bool atr_confirms_squeeze = (atr_buf[0] < atr_ma * m_atr_confirm_factor);

        if(percentile_rank < m_squeeze_percentile && atr_confirms_squeeze) return VOLATILITY_SQUEEZE;
        if(percentile_rank > m_expansion_percentile) return VOLATILITY_EXPANSION;
        
        return VOLATILITY_NORMAL;
    }
};

// کامنت فارسی: کلاس اعتبارسنجی شکست‌ها با تأیید چند تایم‌فریمی
class CBreakoutValidator
{
private:
    string             m_symbol;
    ENUM_TIMEFRAMES    m_period;
    int                m_ema_period_mtf;
    int                m_rsi_period;
    int                m_ema_handle_mtf;
    int                m_rsi_handle;
    double             m_weight_mtf_confirmation;
    double             m_weight_price_action;
    double             m_weight_momentum;
    double             m_weight_follow_through;
    double             m_body_ratio_high;
    double             m_body_ratio_medium;
    double             m_rsi_cross_level;
    double             m_last_bvs;
    CLogManager* m_logger;

    double GetMtfConfirmationScore(const bool is_bullish, const ENUM_TIMEFRAMES htf_period)
    {
        MqlRates htf_rates[];
        if(CopyRates(m_symbol, htf_period, 1, 1, htf_rates) < 1) return 0;
        
        double ema_buf[];
        if(CopyBuffer(m_ema_handle_mtf, 0, 1, 1, ema_buf) < 1) return 0;
        
        double close_price = htf_rates[0].close;
        double ema_value = ema_buf[0];

        if(is_bullish && close_price > ema_value) return m_weight_mtf_confirmation;
        if(!is_bullish && close_price < ema_value) return m_weight_mtf_confirmation;

        return 0;
    }
    
    double GetPriceActionScore(const int index, const bool is_bullish, const MqlRates &rates[])
    {
        if(index >= ArraySize(rates)) return 0;

        double range = rates[index].high - rates[index].low;
        if(range == 0) return 0;
        double body = MathAbs(rates[index].close - rates[index].open);
        double body_ratio = body / range;
        double close_pos = is_bullish ? (rates[index].close - rates[index].low) / range : (rates[index].high - rates[index].close) / range;

        if(body_ratio > m_body_ratio_high && close_pos > 0.7) return m_weight_price_action;
        if(body_ratio > m_body_ratio_medium && close_pos > 0.5) return m_weight_price_action * 0.5;
        return 0;
    }
    
    double GetMomentumScore(const int index, const bool is_bullish, const double &rsi_buf[])
    {
        if(index >= ArraySize(rsi_buf)) return 0;

        double rsi = rsi_buf[index];
        if(is_bullish && rsi > m_rsi_cross_level)
            return MathMin(m_weight_momentum, (rsi - m_rsi_cross_level) / (100 - m_rsi_cross_level) * m_weight_momentum);
        if(!is_bullish && rsi < m_rsi_cross_level)
            return MathMin(m_weight_momentum, (m_rsi_cross_level - rsi) / m_rsi_cross_level * m_weight_momentum);
        return 0;
    }

    double GetFollowThroughScore(const int index, const double breakout_level, const bool is_bullish, const MqlRates &rates[])
    {
        if(index >= ArraySize(rates)) return 0;

        if(is_bullish && rates[index].low > breakout_level) return m_weight_follow_through;
        if(!is_bullish && rates[index].high < breakout_level) return m_weight_follow_through;
        return 0;
    }

public:
    CBreakoutValidator() : m_ema_handle_mtf(INVALID_HANDLE), m_rsi_handle(INVALID_HANDLE), m_last_bvs(0),
                           m_ema_period_mtf(50), m_rsi_period(14),
                           m_weight_mtf_confirmation(4.0), m_weight_price_action(3.0), m_weight_momentum(2.0),
                           m_weight_follow_through(1.0), m_body_ratio_high(0.7), m_body_ratio_medium(0.5),
                           m_rsi_cross_level(50.0), m_logger(NULL) {}
    ~CBreakoutValidator()
    {
        if(m_ema_handle_mtf != INVALID_HANDLE) IndicatorRelease(m_ema_handle_mtf);
        if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
    }

    bool Initialize(const string symbol, const ENUM_TIMEFRAMES period, CLogManager &logger, const int ema_period_mtf=50,
                    const int rsi_period=14, const double weight_mtf_confirmation=4.0,
                    const double weight_price_action=3.0, const double weight_momentum=2.0, const double weight_follow_through=1.0,
                    const double body_ratio_high=0.7, const double body_ratio_medium=0.5, const double rsi_cross_level=50.0)
    {
        m_symbol = symbol;
        m_period = period;
        m_logger = &logger;
        m_ema_period_mtf = ema_period_mtf;
        m_rsi_period = rsi_period;
        m_weight_mtf_confirmation = weight_mtf_confirmation;
        m_weight_price_action = weight_price_action;
        m_weight_momentum = weight_momentum;
        m_weight_follow_through = weight_follow_through;
        m_body_ratio_high = body_ratio_high;
        m_body_ratio_medium = body_ratio_medium;
        m_rsi_cross_level = rsi_cross_level;

        m_rsi_handle = iRSI(m_symbol, m_period, m_rsi_period, PRICE_CLOSE);
        if(m_rsi_handle == INVALID_HANDLE) return false;
        
        return true;
    }
    
    int GetRsiHandle() const { return m_rsi_handle; }

    bool SetMtfEmaHandle(const ENUM_TIMEFRAMES htf_period)
    {
        if(m_ema_handle_mtf != INVALID_HANDLE) 
            IndicatorRelease(m_ema_handle_mtf);
            
        m_ema_handle_mtf = iMA(m_symbol, htf_period, m_ema_period_mtf, 0, MODE_EMA, PRICE_CLOSE);
        if(m_ema_handle_mtf == INVALID_HANDLE) return false;
        
        return true;
    }

    double CalculateBVS(const int breakout_candle_index, const bool is_bullish_breakout, const double breakout_level,
                        const MqlRates &rates[], const double &rsi_buf[], const ENUM_TIMEFRAMES htf_period)
    {
        double score = 0;
        score += GetMtfConfirmationScore(is_bullish_breakout, htf_period);
        score += GetPriceActionScore(breakout_candle_index, is_bullish_breakout, rates);
        score += GetMomentumScore(breakout_candle_index, is_bullish_breakout, rsi_buf);
        score += GetFollowThroughScore(breakout_candle_index - 1, breakout_level, is_bullish_breakout, rates);
        m_last_bvs = MathMin(10.0, score);
        return m_last_bvs;
    }
};

// کامنت فارسی: کلاس نمایش رژیم بازار روی چارت
class CRegimeVisualizer
{
private:
    string             m_symbol;
    ENUM_TIMEFRAMES    m_period;
    string             m_object_name;
    int                m_offset_x;
    int                m_offset_y;
    int                m_font_size;
    string             m_font_name;
    CLogManager* m_logger;

    void GetRegimeTextAndColor(const ENUM_MARKET_REGIME regime, string &text, color &clr)
    {
        switch(regime)
        {
            case REGIME_STRONG_BULL_TREND:
            case REGIME_AVERAGE_BULL_TREND:
            case REGIME_BULL_TREND_EXHAUSTION:
            case REGIME_PROBABLE_BULLISH_REVERSAL:
            case REGIME_BULLISH_BREAKOUT_CONFIRMED:
                text = EnumToString(regime); clr = clrLime; break;
            case REGIME_STRONG_BEAR_TREND:
            case REGIME_AVERAGE_BEAR_TREND:
            case REGIME_BEAR_TREND_EXHAUSTION:
            case REGIME_PROBABLE_BEARISH_REVERSAL:
            case REGIME_BEARISH_BREAKOUT_CONFIRMED:
                text = EnumToString(regime); clr = clrRed; break;
            case REGIME_RANGE_CONSOLIDATION:
            case REGIME_VOLATILITY_SQUEEZE:
                text = EnumToString(regime); clr = clrGoldenrod; break;
            case REGIME_PROBABLE_FAKEOUT:
                text = EnumToString(regime); clr = clrOrange; break;
            default:
                text = "UNDEFINED"; clr = clrGray; break;
        }
    }

public:
    CRegimeVisualizer() : m_object_name("MarketRegimeText"), m_offset_x(20), m_offset_y(20),
                          m_font_size(12), m_font_name("Arial"), m_logger(NULL) {}
    ~CRegimeVisualizer() { ObjectsDeleteAll(0, m_object_name); }

    bool Initialize(const string symbol, const ENUM_TIMEFRAMES period, CLogManager &logger)
    {
        m_symbol = symbol;
        m_period = period;
        m_logger = &logger;
        ObjectsDeleteAll(0, m_object_name);
        return true;
    }

    void Update(const RegimeResult &result)
    {
        string text;
        color clr;
        GetRegimeTextAndColor(result.regime, text, clr);
        text = StringFormat("%s (Conf: %.2f)", text, result.confidenceScore);

        if(ObjectFind(0, m_object_name) < 0)
        {
            ObjectCreate(0, m_object_name, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, m_object_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
            ObjectSetInteger(0, m_object_name, OBJPROP_XDISTANCE, m_offset_x);
            ObjectSetInteger(0, m_object_name, OBJPROP_YDISTANCE, m_offset_y);
            ObjectSetInteger(0, m_object_name, OBJPROP_FONTSIZE, m_font_size);
            ObjectSetString(0, m_object_name, OBJPROP_FONT, m_font_name);
        }

        ObjectSetString(0, m_object_name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, m_object_name, OBJPROP_COLOR, clr);
        ChartRedraw(0);
    }
};

//+------------------------------------------------------------------+
//| CMarketRegimeEngine (نسخه ۲.۲ - نهایی و بازنویسی شده)             |
//+------------------------------------------------------------------+
// کامنت فارسی: کلاس اصلی موتور تشخیص رژیم بازار
class CMarketRegimeEngine
{
private:
    CStructureAnalyzer   m_structure;
    CMomentumAnalyzer    m_momentum;
    CVolatilityAnalyzer  m_volatility;
    CBreakoutValidator   m_breakout;
    CRegimeVisualizer    m_visualizer;
    CLogManager          m_logger;
    bool                 m_is_initialized;
    ENUM_TIMEFRAMES      m_period;
    RegimeResult         m_last_result;
    datetime             m_last_analysis_time;
    ENUM_STRUCTURE_STATE m_last_structure_state;
    double               m_last_breakout_level;
    bool                 m_pending_follow_through;
    double               m_momentum_strong_threshold;
    double               m_momentum_average_threshold;
    double               m_bvs_high_prob;
    double               m_bvs_fakeout;
    MqlRates             m_rates_buf[];
    double               m_atr_structure_buf[];
    double               m_atr_volatility_buf[];
    double               m_adx_main_buf[];
    double               m_adx_plus_di_buf[];
    double               m_adx_minus_di_buf[];
    double               m_rsi_buf[];
    double               m_bb_upper_buf[];
    double               m_bb_lower_buf[];
    double               m_bb_middle_buf[];
    double               m_structure_weight;
    double               m_momentum_weight;
    double               m_volatility_weight;
    double               m_bvs_weight;

    ENUM_TIMEFRAMES GetHigherOrderflowTimeframe(const ENUM_TIMEFRAMES current_period)
    {
        switch(current_period)
        {
            case PERIOD_M1:  return PERIOD_M5;
            case PERIOD_M5:  return PERIOD_M15;
            case PERIOD_M15: return PERIOD_H1;
            case PERIOD_M30: return PERIOD_H4;
            case PERIOD_H1:  return PERIOD_H4;
            case PERIOD_H4:  return PERIOD_D1;
            case PERIOD_D1:  return PERIOD_W1;
            case PERIOD_W1:  return PERIOD_MN1;
            default:         return current_period;
        }
    }

    RegimeResult DetermineFinalRegime(const ENUM_STRUCTURE_STATE structure, const MomentumResult &momentum,
                                     const ENUM_VOLATILITY_STATE volatility, double bvs)
    {
        RegimeResult result;
        result.analysisTime = TimeCurrent();
        result.confidenceScore = 0;
        result.regime = REGIME_UNDEFINED;
        
        if(momentum.is_conflicting)
        {
            result.reasoning = "Signal Conflict between ADX and Hurst.";
            return result;
        }
        
        if(structure == STRUCTURE_UPTREND_BOS)
        {
            if(momentum.score > m_momentum_strong_threshold && !momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
                result.regime = REGIME_STRONG_BULL_TREND;
            else if(momentum.score > m_momentum_average_threshold && !momentum.exhaustion_signal)
                result.regime = REGIME_AVERAGE_BULL_TREND;
            else
                result.regime = REGIME_BULL_TREND_EXHAUSTION;
        }
        else if(structure == STRUCTURE_DOWNTREND_BOS)
        {
            if(momentum.score < -m_momentum_strong_threshold && !momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
                result.regime = REGIME_STRONG_BEAR_TREND;
            else if(momentum.score < -m_momentum_average_threshold && !momentum.exhaustion_signal)
                result.regime = REGIME_AVERAGE_BEAR_TREND;
            else
                result.regime = REGIME_BEAR_TREND_EXHAUSTION;
        }
        else if(structure == STRUCTURE_CONSOLIDATION_RANGE)
        {
            if(MathAbs(momentum.score) < m_momentum_average_threshold)
            {
                if(volatility == VOLATILITY_SQUEEZE)
                    result.regime = REGIME_VOLATILITY_SQUEEZE;
                else
                    result.regime = REGIME_RANGE_CONSOLIDATION;
            }
        }
        else if(structure == STRUCTURE_BEARISH_CHoCH)
        {
            if(momentum.score < 0 && momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
                result.regime = REGIME_PROBABLE_BEARISH_REVERSAL;
        }
        else if(structure == STRUCTURE_BULLISH_CHoCH)
        {
            if(momentum.score > 0 && momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
                result.regime = REGIME_PROBABLE_BULLISH_REVERSAL;
        }

        if(bvs > 0)
        {
            bool is_bullish = momentum.score > 0;
            if(bvs > m_bvs_high_prob && MathAbs(momentum.score) > m_momentum_average_threshold && volatility == VOLATILITY_EXPANSION)
                result.regime = is_bullish ? REGIME_BULLISH_BREAKOUT_CONFIRMED : REGIME_BEARISH_BREAKOUT_CONFIRMED;
            else if(bvs < m_bvs_fakeout)
                result.regime = REGIME_PROBABLE_FAKEOUT;
        }

        return result;
    }

    double CalculateConfidenceScore(const ENUM_STRUCTURE_STATE structure, const MomentumResult &momentum,
                                   const ENUM_VOLATILITY_STATE volatility, const double &bvs)
    {
        double structure_norm = (structure == STRUCTURE_BEARISH_CHoCH || structure == STRUCTURE_BULLISH_CHoCH) ? 0.8 :
                               (structure == STRUCTURE_CONSOLIDATION_RANGE ? 0.7 : 1.0);
        if(structure == STRUCTURE_UNDEFINED) structure_norm = 0;
        
        double momentum_norm = MathAbs(momentum.score) / 100.0;
        if(momentum.exhaustion_signal) momentum_norm *= 0.9;
        
        double volatility_norm = (volatility == VOLATILITY_NORMAL) ? 0.5 : 1.0;
        double bvs_norm = (bvs > 0) ? bvs / 10.0 : 0.0;

        double total_weight = m_structure_weight + m_momentum_weight;
        double score = (m_structure_weight * structure_norm + m_momentum_weight * momentum_norm);
        
        if(bvs > 0)
        {
            total_weight += m_bvs_weight;
            score += m_bvs_weight * bvs_norm;
        }
        else
        {
            total_weight += m_volatility_weight;
            score += m_volatility_weight * volatility_norm;
        }

        return (total_weight > 0) ? score / total_weight : 0;
    }

public:
    CMarketRegimeEngine() : m_is_initialized(false), m_period(PERIOD_CURRENT), m_last_analysis_time(0),
                            m_last_structure_state(STRUCTURE_UNDEFINED), m_last_breakout_level(0), m_pending_follow_through(false),
                            m_momentum_strong_threshold(70.0), m_momentum_average_threshold(40.0),
                            m_bvs_high_prob(7.0), m_bvs_fakeout(4.0),
                            m_structure_weight(0.4), m_momentum_weight(0.4), m_volatility_weight(0.2), m_bvs_weight(0.2) {}
    
    bool Initialize(const string symbol, const ENUM_TIMEFRAMES analysis_period, const bool enable_logging,
                    const int fractal_n=2, const double consolidation_factor=4.0, const int atr_period_consolidation=50,
                    const double fractal_atr_filter_factor=0.5, const int adx_period=14, const int rsi_period=14,
                    const int hurst_window=252, const int bb_period=20,
                    const double bb_dev=2.0, const int lookback=252, const int atr_period=14,
                    const double squeeze_percentile=10.0, const double expansion_percentile=90.0,
                    const double atr_confirm_factor=0.8, const int ema_period_mtf=50,
                    const double weight_mtf_confirmation=4.0, const double weight_price_action=3.0,
                    const double weight_momentum=2.0, const double weight_follow_through=1.0,
                    const double body_ratio_high=0.7, const double body_ratio_medium=0.5,
                    const double rsi_cross_level=50.0, const double momentum_strong_threshold=70.0,
                    const double momentum_average_threshold=40.0, const double bvs_high_prob=7.0,
                    const double bvs_fakeout=4.0, const double structure_weight=0.4,
                    const double momentum_weight=0.4, const double volatility_weight=0.2, const double bvs_weight=0.2)
    {
        m_period = analysis_period;
        m_logger.Initialize(symbol, m_period, enable_logging);
        if(!m_structure.Initialize(symbol, m_period, m_logger, fractal_n, consolidation_factor, atr_period_consolidation, fractal_atr_filter_factor))
            return false;
        if(!m_momentum.Initialize(symbol, m_period, m_structure, m_logger, adx_period, rsi_period, hurst_window))
            return false;
        if(!m_volatility.Initialize(symbol, m_period, m_logger, bb_period, bb_dev, lookback, atr_period, squeeze_percentile, expansion_percentile, atr_confirm_factor))
            return false;
        if(!m_breakout.Initialize(symbol, m_period, m_logger, ema_period_mtf, rsi_period, weight_mtf_confirmation,
                                  weight_price_action, weight_momentum, weight_follow_through, body_ratio_high, body_ratio_medium, rsi_cross_level))
            return false;
        if(!m_breakout.SetMtfEmaHandle(GetHigherOrderflowTimeframe(m_period)))
            return false;
        if(!m_visualizer.Initialize(symbol, m_period, m_logger))
            return false;
            
        m_momentum_strong_threshold = momentum_strong_threshold;
        m_momentum_average_threshold = momentum_average_threshold;
        m_bvs_high_prob = bvs_high_prob;
        m_bvs_fakeout = bvs_fakeout;
        m_structure_weight = structure_weight;
        m_momentum_weight = momentum_weight;
        m_volatility_weight = volatility_weight;
        m_bvs_weight = bvs_weight;
        m_is_initialized = true;
        m_logger.Log("موتور رژیم بازار با موفقیت راه‌اندازی شد");
        return true;
    }

    bool ProcessNewBar()
    {
        if(!m_is_initialized) return false;

        datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, m_period, SERIES_LASTBAR_DATE);
        if(current_bar_time == m_last_analysis_time) return false;
          
        const int bars_to_process = 500;
        ArraySetAsSeries(m_rates_buf, false);
        if(CopyRates(_Symbol, m_period, 0, bars_to_process, m_rates_buf) < bars_to_process) return false;
        
        ArraySetAsSeries(m_atr_structure_buf, true);
        if(CopyBuffer(m_structure.GetAtrHandle(), 0, 0, bars_to_process, m_atr_structure_buf) < bars_to_process) return false;
        
        ArraySetAsSeries(m_atr_volatility_buf, true);
        if(CopyBuffer(m_volatility.GetAtrHandle(), 0, 0, bars_to_process, m_atr_volatility_buf) < bars_to_process) return false;
        
        ArraySetAsSeries(m_adx_main_buf, true);
        ArraySetAsSeries(m_adx_plus_di_buf, true);
        ArraySetAsSeries(m_adx_minus_di_buf, true);
        if(CopyBuffer(m_momentum.GetAdxHandle(), 0, 0, bars_to_process, m_adx_main_buf) < bars_to_process ||
           CopyBuffer(m_momentum.GetAdxHandle(), 1, 0, bars_to_process, m_adx_plus_di_buf) < bars_to_process ||
           CopyBuffer(m_momentum.GetAdxHandle(), 2, 0, bars_to_process, m_adx_minus_di_buf) < bars_to_process) return false;
        
        ArraySetAsSeries(m_rsi_buf, true);
        if(CopyBuffer(m_breakout.GetRsiHandle(), 0, 0, bars_to_process, m_rsi_buf) < bars_to_process) return false;
        
        ArraySetAsSeries(m_bb_upper_buf, true);
        ArraySetAsSeries(m_bb_lower_buf, true);
        ArraySetAsSeries(m_bb_middle_buf, true);
        if(CopyBuffer(m_volatility.GetBBHandle(), 1, 0, bars_to_process, m_bb_upper_buf) < bars_to_process ||
           CopyBuffer(m_volatility.GetBBHandle(), 2, 0, bars_to_process, m_bb_lower_buf) < bars_to_process ||
           CopyBuffer(m_volatility.GetBBHandle(), 0, 0, bars_to_process, m_bb_middle_buf) < bars_to_process) return false;
            
        // ✅ اصلاح اندیس‌گذاری برای بافرهای سری زمانی
        MqlRates rates_for_analysis[];
        ArrayCopy(rates_for_analysis, m_rates_buf);
        ArraySetAsSeries(rates_for_analysis, true);

        ENUM_STRUCTURE_STATE structure = m_structure.Analyze(rates_for_analysis, m_atr_structure_buf, bars_to_process);
        MomentumResult momentum = m_momentum.Analyze(rates_for_analysis, m_adx_main_buf, m_adx_plus_di_buf, m_adx_minus_di_buf, m_rsi_buf);
        ENUM_VOLATILITY_STATE volatility = m_volatility.Analyze(m_bb_upper_buf, m_bb_lower_buf, m_bb_middle_buf, m_atr_volatility_buf);
        double bvs = 0;
        bool is_breakout_event = (m_last_structure_state == STRUCTURE_CONSOLIDATION_RANGE) &&
                                 (structure != STRUCTURE_CONSOLIDATION_RANGE && structure != STRUCTURE_UNDEFINED);

        double breakout_level = 0;
        if(is_breakout_event)
        {
            bool is_bullish = (structure == STRUCTURE_UPTREND_BOS || structure == STRUCTURE_BULLISH_CHoCH);
            SwingPoint swings[];
            if(is_bullish)
            {
                m_structure.GetSwingHighs(swings);
                if(ArraySize(swings) > 0) breakout_level = swings[0].price;
            }
            else
            {
                m_structure.GetSwingLows(swings);
                if(ArraySize(swings) > 0) breakout_level = swings[0].price;
            }
            bvs = m_breakout.CalculateBVS(1, is_bullish, breakout_level, m_rates_buf, m_rsi_buf, GetHigherOrderflowTimeframe(m_period));
            m_last_breakout_level = breakout_level;
            m_pending_follow_through = true;
        }
        else if(m_pending_follow_through)
        {
            bool is_bullish = (m_last_result.regime == REGIME_BULLISH_BREAKOUT_CONFIRMED);
            bvs = m_breakout.CalculateBVS(0, is_bullish, m_last_breakout_level, m_rates_buf, m_rsi_buf, GetHigherOrderflowTimeframe(m_period));
            m_pending_follow_through = false;
        }

        m_last_result = DetermineFinalRegime(structure, momentum, volatility, bvs);
        m_last_result.confidenceScore = CalculateConfidenceScore(structure, momentum, volatility, bvs);
        m_visualizer.Update(m_last_result);
        m_last_analysis_time = current_bar_time;
        m_last_structure_state = structure;
        return true;
    }

    RegimeResult GetLastResult() const { return m_last_result; }
};
