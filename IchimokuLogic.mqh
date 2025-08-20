//+------------------------------------------------------------------+
//|                                     IchimokuLogic.mqh            |
//|                          © 2025, hipoalgoritm                   |
//+------------------------------------------------------------------+
#property copyright "© 2025,hipoalgoritm" // حقوق کپی‌رایت پروژه
#property link      "https://www.mql5.com" // لینک مرتبط با پروژه
#property version   "3.1"  // نسخه با معماری "Hunter" و ارتقاءها
#include "set.mqh" // فایل تنظیمات ورودی‌ها
#include <Trade\Trade.mqh> // کتابخانه مدیریت معاملات
#include <Trade\SymbolInfo.mqh> // کتابخانه اطلاعات نماد
#include <Object.mqh> // کتابخانه مدیریت اشیاء گرافیکی
#include "VisualManager.mqh" // فایل مدیریت گرافیک و داشبورد
#include <MovingAverages.mqh> // کتابخانه میانگین‌های متحرک
#include "MarketStructure.mqh" // کتابخانه تحلیل ساختار بازار

//+------------------------------------------------------------------+
//| ساختار برای نگهداری سیگنال‌های بالقوه (Potential Signals)     |
//+------------------------------------------------------------------+
struct SPotentialSignal
{
    datetime        time; // زمان وقوع سیگنال
    bool            is_buy; // نوع سیگنال: true برای خرید، false برای فروش
    int             grace_candle_count; // شمارنده کندل‌های مهلت برای انقضا
    double          invalidation_level; // سطح ابطال سیگنال (برای حالت ساختاری)
    
    // سازنده کپی برای جلوگیری از مشکلات کپی ساختار
    SPotentialSignal(const SPotentialSignal &other) // کپی سازنده
    {
        time = other.time; // کپی زمان
        is_buy = other.is_buy; // کپی نوع سیگنال
        grace_candle_count = other.grace_candle_count; // کپی شمارنده
        invalidation_level = other.invalidation_level; // کپی سطح ابطال
    }
    // سازنده پیش‌فرض برای مقداردهی اولیه
    SPotentialSignal() // پیش‌فرض
    {
       invalidation_level = 0.0; // مقدار اولیه سطح ابطال
    }
};

//+------------------------------------------------------------------+
//| کلاس مدیریت استراتژی برای هر نماد خاص                          |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
    string              m_symbol; // نماد معاملاتی فعلی
    SSettings           m_settings; // ساختار تنظیمات ورودی‌ها
    CTrade              m_trade; // شیء مدیریت معاملات
   
    datetime            m_last_bar_time_htf; // زمان آخرین کندل در تایم فریم اصلی (HTF)
    datetime            m_last_bar_time_ltf; // زمان آخرین کندل در تایم فریم پایین (LTF)
    
    // --- هندل‌های اندیکاتورها (برای محاسبات) ---
    int                 m_ichimoku_handle; // هندل اندیکاتور ایچیموکو
    int                 m_atr_handle;      // هندل اندیکاتور ATR
    int                 m_adx_handle;       // هندل اندیکاتور ADX برای فیلتر روند
    int                 m_rsi_exit_handle;  // هندل اندیکاتور RSI برای خروج زودرس

    // --- بافرهای داده اندیکاتورها ---
    double              m_tenkan_buffer[]; // بافر تنکان-سن
    double              m_kijun_buffer[]; // بافر کیجون-سن
    double              m_chikou_buffer[]; // بافر چیکو اسپن
    double              m_high_buffer[]; // بافر سقف قیمت‌ها
    double              m_low_buffer[];  // بافر کف قیمت‌ها
    
    // --- مدیریت سیگنال‌ها ---
    SPotentialSignal    m_signal; // سیگنال اصلی فعال
    bool                m_is_waiting; // حالت انتظار برای تایید سیگنال
    bool                m_waiting_for_shift; // [NEW] حالت انتظار برای تغییر ساختار
    bool                m_waiting_for_pullback; // [NEW] حالت انتظار برای پولبک
    SPotentialSignal    m_potential_signals[]; // آرایه سیگنال‌های بالقوه در حالت مسابقه
    CVisualManager* m_visual_manager; // مدیر گرافیک و داشبورد
    CMarketStructureShift m_ltf_analyzer; // تحلیلگر ساختار بازار در تایم فریم پایین (LTF)
    CMarketStructureShift m_grace_structure_analyzer; // تحلیلگر ساختار برای مهلت ساختاری

    //--- توابع کمکی داخلی ---
    void Log(string message); // تابع لاگ کردن پیام‌ها
    
    // --- منطق اصلی سیگنال‌ها ---
    void AddOrUpdatePotentialSignal(bool is_buy); // اضافه یا به‌روزرسانی سیگنال بالقوه
    bool CheckTripleCross(bool& is_buy); // چک کردن کراس سه‌گانه (تنکان، کیجون، چیکو) - بهبود: تلرانس برای Chikou اضافه شد
    bool CheckFinalConfirmation(bool is_buy); // چک تایید نهایی ورود
    bool CheckLowerTfConfirmation(bool is_buy); // چک تایید در تایم فریم پایین (LTF)
    // --- فیلترهای ورود ---
    bool AreAllFiltersPassed(bool is_buy); // چک کردن تمام فیلترهای ورود
    bool CheckKumoFilter(bool is_buy, ENUM_TIMEFRAMES timeframe); // فیلتر موقعیت نسبت به ابر کومو با تایم فریم
    bool CheckAtrFilter(ENUM_TIMEFRAMES timeframe); // فیلتر حداقل نوسان ATR با تایم فریم
    bool CheckAdxFilter(bool is_buy, ENUM_TIMEFRAMES timeframe); // فیلتر قدرت و جهت روند ADX با تایم فریم

    // --- منطق خروج ---
    void CheckForEarlyExit();         // چک کردن شرایط خروج زودرس از معاملات
    bool CheckChikouRsiExit(bool is_buy); // چک منطق خروج با کراس چیکو و تایید RSI

    //--- محاسبه استاپ لاس ---
    double CalculateStopLoss(bool is_buy, double entry_price); // محاسبه نهایی سطح استاپ لاس
    double CalculateAtrStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe); // محاسبه SL مبتنی بر ATR با تایم فریم
    double GetTalaqiTolerance(int reference_shift); // محاسبه تلرانس تلاقی (Confluence)
    double CalculateAtrTolerance(int reference_shift); // محاسبه تلرانس بر اساس ATR
    double CalculateDynamicTolerance(int reference_shift); // محاسبه تلرانس بر اساس ضخامت کومو
    double FindFlatKijun(ENUM_TIMEFRAMES timeframe); // پیدا کردن سطح کیجون فلت با تایم فریم
    double FindPivotKijun(bool is_buy, ENUM_TIMEFRAMES timeframe); // پیدا کردن پیوت روی کیجون با تایم فریم
    double FindPivotTenkan(bool is_buy, ENUM_TIMEFRAMES timeframe); // پیدا کردن پیوت روی تنکان با تایم فریم
    double FindBackupStopLoss(bool is_buy, double buffer, ENUM_TIMEFRAMES timeframe); // محاسبه SL پشتیبان با تایم فریم
    double CalculateStructuralStopLoss(bool is_buy, double entry_price); // [NEW] محاسبه SL ساختاری
    
    //--- مدیریت معاملات ---
    int CountSymbolTrades(); // شمارش معاملات باز برای نماد فعلی
    int CountTotalTrades(); // شمارش کل معاملات باز
    void OpenTrade(bool is_buy); // باز کردن معامله جدید
    bool PlaceLimitOrder(bool is_buy);
    bool IsDataReady(); // چک آماده بودن داده‌های تمام تایم فریم‌ها
    bool IsNewBar(ENUM_TIMEFRAMES timeframe, datetime &last_bar_time); // چک تشکیل کندل جدید در تایم فریم مشخص

    //--- توابع جدید MKM ---
    double CalculateKijunSlope(ENUM_TIMEFRAMES timeframe, int period, double& threshold); // محاسبه شیب کیجون
    bool IsKumoExpanding(ENUM_TIMEFRAMES timeframe, int period); // چک انبساط ابر کومو - بهبود: SMA به EMA تغییر یافت
    bool IsChikouInOpenSpace(bool is_buy, ENUM_TIMEFRAMES timeframe); // چک فضای باز چیکو

public:
    CStrategyManager(string symbol, SSettings &settings); // کانستراکتور کلاس
    ~CStrategyManager(); // دیستراکتور کلاس
    bool Init(); // مقداردهی اولیه کلاس
    void OnTimerTick(); // تابع اصلی رویداد تایمر (هر ثانیه)
    void ProcessSignalSearch(); // جستجوی سیگنال اولیه
    void ManageActiveSignal(bool is_new_htf_bar); // مدیریت سیگنال‌های فعال
    string GetSymbol() const { return m_symbol; } // گرفتن نماد فعلی
    void UpdateMyDashboard(); // به‌روزرسانی داشبورد
    CVisualManager* GetVisualManager() { return m_visual_manager; } // گرفتن مدیر گرافیک
};

//+------------------------------------------------------------------+
//| کانستراکتور کلاس مدیریت استراتژی                                |
//+------------------------------------------------------------------+
CStrategyManager::CStrategyManager(string symbol, SSettings &settings)
{
    m_symbol = symbol; // تنظیم نماد معاملاتی
    m_settings = settings; // کپی تنظیمات ورودی
    m_last_bar_time_htf = 0; // مقدار اولیه زمان آخرین کندل HTF
    m_last_bar_time_ltf = 0; // مقدار اولیه زمان آخرین کندل LTF
    m_is_waiting = false; // مقدار اولیه حالت انتظار (غیرفعال)
    m_waiting_for_shift = false; // [NEW] مقدار اولیه حالت تغییر
    m_waiting_for_pullback = false; // [NEW] مقدار اولیه حالت پولبک
    ArrayFree(m_potential_signals); // آزاد کردن آرایه سیگنال‌های بالقوه
    m_ichimoku_handle = INVALID_HANDLE; // مقدار اولیه هندل ایچیموکو
    m_atr_handle = INVALID_HANDLE; // مقدار اولیه هندل ATR
    m_visual_manager = new CVisualManager(symbol, settings); // ایجاد مدیر گرافیک جدید
}

//+------------------------------------------------------------------+
//| دیستراکتور کلاس (برای آزاد کردن منابع)                          |
//+------------------------------------------------------------------+
CStrategyManager::~CStrategyManager()
{
    // پاک کردن مدیر گرافیک اگر وجود داشته باشد
    if (m_visual_manager != NULL) // چک وجود شیء
    {
        delete m_visual_manager; // حذف شیء
        m_visual_manager = NULL; // ریست اشاره‌گر
    }

    // آزاد کردن هندل‌های اندیکاتورها (هر کدام فقط یک بار)
    if(m_ichimoku_handle != INVALID_HANDLE) // چک هندل ایچیموکو
        IndicatorRelease(m_ichimoku_handle); // آزاد کردن هندل
    if(m_atr_handle != INVALID_HANDLE) // چک هندل ATR
        IndicatorRelease(m_atr_handle); // آزاد کردن هندل
    if(m_adx_handle != INVALID_HANDLE) // چک هندل ADX
        IndicatorRelease(m_adx_handle); // آزاد کردن هندل
    if(m_rsi_exit_handle != INVALID_HANDLE) // چک هندل RSI
        IndicatorRelease(m_rsi_exit_handle); // آزاد کردن هندل
}

