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
//|                      Version: 2.2                          |
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
    int      bar_index;    // اندیس کندل
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
    STRUCTURE_BREAKOUT_FROM_RANGE,  // شکست از رنج
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

// کامنت فارسی: کلاس تحلیل ساختار بازار برای شناسایی نقاط چرخش و //+------------------------------------------------------------------+
//| (نسخه کاملاً اصلاح شده با منطق صحیح اندیس‌گذاری)                   |
//+------------------------------------------------------------------+
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

    // ✅✅✅ تابع بازنویسی شده برای یافتن نقاط چرخش با آرایه سریالی (Series Array) ✅✅✅
    void FindSwingPoints(const MqlRates &rates[], const double &atr_buf[], const int bars_to_check)
    {
        long current_bar_time = (long)rates[0].time;
        if(current_bar_time == m_last_processed_bar_time && ArraySize(m_swing_highs) > 0) return;

        ArrayFree(m_swing_highs);
        ArrayFree(m_swing_lows);

        // حلقه از کندل‌های اخیر به سمت کندل‌های قدیمی‌تر حرکت می‌کند (مناسب برای آرایه سریالی)
        for(int i = m_fractal_n; i < bars_to_check - m_fractal_n; i++)
        {
            bool is_swing_high = true;
            bool is_swing_low = true;

            // چک کردن کندل‌های اطراف برای پیدا کردن فرکتال
            for(int j = 1; j <= m_fractal_n; j++)
            {
                // rates[i] کندل مرکزی است
                // rates[i-j] کندل‌های جدیدتر (به سمت چپ) هستند
                // rates[i+j] کندل‌های قدیمی‌تر (به سمت راست) هستند
                if(rates[i].high <= rates[i-j].high || rates[i].high < rates[i+j].high) // برای سقف، از سقف‌های قدیمی‌تر باید اکیدا بزرگتر باشد
                    is_swing_high = false;
                if(rates[i].low >= rates[i-j].low || rates[i].low > rates[i+j].low) // برای کف، از کف‌های قدیمی‌تر باید اکیدا کوچکتر باشد
                    is_swing_low = false;
            }

            if(is_swing_high)
            {
                SwingPoint sh;
                sh.time = rates[i].time;
                sh.price = rates[i].high;
                sh.bar_index = i; // اندیس سریالی (0 = کندل فعلی)
                int size = ArraySize(m_swing_highs);
                ArrayResize(m_swing_highs, size + 1);
                m_swing_highs[size] = sh;
            }
            if(is_swing_low)
            {
                SwingPoint sl;
                sl.time = rates[i].time;
                sl.price = rates[i].low;
                sl.bar_index = i; // اندیس سریالی
                int size = ArraySize(m_swing_lows);
                ArrayResize(m_swing_lows, size + 1);
                m_swing_lows[size] = sl;
            }
        }
        m_last_processed_bar_time = current_bar_time;
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
        m_fractal_n = fractal_n > 0 ? fractal_n : 2;
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

    // ✅✅✅ تابع بازنویسی شده برای تحلیل ساختار با دسترسی صحیح به نقاط چرخش ✅✅✅
    ENUM_STRUCTURE_STATE Analyze(const MqlRates &rates[], const double &atr_buf[], const int bars_to_process)
    {
        FindSwingPoints(rates, atr_buf, bars_to_process);
        int highs_count = ArraySize(m_swing_highs);
        int lows_count = ArraySize(m_swing_lows);

        if(highs_count < 2 || lows_count < 2) return STRUCTURE_UNDEFINED;

        // چون نقاط از جدید به قدیم پیدا شدند، اندیس 0 جدیدترین و اندیس 1 ماقبل آخر است
        SwingPoint last_h = m_swing_highs[0];
        SwingPoint prev_h = m_swing_highs[1];
        SwingPoint last_l = m_swing_lows[0];
        SwingPoint prev_l = m_swing_lows[1];

        double last_swing_range = MathAbs(last_h.price - last_l.price);
        double atr = atr_buf[1]; // ATR کندل قبلی (بسته شده)
        if(atr > 0 && last_swing_range < m_consolidation_factor * atr)
        {
            return STRUCTURE_CONSOLIDATION_RANGE;
        }

        double current_close = rates[1].close; // قیمت بسته شده کندل قبلی
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
    double             m_hurst_threshold;
    int                m_adx_handle;
    int                m_rsi_handle;
    double             m_adx_main_buf[];
    double             m_adx_plus_di_buf[];
    double             m_adx_minus_di_buf[];
    double             m_rsi_buf[];
    CStructureAnalyzer* m_structure_analyzer;
    CLogManager*       m_logger; // هشدار: ریسک Dangling Pointer در صورت مدیریت نادرست چرخه عمر
    double             m_last_hurst;

    // کامنت فارسی: محاسبه آستانه تطبیقی ADX با محدودسازی بازه
    void CalculateAdaptiveAdxThreshold(const double &adx_buf[])
    {
        const int long_window = 500;
        if(ArraySize(adx_buf) < long_window)
        {
            m_adx_threshold = 25.0;
            m_logger.Log("خطا: داده کافی برای محاسبه آستانه ADX موجود نیست");
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
        double stddev = MathSqrt(variance);
        double calculated_adaptive_threshold = avg + 0.5 * stddev;
        m_adx_threshold = fmax(20.0, fmin(45.0, calculated_adaptive_threshold));
        m_logger.Log(StringFormat("آستانه تطبیقی ADX: %.2f", m_adx_threshold));
    }

    // کامنت فارسی: محاسبه امتیاز ADX
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

    // کامنت فارسی: محاسبه شیب ADX برای تشخیص خستگی
    double CalculateAdxSlope()
    {
        return m_adx_main_buf[0] - m_adx_main_buf[2];
    }

    // کامنت فارسی: تشخیص واگرایی RSI با نقاط چرخش
        // ✅✅✅ تابع بازنویسی شده برای تشخیص واگرایی با اندیس‌گذاری ساده شده ✅✅✅
    bool DetectDivergence(const MqlRates &rates[])
    {
        if(m_structure_analyzer == NULL) return false;
        SwingPoint highs[], lows[];
        int highs_count = m_structure_analyzer.GetSwingHighs(highs);
        int lows_count = m_structure_analyzer.GetSwingLows(lows);
        if(highs_count < 2 || lows_count < 2) return false;

        // جدیدترین نقاط چرخش در اندیس 0 و 1 قرار دارند
        SwingPoint h1 = highs[0]; // جدیدترین سقف
        SwingPoint h2 = highs[1]; // سقف ماقبل آخر
        SwingPoint l1 = lows[0];  // جدیدترین کف
        SwingPoint l2 = lows[1];  // کف ماقبل آخر

        // اندیس‌های bar_index الان مستقیم با اندیس آرایه RSI (که سریالی است) مطابقت دارند
        int h1_idx = h1.bar_index;
        int h2_idx = h2.bar_index;
        int l1_idx = l1.bar_index;
        int l2_idx = l2.bar_index;
        
        // اطمینان از اینکه اندیس‌ها در محدوده آرایه RSI هستند
        int max_idx = (int)MathMax(MathMax(h1_idx, h2_idx), MathMax(l1_idx, l2_idx));
        if(max_idx >= ArraySize(m_rsi_buf)) return false;

        // بررسی واگرایی نزولی: سقف بالاتر در قیمت، سقف پایین‌تر در RSI
        if(h1.price > h2.price && m_rsi_buf[h1_idx] < m_rsi_buf[h2_idx]) return true;
        
        // بررسی واگرایی صعودی: کف پایین‌تر در قیمت، کف بالاتر در RSI
        if(l1.price < l2.price && m_rsi_buf[l1_idx] > m_rsi_buf[l2_idx]) return true;
        
        return false;
    }


    // کامنت فارسی: محاسبه توان Hurst به صورت افزایشی
    double CalculateHurstExponent(const MqlRates &rates[])
    {
        if(ArraySize(rates) < m_hurst_window)
        {
            m_logger.Log("خطا: داده کافی برای محاسبه Hurst موجود نیست");
            return m_last_hurst;
        }

        double log_returns[];
        ArrayResize(log_returns, m_hurst_window - 1, 100);
        for(int i = 0; i < m_hurst_window - 1; i++)
        {
            if(rates[i].close > 0) log_returns[i] = MathLog(rates[i+1].close / rates[i].close);
            else log_returns[i] = 0;
        }

        int n = ArraySize(log_returns);
        if(n < 16) return m_last_hurst;

        double cum_dev = 0, max_dev = 0, min_dev = 0, mean = 0;
        for(int i = 0; i < n; i++) mean += log_returns[i];
        mean /= n;

        double std_dev = 0;
        for(int i = 0; i < n; i++)
        {
            double dev = log_returns[i] - mean;
            cum_dev += dev;
            max_dev = MathMax(max_dev, cum_dev);
            min_dev = MathMin(min_dev, cum_dev);
            std_dev += dev * dev;
        }
        std_dev = MathSqrt(std_dev / n);

        double rs = (max_dev - min_dev) / std_dev;
        if(rs <= 0 || n <= 1) return m_last_hurst;

        m_last_hurst = MathLog(rs) / MathLog(n);
        return m_last_hurst;
    }

public:
    CMomentumAnalyzer() : m_adx_handle(INVALID_HANDLE), m_rsi_handle(INVALID_HANDLE), m_structure_analyzer(NULL),
                          m_adx_threshold(25.0), m_hurst_threshold(0.55), m_logger(NULL), m_last_hurst(0.5) {}
    ~CMomentumAnalyzer()
    {
        if(m_adx_handle != INVALID_HANDLE) IndicatorRelease(m_adx_handle);
        if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
    }

    bool Initialize(const string symbol, const ENUM_TIMEFRAMES period, CStructureAnalyzer &structure_analyzer, CLogManager &logger,
                    const int adx_period=14, const int rsi_period=14, const int hurst_window=252, const double hurst_threshold=0.55)
    {
        m_symbol = symbol;
        m_period = period;
        m_structure_analyzer = &structure_analyzer;
        m_logger = &logger;
        m_adx_period = adx_period;
        m_rsi_period = rsi_period;
        m_hurst_window = hurst_window;
        m_hurst_threshold = hurst_threshold;

        m_adx_handle = iADX(m_symbol, m_period, m_adx_period);
        if(m_adx_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل ADX ناموفق");
            return false;
        }

        m_rsi_handle = iRSI(m_symbol, m_period, m_rsi_period, PRICE_CLOSE);
        if(m_rsi_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل RSI ناموفق");
            return false;
        }

        return true;
    }

    // کامنت فارسی: تحلیل مومنتوم و تشخیص خستگی روند
    MomentumResult Analyze(const MqlRates &rates[], const double &adx_buf[], const double &plus_di_buf[], 
                           const double &minus_di_buf[], const double &rsi_buf[])
    {
        MomentumResult result = {0, false, 0.5, false};

        if(ArraySize(adx_buf) < 3 || ArraySize(plus_di_buf) < 3 || ArraySize(minus_di_buf) < 3)
        {
            m_logger.Log("خطا: داده کافی برای تحلیل ADX موجود نیست");
            return result;
        }

        m_adx_main_buf[0] = adx_buf[0];
        m_adx_main_buf[1] = adx_buf[1];
        m_adx_main_buf[2] = adx_buf[2];
        m_adx_plus_di_buf[0] = plus_di_buf[0];
        m_adx_minus_di_buf[0] = minus_di_buf[0];
        ArrayCopy(m_rsi_buf, rsi_buf);

        CalculateAdaptiveAdxThreshold(adx_buf);
        double adx_score = CalculateAdxScore();
        double hurst = CalculateHurstExponent(rates);
        result.hurst_exponent = hurst;

        double hurst_factor = (hurst - 0.5) * 200.0;
        if(m_adx_plus_di_buf[0] < m_adx_minus_di_buf[0]) hurst_factor *= -1;

        result.score = (adx_score * 0.5) + (hurst_factor * 0.5);
        bool adx_exhaustion = (m_adx_main_buf[0] > 40 && CalculateAdxSlope() < 0);
        bool divergence_found = DetectDivergence(rates);
        result.exhaustion_signal = adx_exhaustion || divergence_found;
        result.is_conflicting = (m_adx_main_buf[0] > m_adx_threshold) != (hurst > 0.55);

        m_logger.Log(StringFormat("مومنتوم: امتیاز=%.2f, خستگی=%s, Hurst=%.2f, تضاد=%s",
                                 result.score, result.exhaustion_signal ? "بله" : "خیر", hurst, result.is_conflicting ? "بله" : "خیر"));
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
    CLogManager*       m_logger; // هشدار: ریسک Dangling Pointer در صورت مدیریت نادرست چرخه عمر

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
        if(m_bb_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل Bollinger Bands ناموفق");
            return false;
        }

        m_atr_handle = iATR(m_symbol, m_period, m_atr_period);
        if(m_atr_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل ATR ناموفق");
            return false;
        }
        return true;
    }

    // کامنت فارسی: تحلیل نوسانات با بولینگر و ATR
    ENUM_VOLATILITY_STATE Analyze(const double &upper_buf[], const double &lower_buf[], const double &middle_buf[], const double &atr_buf[])
    {
        if(ArraySize(upper_buf) < m_lookback_period || ArraySize(lower_buf) < m_lookback_period || ArraySize(middle_buf) < m_lookback_period)
        {
            m_logger.Log("خطا: داده کافی برای تحلیل بولینگر موجود نیست");
            return VOLATILITY_NORMAL;
        }

        ArrayResize(m_bbw_history, m_lookback_period, 100);
        for(int i = 0; i < m_lookback_period; i++)
        {
            m_bbw_history[i] = middle_buf[i] > 0 ? (upper_buf[i] - lower_buf[i]) / middle_buf[i] : 0;
        }

        double current_bbw = m_bbw_history[0];
        int count_less = 0;
        for(int i = 1; i < m_lookback_period; i++)
        {
            if(m_bbw_history[i] < current_bbw) count_less++;
        }

        double percentile_rank = (double)count_less / (m_lookback_period - 1) * 100.0;
        if(ArraySize(atr_buf) < m_bb_period + 1)
        {
            m_logger.Log("خطا: داده کافی برای تحلیل ATR موجود نیست");
            return VOLATILITY_NORMAL;
        }

        double sum_atr = 0;
        for(int i = 1; i <= m_bb_period; i++) sum_atr += atr_buf[i];
        double atr_ma = sum_atr / m_bb_period;
        bool atr_confirms_squeeze = (atr_buf[0] < atr_ma * m_atr_confirm_factor);

        if(percentile_rank < m_squeeze_percentile && atr_confirms_squeeze)
        {
            m_logger.Log("نوسانات: فشردگی تشخیص داده شد");
            return VOLATILITY_SQUEEZE;
        }
        if(percentile_rank > m_expansion_percentile)
        {
            m_logger.Log("نوسانات: انبساط تشخیص داده شد");
            return VOLATILITY_EXPANSION;
        }
        m_logger.Log("نوسانات: حالت نرمال");
        return VOLATILITY_NORMAL;
    }
};
//+------------------------------------------------------------------+
//| CBreakoutValidator (نسخه ۲.۲ - بازنویسی کامل)                     |
//+------------------------------------------------------------------+
// کامنت فارسی: کلاس اعتبارسنجی شکست‌ها با تأیید چند تایم‌فریمی
class CBreakoutValidator
{
private:
    string             m_symbol;
    ENUM_TIMEFRAMES    m_period;
    int                m_ema_period_mtf;    // دوره EMA برای تأیید چند تایم‌فریمی
    int                m_rsi_period;
    int                m_ema_handle_mtf;   // هندل EMA برای تایم‌فریم بالاتر
    int                m_rsi_handle;
    double             m_weight_mtf_confirmation; // وزن تأیید چند تایم‌فریمی
    double             m_weight_price_action;
    double             m_weight_momentum;
    double             m_weight_follow_through;
    double             m_body_ratio_high;
    double             m_body_ratio_medium;
    double             m_rsi_cross_level;
    double             m_last_bvs;
    CLogManager* m_logger;

    // کامنت فارسی: محاسبه امتیاز تأیید چند تایم‌فریمی با EMA در تایم‌فریم بالاتر (نسخه امن و بدون ریپینت)
    double GetMtfConfirmationScore(const bool is_bullish, const ENUM_TIMEFRAMES htf_period)
    {
        // بارگذاری داده‌های کندل بسته شده قبلی (شیفت ۱) از تایم‌فریم بالاتر
        MqlRates htf_rates[];
        if(CopyRates(m_symbol, htf_period, 1, 1, htf_rates) < 1)
        {
            m_logger.Log("خطا: داده قیمت برای تایم‌فریم بالاتر موجود نیست");
            return 0;
        }
        
        // بارگذاری داده‌های EMA از کندل بسته شده قبلی (شیفت ۱) از تایم‌فریم بالاتر
        double ema_buf[];
        if(CopyBuffer(m_ema_handle_mtf, 0, 1, 1, ema_buf) < 1)
        {
            m_logger.Log("خطا: داده EMA برای تایم‌فریم بالاتر موجود نیست");
            return 0;
        }
        
        double close_price = htf_rates[0].close;
        double ema_value = ema_buf[0];

        // بررسی تأیید روند در تایم‌فریم بالاتر
        if(is_bullish && close_price > ema_value)
        {
            m_logger.Log("تأیید MTF: شکست صعودی با قیمت بالای EMA در HTF");
            return m_weight_mtf_confirmation;
        }
        if(!is_bullish && close_price < ema_value)
        {
            m_logger.Log("تأیید MTF: شکست نزولی با قیمت پایین EMA در HTF");
            return m_weight_mtf_confirmation;
        }

        m_logger.Log("عدم تأیید MTF: شکست با روند تایم‌فریم بالاتر همخوانی ندارد");
        return 0;
    }
    
    // ... سایر توابع GetPriceActionScore, GetMomentumScore, GetFollowThroughScore بدون تغییر باقی می‌مانند ...
    double GetPriceActionScore(const int index, const bool is_bullish, const MqlRates &rates[])
    {
        if(index >= ArraySize(rates))
        {
            m_logger.Log("خطا: اندیس نامعتبر برای محاسبه پرایس اکشن");
            return 0;
        }

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
        if(index >= ArraySize(rsi_buf))
        {
            m_logger.Log("خطا: اندیس نامعتبر برای محاسبه مومنتوم RSI");
            return 0;
        }

        double rsi = rsi_buf[index];
        if(is_bullish && rsi > m_rsi_cross_level)
            return MathMin(m_weight_momentum, (rsi - m_rsi_cross_level) / (100 - m_rsi_cross_level) * m_weight_momentum);
        if(!is_bullish && rsi < m_rsi_cross_level)
            return MathMin(m_weight_momentum, (m_rsi_cross_level - rsi) / m_rsi_cross_level * m_weight_momentum);
        return 0;
    }

    double GetFollowThroughScore(const int index, const double breakout_level, const bool is_bullish, const MqlRates &rates[])
    {
        if(index >= ArraySize(rates))
        {
            m_logger.Log("خطا: اندیس نامعتبر برای محاسبه Follow-Through");
            return 0;
        }

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
        if(m_rsi_handle == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل RSI برای Breakout ناموفق");
            return false;
        }
        return true;
    }

    bool SetMtfEmaHandle(const ENUM_TIMEFRAMES htf_period)
    {
        if(m_ema_handle_mtf != INVALID_HANDLE) 
            IndicatorRelease(m_ema_handle_mtf);
            
        m_ema_handle_mtf = iMA(m_symbol, htf_period, m_ema_period_mtf, 0, MODE_EMA, PRICE_CLOSE);
        if(m_ema_handle_mtf == INVALID_HANDLE)
        {
            m_logger.Log("خطا: ایجاد هندل EMA برای تایم‌فریم بالاتر ناموفق");
            return false;
        }
        m_logger.Log("هندل EMA برای تایم‌فریم بالاتر با موفقیت تنظیم شد.");
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
        m_logger.Log(StringFormat("BVS محاسبه شد: %.2f", m_last_bvs));
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
    CLogManager*       m_logger; // هشدار: ریسک Dangling Pointer در صورت مدیریت نادرست چرخه عمر

    // کامنت فارسی: دریافت متن و رنگ رژیم
    void GetRegimeTextAndColor(const ENUM_MARKET_REGIME regime, string &text, color &clr)
    {
        switch(regime)
        {
            case REGIME_STRONG_BULL_TREND:
            case REGIME_AVERAGE_BULL_TREND:
            case REGIME_BULL_TREND_EXHAUSTION:
            case REGIME_PROBABLE_BULLISH_REVERSAL:
            case REGIME_BULLISH_BREAKOUT_CONFIRMED:
                text = EnumToString(regime);
                clr = clrGreen;
                break;
            case REGIME_STRONG_BEAR_TREND:
            case REGIME_AVERAGE_BEAR_TREND:
            case REGIME_BEAR_TREND_EXHAUSTION:
            case REGIME_PROBABLE_BEARISH_REVERSAL:
            case REGIME_BEARISH_BREAKOUT_CONFIRMED:
                text = EnumToString(regime);
                clr = clrRed;
                break;
            case REGIME_RANGE_CONSOLIDATION:
            case REGIME_VOLATILITY_SQUEEZE:
                text = EnumToString(regime);
                clr = clrYellow;
                break;
            case REGIME_PROBABLE_FAKEOUT:
                text = EnumToString(regime);
                clr = clrOrange;
                break;
            case REGIME_UNDEFINED:
                text = "نامشخص";
                clr = clrGray;
                break;
            default:
                text = "نامشخص";
                clr = clrGray;
                break;
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

    // کامنت فارسی: به‌روزرسانی نمایش رژیم روی چارت
    void Update(const RegimeResult &result)
    {
        string text;
        color clr;
        GetRegimeTextAndColor(result.regime, text, clr);
        text = StringFormat("%s (اطمینان: %.2f)", text, result.confidenceScore);

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
        m_logger.Log(StringFormat("نمایش رژیم: %s", text));
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
    ENUM_TIMEFRAMES      m_period; // تایم‌فریم تحلیل
    RegimeResult         m_last_result;
    datetime             m_last_analysis_time;
    ENUM_STRUCTURE_STATE m_last_structure_state;
    double               m_last_breakout_level;
    bool                 m_pending_follow_through;
    double               m_momentum_strong_threshold;
    double               m_momentum_average_threshold;
    double               m_bvs_high_prob;
    double               m_bvs_fakeout;
    MqlRates             m_rates_buf[]; // بافر مرکزی برای داده‌های کندل
    double               m_atr_structure_buf[]; // بافر ATR برای ساختار
    double               m_atr_volatility_buf[];
    double               m_adx_main_buf[]; // بافر ADX Main
    double               m_adx_plus_di_buf[]; // بافر ADX +DI
    double               m_adx_minus_di_buf[]; // بافر ADX -DI
    double               m_rsi_buf[]; // بافر RSI
    double               m_bb_upper_buf[]; // بافر باند بالا
    double               m_bb_lower_buf[]; // بافر باند پایین
    double               m_bb_middle_buf[]; // بافر باند میانی
    double               m_structure_weight; // وزن ساختار
    double               m_momentum_weight; // وزن مومنتوم
    double               m_volatility_weight; // وزن نوسانات
    double               m_bvs_weight; // وزن BVS

    // کامنت فارسی: انتخاب هوشمند تایم‌فریم بالاتر برای تأیید چند تایم‌فریمی
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

    // کامنت فارسی: تعیین رژیم نهایی با ماتریس تصمیم
    RegimeResult DetermineFinalRegime(const ENUM_STRUCTURE_STATE structure, const MomentumResult momentum,
                                     const ENUM_VOLATILITY_STATE volatility, double bvs)
    {
        RegimeResult result;
        result.analysisTime = TimeCurrent();
        result.confidenceScore = 0;
        result.reasoning = "";
        result.regime = REGIME_UNDEFINED;

        if(momentum.is_conflicting)
        {
            result.regime = REGIME_UNDEFINED;
            result.reasoning = "تضاد سیگنال بین مومنتوم کوتاه‌مدت (ADX) و بلندمدت (Hurst)";
            m_logger.Log(result.reasoning);
            return result;
        }

        if(structure == STRUCTURE_UPTREND_BOS)
        {
            if(momentum.score > m_momentum_strong_threshold && !momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
            {
                result.regime = REGIME_STRONG_BULL_TREND;
                result.reasoning = "روند صعودی قوی: BOS صعودی، مومنتوم بالا، بدون خستگی، انبساط";
            }
            else if(momentum.score > m_momentum_average_threshold && !momentum.exhaustion_signal)
            {
                result.regime = REGIME_AVERAGE_BULL_TREND;
                result.reasoning = "روند صعودی متوسط: BOS صعودی، مومنتوم متوسط، بدون خستگی";
            }
            else
            {
                result.regime = REGIME_BULL_TREND_EXHAUSTION;
                result.reasoning = "خستگی روند صعودی: BOS صعودی اما مومنتوم پایین یا خستگی";
            }
        }
        else if(structure == STRUCTURE_DOWNTREND_BOS)
        {
            if(momentum.score < -m_momentum_strong_threshold && !momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
            {
                result.regime = REGIME_STRONG_BEAR_TREND;
                result.reasoning = "روند نزولی قوی: BOS نزولی، مومنتوم پایین، بدون خستگی، انبساط";
            }
            else if(momentum.score < -m_momentum_average_threshold && !momentum.exhaustion_signal)
            {
                result.regime = REGIME_AVERAGE_BEAR_TREND;
                result.reasoning = "روند نزولی متوسط: BOS نزولی، مومنتوم متوسط، بدون خستگی";
            }
            else
            {
                result.regime = REGIME_BEAR_TREND_EXHAUSTION;
                result.reasoning = "خستگی روند نزولی: BOS نزولی اما مومنتوم بالا یا خستگی";
            }
        }
        else if(structure == STRUCTURE_CONSOLIDATION_RANGE)
        {
            if(MathAbs(momentum.score) < m_momentum_average_threshold)
            {
                if(volatility == VOLATILITY_SQUEEZE)
                {
                    result.regime = REGIME_VOLATILITY_SQUEEZE;
                    result.reasoning = "فشردگی نوسانات: ساختار خنثی، مومنتوم نزدیک صفر، فشردگی";
                }
                else
                {
                    result.regime = REGIME_RANGE_CONSOLIDATION;
                    result.reasoning = "بازار رنج: ساختار خنثی، مومنتوم نزدیک صفر، نوسانات نرمال";
                }
            }
        }
        else if(structure == STRUCTURE_BEARISH_CHoCH)
        {
            if(momentum.score < 0 && momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
            {
                result.regime = REGIME_PROBABLE_BEARISH_REVERSAL;
                result.reasoning = "بازگشت نزولی احتمالی: CHoCH نزولی، مومنتوم در حال کاهش، خستگی، انبساط";
            }
        }
        else if(structure == STRUCTURE_BULLISH_CHoCH)
        {
            if(momentum.score > 0 && momentum.exhaustion_signal && volatility == VOLATILITY_EXPANSION)
            {
                result.regime = REGIME_PROBABLE_BULLISH_REVERSAL;
                result.reasoning = "بازگشت صعودی احتمالی: CHoCH صعودی، مومنتوم در حال افزایش، خستگی، انبساط";
            }
        }

        if(bvs > 0)
        {
            bool is_bullish = momentum.score > 0;
            if(bvs > m_bvs_high_prob && MathAbs(momentum.score) > m_momentum_average_threshold && volatility == VOLATILITY_EXPANSION)
            {
                result.regime = is_bullish ? REGIME_BULLISH_BREAKOUT_CONFIRMED : REGIME_BEARISH_BREAKOUT_CONFIRMED;
                result.reasoning = StringFormat("شروع روند %s (شکست تایید شده): BVS >%.1f، مومنتوم قوی، انبساط",
                                               is_bullish ? "صعودی" : "نزولی", m_bvs_high_prob);
            }
            else if(bvs < m_bvs_fakeout)
            {
                result.regime = REGIME_PROBABLE_FAKEOUT;
                result.reasoning = StringFormat("شکست کاذب احتمالی: BVS <%.1f", m_bvs_fakeout);
            }
        }

        if(result.regime == REGIME_UNDEFINED)
            result.reasoning = "هیچ رژیم واضحی تشخیص داده نشد";

        m_logger.Log(StringFormat("رژیم نهایی: %s, دلیل: %s", EnumToString(result.regime), result.reasoning));
        return result;
    }

    // کامنت فارسی: محاسبه امتیاز اطمینان
    double CalculateConfidenceScore(const ENUM_STRUCTURE_STATE structure, const MomentumResult momentum,
                                   const ENUM_VOLATILITY_STATE volatility, const double bvs)
    {
        double structure_norm = (structure == STRUCTURE_BEARISH_CHoCH || structure == STRUCTURE_BULLISH_CHoCH) ? 0.8 :
                               (structure == STRUCTURE_CONSOLIDATION_RANGE ? 0.7 : 1.0);
        double momentum_norm = MathAbs(momentum.score) / 100.0;
        if(momentum.exhaustion_signal) momentum_norm *= 0.9;
        double volatility_norm = (volatility == VOLATILITY_NORMAL) ? 0.5 : 1.0;
        double bvs_norm = (bvs > 0) ? bvs / 10.0 : 0.0;

        double confidence = (bvs > 0) ? 
                           (m_structure_weight * structure_norm + m_momentum_weight * momentum_norm + m_bvs_weight * bvs_norm) :
                           (m_structure_weight * structure_norm + m_momentum_weight * momentum_norm + m_volatility_weight * volatility_norm);
        return MathMin(1.0, confidence);
    }

public:
    CMarketRegimeEngine() : m_is_initialized(false), m_period(PERIOD_CURRENT), m_last_analysis_time(0),
                            m_last_structure_state(STRUCTURE_UNDEFINED), m_last_breakout_level(0), m_pending_follow_through(false),
                            m_momentum_strong_threshold(70.0), m_momentum_average_threshold(40.0),
                            m_bvs_high_prob(7.0), m_bvs_fakeout(4.0),
                            m_structure_weight(0.4), m_momentum_weight(0.4), m_volatility_weight(0.2), m_bvs_weight(0.2) {}
    
    // کامنت فارسی: راه‌اندازی همه ماژول‌ها با سوئیچ لاگ و تایم‌فریم تحلیل
    bool Initialize(const string symbol, const ENUM_TIMEFRAMES analysis_period, const bool enable_logging,
                    const int fractal_n=2, const double consolidation_factor=4.0, const int atr_period_consolidation=50,
                    const double fractal_atr_filter_factor=0.5, const int adx_period=14, const int rsi_period=14,
                    const int hurst_window=252, const double hurst_threshold=0.55, const int bb_period=20,
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
        if(!m_momentum.Initialize(symbol, m_period, m_structure, m_logger, adx_period, rsi_period, hurst_window, hurst_threshold))
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

    // کامنت فارسی: پردازش کندل جدید و به‌روزرسانی رژیم
    bool ProcessNewBar()
    {
        if(!m_is_initialized)
        {
            m_logger.Log("خطا: موتور راه‌اندازی نشده است");
            return false;
        }

        datetime current_bar_time = (datetime)SeriesInfoInteger(_Symbol, m_period, SERIES_LASTBAR_DATE);
        if(current_bar_time == m_last_analysis_time) return false;
          
              // بارگذاری داده‌ها به بافرهای مرکزی (نسخه اصلاح شده با اندیس‌گذاری استاندارد)
            const int bars_to_process = 500;
            ArraySetAsSeries(m_rates_buf, true); // ✅ اصلاح: استانداردسازی اندیس‌گذاری
            if(CopyRates(_Symbol, m_period, 0, bars_to_process, m_rates_buf) < bars_to_process)
            {
                m_logger.Log("خطا: داده کافی برای کندل‌ها موجود نیست");
                return false;
            }
            
            ArraySetAsSeries(m_atr_structure_buf, true); // ✅ اصلاح
            if(CopyBuffer(m_structure.GetAtrHandle(), 0, 0, bars_to_process, m_atr_structure_buf) < bars_to_process)
            {
                m_logger.Log("خطا: داده کافی برای ATR ساختار موجود نیست");
                return false;
            }
            
            ArraySetAsSeries(m_atr_volatility_buf, true); // ✅ اصلاح
            if(CopyBuffer(m_volatility.GetAtrHandle(), 0, 0, bars_to_process, m_atr_volatility_buf) < bars_to_process)
            {
                m_logger.Log("خطا: داده کافی برای ATR نوسانات موجود نیست");
                return false;
            }
            
            ArraySetAsSeries(m_adx_main_buf, true); // ✅ اصلاح
            ArraySetAsSeries(m_adx_plus_di_buf, true); // ✅ اصلاح
            ArraySetAsSeries(m_adx_minus_di_buf, true); // ✅ اصلاح
            if(CopyBuffer(m_momentum.GetAdxHandle(), 0, 0, bars_to_process, m_adx_main_buf) < bars_to_process ||
               CopyBuffer(m_momentum.GetAdxHandle(), 1, 0, bars_to_process, m_adx_plus_di_buf) < bars_to_process ||
               CopyBuffer(m_momentum.GetAdxHandle(), 2, 0, bars_to_process, m_adx_minus_di_buf) < bars_to_process)
            {
                m_logger.Log("خطا: داده کافی برای ADX موجود نیست");
                return false;
            }
            
            ArraySetAsSeries(m_rsi_buf, true); // ✅ اصلاح
            if(CopyBuffer(m_breakout.GetRsiHandle(), 0, 0, bars_to_process, m_rsi_buf) < bars_to_process)
            {
                m_logger.Log("خطا: داده کافی برای RSI موجود نیست");
                return false;
            }
            
            ArraySetAsSeries(m_bb_upper_buf, true); // ✅ اصلاح
            ArraySetAsSeries(m_bb_lower_buf, true); // ✅ اصلاح
            ArraySetAsSeries(m_bb_middle_buf, true); // ✅ اصلاح
            if(CopyBuffer(m_volatility.GetBBHandle(), 1, 0, bars_to_process, m_bb_upper_buf) < bars_to_process ||
               CopyBuffer(m_volatility.GetBBHandle(), 2, 0, bars_to_process, m_bb_lower_buf) < bars_to_process ||
               CopyBuffer(m_volatility.GetBBHandle(), 0, 0, bars_to_process, m_bb_middle_buf) < bars_to_process)
            {
                m_logger.Log("خطا: داده کافی برای Bollinger Bands موجود نیست");
                return false;
            }
            
        ENUM_STRUCTURE_STATE structure = m_structure.Analyze(m_rates_buf, m_atr_structure_buf, bars_to_process);
        MomentumResult momentum = m_momentum.Analyze(m_rates_buf, m_adx_main_buf, m_adx_plus_di_buf, m_adx_minus_di_buf, m_rsi_buf);
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
                if(ArraySize(swings) > 0) breakout_level = swings[ArraySize(swings)-1].price;
            }
            else
            {
                m_structure.GetSwingLows(swings); // ✅ اصلاح اشتباه تایپی
                if(ArraySize(swings) > 0) breakout_level = swings[ArraySize(swings)-1].price;
            }
            // ✅ اصلاح: کندل شکست، کندل شماره ۱ (آخرین کندل بسته شده) است
            bvs = m_breakout.CalculateBVS(1, is_bullish, breakout_level, m_rates_buf, m_rsi_buf, GetHigherOrderflowTimeframe(m_period));
            m_last_breakout_level = breakout_level;
            m_pending_follow_through = true;
        }
        else if(m_pending_follow_through)
        {
            bool is_bullish = (m_last_result.regime == REGIME_BULLISH_BREAKOUT_CONFIRMED); // جهت را از نتیجه قبلی میگیریم
            // ✅ اصلاح: کندل تایید، کندل شماره ۱ (آخرین کندل بسته شده) است که در فراخوانی قبلی کندل ۰ بوده
            bvs = m_breakout.CalculateBVS(1, is_bullish, m_last_breakout_level, m_rates_buf, m_rsi_buf, GetHigherOrderflowTimeframe(m_period));
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