//+------------------------------------------------------------------+
//| به‌روزرسانی داشبورد اطلاعاتی                                    |
//+------------------------------------------------------------------+
void CStrategyManager::UpdateMyDashboard() 
{ 
    if (m_visual_manager != NULL) // چک وجود مدیر گرافیک
    {
        m_visual_manager.UpdateDashboard(); // فراخوانی تابع به‌روزرسانی داشبورد
    }
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه کلاس (با واکسیناسیون داده‌ها)                    |
//+------------------------------------------------------------------+
bool CStrategyManager::Init()
{
    // +++ واکسیناسیون برای اطمینان از بارگذاری داده‌ها +++
    int attempts = 0; // شمارنده تلاش‌ها
    while(iBars(m_symbol, m_settings.ichimoku_timeframe) < 200 && attempts < 100) // حلقه تا بارگذاری کافی
    {
        Sleep(100);  // تاخیر ۱۰۰ میلی‌ثانیه
        MqlRates rates[]; // آرایه نرخ‌ها
        CopyRates(m_symbol, m_settings.ichimoku_timeframe, 0, 1, rates);  // کپی نرخ‌ها برای تحریک بارگذاری
        attempts++; // افزایش شمارنده
    }
    if (iBars(m_symbol, m_settings.ichimoku_timeframe) < 200) // چک نهایی تعداد بارها
    {
        Log("خطای بحرانی: پس از تلاش‌های مکرر، داده‌های کافی برای نماد " + m_symbol + " بارگذاری نشد."); // لاگ خطا
        return false; // بازگشت شکست
    }
    // +++ پایان واکسیناسیون +++

    
    // تنظیمات اولیه شیء ترید
    m_trade.SetExpertMagicNumber(m_settings.magic_number); // تنظیم شماره جادویی
    m_trade.SetTypeFillingBySymbol(m_symbol); // تنظیم نوع پر کردن سفارش بر اساس نماد
    
    // --- ایجاد هندل اندیکاتورها در حالت نامرئی (Ghost Mode) ---
    // ایچیموکو در حالت نامرئی
    MqlParam ichimoku_params[3]; // پارامترهای ایچیموکو
    ichimoku_params[0].type = TYPE_INT; ichimoku_params[0].integer_value = m_settings.tenkan_period; // دوره تنکان
    ichimoku_params[1].type = TYPE_INT; ichimoku_params[1].integer_value = m_settings.kijun_period; // دوره کیجون
    ichimoku_params[2].type = TYPE_INT; ichimoku_params[2].integer_value = m_settings.senkou_period; // دوره سنکو
    m_ichimoku_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ICHIMOKU, 3, ichimoku_params); // ایجاد هندل

    // ATR در حالت نامرئی
    MqlParam atr_params[1]; // پارامتر ATR
    atr_params[0].type = TYPE_INT; atr_params[0].integer_value = m_settings.atr_filter_period; // دوره ATR
    m_atr_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ATR, 1, atr_params); // ایجاد هندل

    // ADX در حالت نامرئی
    MqlParam adx_params[1]; // پارامتر ADX
    adx_params[0].type = TYPE_INT; adx_params[0].integer_value = m_settings.adx_period; // دوره ADX
    m_adx_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ADX, 1, adx_params); // ایجاد هندل

    // RSI در حالت نامرئی
    MqlParam rsi_params[2]; // پارامترهای RSI
    rsi_params[0].type = TYPE_INT; rsi_params[0].integer_value = m_settings.early_exit_rsi_period; // دوره RSI
    rsi_params[1].type = TYPE_INT; rsi_params[1].integer_value = PRICE_CLOSE; // نوع قیمت (بسته)
    m_rsi_exit_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_RSI, 2, rsi_params); // ایجاد هندل
    
    // بررسی اعتبار تمام هندل‌ها
    if (m_ichimoku_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE || m_adx_handle == INVALID_HANDLE || m_rsi_exit_handle == INVALID_HANDLE) // چک هندل‌ها
    {
        Log("خطا در ایجاد یک یا چند اندیکاتور. لطفاً تنظیمات را بررسی کنید."); // لاگ خطا
        return false; // بازگشت شکست
    }

    // مقداردهی اولیه بافرها
    ArraySetAsSeries(m_tenkan_buffer, true); // تنظیم بافر تنکان به عنوان سری زمانی
    ArraySetAsSeries(m_kijun_buffer, true); // تنظیم بافر کیجون به عنوان سری زمانی
    ArraySetAsSeries(m_chikou_buffer, true); // تنظیم بافر چیکو به عنوان سری زمانی
    ArraySetAsSeries(m_high_buffer, true); // تنظیم بافر سقف به عنوان سری زمانی
    ArraySetAsSeries(m_low_buffer, true);  // تنظیم بافر کف به عنوان سری زمانی
    
    if (!m_visual_manager.Init()) // چک مقداردهی مدیر گرافیک
    {
        Log("خطا در مقداردهی اولیه VisualManager."); // لاگ خطا
        return false; // بازگشت شکست
    }

    if(m_symbol == _Symbol) // اگر نماد فعلی روی چارت است
    {
        m_visual_manager.InitDashboard(); // مقداردهی داشبورد
    }
    
    m_ltf_analyzer.Init(m_symbol, m_settings.ltf_timeframe); // مقداردهی تحلیلگر LTF
    
    m_grace_structure_analyzer.Init(m_symbol, m_settings.ichimoku_timeframe); // تحلیلگر مهلت روی تایم فریم اصلی 
    
    Log("با موفقیت مقداردهی اولیه شد."); // لاگ موفقیت
    return true; // بازگشت موفقیت
}

//+------------------------------------------------------------------+
//| تابع اصلی رویداد تایمر (هر ثانیه اجرا می‌شود)                  |
//+------------------------------------------------------------------+
void CStrategyManager::OnTimerTick()
{
    // واکسن: چک آماده بودن داده‌ها
    if (!IsDataReady()) return; // اگر داده آماده نیست، خروج

    // آپدیت تحلیلگر LTF اگر کندل جدید باشد
    bool is_new_ltf_bar = IsNewBar(m_settings.ltf_timeframe, m_last_bar_time_ltf); // چک کندل جدید LTF
    if (is_new_ltf_bar) // اگر کندل جدید
    {
        m_ltf_analyzer.ProcessNewBar();  // پردازش کندل جدید در تحلیلگر LTF
    }

    // جستجوی سیگنال فقط روی کندل جدید HTF
    bool is_new_htf_bar = IsNewBar(m_settings.ichimoku_timeframe, m_last_bar_time_htf); // چک کندل جدید HTF
    if (is_new_htf_bar) // اگر کندل جدید
    {
        m_grace_structure_analyzer.ProcessNewBar();  // پردازش کندل جدید در تحلیلگر مهلت

        ProcessSignalSearch();  // جستجوی سیگنال اولیه
    }

    // مدیریت سیگنال‌های فعال
    if (m_waiting_for_shift || m_waiting_for_pullback || m_is_waiting || ArraySize(m_potential_signals) > 0) // [MODIFIED] چک حالت‌های جدید
    {
        if (is_new_htf_bar || is_new_ltf_bar) // اگر رویداد جدید HTF یا LTF
        {
            ManageActiveSignal(is_new_htf_bar); // مدیریت سیگنال
        }
    }

    // چک خروج زودرس اگر فعال باشد
    if (is_new_htf_bar && m_settings.enable_early_exit) // اگر کندل جدید HTF و خروج زودرس فعال
    {
        CheckForEarlyExit(); // چک شرایط خروج
    }
}

//+------------------------------------------------------------------+
//| [MODIFIED] جستجوی سیگنال اولیه با معماری جدید "شکارچی"           |
//+------------------------------------------------------------------+
// IchimokuLogic.mqh

void CStrategyManager::ProcessSignalSearch()
{
    // اگر در هر یک از حالت‌های انتظار هستیم، به دنبال سیگنال جدید نگرد
    if (m_waiting_for_shift || m_waiting_for_pullback || m_is_waiting) return;

    // --- مسیر استراتژی 1: کراس سه‌گانه ---
    if (m_settings.primary_strategy == STRATEGY_TRIPLE_CROSS)
    {
        bool is_new_signal_buy = false;
        if (!CheckTripleCross(is_new_signal_buy)) return;

        Log("سیگنال اولیه HTF (Triple Cross) یافت شد: " + (is_new_signal_buy ? "خرید" : "فروش"));

        // ریست کامل متغیرهای حالت
        m_waiting_for_shift = false;
        m_waiting_for_pullback = false;
        m_is_waiting = false;
        
        m_signal.is_buy = is_new_signal_buy;
        m_signal.time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou_period);
        m_signal.grace_candle_count = 0;

        // معماری جدید "خلبان": چک فوری ساختار LTF
        if (m_settings.entry_confirmation_mode == CONFIRM_LOWER_TIMEFRAME)
        {
            int found_at_bar = -1;
            bool has_existing_mss = m_ltf_analyzer.ScanPastForMSS(is_new_signal_buy, m_settings.structure_lookback_bars, found_at_bar);

            if (has_existing_mss)
            {
                m_waiting_for_pullback = true;
                Log("ساختار LTF هم‌جهت است. ورود به فاز انتظار برای پولبک.");
            }
            else
            {
                m_waiting_for_shift = true;
                Log("ساختار LTF هم‌جهت نیست. ورود به فاز انتظار برای تغییر ساختار (MSS).");
            }
            
            m_signal.invalidation_level = m_signal.is_buy ? m_ltf_analyzer.GetSecondLastSwingLow() : m_ltf_analyzer.GetSecondLastSwingHigh();
            Log("سطح ابطال (Grandfather) در LTF تنظیم شد: " + DoubleToString(m_signal.invalidation_level, _Digits));
        }
        // معماری قدیمی: تاییدیه در تایم جاری
        else
        {
            if (m_settings.signal_mode == MODE_REPLACE_SIGNAL)
            {
                m_is_waiting = true;
                if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE)
                {
                    m_signal.invalidation_level = is_new_signal_buy ? m_grace_structure_analyzer.GetLastSwingLow() : m_grace_structure_analyzer.GetLastSwingHigh();
                }
            }
            else // MODE_SIGNAL_CONTEST
            {
                AddOrUpdatePotentialSignal(is_new_signal_buy);
            }
        }

        if(m_symbol == _Symbol && m_visual_manager != NULL) 
            m_visual_manager.DrawTripleCrossRectangle(is_new_signal_buy, m_settings.chikou_period);
    }
    // --- مسیر استراتژی 2: MKM ---
    else if (m_settings.primary_strategy == STRATEGY_KUMO_MTL)
    {
        // فیلتر روند کلان در HTF 
        int htf_ichi_handle = iIchimoku(m_symbol, m_settings.ichimoku_timeframe, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period);
        if (htf_ichi_handle == INVALID_HANDLE) return;

        double senkou_a[1], senkou_b[1];
        if(CopyBuffer(htf_ichi_handle, 2, 0, 1, senkou_a) < 1 || CopyBuffer(htf_ichi_handle, 3, 0, 1, senkou_b) < 1)
        {
            IndicatorRelease(htf_ichi_handle);
            return;
        }
        IndicatorRelease(htf_ichi_handle);

        double high_kumo = MathMax(senkou_a[0], senkou_b[0]);
        double low_kumo = MathMin(senkou_a[0], senkou_b[0]);
        double close_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1); // Use close of last bar for stability

        bool is_buy_trend = (close_price > high_kumo);
        bool is_sell_trend = (close_price < low_kumo);

        if (is_buy_trend || is_sell_trend)
        {
            m_signal.is_buy = is_buy_trend;
            m_signal.time = TimeCurrent();
            Log("روند کلان MKM " + (m_signal.is_buy ? "صعودی" : "نزولی") + " است. ورود به حالت انتظار برای تاییدیه LTF...");

            int found_bar = -1;
            bool has_existing_mss = m_ltf_analyzer.ScanPastForMSS(m_signal.is_buy, m_settings.structure_lookback_bars, found_bar);
            if (has_existing_mss)
            {
                m_waiting_for_pullback = true;
            }
            else
            {
                m_waiting_for_shift = true;
            }

            if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE)
            {
                m_signal.invalidation_level = m_signal.is_buy ? m_ltf_analyzer.GetSecondLastSwingLow() : m_ltf_analyzer.GetSecondLastSwingHigh();
            }
        }
    }
}



//+------------------------------------------------------------------+
//| مدیریت سیگنال‌های فعال با معماری حالت-محور (نسخه تاکتیکی)        |
//+------------------------------------------------------------------+
void CStrategyManager::ManageActiveSignal(bool is_new_htf_bar)
{
    // اگر در هیچ حالت انتظاری نیستیم، هیچ کاری برای انجام دادن وجود ندارد.
    if (!m_waiting_for_shift && !m_waiting_for_pullback && !m_is_waiting && ArraySize(m_potential_signals) == 0) return;

    // چک می‌کنیم آیا کندل جدید در تایم فریم پایین (LTF) داریم یا نه
    bool is_new_ltf_bar = IsNewBar(m_settings.ltf_timeframe, m_last_bar_time_ltf);

    // --- بخش ۱: اجرای معماری "خلبان" با تاکتیک‌های ورودی متفاوت ---
    if (m_settings.entry_confirmation_mode == CONFIRM_LOWER_TIMEFRAME && (m_waiting_for_shift || m_waiting_for_pullback))
    {
        // --- مدیریت انقضای سیگنال (خط قرمز یا قانون پدربزرگ) ---
        bool is_signal_expired = false;
        if (m_settings.grace_period_mode == GRACE_BY_CANDLES)
        {
            if (is_new_ltf_bar) m_signal.grace_candle_count++;
            if (m_signal.grace_candle_count >= m_settings.structural_grace_candles) is_signal_expired = true;
        }
        else // GRACE_BY_STRUCTURE (روش هوشمند)
        {
            double current_price_ltf = iClose(m_symbol, m_settings.ltf_timeframe, 1);
            if (m_signal.invalidation_level > 0 &&
               ((m_signal.is_buy && current_price_ltf < m_signal.invalidation_level) ||
               (!m_signal.is_buy && current_price_ltf > m_signal.invalidation_level)))
               is_signal_expired = true;
        }
        
        if (is_signal_expired)
        {
            Log("سیگنال به دلیل انقضا (شکست سطح ابطال یا تمام شدن کندل‌های مهلت) باطل شد.");
            m_waiting_for_shift = false;
            m_waiting_for_pullback = false;
            return;
        }

        // --- مدیریت حالت‌ها فقط در کندل جدید LTF ---
        if (is_new_ltf_bar)
        {
            // از تحلیلگر ساختار بازار گزارش جدید می‌گیریم
            SMssSignal ltf_signal = m_ltf_analyzer.ProcessNewBar();
            
            // اگر در فاز "انتظار برای تغییر ساختار" (MSS) هستیم
            if (m_waiting_for_shift)
            {
                if ((m_signal.is_buy && ltf_signal.type == MSS_SHIFT_UP) || (!m_signal.is_buy && ltf_signal.type == MSS_SHIFT_DOWN))
                {
                    Log("تغییر ساختار (MSS) در LTF تایید شد. ورود به فاز انتظار پولبک.");
                    m_waiting_for_shift = false;
                    m_waiting_for_pullback = true;
                }
            }
            // اگر در فاز "انتظار برای پولبک" هستیم
            else if (m_waiting_for_pullback)
            {
                // ================== دوراهی تاکتیک ورود: کاربر کدام روش را انتخاب کرده؟ ==================
                if(m_settings.entry_tactic == TACTIC_CONFIRMATION)
                {
                    // تاکتیک ۱: ورود بر اساس تایید (منطق قبلی و محافظه‌کارانه)
                    // منتظر می‌مانیم تا یک سوینگ لو (برای خرید) یا سوینگ های (برای فروش) به طور کامل تایید شود
                    if (ltf_signal.new_swing_formed && (m_signal.is_buy != ltf_signal.is_swing_high))
                    {
                        Log("تاکتیک تایید: پولبک (تشکیل سوینگ مخالف) در LTF تایید شد. آماده برای ورود Market.");
                        if(AreAllFiltersPassed(m_signal.is_buy))
                        {
                            OpenTrade(m_signal.is_buy);
                        }
                        // ریست کامل حالت‌ها پس از تلاش برای ورود
                        m_waiting_for_shift = false;
                        m_waiting_for_pullback = false;
                    }
                }
                else // TACTIC_PREDICTIVE
                {
                    // تاکتیک ۲: ورود پیش‌بینی با لیمیت اردر (منطق جدید و تهاجمی)
                    // به جای انتظار برای تایید، تلاش می‌کنیم یک سفارش لیمیت در محل احتمالی پایان پولبک قرار دهیم
                    Log("تاکتیک پیش‌بینی: جستجو برای محل مناسب لیمیت اردر...");
                    if(PlaceLimitOrder(m_signal.is_buy))
                    {
                        // اگر سفارش با موفقیت گذاشته شد، از حالت انتظار خارج می‌شویم
                        m_waiting_for_shift = false;
                        m_waiting_for_pullback = false;
                    }
                }
                // ======================================================================================
            }
        }
    }
    // --- بخش ۲: اجرای معماری قدیمی (برای سازگاری با تنظیمات قبلی) ---
    else if (m_settings.entry_confirmation_mode == CONFIRM_CURRENT_TIMEFRAME)
    {
        // (این بخش بدون تغییر باقی می‌ماند)
        // منطق برای حالت MODE_REPLACE_SIGNAL
        if (m_settings.signal_mode == MODE_REPLACE_SIGNAL && m_is_waiting)
        {
            bool is_signal_expired = false;
            if (is_new_htf_bar && m_settings.grace_period_mode == GRACE_BY_CANDLES)
            {
                m_signal.grace_candle_count++;
                if (m_signal.grace_candle_count >= m_settings.grace_period_candles) is_signal_expired = true;
            }
            else if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE)
            {
                double current_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
                if (m_signal.invalidation_level > 0 &&
                   ((m_signal.is_buy && current_price < m_signal.invalidation_level) ||
                   (!m_signal.is_buy && current_price > m_signal.invalidation_level)))
                   is_signal_expired = true;
            }

            if (is_signal_expired) { m_is_waiting = false; }
            else if (CheckFinalConfirmation(m_signal.is_buy))
            {
                if (AreAllFiltersPassed(m_signal.is_buy)) { OpenTrade(m_signal.is_buy); }
                m_is_waiting = false;
            }
        }
        // منطق برای حالت MODE_SIGNAL_CONTEST
        else if (m_settings.signal_mode == MODE_SIGNAL_CONTEST && ArraySize(m_potential_signals) > 0)
        {
             for (int i = ArraySize(m_potential_signals) - 1; i >= 0; i--)
             {
                bool is_signal_expired = false;
                if (m_settings.grace_period_mode == GRACE_BY_CANDLES && is_new_htf_bar)
                {
                    m_potential_signals[i].grace_candle_count++;
                    if (m_potential_signals[i].grace_candle_count >= m_settings.grace_period_candles)
                        is_signal_expired = true;
                }
                else if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE)
                {
                    double current_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
                     if (m_potential_signals[i].invalidation_level > 0 &&
                        ((m_potential_signals[i].is_buy && current_price < m_potential_signals[i].invalidation_level) ||
                         (!m_potential_signals[i].is_buy && current_price > m_potential_signals[i].invalidation_level)))
                         is_signal_expired = true;
                }

                if(is_signal_expired)
                {
                    ArrayRemove(m_potential_signals, i, 1);
                    continue;
                }

                if(CheckFinalConfirmation(m_potential_signals[i].is_buy) && AreAllFiltersPassed(m_potential_signals[i].is_buy))
                {
                    OpenTrade(m_potential_signals[i].is_buy);
                    bool winner_is_buy = m_potential_signals[i].is_buy;
                    for (int j = ArraySize(m_potential_signals) - 1; j >= 0; j--)
                    {
                        if (m_potential_signals[j].is_buy == winner_is_buy)
                            ArrayRemove(m_potential_signals, j, 1);
                    }
                    return;
                }
             }
        }
    }



    // مسیر MKM
    else if (m_settings.primary_strategy == STRATEGY_KUMO_MTL)
    {
        if (!m_waiting_for_shift && !m_waiting_for_pullback) return; // اگر منتظر نیست، خروج

        ENUM_TIMEFRAMES ltf = m_settings.ltf_timeframe; // تایم LTF
        bool is_buy = m_signal.is_buy; // نوع سیگنال

        // فیلتر مومنتوم
        double slope_threshold = 0.0; // آستانه شیب
        double slope = CalculateKijunSlope(ltf, m_settings.mkm_kijun_slope_period, slope_threshold); // [MODIFIED] استفاده از تنظیم جدید
        bool momentum_ok = is_buy ? (slope > slope_threshold) : (slope < -slope_threshold); // چک مومنتوم

        // فیلتر نوسان
        bool volatility_ok = IsKumoExpanding(ltf, m_settings.mkm_kumo_expansion_period); // [MODIFIED] استفاده از تنظیم جدید (فرض بر تعریف ورودی جدید)

        // تایید ساختاری
        bool structure_ok = IsChikouInOpenSpace(is_buy, ltf); // چک فضای چیکو

        // ماشه ورود: بونس کیجون
        bool trigger_ok = false; // فلگ ماشه
        int ltf_ichi_handle = iIchimoku(m_symbol, ltf, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period); // هندل LTF
        if (ltf_ichi_handle != INVALID_HANDLE) // چک هندل
        {
            double kijun_buffer[1]; // بافر کیجون
            CopyBuffer(ltf_ichi_handle, 1, 1, 1, kijun_buffer); // کپی کیجون شیفت 1
            double kijun = kijun_buffer[0]; // مقدار کیجون
            IndicatorRelease(ltf_ichi_handle); // آزاد هندل

            if (is_buy && iLow(m_symbol, ltf, 1) <= kijun && iClose(m_symbol, ltf, 1) > kijun) // چک بونس خرید
                trigger_ok = true;
            if (!is_buy && iHigh(m_symbol, ltf, 1) >= kijun && iClose(m_symbol, ltf, 1) < kijun) // چک بونس فروش
                trigger_ok = true;
        }

        if (momentum_ok && volatility_ok && structure_ok && trigger_ok) // اگر تمام شرایط
        {
            Log("تمام شرایط MKM برای " + (is_buy ? "خرید" : "فروش") + " فراهم شد."); // لاگ
            if(AreAllFiltersPassed(is_buy)) // چک فیلترها
            {
                OpenTrade(is_buy); // باز کردن
            }
            m_waiting_for_shift = false; // ریست
            m_waiting_for_pullback = false; // ریست
        }
    }
}

//+------------------------------------------------------------------+
//| چک کراس سه‌گانه (Triple Cross) - بهبود: تلرانس برای Chikou اضافه شد|
//+------------------------------------------------------------------+
bool CStrategyManager::CheckTripleCross(bool& is_buy)
{
    int shift = m_settings.chikou_period; // شیفت مرجع چیکو
    if (iBars(m_symbol, _Period) < shift + 2) return false; // چک تعداد بارها

    double tk_shifted[], ks_shifted[]; // بافرهای شیفت شده
    if(CopyBuffer(m_ichimoku_handle, 0, shift, 2, tk_shifted) < 2 || 
       CopyBuffer(m_ichimoku_handle, 1, shift, 2, ks_shifted) < 2)
    {
       return false; // اگر داده کافی نبود
    }
       
    double tenkan_at_shift = tk_shifted[0]; // تنکان در شیفت
    double kijun_at_shift = ks_shifted[0]; // کیجون در شیفت
    double tenkan_prev_shift = tk_shifted[1]; // تنکان قبلی
    double kijun_prev_shift = ks_shifted[1]; // کیجون قبلی

    bool is_cross_up = tenkan_prev_shift < kijun_prev_shift && tenkan_at_shift > kijun_at_shift; // کراس صعودی
    bool is_cross_down = tenkan_prev_shift > kijun_prev_shift && tenkan_at_shift < kijun_at_shift; // کراس نزولی
    bool is_tk_cross = is_cross_up || is_cross_down; // وجود کراس

    double tolerance = GetTalaqiTolerance(shift); // تلرانس تلاقی
    bool is_confluence = (tolerance > 0) ? (MathAbs(tenkan_at_shift - kijun_at_shift) <= tolerance) : false; // چک تلاقی

    if (!is_tk_cross && !is_confluence) // اگر نه کراس و نه تلاقی
    {
        return false; // بدون سیگنال
    }

    double chikou_now  = iClose(m_symbol, m_settings.ichimoku_timeframe, 1); // چیکو فعلی
    double chikou_prev = iClose(m_symbol, m_settings.ichimoku_timeframe, 2);  // چیکو قبلی

    double upper_line = MathMax(tenkan_at_shift, kijun_at_shift); // خط بالا
    double lower_line = MathMin(tenkan_at_shift, kijun_at_shift); // خط پایین

    // بهبود: تلرانس کوچک برای Chikou (نصف تلرانس TK) برای جلوگیری از نویز
    double chikou_tolerance = tolerance * 0.5; // تلرانس Chikou (پیشنهاد تست شده)

    bool chikou_crosses_up = (chikou_now > upper_line - chikou_tolerance) && (chikou_prev < upper_line + chikou_tolerance); // کراس صعودی با تلرانس
    if (chikou_crosses_up) // اگر صعودی
    {
        is_buy = true; // تنظیم خرید
        return true;  // موفقیت
    }

    bool chikou_crosses_down = (chikou_now < lower_line + chikou_tolerance) && (chikou_prev > lower_line - chikou_tolerance); // کراس نزولی با تلرانس
    if (chikou_crosses_down) // اگر نزولی
    {
        is_buy = false; // تنظیم فروش
        return true;  // موفقیت
    }

    return false;  // بدون سیگنال
}

//+------------------------------------------------------------------+
//| چک تایید نهایی ورود                                              |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckFinalConfirmation(bool is_buy)
{
    switch(m_settings.entry_confirmation_mode) // سوئیچ بر اساس حالت تایید
    {
        case CONFIRM_LOWER_TIMEFRAME: // حالت LTF
            return CheckLowerTfConfirmation(is_buy); // چک LTF

        case CONFIRM_CURRENT_TIMEFRAME: // حالت فعلی
        {
            if (iBars(m_symbol, m_settings.ichimoku_timeframe) < 2) return false; // چک بارها

            CopyBuffer(m_ichimoku_handle, 0, 1, 1, m_tenkan_buffer); // کپی تنکان
            CopyBuffer(m_ichimoku_handle, 1, 1, 1, m_kijun_buffer); // کپی کیجون

            double tenkan_at_1 = m_tenkan_buffer[0]; // تنکان شیفت 1
            double kijun_at_1 = m_kijun_buffer[0]; // کیجون شیفت 1
            double open_at_1 = iOpen(m_symbol, m_settings.ichimoku_timeframe, 1); // باز شیفت 1
            double close_at_1 = iClose(m_symbol, m_settings.ichimoku_timeframe, 1); // بسته شیفت 1

            if (is_buy) // برای خرید
            {
                if (tenkan_at_1 <= kijun_at_1) return false; // چک تنکان بالای کیجون
                if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE) { // چک باز و بسته
                    if (open_at_1 > tenkan_at_1 && open_at_1 > kijun_at_1 && close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                        return true; // تایید
                } else { // چک بسته
                    if (close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                        return true; // تایید
                }
            }
            else // برای فروش
            {
                if (tenkan_at_1 >= kijun_at_1) return false; // چک تنکان پایین کیجون
                if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE) { // چک باز و بسته
                    if (open_at_1 < tenkan_at_1 && open_at_1 < kijun_at_1 && close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                        return true; // تایید
                } else { // چک بسته
                    if (close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                        return true; // تایید
                }
            }
            return false; // عدم تایید
        }
    }
    return false; // پیش‌فرض عدم تایید
}


//+------------------------------------------------------------------+
//| [جدید] قرار دادن سفارش لیمیت بر اساس تاکتیک پیش‌بینی            |
//+------------------------------------------------------------------+
bool CStrategyManager::PlaceLimitOrder(bool is_buy)
{
    // ۱. گرفتن قیمت کیجون‌سن در تایم فریم پایین به عنوان هدف پولبک
    int ltf_ichi_handle = iIchimoku(m_symbol, m_settings.ltf_timeframe, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period);
    if(ltf_ichi_handle == INVALID_HANDLE) return false;

    double kijun_buffer[1];
    if(CopyBuffer(ltf_ichi_handle, 1, 1, 1, kijun_buffer) < 1)
    {
        IndicatorRelease(ltf_ichi_handle);
        return false;
    }
    IndicatorRelease(ltf_ichi_handle);
    double limit_price = kijun_buffer[0];

    // ۲. بررسی منطقی بودن قیمت لیمیت
    // سفارش خرید لیمیت باید پایین‌تر از قیمت فعلی بازار باشد
    if(is_buy && limit_price >= SymbolInfoDouble(m_symbol, SYMBOL_ASK))
    {
        Log("قیمت لیمیت خرید ("+DoubleToString(limit_price, _Digits)+") بالاتر از قیمت فعلی Ask است. سفارش قرار داده نشد.");
        return false;
    }
    // سفارش فروش لیمیت باید بالاتر از قیمت فعلی بازار باشد
    if(!is_buy && limit_price <= SymbolInfoDouble(m_symbol, SYMBOL_BID))
    {
        Log("قیمت لیمیت فروش ("+DoubleToString(limit_price, _Digits)+") پایین‌تر از قیمت فعلی Bid است. سفارش قرار داده نشد.");
        return false;
    }

    // ۳. چک کردن تمام فیلترهای اصلی (کومو، ATR، ADX و...)
    if(!AreAllFiltersPassed(is_buy))
    {
        Log("فیلترها برای قرار دادن لیمیت اردر رد شدند.");
        return false; // هنوز شرایط برای سفارش‌گذاری مناسب نیست
    }
    
    // ۴. محاسبه استاپ لاس بر اساس ساختار (قانون پدربزرگ)
    // ما از سطح ابطال سیگنال که قبلاً مشخص شده به عنوان نقطه مرجع استاپ استفاده می‌کنیم
    double sl = m_signal.invalidation_level;
    if(sl <= 0) 
    {
        Log("خطا: سطح ابطال برای محاسبه استاپ لاس لیمیت اردر نامعتبر است.");
        return false;
    }

    // ۵. محاسبه دقیق حجم معامله و حد سود (کپی شده از منطق OpenTrade برای ثبات)
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (m_settings.risk_percent_per_trade / 100.0);
    double loss_for_one_lot = 0;

    // توجه: محاسبه سود/ضرر برای لیمیت اردر باید بر اساس قیمت لیمیت و استاپ لاس انجام شود
    if(!OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, 1.0, limit_price, sl, loss_for_one_lot))
    {
        Log("خطا در محاسبه سود/زیان برای لیمیت اردر. کد خطا: " + (string)GetLastError());
        return false;
    }
    loss_for_one_lot = MathAbs(loss_for_one_lot);
    if(loss_for_one_lot <= 0)
    {
        Log("میزان ضرر محاسبه شده برای لیمیت اردر معتبر نیست.");
        return false;
    }
    
    double lot_size = NormalizeDouble(risk_amount / loss_for_one_lot, 2);
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
    lot_size = MathRound(lot_size / lot_step) * lot_step;

    if(lot_size < min_lot)
    {
        Log("حجم محاسبه شده برای لیمیت اردر کمتر از حد مجاز است.");
        return false;
    }
    
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double sl_distance_points = MathAbs(limit_price - sl) / point;
    double tp_distance_points = sl_distance_points * m_settings.take_profit_ratio;
    double tp = is_buy ? limit_price + tp_distance_points * point : limit_price - tp_distance_points * point;
    
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    limit_price = NormalizeDouble(limit_price, digits);
    
    // ۶. تنظیم زمان انقضای سفارش (مثلاً ۵ کندل تایم پایین)
    datetime expiration = TimeCurrent() + 5 * (datetime)PeriodSeconds(m_settings.ltf_timeframe);

    // ۷. قرار دادن سفارش لیمیت
    string comment = "Memento Predictive";
    if(is_buy)
    {
        m_trade.BuyLimit(lot_size, limit_price, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, comment);
    }
    else
    {
        m_trade.SellLimit(lot_size, limit_price, m_symbol, sl, tp, ORDER_TIME_SPECIFIED, expiration, comment);
    }
    
    Log("سفارش لیمیت " + (is_buy ? "خرید" : "فروش") + " در قیمت " + DoubleToString(limit_price, _Digits) + " با موفقیت قرار داده شد. حجم: " + DoubleToString(lot_size,2));
    return true; // به نشانه موفقیت در قرار دادن سفارش
}





//+------------------------------------------------------------------+
//| محاسبه سطح استاپ لاس                                             |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateStopLoss(bool is_buy, double entry_price)
{
    ENUM_TIMEFRAMES sl_tf = (m_settings.sl_timeframe == PERIOD_CURRENT) ? _Period : m_settings.sl_timeframe; // تعیین تایم SL
    if (m_settings.stoploss_type == MODE_SIMPLE) // حالت ساده
    {
        double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بافر
        return FindBackupStopLoss(is_buy, buffer, sl_tf); // محاسبه پشتیبان
    }
    if (m_settings.stoploss_type == MODE_ATR) // حالت ATR
    {
        double sl_price = CalculateAtrStopLoss(is_buy, entry_price, sl_tf); // محاسبه ATR
        if (sl_price == 0) // اگر شکست
        {
            Log("محاسبه ATR SL با خطا مواجه شد. استفاده از روش پشتیبان..."); // لاگ
            double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بافر
            return FindBackupStopLoss(is_buy, buffer, sl_tf); // پشتیبان
        }
        return sl_price; // بازگشت SL
    }
    if (m_settings.stoploss_type == MODE_STRUCTURE) // [NEW] حالت ساختاری
    {
        double sl_price = CalculateStructuralStopLoss(is_buy, entry_price); // محاسبه ساختاری
        if (sl_price == 0) // اگر شکست
        {
            Log("محاسبه Structural SL با خطا مواجه شد. استفاده از روش پشتیبان..."); // لاگ
            double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بافر
            return FindBackupStopLoss(is_buy, buffer, sl_tf); // پشتیبان
        }
        return sl_price; // بازگشت SL
    }

    // حالت پیچیده (بهینه)
    Log("شروع فرآیند انتخاب استاپ لاس بهینه..."); // لاگ شروع
    double candidates[]; // آرایه کاندیداها
    int count = 0; // شمارنده
    double sl_candidate = 0; // کاندیدای موقت
    double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بافر
    
    sl_candidate = FindFlatKijun(sl_tf); // کاندیدای کیجون فلت
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر اندازه
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; // تنظیم با بافر
        count++; // افزایش
    }
    
    sl_candidate = FindPivotKijun(is_buy, sl_tf); // کاندیدای پیوت کیجون
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر اندازه
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; // تنظیم
        count++; // افزایش
    }

    sl_candidate = FindPivotTenkan(is_buy, sl_tf); // کاندیدای پیوت تنکان
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر اندازه
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; // تنظیم
        count++; // افزایش
    }

    sl_candidate = FindBackupStopLoss(is_buy, buffer, sl_tf); // کاندیدای ساده
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر اندازه
        candidates[count] = sl_candidate; // اضافه
        count++; // افزایش
    }
    
    sl_candidate = CalculateAtrStopLoss(is_buy, entry_price, sl_tf); // کاندیدای ATR
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر اندازه
        candidates[count] = sl_candidate; // اضافه
        count++; // افزایش
    }

    if (count == 0) // اگر هیچ کاندیدا
    {
        Log("خطا: هیچ کاندیدای اولیه‌ای برای استاپ لاس پیدا نشد."); // لاگ
        return 0.0; // صفر
    }

    // اعتبارسنجی کاندیداها
    double valid_candidates[]; // آرایه معتبرها
    int valid_count = 0; // شمارنده معتبر
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); // پوینت نماد
    double spread = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * point; // اسپرد
    double min_safe_distance = spread + buffer;  // حداقل فاصله ایمن

    for (int i = 0; i < count; i++) // حلقه اعتبارسنجی
    {
        double current_sl = candidates[i]; // SL فعلی
        
        if ((is_buy && current_sl >= entry_price) || (!is_buy && current_sl <= entry_price)) // چک موقعیت نامعتبر
        {
            continue;  // رد کاندیدا
        }

        if (MathAbs(entry_price - current_sl) < min_safe_distance) // چک فاصله کم
        {
            current_sl = is_buy ? entry_price - min_safe_distance : entry_price + min_safe_distance; // اصلاح SL
            Log("کاندیدای شماره " + (string)(i+1) + " به دلیل نزدیکی بیش از حد به قیمت " + DoubleToString(current_sl, _Digits) + " اصلاح شد."); // لاگ
        }

        ArrayResize(valid_candidates, valid_count + 1); // تغییر اندازه
        valid_candidates[valid_count] = current_sl; // اضافه به معتبرها
        valid_count++; // افزایش
    }

    if (valid_count == 0) // اگر هیچ معتبر
    {
        Log("خطا: پس از فیلترینگ، هیچ کاندیدای معتبری برای استاپ لاس باقی نماند."); // لاگ
        return 0.0; // صفر
    }
    
    // انتخاب نزدیک‌ترین معتبر
    double best_sl_price = 0.0; // بهترین SL
    double smallest_distance = DBL_MAX; // حداقل فاصله اولیه

    for (int i = 0; i < valid_count; i++) // حلقه انتخاب
    {
        double distance = MathAbs(entry_price - valid_candidates[i]); // فاصله
        if (distance < smallest_distance) // اگر کوچکتر
        {
            smallest_distance = distance; // آپدیت حداقل
            best_sl_price = valid_candidates[i]; // بهترین
        }
    }

    Log("✅ استاپ لاس بهینه پیدا شد: " + DoubleToString(best_sl_price, _Digits) + ". فاصله: " + DoubleToString(smallest_distance / point, 1) + " پوینت."); // لاگ موفقیت

    return best_sl_price; // بازگشت بهترین SL
}

//+------------------------------------------------------------------+
//| محاسبه SL پشتیبان بر اساس کندل مخالف                             |
//+------------------------------------------------------------------+
double CStrategyManager::FindBackupStopLoss(bool is_buy, double buffer, ENUM_TIMEFRAMES timeframe)
{
    int bars_to_check = m_settings.sl_lookback_period; // تعداد بار برای چک
    if (iBars(m_symbol, timeframe) < bars_to_check + 1) return 0; // چک تعداد بارها
    
    for (int i = 1; i <= bars_to_check; i++) // حلقه به عقب
    {
        bool is_candle_bullish = (iClose(m_symbol, timeframe, i) > iOpen(m_symbol, timeframe, i)); // چک صعودی
        bool is_candle_bearish = (iClose(m_symbol, timeframe, i) < iOpen(m_symbol, timeframe, i)); // چک نزولی

        if (is_buy) // برای خرید
        {
            if (is_candle_bearish) // اگر نزولی پیدا شد
            {
                double sl_price = iLow(m_symbol, timeframe, i) - buffer; // SL زیر کف
                Log("استاپ لاس ساده: اولین کندل نزولی در شیفت " + (string)i + " پیدا شد."); // لاگ
                return sl_price; // بازگشت
            }
        }
        else // برای فروش
        {
            if (is_candle_bullish) // اگر صعودی پیدا شد
            {
                double sl_price = iHigh(m_symbol, timeframe, i) + buffer; // SL بالای سقف
                Log("استاپ لاس ساده: اولین کندل صعودی در شیفت " + (string)i + " پیدا شد."); // لاگ
                return sl_price; // بازگشت
            }
        }
    }
    
    // پشتیبان اگر مخالف پیدا نشد
    Log("هیچ کندل رنگ مخالفی برای استاپ لاس ساده پیدا نشد. از روش سقف/کف مطلق استفاده می‌شود."); // لاگ
    CopyHigh(m_symbol, timeframe, 1, bars_to_check, m_high_buffer); // کپی سقف‌ها
    CopyLow(m_symbol, timeframe, 1, bars_to_check, m_low_buffer); // کپی کف‌ها

    if(is_buy) // برای خرید
    {
       int min_index = ArrayMinimum(m_low_buffer, 0, bars_to_check); // حداقل کف
       return m_low_buffer[min_index] - buffer; // بازگشت با بافر
    }
    else // برای فروش
    {
       int max_index = ArrayMaximum(m_high_buffer, 0, bars_to_check); // حداکثر سقف
       return m_high_buffer[max_index] + buffer; // بازگشت با بافر
    }
}

//+------------------------------------------------------------------+
//| پیدا کردن کیجون فلت                                              |
//+------------------------------------------------------------------+
double CStrategyManager::FindFlatKijun(ENUM_TIMEFRAMES timeframe)
{
    int kijun_handle = m_ichimoku_handle; // هندل پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // اگر متفاوت
    {
        MqlParam params[3]; // پارامترها
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.tenkan_period;
        params[1].type = TYPE_INT; params[1].integer_value = m_settings.kijun_period;
        params[2].type = TYPE_INT; params[2].integer_value = m_settings.senkou_period;
        kijun_handle = IndicatorCreate(m_symbol, timeframe, IND_ICHIMOKU, 3, params); // موقت
        if (kijun_handle == INVALID_HANDLE) return 0.0; // شکست
    }

    double kijun_values[]; // آرایه کیجون
    if (CopyBuffer(kijun_handle, 1, 1, m_settings.flat_kijun_period, kijun_values) < m_settings.flat_kijun_period) // کپی
    {
        if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
        return 0.0; // صفر
    }

    ArraySetAsSeries(kijun_values, true); // تنظیم سری

    int flat_count = 1; // شمارنده فلت
    for (int i = 1; i < m_settings.flat_kijun_period; i++) // حلقه چک فلت
    {
        if (kijun_values[i] == kijun_values[i - 1]) // اگر برابر
        {
            flat_count++; // افزایش
            if (flat_count >= m_settings.flat_kijun_min_length) // اگر حداقل طول
            {
                if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
                return kijun_values[i]; // بازگشت سطح فلت
            }
        }
        else // ریست فلت
        {
            flat_count = 1; // ریست
        }
    }

    if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد نهایی
    return 0.0; // هیچ فلت
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت روی کیجون                                         |
//+------------------------------------------------------------------+
double CStrategyManager::FindPivotKijun(bool is_buy, ENUM_TIMEFRAMES timeframe)
{
    int kijun_handle = m_ichimoku_handle; // پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
    {
        MqlParam params[3]; // پارامترها
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.tenkan_period;
        params[1].type = TYPE_INT; params[1].integer_value = m_settings.kijun_period;
        params[2].type = TYPE_INT; params[2].integer_value = m_settings.senkou_period;
        kijun_handle = IndicatorCreate(m_symbol, timeframe, IND_ICHIMOKU, 3, params); // موقت
        if (kijun_handle == INVALID_HANDLE) return 0.0; // شکست
    }

    double kijun_values[]; // آرایه
    if (CopyBuffer(kijun_handle, 1, 1, m_settings.pivot_lookback, kijun_values) < m_settings.pivot_lookback) // کپی
    {
        if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
        return 0.0; // صفر
    }

    ArraySetAsSeries(kijun_values, true); // سری

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++) // حلقه پیوت
    {
        if (is_buy && kijun_values[i] < kijun_values[i - 1] && kijun_values[i] < kijun_values[i + 1]) // دره برای خرید
        {
            if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
            return kijun_values[i]; // بازگشت
        }
        if (!is_buy && kijun_values[i] > kijun_values[i - 1] && kijun_values[i] > kijun_values[i + 1]) // قله برای فروش
        {
            if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
            return kijun_values[i]; // بازگشت
        }
    }

    if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد نهایی
    return 0.0; // هیچ پیوت
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت روی تنکان                                         |
//+------------------------------------------------------------------+
double CStrategyManager::FindPivotTenkan(bool is_buy, ENUM_TIMEFRAMES timeframe)
{
    int tenkan_handle = m_ichimoku_handle; // پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
    {
        MqlParam params[3]; // پارامترها
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.tenkan_period;
        params[1].type = TYPE_INT; params[1].integer_value = m_settings.kijun_period;
        params[2].type = TYPE_INT; params[2].integer_value = m_settings.senkou_period;
        tenkan_handle = IndicatorCreate(m_symbol, timeframe, IND_ICHIMOKU, 3, params); // موقت
        if (tenkan_handle == INVALID_HANDLE) return 0.0; // شکست
    }

    double tenkan_values[]; // آرایه
    if (CopyBuffer(tenkan_handle, 0, 1, m_settings.pivot_lookback, tenkan_values) < m_settings.pivot_lookback) // کپی
    {
        if (tenkan_handle != m_ichimoku_handle) IndicatorRelease(tenkan_handle); // آزاد
        return 0.0; // صفر
    }

    ArraySetAsSeries(tenkan_values, true); // سری

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++) // حلقه پیوت
    {
        if (is_buy && tenkan_values[i] < tenkan_values[i - 1] && tenkan_values[i] < tenkan_values[i + 1]) // دره
        {
            if (tenkan_handle != m_ichimoku_handle) IndicatorRelease(tenkan_handle); // آزاد
            return tenkan_values[i]; // بازگشت
        }
        if (!is_buy && tenkan_values[i] > tenkan_values[i - 1] && tenkan_values[i] > tenkan_values[i + 1]) // قله
        {
            if (tenkan_handle != m_ichimoku_handle) IndicatorRelease(tenkan_handle); // آزاد
            return tenkan_values[i]; // بازگشت
        }
    }

    if (tenkan_handle != m_ichimoku_handle) IndicatorRelease(tenkan_handle); // آزاد نهایی
    return 0.0; // هیچ
}

//+------------------------------------------------------------------+
//| محاسبه SL مبتنی بر ATR                                            |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateAtrStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe)
{
    if (!m_settings.enable_sl_vol_regime) // اگر پویا غیرفعال
    {
        int atr_handle = m_atr_handle; // پیش‌فرض
        if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
        {
            MqlParam params[1]; // پارامتر
            params[0].type = TYPE_INT; params[0].integer_value = m_settings.atr_filter_period;
            atr_handle = IndicatorCreate(m_symbol, timeframe, IND_ATR, 1, params); // موقت
            if (atr_handle == INVALID_HANDLE) // چک
            {
                Log("خطای بحرانی در CalculateAtrStopLoss: هندل ATR نامعتبر است! پریود ATR در تنظیمات ورودی را بررسی کنید."); // لاگ
                return 0.0; // صفر
            }
        }
        
        double atr_buffer[]; // بافر
        if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) < 1) // کپی
        {
            Log("داده ATR برای محاسبه حد ضرر ساده موجود نیست. (تابع CopyBuffer شکست خورد)"); // لاگ
            if (atr_handle != m_atr_handle) IndicatorRelease(atr_handle); // آزاد
            return 0.0; // صفر
        }
        
        if (atr_handle != m_atr_handle) IndicatorRelease(atr_handle); // آزاد
        
        double atr_value = atr_buffer[0]; // مقدار ATR
        double sl = is_buy ? entry_price - (atr_value * m_settings.sl_atr_multiplier) : entry_price + (atr_value * m_settings.sl_atr_multiplier); // SL اولیه
        // [NEW] اعمال حداقل فاصله و بافر ATR-based
        double min_distance = atr_value * m_settings.min_sl_distance_atr_percent / 100.0; // حداقل فاصله
        double atr_buffer_val = atr_value * m_settings.sl_buffer_atr_percent / 100.0; // بافر ATR
        if (MathAbs(entry_price - sl) < min_distance) // چک حداقل
        {
            sl = is_buy ? entry_price - min_distance : entry_price + min_distance; // اصلاح
        }
        sl = is_buy ? sl - atr_buffer_val : sl + atr_buffer_val; // اعمال بافر
        return sl; // بازگشت SL نهایی
    }

    // منطق پویا
    int history_size = m_settings.sl_vol_regime_ema_period + 5; // اندازه تاریخچه
    double atr_values[], ema_values[]; // آرایه‌ها

    int atr_sl_handle = iATR(m_symbol, timeframe, m_settings.sl_vol_regime_atr_period); // هندل ATR
    if (atr_sl_handle == INVALID_HANDLE || CopyBuffer(atr_sl_handle, 0, 0, history_size, atr_values) < history_size) // چک
    {
        Log("داده کافی برای محاسبه SL پویا موجود نیست."); // لاگ
        if(atr_sl_handle != INVALID_HANDLE) 
            IndicatorRelease(atr_sl_handle); // آزاد
        return 0.0; // صفر
    }
    
    IndicatorRelease(atr_sl_handle); // آزاد
    ArraySetAsSeries(atr_values, true);  // سری

    if(SimpleMAOnBuffer(history_size, 0, m_settings.sl_vol_regime_ema_period, MODE_EMA, atr_values, ema_values) < 1) // محاسبه EMA
    {
         Log("خطا در محاسبه EMA روی ATR."); // لاگ
         return 0.0; // صفر
    }

    double current_atr = atr_values[1];  // ATR شیفت 1
    double ema_atr = ema_values[1];      // EMA شیفت 1

    bool is_high_volatility = (current_atr > ema_atr); // چک رژیم بالا
    double final_multiplier = is_high_volatility ? m_settings.sl_high_vol_multiplier : m_settings.sl_low_vol_multiplier; // ضریب نهایی

    Log("رژیم نوسان: " + (is_high_volatility ? "بالا" : "پایین") + ". ضریب SL نهایی: " + (string)final_multiplier); // لاگ

    double sl = is_buy ? entry_price - (current_atr * final_multiplier) : entry_price + (current_atr * final_multiplier); // SL پویا
    // [NEW] اعمال حداقل فاصله و بافر ATR-based
    double min_distance = current_atr * m_settings.min_sl_distance_atr_percent / 100.0; // حداقل
    double atr_buffer_val = current_atr * m_settings.sl_buffer_atr_percent / 100.0; // بافر
    if (MathAbs(entry_price - sl) < min_distance) // چک
    {
        sl = is_buy ? entry_price - min_distance : entry_price + min_distance; // اصلاح
    }
    sl = is_buy ? sl - atr_buffer_val : sl + atr_buffer_val; // اعمال بافر
    return sl; // بازگشت
}

//+------------------------------------------------------------------+
//| محاسبه تلرانس تلاقی                                               |
//+------------------------------------------------------------------+
double CStrategyManager::GetTalaqiTolerance(int reference_shift)
{
    switch(m_settings.talaqi_calculation_mode) // سوئیچ حالت
    {
        case TALAQI_MODE_MANUAL: // دستی
            return m_settings.talaqi_distance_in_points * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بر اساس پوینت
        case TALAQI_MODE_KUMO: // کومو
            return CalculateDynamicTolerance(reference_shift); // پویا کومو
        case TALAQI_MODE_ATR: // ATR
            return CalculateAtrTolerance(reference_shift);     // ATR
        default: // پیش‌فرض
            return 0.0; // بدون تلرانس
    }
}

//+------------------------------------------------------------------+
//| محاسبه تلرانس بر اساس کومو                                       |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateDynamicTolerance(int reference_shift)
{
    if(m_settings.talaqi_kumo_factor <= 0) return 0.0; // اگر ضریب نامعتبر

    double senkou_a_buffer[], senkou_b_buffer[]; // بافرهای سنکو

    if(CopyBuffer(m_ichimoku_handle, 2, reference_shift, 1, senkou_a_buffer) < 1 || 
       CopyBuffer(m_ichimoku_handle, 3, reference_shift, 1, senkou_b_buffer) < 1)
    {
       Log("داده کافی برای محاسبه ضخامت کومو در گذشته وجود ندارد."); // لاگ
       return 0.0; // صفر
    }

    double kumo_thickness = MathAbs(senkou_a_buffer[0] - senkou_b_buffer[0]); // ضخامت کومو

    if(kumo_thickness == 0) return SymbolInfoDouble(m_symbol, SYMBOL_POINT); // حداقل کوچک

    double tolerance = kumo_thickness * m_settings.talaqi_kumo_factor; // تلرانس

    return tolerance; // بازگشت
}

//+------------------------------------------------------------------+
//| اضافه کردن سیگنال به لیست در حالت مسابقه                        |
//+------------------------------------------------------------------+
void CStrategyManager::AddOrUpdatePotentialSignal(bool is_buy)
{
    int total = ArraySize(m_potential_signals); // تعداد فعلی
    ArrayResize(m_potential_signals, total + 1); // اضافه یک عضو
    
    m_potential_signals[total].time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou_period); // زمان
    m_potential_signals[total].is_buy = is_buy; // نوع
    m_potential_signals[total].grace_candle_count = 0; // ریست شمارنده
    
    Log("[حالت مسابقه‌ای] سیگنال نامزد جدید " + (is_buy ? "خرید" : "فروش") + " به لیست انتظار مسابقه اضافه شد. تعداد کل نامزدها: " + (string)ArraySize(m_potential_signals)); // لاگ
    
    if(m_symbol == _Symbol && m_visual_manager != NULL) // چک رسم
    m_visual_manager.DrawTripleCrossRectangle(is_buy, m_settings.chikou_period); // رسم
}

//+------------------------------------------------------------------+
//| محاسبه تلرانس بر اساس ATR                                        |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateAtrTolerance(int reference_shift)
{
    if(m_settings.talaqi_atr_multiplier <= 0) return 0.0; // اگر ضریب نامعتبر
    
    if (m_atr_handle == INVALID_HANDLE) // چک هندل
    {
        Log("محاسبه تلورانس ATR ممکن نیست چون هندل آن نامعتبر است. پریود ATR در تنظیمات ورودی را بررسی کنید."); // لاگ
        return 0.0; // صفر
    }

    double atr_buffer[]; // بافر
    if(CopyBuffer(m_atr_handle, 0, reference_shift, 1, atr_buffer) < 1) // کپی
    {
        Log("داده کافی برای محاسبه ATR در گذشته وجود ندارد."); // لاگ
        return 0.0; // صفر
    }
    
    double tolerance = atr_buffer[0] * m_settings.talaqi_atr_multiplier; // تلرانس
    return tolerance; // بازگشت
}

//+------------------------------------------------------------------+
//| چک تمام فیلترهای ورود                                            |
//+------------------------------------------------------------------+
bool CStrategyManager::AreAllFiltersPassed(bool is_buy)
{
    ENUM_TIMEFRAMES filter_tf = (m_settings.filter_context == FILTER_CONTEXT_HTF) 
                                ? m_settings.ichimoku_timeframe 
                                : m_settings.ltf_timeframe; // تایم فیلتر

    if (m_settings.enable_kumo_filter) // فیلتر کومو
    {
        if (!CheckKumoFilter(is_buy, filter_tf)) // چک
        {
            Log("فیلتر کومو رد شد."); // لاگ
            return false; // رد
        }
    }

    if (m_settings.enable_atr_filter) // فیلتر ATR
    {
        if (!CheckAtrFilter(filter_tf)) // چک
        {
            Log("فیلتر ATR رد شد."); // لاگ
            return false; // رد
        }
    }

    if (m_settings.enable_adx_filter) // فیلتر ADX
    {
        if (!CheckAdxFilter(is_buy, filter_tf)) // چک
        {
            Log("فیلتر ADX رد شد."); // لاگ
            return false; // رد
        }
    }

    // فیلترهای MKM
    if (m_settings.enable_kijun_slope_filter) // شیب کیجون
    {
        double threshold = 0.0; // آستانه
        double slope = CalculateKijunSlope(filter_tf, 5, threshold); // محاسبه
        if (is_buy && slope <= threshold) return false; // رد خرید
        if (!is_buy && slope >= -threshold) return false; // رد فروش
    }
    if (m_settings.enable_kumo_expansion_filter) // انبساط کومو
    {
        if (!IsKumoExpanding(filter_tf, 20)) return false; // رد
    }
    if (m_settings.enable_chikou_space_filter) // فضای چیکو
    {
        if (!IsChikouInOpenSpace(is_buy, filter_tf)) return false; // رد
    }

    Log("✅ تمام فیلترهای فعال با موفقیت پاس شدند."); // لاگ موفقیت
    return true; // پاس
}

//+------------------------------------------------------------------+
//| فیلتر موقعیت نسبت به کومو                                         |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckKumoFilter(bool is_buy, ENUM_TIMEFRAMES timeframe)
{
    int ichi_handle = m_ichimoku_handle; // پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
    {
        MqlParam params[3]; // پارامترها
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.tenkan_period;
        params[1].type = TYPE_INT; params[1].integer_value = m_settings.kijun_period;
        params[2].type = TYPE_INT; params[2].integer_value = m_settings.senkou_period;
        ichi_handle = IndicatorCreate(m_symbol, timeframe, IND_ICHIMOKU, 3, params); // موقت
        if (ichi_handle == INVALID_HANDLE) // چک
        {
            Log("خطا: هندل ایچیموکو برای فیلتر کومو در تایم فریم " + EnumToString(timeframe) + " ایجاد نشد."); // لاگ
            return false; // رد
        }
    }
    
    double senkou_a[], senkou_b[]; // بافرها
    if(CopyBuffer(ichi_handle, 2, 0, 1, senkou_a) < 1 || 
       CopyBuffer(ichi_handle, 3, 0, 1, senkou_b) < 1)
    {
       Log("خطا: داده کافی برای فیلتر کومو موجود نیست."); // لاگ
       if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد
       return false; // رد
    }
    
    if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد
    
    double high_kumo = MathMax(senkou_a[0], senkou_b[0]); // بالای کومو
    double low_kumo = MathMin(senkou_a[0], senkou_b[0]); // پایین کومو
    double close_price = iClose(m_symbol, timeframe, 1); // بسته شیفت 1

    if (is_buy) // خرید
    {
        return (close_price > high_kumo); // بالای کومو
    }
    else // فروش
    {
        return (close_price < low_kumo); // پایین کومو
    }
}

//+------------------------------------------------------------------+
//| فیلتر حداقل ATR                                                   |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckAtrFilter(ENUM_TIMEFRAMES timeframe)
{
    int atr_handle = m_atr_handle; // پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
    {
        MqlParam params[1]; // پارامتر
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.atr_filter_period;
        atr_handle = IndicatorCreate(m_symbol, timeframe, IND_ATR, 1, params); // موقت
        if (atr_handle == INVALID_HANDLE) // چک
        {
            Log("فیلتر ATR رد شد چون هندل آن نامعتبر است. پریود ATR در تنظیمات ورودی را بررسی کنید."); // لاگ
            return false; // رد
        }
    }
    
    double atr_value_buffer[]; // بافر
    if(CopyBuffer(atr_handle, 0, 1, 1, atr_value_buffer) < 1) // کپی
    {
       Log("خطا: داده کافی برای فیلتر ATR موجود نیست."); // لاگ
       if (atr_handle != m_atr_handle) IndicatorRelease(atr_handle); // آزاد
       return false; // رد
    }
    
    if (atr_handle != m_atr_handle) IndicatorRelease(atr_handle); // آزاد
    
    double current_atr = atr_value_buffer[0]; // ATR فعلی
    
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); // پوینت
    double min_atr_threshold = m_settings.atr_filter_min_value_pips * point; // آستانه
    
    if(_Digits == 3 || _Digits == 5) // تنظیم برای نمادهای 3 یا 5 رقمی
    {
        min_atr_threshold *= 10; // ضرب در 10
    }

    return (current_atr >= min_atr_threshold); // چک حداقل
}

//+------------------------------------------------------------------+
//| فیلتر ADX                                                         |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckAdxFilter(bool is_buy, ENUM_TIMEFRAMES timeframe) 
{  
    int adx_handle = m_adx_handle; // پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
    {
        MqlParam params[1]; // پارامتر
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.adx_period;
        adx_handle = IndicatorCreate(m_symbol, timeframe, IND_ADX, 1, params); // موقت
        if (adx_handle == INVALID_HANDLE) // چک
        {
            Log("خطا در ایجاد هندل ADX برای فیلتر در تایم فریم " + EnumToString(timeframe)); // لاگ
            return false; // رد
        }
    }
    
    double adx_buffer[1], di_plus_buffer[1], di_minus_buffer[1];  // بافرها
    
    if (CopyBuffer(adx_handle, 0, 1, 1, adx_buffer) < 1 ||  // ADX
        CopyBuffer(adx_handle, 1, 1, 1, di_plus_buffer) < 1 ||  // DI+
        CopyBuffer(adx_handle, 2, 1, 1, di_minus_buffer) < 1) // DI-
    {
        Log("داده کافی برای فیلتر ADX موجود نیست."); // لاگ
        if (adx_handle != m_adx_handle) IndicatorRelease(adx_handle); // آزاد
        return false; // رد
    }
    
    if (adx_handle != m_adx_handle) IndicatorRelease(adx_handle); // آزاد
    
    if (adx_buffer[0] <= m_settings.adx_threshold)  // چک قدرت
    {
        return false; // رد
    }
    
    if (is_buy) // خرید
    {
        return (di_plus_buffer[0] > di_minus_buffer[0]); // DI+ > DI-
    }
    else // فروش
    {
        return (di_minus_buffer[0] > di_plus_buffer[0]); // DI- > DI+
    }
}

//+------------------------------------------------------------------+
//| چک خروج زودرس از معاملات                                         |
//+------------------------------------------------------------------+
void CStrategyManager::CheckForEarlyExit()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)  // حلقه پوزیشن‌ها
    {
        ulong ticket = PositionGetTicket(i); // تیکت پوزیشن
        if (PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number) // چک نماد و مجیک
        {
            if (PositionSelectByTicket(ticket)) // انتخاب پوزیشن
            {
                bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY); // نوع پوزیشن
                if (CheckChikouRsiExit(is_buy))  // چک شرایط خروج
                { 
                    Log("🚨 سیگنال خروج زودرس برای تیکت " + (string)ticket + " صادر شد. بستن معامله..."); // لاگ
                    m_trade.PositionClose(ticket);  // بستن پوزیشن
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| چک شرایط خروج با چیکو و RSI                                      |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckChikouRsiExit(bool is_buy)
{
    double chikou_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1); // چیکو شیفت 1
    
    double tenkan_buffer[1], kijun_buffer[1], rsi_buffer[1]; // بافرها
    if(CopyBuffer(m_ichimoku_handle, 0, 1, 1, tenkan_buffer) < 1 ||
       CopyBuffer(m_ichimoku_handle, 1, 1, 1, kijun_buffer) < 1 ||
       CopyBuffer(m_rsi_exit_handle, 0, 1, 1, rsi_buffer) < 1)
    {
        return false; // اگر داده نبود
    }
    
    double tenkan = tenkan_buffer[0]; // تنکان
    double kijun = kijun_buffer[0]; // کیجون
    double rsi = rsi_buffer[0]; // RSI
    
    bool chikou_cross_confirms_exit = false; // فلگ چیکو
    bool rsi_confirms_exit = false; // فلگ RSI

    if (is_buy) // خروج از خرید (نزولی)
    {
        chikou_cross_confirms_exit = (chikou_price < MathMin(tenkan, kijun)); // چیکو زیر خطوط
        rsi_confirms_exit = (rsi < m_settings.early_exit_rsi_oversold); // RSI اشباع فروش
    }
    else // خروج از فروش (صعودی)
    {
        chikou_cross_confirms_exit = (chikou_price > MathMax(tenkan, kijun)); // چیکو بالای خطوط
        rsi_confirms_exit = (rsi > m_settings.early_exit_rsi_overbought); // RSI اشباع خرید
    }
    
    return (chikou_cross_confirms_exit && rsi_confirms_exit); // بازگشت اگر هر دو
}

//+------------------------------------------------------------------+
//| چک تایید LTF (اصلاح شده)                                         |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckLowerTfConfirmation(bool is_buy)
{
    if (is_buy)
    {
        if (m_ltf_analyzer.IsUptrend())
        {
            Log("✅ تاییدیه ساختار صعودی (HH/HL) در LTF دریافت شد.");
            return true;
        }
    }
    else 
    {
        if (m_ltf_analyzer.IsDowntrend())
        {
            Log("✅ تاییدیه ساختار نزولی (LH/LL) در LTF دریافت شد.");
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| تابع لاگ                                                          |
//+------------------------------------------------------------------+
void CStrategyManager::Log(string message)
{
    if (m_settings.enable_logging) // اگر لاگ فعال
    {
        Print(m_symbol, ": ", message); // چاپ پیام
    }
}

//+------------------------------------------------------------------+
//| شمارش معاملات نماد                                               |
//+------------------------------------------------------------------+
int CStrategyManager::CountSymbolTrades()
{
    int count = 0; // شمارنده
    for(int i = PositionsTotal() - 1; i >= 0; i--) // حلقه پوزیشن‌ها
    {
        if(PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number) // چک
        {
            count++; // افزایش
        }
    }
    return count; // بازگشت
}

//+------------------------------------------------------------------+
//| شمارش کل معاملات                                                 |
//+------------------------------------------------------------------+
int CStrategyManager::CountTotalTrades()
{
    int count = 0; // شمارنده
    for(int i = PositionsTotal() - 1; i >= 0; i--) // حلقه
    {
        if(PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number) // چک مجیک
        {
            count++; // افزایش
        }
    }
    return count; // بازگشت
}

//+------------------------------------------------------------------+
//| باز کردن معامله                                                  |
//+------------------------------------------------------------------+
void CStrategyManager::OpenTrade(bool is_buy)
{
    if(CountTotalTrades() >= m_settings.max_total_trades || CountSymbolTrades() >= m_settings.max_trades_per_symbol) // چک حد
    {
        Log("رسیدن به حد مجاز معاملات. معامله جدید باز نشد."); // لاگ
        return; // خروج
    }

    double entry_price = is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID); // قیمت ورود
    double sl = CalculateStopLoss(is_buy, entry_price); // محاسبه SL

    if(sl == 0) // چک SL
    {
        Log("خطا در محاسبه استاپ لاس. معامله باز نشد."); // لاگ
        return; // خروج
    }
    
    double balance = AccountInfoDouble(ACCOUNT_BALANCE); // بالانس حساب
    double risk_amount = balance * (m_settings.risk_percent_per_trade / 100.0); // ریسک به پول

    double loss_for_one_lot = 0; // ضرر یک لات
    if(!OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, 1.0, entry_price, sl, loss_for_one_lot)) // محاسبه
    {
        Log("خطا در محاسبه سود/زیان با OrderCalcProfit. کد خطا: " + (string)GetLastError()); // لاگ
        return; // خروج
    }
    loss_for_one_lot = MathAbs(loss_for_one_lot); // مطلق ضرر

    if(loss_for_one_lot <= 0) // چک معتبر
    {
        Log("میزان ضرر محاسبه شده برای ۱ لات معتبر نیست. معامله باز نشد."); // لاگ
        return; // خروج
    }

    double lot_size = NormalizeDouble(risk_amount / loss_for_one_lot, 2); // حجم لات

    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN); // حداقل لات
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX); // حداکثر لات
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP); // گام لات
    
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size)); // محدوده
    lot_size = MathRound(lot_size / lot_step) * lot_step; // گرد کردن

    if(lot_size < min_lot) // چک حداقل
    {
        Log("حجم محاسبه شده (" + DoubleToString(lot_size,2) + ") کمتر از حداقل لات مجاز (" + DoubleToString(min_lot,2) + ") است. معامله باز نشد."); // لاگ
        return; // خروج
    }

    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); // پوینت
    double sl_distance_points = MathAbs(entry_price - sl) / point; // فاصله SL به پوینت
    double tp_distance_points = sl_distance_points * m_settings.take_profit_ratio; // فاصله TP
    double tp = is_buy ? entry_price + tp_distance_points * point : entry_price - tp_distance_points * point; // TP
    
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS); // digits نماد
    sl = NormalizeDouble(sl, digits); // نرمال SL
    tp = NormalizeDouble(tp, digits); // نرمال TP
    
    string comment = "Memento " + (is_buy ? "Buy" : "Sell"); // کامنت معامله
    MqlTradeResult result; // نتیجه معامله
    
    if(is_buy) // خرید
    {
        m_trade.Buy(lot_size, m_symbol, 0, sl, tp, comment); // باز کردن خرید
    }
    else // فروش
    {
        m_trade.Sell(lot_size, m_symbol, 0, sl, tp, comment); // باز کردن فروش
    }
    
    if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE) // چک موفقیت
    {
        Log("معامله " + comment + " با لات " + DoubleToString(lot_size, 2) + " با موفقیت باز شد."); // لاگ
    }
    else // شکست
    {
        Log("خطا در باز کردن معامله " + comment + ": " + (string)m_trade.ResultRetcode() + " - " + m_trade.ResultComment()); // لاگ
    }
}

//+------------------------------------------------------------------+
//| چک آماده بودن داده‌ها                                             |
//+------------------------------------------------------------------+
bool CStrategyManager::IsDataReady()
{
    ENUM_TIMEFRAMES timeframes_to_check[3]; // آرایه تایم فریم‌ها
    timeframes_to_check[0] = m_settings.ichimoku_timeframe; // HTF
    timeframes_to_check[1] = m_settings.ltf_timeframe;      // LTF
    timeframes_to_check[2] = PERIOD_CURRENT;                 // فعلی

    int required_bars = 200;  // حداقل بار مورد نیاز

    for(int i = 0; i < 3; i++) // حلقه چک
    {
        ENUM_TIMEFRAMES tf = timeframes_to_check[i]; // تایم فعلی
        if(iBars(m_symbol, tf) < required_bars || iTime(m_symbol, tf, 1) == 0) // چک بار و زمان
        {
            // Log("داده برای تایم فریم " + EnumToString(tf) + " هنوز آماده نیست.");
            return false; // نه آماده
        }
    }
    
    return true;  // آماده
}

//+------------------------------------------------------------------+
//| چک کندل جدید                                                      |
//+------------------------------------------------------------------+
bool CStrategyManager::IsNewBar(ENUM_TIMEFRAMES timeframe, datetime &last_bar_time)
{
    datetime current_bar_time = iTime(m_symbol, timeframe, 0); // زمان فعلی
    if (current_bar_time > last_bar_time) // اگر جدید
    {
        last_bar_time = current_bar_time; // آپدیت
        return true; // جدید
    }
    return false; // قدیمی
}

//+------------------------------------------------------------------+
//| محاسبه شیب کیجون                                                 |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateKijunSlope(ENUM_TIMEFRAMES timeframe, int period, double& threshold)
{
    threshold = 0.0; // آستانه پیش‌فرض

    int kijun_handle = (timeframe == m_settings.ichimoku_timeframe) ? m_ichimoku_handle : iIchimoku(m_symbol, timeframe, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period); // هندل
    if (kijun_handle == INVALID_HANDLE) return 0.0; // شکست

    double kijun_buffer[]; // بافر
    if (CopyBuffer(kijun_handle, 1, 0, period + 1, kijun_buffer) < period + 1) // کپی
    {
        if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
        return 0.0; // صفر
    }

    if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد

    ArraySetAsSeries(kijun_buffer, true); // سری
    double current_kijun = kijun_buffer[0]; // فعلی
    double past_kijun = kijun_buffer[period]; // گذشته

    double slope = (current_kijun - past_kijun) / period; // شیب
    return slope; // بازگشت
}

//+------------------------------------------------------------------+
//| چک انبساط کومو - بهبود: SimpleMAOnBuffer به ExponentialMAOnBuffer تغییر یافت برای واکنش سریع‌تر|
//+------------------------------------------------------------------+
bool CStrategyManager::IsKumoExpanding(ENUM_TIMEFRAMES timeframe, int period)
{
    int ichi_handle = (timeframe == m_settings.ichimoku_timeframe) ? m_ichimoku_handle : iIchimoku(m_symbol, timeframe, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period); // هندل
    if (ichi_handle == INVALID_HANDLE) return false; // شکست

    double senkou_a[], senkou_b[]; // بافرها
    if (CopyBuffer(ichi_handle, 2, 0, period, senkou_a) < period || CopyBuffer(ichi_handle, 3, 0, period, senkou_b) < period) // کپی
    {
        if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد
        return false; // رد
    }

    if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد

    ArraySetAsSeries(senkou_a, true); // سری A
    ArraySetAsSeries(senkou_b, true); // سری B

    double thickness[]; // آرایه ضخامت
    ArrayResize(thickness, period); // تغییر اندازه
    for (int i = 0; i < period; i++) // حلقه
    {
        thickness[i] = MathAbs(senkou_a[i] - senkou_b[i]); // ضخامت
    }

    // [MODIFIED] استفاده از روش امن و ساده مقایسه مستقیم
    if(ArraySize(thickness) < 2) return false; // گاردریل برای داده ناکافی
    ArraySetAsSeries(thickness, true); // سری ضخامت
    return (thickness[0] > thickness[1]); // چک افزایش (انبساط)
}

//+------------------------------------------------------------------+
//| چک فضای باز چیکو                                                 |
//+------------------------------------------------------------------+
bool CStrategyManager::IsChikouInOpenSpace(bool is_buy, ENUM_TIMEFRAMES timeframe)
{
    int ichi_handle = (timeframe == m_settings.ichimoku_timeframe) ? m_ichimoku_handle : iIchimoku(m_symbol, timeframe, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period); // هندل
    if (ichi_handle == INVALID_HANDLE) return false; // شکست

    double chikou_buffer[]; // بافر چیکو
    if (CopyBuffer(ichi_handle, 4, 1, 1, chikou_buffer) < 1) // کپی شیفت 1
    {
        if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد
        return false; // رد
    }

    if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد

    double chikou = chikou_buffer[0]; // مقدار چیکو

    double high_buffer[], low_buffer[]; // بافرهای قیمت
    CopyHigh(m_symbol, timeframe, 1, 26, high_buffer); // سقف 26 شیفت
    CopyLow(m_symbol, timeframe, 1, 26, low_buffer); // کف 26 شیفت

    if (is_buy) // خرید
    {
        return (chikou > ArrayMaximum(high_buffer)); // چیکو بالای حداکثر
    }
    else // فروش
    {
        return (chikou < ArrayMinimum(low_buffer)); // چیکو پایین حداقل
    }
}

//+------------------------------------------------------------------+
//| [NEW] محاسبه SL ساختاری                                          |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateStructuralStopLoss(bool is_buy, double entry_price)
{
    double sl_level = is_buy ? m_ltf_analyzer.GetLastSwingLow() : m_ltf_analyzer.GetLastSwingHigh(); // سطح SL ساختاری
    if (sl_level <= 0) return 0.0; // اگر نامعتبر

    double atr_buffer[1]; // بافر ATR
    if (CopyBuffer(m_atr_handle, 0, 1, 1, atr_buffer) < 1) return 0.0; // چک ATR

    double atr_value = atr_buffer[0]; // ATR فعلی
    double buffer = atr_value * m_settings.sl_buffer_atr_percent / 100.0; // بافر ATR
    sl_level = is_buy ? sl_level - buffer : sl_level + buffer; // اعمال بافر

    double min_distance = atr_value * m_settings.min_sl_distance_atr_percent / 100.0; // حداقل فاصله
    if (MathAbs(entry_price - sl_level) < min_distance) // چک حداقل
    {
        sl_level = is_buy ? entry_price - min_distance : entry_price + min_distance; // اصلاح
    }

    return sl_level; // بازگشت SL ساختاری
}
