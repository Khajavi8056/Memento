//+------------------------------------------------------------------+
//|                                     IchimokuLogic.mqh            |
//|                          © 2025, hipoalgoritm              |
//+------------------------------------------------------------------+
#property copyright "© 2025,hipoalgoritm" // حقوق کپی‌رایت
#property link      "https://www.mql5.com" // لینک مرتبط
#property version   "2.1"  // نسخه
#include "set.mqh" // تنظیمات
#include <Trade\Trade.mqh> // کتابخانه ترید
#include <Trade\SymbolInfo.mqh> // اطلاعات نماد
#include <Object.mqh> // اشیاء
#include "VisualManager.mqh" // مدیریت گرافیک
#include <MovingAverages.mqh> // میانگین متحرک
#include "MarketStructure.mqh" // ساختار بازار




// IchimokuLogic.mqh

struct SPotentialSignal
{
    datetime        time; // زمان سیگنال
    bool            is_buy; // نوع خرید/فروش
    int             grace_candle_count; // شمارنده کندل مهلت
    double          invalidation_level; // سطح ابطال
    
    // سازنده کپی (Copy Constructor)
    SPotentialSignal(const SPotentialSignal &other) // کپی سازنده
    {
        time = other.time; // کپی زمان
        is_buy = other.is_buy; // کپی نوع
        grace_candle_count = other.grace_candle_count; // کپی شمارنده
        invalidation_level = other.invalidation_level; // کپی سطح
    }
    // سازنده پیش‌فرض (برای اینکه کد به مشکل نخوره)
    SPotentialSignal() // پیش‌فرض
    {
       invalidation_level = 0.0; // اولیه سطح
    }
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

//================================================================
//+------------------------------------------------------------------+
//| کلاس مدیریت استراتژی برای یک نماد خاص                             |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
    string              m_symbol; // نماد
    SSettings           m_settings; // تنظیمات
    CTrade              m_trade; // شیء ترید
   
    datetime            m_last_bar_time_htf; // زمان آخرین بار HTF
    datetime            m_last_bar_time_ltf; // زمان آخرین بار LTF
    
    // --- هندل های اندیکاتور ---
    int                 m_ichimoku_handle; // هندل ایچیموکو
    int                 m_atr_handle;      // هندل ATR
    int                 m_adx_handle;       // +++ NEW: هندل برای فیلتر ADX
    int                 m_rsi_exit_handle;  // +++ NEW: هندل برای خروج با RSI

    // --- بافرهای داده ---
    double              m_tenkan_buffer[]; // بافر تنکان
    double              m_kijun_buffer[]; // بافر کیجون
    double              m_chikou_buffer[]; // بافر چیکو
    double              m_high_buffer[]; // بافر سقف
    double              m_low_buffer[]; // بافر کف
    
    // --- مدیریت سیگنال ---
    SPotentialSignal    m_signal; // سیگنال اصلی
    bool                m_is_waiting; // حالت انتظار
    SPotentialSignal    m_potential_signals[]; // آرایه سیگنال‌های بالقوه
    CVisualManager* m_visual_manager; // مدیر گرافیک
    CMarketStructureShift m_ltf_analyzer; // تحلیلگر LTF
    CMarketStructureShift m_grace_structure_analyzer; // تحلیلگر برای مهلت ساختاری

    //--- توابع کمکی ---
    void Log(string message); // لاگ پیام
    
    // --- منطق اصلی سیگنال ---
    void AddOrUpdatePotentialSignal(bool is_buy); // اضافه یا آپدیت سیگنال
    bool CheckTripleCross(bool& is_buy); // چک کراس سه‌گانه
    bool CheckFinalConfirmation(bool is_buy); // چک تایید نهایی
    //[تابع جدید] تابع برای بررسی تاییدیه در تایم فریم پایین 
    bool CheckLowerTfConfirmation(bool is_buy); // چک تایید LTF
    // --- فیلترهای ورود ---
    bool AreAllFiltersPassed(bool is_buy); // چک تمام فیلترها
    bool CheckKumoFilter(bool is_buy, ENUM_TIMEFRAMES timeframe); // چک فیلتر کومو با تایم فریم
    bool CheckAtrFilter(ENUM_TIMEFRAMES timeframe); // چک فیلتر ATR با تایم فریم
    bool CheckAdxFilter(bool is_buy, ENUM_TIMEFRAMES timeframe); // تابع برای فیلتر ADX با تایم فریم

    // --- منطق خروج ---
    void CheckForEarlyExit();         // +++ NEW: تابع اصلی برای بررسی خروج زودرس
    bool CheckChikouRsiExit(bool is_buy); // +++ NEW: تابع کمکی برای منطق خروج چیکو+RSI

    //--- محاسبه استاپ لاس ---
    double CalculateStopLoss(bool is_buy, double entry_price); // محاسبه SL
    double CalculateAtrStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe); // محاسبه ATR با تایم فریم
    double GetTalaqiTolerance(int reference_shift); // تلرانس تلاقی
    double CalculateAtrTolerance(int reference_shift); // تلرانس ATR
    double CalculateDynamicTolerance(int reference_shift); // تلرانس پویا
    double FindFlatKijun(ENUM_TIMEFRAMES timeframe); // پیدا کردن کیجون فلت با تایم فریم
    double FindPivotKijun(bool is_buy, ENUM_TIMEFRAMES timeframe); // پیوت کیجون با تایم فریم
    double FindPivotTenkan(bool is_buy, ENUM_TIMEFRAMES timeframe); // پیوت تنکان با تایم فریم
    double FindBackupStopLoss(bool is_buy, double buffer, ENUM_TIMEFRAMES timeframe); // SL پشتیبان با تایم فریم
    
    //--- مدیریت معاملات ---
    int CountSymbolTrades(); // شمارش معاملات نماد
    int CountTotalTrades(); // شمارش معاملات کل
    void OpenTrade(bool is_buy); // باز کردن معامله
    bool IsDataReady(); // چک آماده بودن داده
    bool IsNewBar(ENUM_TIMEFRAMES timeframe, datetime &last_bar_time); // چک بار جدید

public:
    CStrategyManager(string symbol, SSettings &settings); // کانستراکتور
    ~CStrategyManager(); // دیستراکتور
    bool Init(); // اولیه
    void OnTimerTick(); // تیک تایمر
    void ProcessSignalSearch(); // جستجوی سیگنال
    void ManageActiveSignal(bool is_new_htf_bar); // مدیریت سیگنال فعال
    string GetSymbol() const { return m_symbol; } // گرفتن نماد
    void UpdateMyDashboard(); // آپدیت داشبورد
    CVisualManager* GetVisualManager() { return m_visual_manager; } // گرفتن مدیر گرافیک
};
//+------------------------------------------------------------------+
//| کانستراکتور کلاس                                                |
//+------------------------------------------------------------------+
CStrategyManager::CStrategyManager(string symbol, SSettings &settings)
{
    m_symbol = symbol; // تنظیم نماد
    m_settings = settings; // تنظیم تنظیمات
    m_last_bar_time_htf = 0; // اولیه زمان HTF
    m_last_bar_time_ltf = 0; // اولیه زمان LTF
    m_is_waiting = false; // اولیه حالت انتظار
    ArrayFree(m_potential_signals); // آزاد کردن سیگنال‌ها
    m_ichimoku_handle = INVALID_HANDLE; // اولیه هندل ایچیموکو
    m_atr_handle = INVALID_HANDLE; // اولیه هندل ATR
    m_visual_manager = new CVisualManager(symbol, settings); // ایجاد مدیر گرافیک
}

//+------------------------------------------------------------------+
//| دیستراکتور کلاس (نسخه نهایی و اصلاح شده)                           |
//+------------------------------------------------------------------+
CStrategyManager::~CStrategyManager()
{
    // پاک کردن مدیر گرافیک
    if (m_visual_manager != NULL) // چک وجود
    {
        delete m_visual_manager; // حذف
        m_visual_manager = NULL; // ریست
    }

    // آزاد کردن هندل‌های اندیکاتور (هر کدام فقط یک بار)
    if(m_ichimoku_handle != INVALID_HANDLE) // چک ایچیموکو
        IndicatorRelease(m_ichimoku_handle); // آزاد
        
    if(m_atr_handle != INVALID_HANDLE) // چک ATR
        IndicatorRelease(m_atr_handle); // آزاد
        
    if(m_adx_handle != INVALID_HANDLE) // چک ADX
        IndicatorRelease(m_adx_handle); // آزاد

    if(m_rsi_exit_handle != INVALID_HANDLE) // چک RSI
        IndicatorRelease(m_rsi_exit_handle); // آزاد
}

//+------------------------------------------------------------------+
//| آپدیت کردن داشبورد                                                |
//+------------------------------------------------------------------+
void CStrategyManager::UpdateMyDashboard() 
{ 
    if (m_visual_manager != NULL) // چک وجود
    {
        m_visual_manager.UpdateDashboard(); // آپدیت
    }
}
//================================================================


//+------------------------------------------------------------------+
//| مقداردهی اولیه (نسخه کامل با اندیکاتورهای نامرئی)                  |
//+------------------------------------------------------------------+
bool CStrategyManager::Init()
{
    // +++ بخش واکسیناسیون برای اطمینان از آمادگی داده‌ها (بدون تغییر) +++
    int attempts = 0; // شمارنده
    while(iBars(m_symbol, m_settings.ichimoku_timeframe) < 200 && attempts < 100) // حلقه
    {
        Sleep(100);  // تاخیر
        MqlRates rates[]; // نرخ‌ها
        CopyRates(m_symbol, m_settings.ichimoku_timeframe, 0, 1, rates);  // کپی
        attempts++; // افزایش
    }
    if (iBars(m_symbol, m_settings.ichimoku_timeframe) < 200) // چک نهایی
    {
        Log("خطای بحرانی: پس از تلاش‌های مکرر، داده‌های کافی برای نماد " + m_symbol + " بارگذاری نشد.");
        return false; // شکست
    }
    // +++ پایان بخش واکسیناسیون +++

    
    // تنظیمات اولیه شیء ترید (بدون تغییر)
    m_trade.SetExpertMagicNumber(m_settings.magic_number); // مجیک
    m_trade.SetTypeFillingBySymbol(m_symbol); // فیلینگ
    
    // --- =================================================================== ---
    // --- ✅ بخش اصلی تغییرات: ساخت هندل اندیکاتورها (حالت روح و عادی) ✅ ---
    // --- =================================================================== ---

    // 💡 **ایچیموکو: انتخاب بین حالت نمایشی یا حالت روح**

    // --- حالت ۱ (فعال): ایچیموکو روی چارت نمایش داده می‌شود ---
   // m_ichimoku_handle = iIchimoku(m_symbol, m_settings.ichimoku_timeframe, m_settings.tenkan_period, m_settings.kijun_period, m_settings.senkou_period);

    
    // --- حالت ۲ (غیرفعال): ایچیموکو در پس‌زمینه محاسبه شده و روی چارت نمی‌آید (حالت روح) ---
    // برای فعال کردن این حالت، کد بالا را کامنت کرده و این بلاک را از کامنت خارج کنید.
    MqlParam ichimoku_params[3]; // پارامترها
    ichimoku_params[0].type = TYPE_INT; // نوع
    ichimoku_params[0].integer_value = m_settings.tenkan_period; // تنکان
    ichimoku_params[1].type = TYPE_INT; // نوع
    ichimoku_params[1].integer_value = m_settings.kijun_period; // کیجون
    ichimoku_params[2].type = TYPE_INT; // نوع
    ichimoku_params[2].integer_value = m_settings.senkou_period; // سنکو
    m_ichimoku_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ICHIMOKU, 3, ichimoku_params); // ایجاد
    

    // 👻 **ساخت هندل ATR در حالت روح (نامرئی)**
    MqlParam atr_params[1]; // پارامتر ATR
    atr_params[0].type = TYPE_INT; // نوع
    atr_params[0].integer_value = m_settings.atr_filter_period; // دوره
    m_atr_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ATR, 1, atr_params); // ایجاد

    // 👻 **ساخت هندل ADX در حالت روح (نامرئی)**
    MqlParam adx_params[1]; // پارامتر ADX
    adx_params[0].type = TYPE_INT; // نوع
    adx_params[0].integer_value = m_settings.adx_period; // دوره
    m_adx_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ADX, 1, adx_params); // ایجاد

    // 👻 **ساخت هندل RSI در حالت روح (نامرئی)**
    MqlParam rsi_params[2]; // پارامتر RSI
    rsi_params[0].type = TYPE_INT; // نوع
    rsi_params[0].integer_value = m_settings.early_exit_rsi_period; // دوره
    rsi_params[1].type = TYPE_INT; // نوع
    rsi_params[1].integer_value = PRICE_CLOSE; // قیمت
    m_rsi_exit_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_RSI, 2, rsi_params); // ایجاد
    
    // --- =================================================================== ---
    // --- ✅ پایان بخش تغییرات ✅ ---
    // --- =================================================================== ---

    // بررسی نهایی اعتبار تمام هندل‌ها
    if (m_ichimoku_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE || m_adx_handle == INVALID_HANDLE || m_rsi_exit_handle == INVALID_HANDLE) // چک هندل‌ها
    {
        Log("خطا در ایجاد یک یا چند اندیکاتور. لطفاً تنظیمات را بررسی کنید."); // لاگ خطا
        return false; // شکست
    }

    // مقداردهی اولیه بافرها و کتابخانه‌های دیگر (بدون تغییر)
    ArraySetAsSeries(m_tenkan_buffer, true); // سری تنکان
    ArraySetAsSeries(m_kijun_buffer, true); // سری کیجون
    ArraySetAsSeries(m_chikou_buffer, true); // سری چیکو
    ArraySetAsSeries(m_high_buffer, true); // سری سقف
    ArraySetAsSeries(m_low_buffer, true);  // سری کف
    
    if (!m_visual_manager.Init()) // چک گرافیک
    {
        Log("خطا در مقداردهی اولیه VisualManager."); // لاگ
        return false; // شکست
    }

    if(m_symbol == _Symbol) // چک چارت
    {
        m_visual_manager.InitDashboard(); // داشبورد
    }
    
    m_ltf_analyzer.Init(m_symbol, m_settings.ltf_timeframe); // تحلیلگر LTF
    
    Log("با موفقیت مقداردهی اولیه شد."); // لاگ موفقیت
    return true; // موفقیت
}


//+------------------------------------------------------------------+
//| تابع اصلی رویدادها (هر ثانیه توسط OnTimer فراخوانی می‌شود)         |
//| این تابع مثل یک ارکستراتور عمل می‌کنه: تصمیم می‌گیره کدوم بخش از منطق رو بر اساس رویدادهای HTF یا LTF فعال کنه. |
//| مراحل: ۱. چک واکسن داده‌ها. ۲. همیشه تحلیل LTF رو آپدیت کن. ۳. اگر بار HTF جدید بود، سیگنال اولیه رو شکار کن. ۴. سیگنال‌های فعال رو مدیریت کن. ۵. خروج زودرس رو چک کن. |
//+------------------------------------------------------------------+
void CStrategyManager::OnTimerTick()
{
    // واکسن: اگر داده آماده نیست، هیچ کاری نکن
    if (!IsDataReady()) return; // چک داده

    // اصل اول: کتابخانه ساختار بازار LTF همیشه باید فعال باشد
    bool is_new_ltf_bar = IsNewBar(m_settings.ltf_timeframe, m_last_bar_time_ltf); // چک بار جدید LTF
    if (is_new_ltf_bar) // اگر جدید
    {
        // آپدیت تحلیلگر تاییدیه
        m_ltf_analyzer.ProcessNewBar();  // پردازش
    }

    // اصل دوم: جستجوی سیگنال فقط روی کندل جدید HTF
    bool is_new_htf_bar = IsNewBar(m_settings.ichimoku_timeframe, m_last_bar_time_htf); // چک HTF
    if (is_new_htf_bar) // اگر جدید
    {
        // آپدیت تحلیلگر مهلت ساختاری (که روی HTF کار می‌کند)
        m_grace_structure_analyzer.ProcessNewBar();  // پردازش

        // اجرای منطق شکار سیگنال
        ProcessSignalSearch();  // جستجو
    }

    // اصل سوم: مدیریت سیگنال‌های فعال با هر رویداد جدید (HTF یا LTF)
    if (m_is_waiting || ArraySize(m_potential_signals) > 0) // چک فعال
    {
        if (is_new_htf_bar || is_new_ltf_bar) // چک رویداد
        {
            ManageActiveSignal(is_new_htf_bar); // مدیریت
        }
    }

    // اجرای منطق خروج زودرس (مثلاً با هر کندل HTF)
    if (is_new_htf_bar && m_settings.enable_early_exit) // چک خروج
    {
        CheckForEarlyExit(); // چک
    }
}

//+------------------------------------------------------------------+
//| شکارچی: فقط روی HTF دنبال سیگنال اولیه می‌گردد                  |
//| این تابع فقط مسئول پیدا کردن کراس سه‌گانه (سیگنال اولیه) است. اگر پیدا شد، بسته به حالت سیگنال (جایگزینی یا مسابقه) عمل می‌کنه و گرافیک رو رسم می‌کنه. |
//| مراحل: ۱. چک کراس سه‌گانه. ۲. اگر پیدا شد، بسته به حالت، سیگنال رو مدیریت کن. ۳. مستطیل کراس رو رسم کن. |
//+------------------------------------------------------------------+
void CStrategyManager::ProcessSignalSearch()
{
    bool is_new_signal_buy = false; // فلگ سیگنال
    if (!CheckTripleCross(is_new_signal_buy)) // چک کراس
        return; // اگر نبود، خارج

    // اگر سیگنال پیدا شد:
    if (m_settings.signal_mode == MODE_REPLACE_SIGNAL) // حالت جایگزینی
    {
        if (m_is_waiting && is_new_signal_buy != m_signal.is_buy) // چک مخالف
        {
            Log("سیگنال جدید و مخالف پیدا شد! سیگنال قبلی کنسل شد."); // لاگ
            m_is_waiting = false; // ریست
        }
        if (!m_is_waiting) // اگر منتظر نبود
        {
            m_is_waiting = true; // تنظیم انتظار
            m_signal.is_buy = is_new_signal_buy; // نوع
            m_signal.time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou_period); // زمان
            m_signal.grace_candle_count = 0; // ریست شمارنده
            m_signal.invalidation_level = 0.0; // ریست سطح

            if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE) // حالت ساختاری
            {
                m_signal.invalidation_level = is_new_signal_buy ? m_grace_structure_analyzer.GetLastSwingLow() : m_grace_structure_analyzer.GetLastSwingHigh(); // سطح
            }
            Log("سیگنال اولیه " + (m_signal.is_buy ? "خرید" : "فروش") + " پیدا شد. ورود به حالت انتظار..."); // لاگ
        }
    }
    else // MODE_SIGNAL_CONTEST // مسابقه
    {
        AddOrUpdatePotentialSignal(is_new_signal_buy); // اضافه
    }

    if(m_symbol == _Symbol) // چک چارت
        m_visual_manager.DrawTripleCrossRectangle(is_new_signal_buy, m_settings.chikou_period); // رسم
}

//+------------------------------------------------------------------+
//| مدیر: سیگنال‌های فعال را بر اساس رویدادهای HTF و LTF مدیریت می‌کند |
//| این تابع مسئول بررسی انقضا، چک تایید نهایی، فیلترها و باز کردن معامله است. بسته به حالت سیگنال (جایگزینی یا مسابقه) عمل می‌کنه. |
//| مراحل: ۱. چک انقضا بر اساس مهلت (کندلی یا ساختاری). ۲. اگر منقضی، حذف کن. ۳. چک تایید و فیلترها. ۴. اگر پاس شد، معامله باز کن و پاکسازی کن. |
//+------------------------------------------------------------------+
void CStrategyManager::ManageActiveSignal(bool is_new_htf_bar)
{
    // منطق برای حالت MODE_REPLACE_SIGNAL
    if (m_settings.signal_mode == MODE_REPLACE_SIGNAL && m_is_waiting) // چک حالت و انتظار
    {
        bool is_signal_expired = false; // فلگ انقضا
        // بررسی انقضا
        if (m_settings.grace_period_mode == GRACE_BY_CANDLES && is_new_htf_bar) // کندلی و HTF
        {
            m_signal.grace_candle_count++; // افزایش
            if (m_signal.grace_candle_count >= m_settings.grace_period_candles) // چک
                is_signal_expired = true; // انقضا
        }
        else if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE) // ساختاری
        {
            double current_price = iClose(m_symbol, m_settings.ltf_timeframe, 1); // قیمت LTF
            if (m_signal.invalidation_level > 0 &&  // چک سطح
               ((m_signal.is_buy && current_price < m_signal.invalidation_level) || 
               (!m_signal.is_buy && current_price > m_signal.invalidation_level)))
               is_signal_expired = true; // انقضا
        }

        // تصمیم‌گیری نهایی
        if (is_signal_expired) // منقضی
        {
            m_is_waiting = false; // ریست
        }
        else if (CheckFinalConfirmation(m_signal.is_buy)) // تایید
        {
            if (AreAllFiltersPassed(m_signal.is_buy)) // فیلترها
            {
                OpenTrade(m_signal.is_buy); // باز کردن
            }
            m_is_waiting = false; // ریست
        }
    }
    // منطق برای حالت MODE_SIGNAL_CONTEST
    else if (m_settings.signal_mode == MODE_SIGNAL_CONTEST && ArraySize(m_potential_signals) > 0) // چک مسابقه
    {
         for (int i = ArraySize(m_potential_signals) - 1; i >= 0; i--) // حلقه معکوس
         {
            bool is_signal_expired = false; // فلگ
            // بررسی انقضا
            if (m_settings.grace_period_mode == GRACE_BY_CANDLES && is_new_htf_bar) // کندلی
            {
                m_potential_signals[i].grace_candle_count++; // افزایش
                if (m_potential_signals[i].grace_candle_count >= m_settings.grace_period_candles) // چک
                    is_signal_expired = true; // انقضا
            }
            else if (m_settings.grace_period_mode == GRACE_BY_STRUCTURE) // ساختاری
            {
                double current_price = iClose(m_symbol, m_settings.ltf_timeframe, 1); // قیمت
                 if (m_potential_signals[i].invalidation_level > 0 &&
                    ((m_potential_signals[i].is_buy && current_price < m_potential_signals[i].invalidation_level) ||
                     (!m_potential_signals[i].is_buy && current_price > m_potential_signals[i].invalidation_level)))
                     is_signal_expired = true; // انقضا
            }

            if(is_signal_expired) // منقضی
            {
                ArrayRemove(m_potential_signals, i, 1); // حذف
                continue; // ادامه
            }

            if(CheckFinalConfirmation(m_potential_signals[i].is_buy) && AreAllFiltersPassed(m_potential_signals[i].is_buy)) // چک تایید و فیلتر
            {
                OpenTrade(m_potential_signals[i].is_buy); // باز کردن
                // پاکسازی سایر سیگنال‌های هم‌جهت
                bool winner_is_buy = m_potential_signals[i].is_buy; // برنده
                for (int j = ArraySize(m_potential_signals) - 1; j >= 0; j--) // پاکسازی
                {
                    if (m_potential_signals[j].is_buy == winner_is_buy) // هم‌جهت
                        ArrayRemove(m_potential_signals, j, 1); // حذف
                }
                return; // خروج چون کار تمام است
            }
         }
    }
}

//+------------------------------------------------------------------+
//| منطق فاز ۱: چک کردن کراس سه گانه (بازنویسی کامل و نهایی)         |
//| این تابع بررسی می‌کنه آیا کراس سه‌گانه (تنکان-کیجون-چیکو) اتفاق افتاده یا نه. اگر بله، نوع خرید/فروش رو تنظیم می‌کنه. |
//| مراحل: ۱. آماده‌سازی داده‌ها و شیفت. ۲. دریافت مقادیر ایچیموکو. ۳. چک کراس تنکان-کیجون یا تلاقی. ۴. چک کراس چیکو. |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckTripleCross(bool& is_buy)
{
    // --- گام اول: آماده‌سازی داده‌ها ---

    // شیفت زمانی که می‌خوایم در گذشته بررسی کنیم (مثلاً ۲۶ کندل قبل)
    int shift = m_settings.chikou_period; // شیفت چیکو
    
    // اگه به اندازه کافی کندل توی چارت نباشه، از تابع خارج می‌شیم
    if (iBars(m_symbol, _Period) < shift + 2) return false; // چک بارها

    // --- گام دوم: دریافت مقادیر ایچیموکو در گذشته ---

    // دو آرایه برای نگهداری مقادیر تنکان و کیجون در نقطه مرجع و کندل قبل از آن
    double tk_shifted[], ks_shifted[]; // آرایه‌ها
    
    // از متاتریدر می‌خوایم که ۲ مقدار آخر تنکان و کیجون رو از نقطه "شیفت" به ما بده
    if(CopyBuffer(m_ichimoku_handle, 0, shift, 2, tk_shifted) < 2 || 
       CopyBuffer(m_ichimoku_handle, 1, shift, 2, ks_shifted) < 2)
    {
       // اگر داده کافی وجود نداشت، ادامه نمی‌دهیم
       return false; // بازگشت شکست
    }
       
    // مقدار تنکان و کیجون در نقطه مرجع (مثلاً کندل ۲۶ قبل)
    double tenkan_at_shift = tk_shifted[0]; // تنکان
    double kijun_at_shift = ks_shifted[0]; // کیجون
    
    // مقدار تنکان و کیجون در کندلِ قبل از نقطه مرجع (مثلاً کندل ۲۷ قبل)
    double tenkan_prev_shift = tk_shifted[1]; // تنکان قبلی
    double kijun_prev_shift = ks_shifted[1]; // کیجون قبلی

    // --- گام سوم: بررسی شرط اولیه (آیا در گذشته کراس یا تلاقی داشتیم؟) ---

    // آیا کراس صعودی اتفاق افتاده؟ (تنکان از پایین اومده بالای کیجون)
    bool is_cross_up = tenkan_prev_shift < kijun_prev_shift && tenkan_at_shift > kijun_at_shift; // کراس صعودی
    
    // آیا کراس نزولی اتفاق افتاده؟ (تنکان از بالا اومده پایین کیجون)
    bool is_cross_down = tenkan_prev_shift > kijun_prev_shift && tenkan_at_shift < kijun_at_shift; // کراس نزولی
    
    // آیا کلاً کراسی داشتیم؟ (یا صعودی یا نزولی، جهتش مهم نیست)
    bool is_tk_cross = is_cross_up || is_cross_down; // کراس کلی

    // آیا دو خط خیلی به هم نزدیک بودن (تلاقی)؟
    double tolerance = GetTalaqiTolerance(shift); // تلرانس
    bool is_confluence = (tolerance > 0) ? (MathAbs(tenkan_at_shift - kijun_at_shift) <= tolerance) : false; // تلاقی

    // شرط اصلی اولیه: اگر نه کراسی داشتیم و نه تلاقی، پس سیگنالی در کار نیست و خارج می‌شویم
    if (!is_tk_cross && !is_confluence) // چک اولیه
    {
        return false; // بدون سیگنال
    }

    // --- گام چهارم: بررسی شرط نهایی (کراس چیکو اسپن از خطوط گذشته) ---

    // قیمت فعلی که نقش چیکو اسپن را برای گذشته بازی می‌کند (کلوز کندل شماره ۱)
    double chikou_now  = iClose(m_symbol, m_settings.ichimoku_timeframe, 1); // چیکو حالا
    // قیمت کندل قبل از آن (کلوز کندل شماره ۲)
    double chikou_prev = iClose(m_symbol, m_settings.ichimoku_timeframe, 2);  // چیکو قبلی

    // بالاترین سطح بین تنکان و کیجون در نقطه مرجع
    double upper_line = MathMax(tenkan_at_shift, kijun_at_shift); // خط بالا
    // پایین‌ترین سطح بین تنکان و کیجون در نقطه مرجع
    double lower_line = MathMin(tenkan_at_shift, kijun_at_shift); // خط پایین

    // بررسی برای سیگنال خرید:
    // آیا قیمت فعلی (چیکو) از بالای هر دو خط عبور کرده؟
    bool chikou_crosses_up = chikou_now > upper_line && // شرط ۱
                             chikou_prev < upper_line;    // شرط ۲
    
    if (chikou_crosses_up) // اگر صعودی
    {
        is_buy = true; // خرید
        return true;  // موفقیت
    }

    // بررسی برای سیگنال فروش:
    // آیا قیمت فعلی (چیکو) از پایین هر دو خط عبور کرده؟
    bool chikou_crosses_down = chikou_now < lower_line && // شرط ۱
                               chikou_prev > lower_line;    // شرط ۲
    
    if (chikou_crosses_down) // اگر نزولی
    {
        is_buy = false; // فروش
        return true;  // موفقیت
    }

    return false;  // بدون سیگنال
}


//+------------------------------------------------------------------+
//| (نسخه آپگرید شده) مدیر کل تاییدیه نهایی                           |
//| این تابع بر اساس حالت انتخابی کاربر، تایید نهایی ورود رو چک می‌کنه. اگر LTF، از شکست ساختار استفاده می‌کنه؛ اگر فعلی، از کندل. |
//| مراحل: ۱. سوئیچ حالت. ۲. برای LTF، چک شکست ساختار. ۳. برای فعلی، چک موقعیت کندل نسبت به خطوط. |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckFinalConfirmation(bool is_buy)
{
    // بر اساس انتخاب کاربر در تنظیمات، روش تاییدیه را انتخاب کن
    switch(m_settings.entry_confirmation_mode) // سوئیچ حالت
    {
        // حالت ۱: استفاده از روش جدید و سریع (تایم فریم پایین)
        case CONFIRM_LOWER_TIMEFRAME: // LTF
            return CheckLowerTfConfirmation(is_buy); // چک LTF

        // حالت ۲: استفاده از روش قدیمی و کند (تایم فریم فعلی)
        case CONFIRM_CURRENT_TIMEFRAME: // فعلی
        {
            // این بلاک کد، همان منطق قدیمی تابع است
            if (iBars(m_symbol, m_settings.ichimoku_timeframe) < 2) return false; // چک بارها

            CopyBuffer(m_ichimoku_handle, 0, 1, 1, m_tenkan_buffer); // کپی تنکان
            CopyBuffer(m_ichimoku_handle, 1, 1, 1, m_kijun_buffer); // کپی کیجون

            double tenkan_at_1 = m_tenkan_buffer[0]; // تنکان 1
            double kijun_at_1 = m_kijun_buffer[0]; // کیجون 1
            double open_at_1 = iOpen(m_symbol, m_settings.ichimoku_timeframe, 1); // باز 1
            double close_at_1 = iClose(m_symbol, m_settings.ichimoku_timeframe, 1); // بسته 1

            if (is_buy) // خرید
            {
                if (tenkan_at_1 <= kijun_at_1) return false; // چک تنکان بالا
                if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE) { // باز و بسته
                    if (open_at_1 > tenkan_at_1 && open_at_1 > kijun_at_1 && close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                        return true; // تایید
                } else { // بسته
                    if (close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                        return true; // تایید
                }
            }
            else // فروش
            {
                if (tenkan_at_1 >= kijun_at_1) return false; // چک تنکان پایین
                if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE) { // باز و بسته
                    if (open_at_1 < tenkan_at_1 && open_at_1 < kijun_at_1 && close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                        return true; // تایید
                } else { // بسته
                    if (close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                        return true; // تایید
                }
            }
            return false; // عدم تایید
        }
    }
    return false; // پیش‌فرض
}

//+------------------------------------------------------------------+
//| محاسبه استاپ لاس با منطق انتخاب بهینه                           |
//| این تابع بهترین سطح SL رو از بین کاندیداها انتخاب می‌کنه. تایم فریم رو تعیین می‌کنه و به زیرتوابع پاس میده. |
//| مراحل: ۱. تعیین تایم فریم SL. ۲. اگر ساده یا ATR، مستقیم محاسبه کن. ۳. برای پیچیده، کاندیداها رو جمع کن و نزدیک‌ترین معتبر رو انتخاب کن. |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateStopLoss(bool is_buy, double entry_price)
{
    // تعیین تایم فریم محاسبات بر اساس ورودی کاربر
    ENUM_TIMEFRAMES sl_tf = (m_settings.sl_timeframe == PERIOD_CURRENT) 
                            ? _Period 
                            : m_settings.sl_timeframe; // تایم فریم SL

    if (m_settings.stoploss_type == MODE_SIMPLE) // ساده
    {
        double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بافر
        return FindBackupStopLoss(is_buy, buffer, sl_tf); // پشتیبان با تایم فریم
    }
    if (m_settings.stoploss_type == MODE_ATR) // ATR
    {
        double sl_price = CalculateAtrStopLoss(is_buy, entry_price, sl_tf); // ATR با تایم فریم
        if (sl_price == 0) // اگر شکست
        {
            Log("محاسبه ATR SL با خطا مواجه شد. استفاده از روش پشتیبان..."); // لاگ
            double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بافر
            return FindBackupStopLoss(is_buy, buffer, sl_tf); // پشتیبان با تایم فریم
        }
        return sl_price; // بازگشت
    }

    // --- قلب تپنده منطق جدید: انتخاب بهینه (برای MODE_COMPLEX) ---

    Log("شروع فرآیند انتخاب استاپ لاس بهینه..."); // لاگ شروع

    // --- مرحله ۱: تشکیل لیست کاندیداها ---
    double candidates[]; // آرایه کاندیداها
    int count = 0; // شمارنده
    double sl_candidate = 0; // موقت
    double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // بافر
    
    // کاندیدای ۱: کیجون فلت
    sl_candidate = FindFlatKijun(sl_tf); // فلت با تایم فریم
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; // تنظیم
        count++; // افزایش
    }
    
    // کاندیدای ۲: پیوت کیجون
    sl_candidate = FindPivotKijun(is_buy, sl_tf); // پیوت کیجون با تایم فریم
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; // تنظیم
        count++; // افزایش
    }

    // کاندیدای ۳: پیوت تنکان
    sl_candidate = FindPivotTenkan(is_buy, sl_tf); // پیوت تنکان با تایم فریم
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر
        candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; // تنظیم
        count++; // افزایش
    }

    // کاندیدای ۴: روش ساده (کندل مخالف)
    sl_candidate = FindBackupStopLoss(is_buy, buffer, sl_tf); // پشتیبان با تایم فریم
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر
        candidates[count] = sl_candidate; // اضافه
        count++; // افزایش
    }
    
    // کاندیدای ۵: روش ATR
    sl_candidate = CalculateAtrStopLoss(is_buy, entry_price, sl_tf); // ATR با تایم فریم
    if (sl_candidate > 0) {
        ArrayResize(candidates, count + 1); // تغییر
        candidates[count] = sl_candidate; // اضافه
        count++; // افزایش
    }

    if (count == 0) // هیچ
    {
        Log("خطا: هیچ کاندیدای اولیه‌ای برای استاپ لاس پیدا نشد."); // لاگ
        return 0.0; // صفر
    }

    // --- مرحله ۲: اعتبارسنجی و بهینه‌سازی کاندیداها ---
    double valid_candidates[]; // معتبرها
    int valid_count = 0; // شمارنده معتبر
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); // پوینت
    double spread = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * point; // اسپرد
    double min_safe_distance = spread + buffer;  // حداقل فاصله

    for (int i = 0; i < count; i++) // حلقه
    {
        double current_sl = candidates[i]; // فعلی
        
        if ((is_buy && current_sl >= entry_price) || (!is_buy && current_sl <= entry_price)) // چک معتبر
        {
            continue;  // رد
        }

        if (MathAbs(entry_price - current_sl) < min_safe_distance) // چک فاصله
        {
            current_sl = is_buy ? entry_price - min_safe_distance : entry_price + min_safe_distance; // اصلاح
            Log("کاندیدای شماره " + (string)(i+1) + " به دلیل نزدیکی بیش از حد به قیمت " + DoubleToString(current_sl, _Digits) + " اصلاح شد."); // لاگ
        }

        ArrayResize(valid_candidates, valid_count + 1); // تغییر
        valid_candidates[valid_count] = current_sl; // اضافه
        valid_count++; // افزایش
    }

    if (valid_count == 0) // هیچ معتبر
    {
        Log("خطا: پس از فیلترینگ، هیچ کاندیدای معتبری برای استاپ لاس باقی نماند."); // لاگ
        return 0.0; // صفر
    }
    
    // --- مرحله ۳: انتخاب نزدیک‌ترین گزینه معتبر ---
    double best_sl_price = 0.0; // بهترین
    double smallest_distance = DBL_MAX; // حداقل فاصله

    for (int i = 0; i < valid_count; i++) // حلقه
    {
        double distance = MathAbs(entry_price - valid_candidates[i]); // فاصله
        if (distance < smallest_distance) // چک کوچکتر
        {
            smallest_distance = distance; // آپدیت
            best_sl_price = valid_candidates[i]; // بهترین
        }
    }

    Log("✅ استاپ لاس بهینه پیدا شد: " + DoubleToString(best_sl_price, _Digits) + ". فاصله: " + DoubleToString(smallest_distance / point, 1) + " پوینت."); // لاگ موفقیت

    return best_sl_price; // بازگشت
}

//+------------------------------------------------------------------+
//| تابع استاپ لاس پشتیبان بر اساس رنگ مخالف کندل‌ها                 |
//| این تابع اول دنبال اولین کندل مخالف می‌گرده، اگر پیدا نکرد از سقف/کف مطلق استفاده می‌کنه. حالا تایم فریم دلخواه رو می‌گیره و محاسبات رو روش انجام میده. |
//| مراحل: ۱. چک تعداد بارها در تایم فریم. ۲. حلقه عقبگرد برای پیدا کردن کندل مخالف. ۳. اگر پیدا شد، SL رو تنظیم کن. ۴. اگر نه، از روش مطلق استفاده کن. |
//+------------------------------------------------------------------+
double CStrategyManager::FindBackupStopLoss(bool is_buy, double buffer, ENUM_TIMEFRAMES timeframe)
{
    // تعداد کندلی که می‌خواهیم در گذشته برای پیدا کردن استاپ لاس جستجو کنیم.
    int bars_to_check = m_settings.sl_lookback_period; // تعداد
    
    // اگر تعداد کندل‌های موجود در چارت کافی نیست، از تابع خارج می‌شویم.
    if (iBars(m_symbol, timeframe) < bars_to_check + 1) return 0; // چک بارها در تایم فریم
    
    // یک حلقه 'for' می‌سازیم که از کندل شماره ۱ (کندل قبلی) شروع به حرکت به عقب می‌کند.
    for (int i = 1; i <= bars_to_check; i++) // حلقه
    {
        // رنگ کندلی که در حال بررسی آن هستیم را مشخص می‌کنیم.
        bool is_candle_bullish = (iClose(m_symbol, timeframe, i) > iOpen(m_symbol, timeframe, i)); // صعودی در تایم فریم
        bool is_candle_bearish = (iClose(m_symbol, timeframe, i) < iOpen(m_symbol, timeframe, i)); // نزولی در تایم فریم

        // اگر معامله ما از نوع "خرید" (Buy) باشد...
        if (is_buy) // خرید
        {
            // ...پس ما به دنبال اولین کندل با رنگ مخالف، یعنی کندل "نزولی" (Bearish) هستیم.
            if (is_candle_bearish) // نزولی
            {
                // به محض پیدا کردن اولین کندل نزولی، استاپ لاس را چند پوینت زیر کفِ (Low) همان کندل قرار می‌دهیم.
                double sl_price = iLow(m_symbol, timeframe, i) - buffer; // SL در تایم فریم
                Log("استاپ لاس ساده: اولین کندل نزولی در شیفت " + (string)i + " پیدا شد."); // لاگ
                
                // قیمت محاسبه شده را برمی‌گردانیم و کار تابع تمام می‌شود.
                return sl_price; // بازگشت
            }
        }
        // اگر معامله ما از نوع "فروش" (Sell) باشد...
        else // فروش
        {
            // ...پس ما به دنبال اولین کندل با رنگ مخالف، یعنی کندل "صعودی" (Bullish) هستیم.
            if (is_candle_bullish) // صعودی
            {
                // به محض پیدا کردن اولین کندل صعودی، استاپ لاس را چند پوینت بالای سقفِ (High) همان کندل قرار می‌دهیم.
                double sl_price = iHigh(m_symbol, timeframe, i) + buffer; // SL در تایم فریم
                Log("استاپ لاس ساده: اولین کندل صعودی در شیفت " + (string)i + " پیدا شد."); // لاگ
                
                // قیمت محاسبه شده را برمی‌گردانیم و کار تابع تمام می‌شود.
                return sl_price; // بازگشت
            }
        }
    }
    
    // --- بخش پشتیبانِ پشتیبان ---
    // اگر حلقه 'for' تمام شود و کد به اینجا برسد، یعنی در کل بازه مورد بررسی، هیچ کندل رنگ مخالفی پیدا نشده است.
    // (مثلاً در یک روند خیلی قوی که همه کندل‌ها یک رنگ هستند)
    // در این حالت اضطراری، برای اینکه بدون استاپ لاس نمانیم، از روش قدیمی (پیدا کردن بالاترین/پایین‌ترین قیمت) استفاده می‌کنیم.
    Log("هیچ کندل رنگ مخالفی برای استاپ لاس ساده پیدا نشد. از روش سقف/کف مطلق استفاده می‌شود."); // لاگ پشتیبان
    
    // داده‌های سقف و کف کندل‌ها را در آرایه‌ها کپی می‌کنیم.
    CopyHigh(m_symbol, timeframe, 1, bars_to_check, m_high_buffer); // کپی سقف در تایم فریم
    CopyLow(m_symbol, timeframe, 1, bars_to_check, m_low_buffer); // کپی کف در تایم فریم

    if(is_buy) // خرید
    {
       // برای خرید، ایندکس پایین‌ترین کندل را پیدا کرده و قیمت Low آن را برمی‌گردانیم.
       int min_index = ArrayMinimum(m_low_buffer, 0, bars_to_check); // حداقل
       return m_low_buffer[min_index] - buffer; // بازگشت با بافر
    }
    else // فروش
    {
       // برای فروش، ایندکس بالاترین کندل را پیدا کرده و قیمت High آن را برمی‌گردانیم.
       int max_index = ArrayMaximum(m_high_buffer, 0, bars_to_check); // حداکثر
       return m_high_buffer[max_index] + buffer; // بازگشت با بافر
    }
}

//+------------------------------------------------------------------+
//| توابع کمکی دیگر                                                  |
//+------------------------------------------------------------------+
void CStrategyManager::Log(string message)
{
    if (m_settings.enable_logging) // چک
    {
        Print(m_symbol, ": ", message); // چاپ
    }
}

int CStrategyManager::CountSymbolTrades()
{
    int count = 0; // شمارنده
    for(int i = PositionsTotal() - 1; i >= 0; i--) // حلقه
    {
        if(PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number) // چک
        {
            count++; // افزایش
        }
    }
    return count; // بازگشت
}

int CStrategyManager::CountTotalTrades()
{
    int count = 0; // شمارنده
    for(int i = PositionsTotal() - 1; i >= 0; i--) // حلقه
    {
        if(PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number) // چک
        {
            count++; // افزایش
        }
    }
    return count; // بازگشت
}

//+------------------------------------------------------------------+
//| باز کردن معامله (با مدیریت سرمایه اصلاح شده و دقیق)                |
//| این تابع معامله رو با محاسبه حجم، SL و TP باز می‌کنه. اگر حد معاملات رسیده باشه، باز نمی‌کنه. |
//| مراحل: ۱. چک حد معاملات. ۲. محاسبه SL. ۳. محاسبه حجم بر اساس ریسک. ۴. محاسبه TP. ۵. ارسال معامله. |
//+------------------------------------------------------------------+
void CStrategyManager::OpenTrade(bool is_buy)
{
    if(CountTotalTrades() >= m_settings.max_total_trades || CountSymbolTrades() >= m_settings.max_trades_per_symbol) // چک حد
    {
        Log("رسیدن به حد مجاز معاملات. معامله جدید باز نشد."); // لاگ
        return; // خروج
    }

    double entry_price = is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID); // قیمت ورود
    double sl = CalculateStopLoss(is_buy, entry_price); // SL

    if(sl == 0) // چک SL
    {
        Log("خطا در محاسبه استاپ لاس. معامله باز نشد."); // لاگ
        return; // خروج
    }
    
    // ✅✅✅ بخش کلیدی و اصلاح شده ✅✅✅

    // --- گام ۱: محاسبه ریسک به ازای هر معامله به پول حساب ---
    double balance = AccountInfoDouble(ACCOUNT_BALANCE); // بالانس
    double risk_amount = balance * (m_settings.risk_percent_per_trade / 100.0); // ریسک

    // --- گام ۲: محاسبه میزان ضرر برای ۱ لات معامله با این استاپ لاس ---
    double loss_for_one_lot = 0; // ضرر یک لات
    string base_currency = AccountInfoString(ACCOUNT_CURRENCY); // ارز
    // از تابع تخصصی متاتریدر برای این کار استفاده می‌کنیم
    if(!OrderCalcProfit(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, m_symbol, 1.0, entry_price, sl, loss_for_one_lot)) // محاسبه
    {
        Log("خطا در محاسبه سود/زیان با OrderCalcProfit. کد خطا: " + (string)GetLastError()); // لاگ
        return; // خروج
    }
    loss_for_one_lot = MathAbs(loss_for_one_lot); // مطلق

    if(loss_for_one_lot <= 0) // چک معتبر
    {
        Log("میزان ضرر محاسبه شده برای ۱ لات معتبر نیست. معامله باز نشد."); // لاگ
        return; // خروج
    }

    // --- گام ۳: محاسبه حجم دقیق لات بر اساس ریسک و میزان ضرر ۱ لات ---
    double lot_size = NormalizeDouble(risk_amount / loss_for_one_lot, 2); // حجم

    // --- گام ۴: نرمال‌سازی و گرد کردن لات بر اساس محدودیت‌های بروکر ---
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN); // حداقل
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX); // حداکثر
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP); // گام
    
    // اطمینان از اینکه لات در محدوده مجاز است
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size)); // محدوده
    
    // گرد کردن لات بر اساس گام مجاز بروکر
    lot_size = MathRound(lot_size / lot_step) * lot_step; // گرد

    if(lot_size < min_lot) // چک حداقل
    {
        Log("حجم محاسبه شده (" + DoubleToString(lot_size,2) + ") کمتر از حداقل لات مجاز (" + DoubleToString(min_lot,2) + ") است. معامله باز نشد."); // لاگ
        return; // خروج
    }

    // --- گام ۵: محاسبه حد سود و ارسال معامله ---
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); // پوینت
    double sl_distance_points = MathAbs(entry_price - sl) / point; // فاصله SL
    double tp_distance_points = sl_distance_points * m_settings.take_profit_ratio; // فاصله TP
    double tp = is_buy ? entry_price + tp_distance_points * point : entry_price - tp_distance_points * point; // TP
    
    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS); // digits
    sl = NormalizeDouble(sl, digits); // نرمال SL
    tp = NormalizeDouble(tp, digits); // نرمال TP
    
    string comment = "Memento " + (is_buy ? "Buy" : "Sell"); // کامنت
    MqlTradeResult result; // نتیجه
    
    if(is_buy) // خرید
    {
        m_trade.Buy(lot_size, m_symbol, 0, sl, tp, comment); // باز کردن
    }
    else // فروش
    {
        m_trade.Sell(lot_size, m_symbol, 0, sl, tp, comment); // باز کردن
    }
    
    // لاگ کردن نتیجه
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
//| پیدا کردن سطح کیجون سن فلت (صاف) با تایم فریم دلخواه            |
//| این تابع در گذشته کیجون رو چک می‌کنه تا یک سطح فلت (صاف) پیدا کنه. اگر تایم فریم غیر از اصلی باشه، هندل موقت می‌سازه. |
//| مراحل: ۱. اگر تایم فریم اصلی نیست، هندل موقت ایچیموکو بساز. ۲. کپی بافر کیجون. ۳. حلقه برای پیدا کردن فلت. ۴. اگر پیدا شد، بازگشت سطح. |
//+------------------------------------------------------------------+
double CStrategyManager::FindFlatKijun(ENUM_TIMEFRAMES timeframe)
{
    int kijun_handle = m_ichimoku_handle; // هندل پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // اگر متفاوت
    {
        // هندل موقت برای تایم فریم دیگر بساز
        MqlParam params[3]; // پارامترها
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.tenkan_period; // تنکان
        params[1].type = TYPE_INT; params[1].integer_value = m_settings.kijun_period; // کیجون
        params[2].type = TYPE_INT; params[2].integer_value = m_settings.senkou_period; // سنکو
        kijun_handle = IndicatorCreate(m_symbol, timeframe, IND_ICHIMOKU, 3, params); // ایجاد موقت
        if (kijun_handle == INVALID_HANDLE) return 0.0; // چک شکست
    }

    double kijun_values[]; // آرایه کیجون
    if (CopyBuffer(kijun_handle, 1, 1, m_settings.flat_kijun_period, kijun_values) < m_settings.flat_kijun_period) // کپی در تایم فریم
    {
        if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد موقت
        return 0.0; // بازگشت صفر
    }

    ArraySetAsSeries(kijun_values, true); // سری

    int flat_count = 1; // شمارنده
    for (int i = 1; i < m_settings.flat_kijun_period; i++) // حلقه
    {
        if (kijun_values[i] == kijun_values[i - 1]) // چک فلت
        {
            flat_count++; // افزایش
            if (flat_count >= m_settings.flat_kijun_min_length) // چک حداقل
            {
                if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
                return kijun_values[i]; // سطح فلت پیدا شد
            }
        }
        else // ریست
        {
            flat_count = 1; // ریست
        }
    }

    if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد نهایی
    return 0.0; // هیچ فلتی پیدا نشد
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت (نقطه چرخش) روی کیجون سن با تایم فریم دلخواه     |
//| این تابع پیوت روی کیجون رو پیدا می‌کنه. اگر تایم فریم متفاوت باشه، هندل موقت می‌سازه و برای خرید/فروش دره/قله برمی‌گردونه. |
//| مراحل: ۱. اگر لازم، هندل موقت بساز. ۲. کپی بافر کیجون. ۳. حلقه برای پیدا کردن پیوت (دره برای خرید، قله برای فروش). ۴. آزاد کردن هندل اگر موقت. |
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

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++) // حلقه
    {
        // برای معامله خرید، دنبال یک دره (پیوت کف) می‌گردیم
        if (is_buy && kijun_values[i] < kijun_values[i - 1] && kijun_values[i] < kijun_values[i + 1]) // دره
        {
            if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
            return kijun_values[i]; // بازگشت
        }
        // برای معامله فروش، دنبال یک قله (پیوت سقف) می‌گردیم
        if (!is_buy && kijun_values[i] > kijun_values[i - 1] && kijun_values[i] > kijun_values[i + 1]) // قله
        {
            if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد
            return kijun_values[i]; // بازگشت
        }
    }

    if (kijun_handle != m_ichimoku_handle) IndicatorRelease(kijun_handle); // آزاد نهایی
    return 0.0; // هیچ پیوتی
}

//+------------------------------------------------------------------+
//| پیدا کردن پیوت (نقطه چرخش) روی تنکان سن با تایم فریم دلخواه     |
//| مشابه FindPivotKijun، اما برای تنکان سن. هندل موقت اگر لازم، و چک دره/قله بر اساس خرید/فروش. |
//| مراحل: ۱. چک و ساخت هندل موقت اگر تایم فریم متفاوت. ۲. کپی بافر تنکان. ۳. حلقه پیوت‌یابی. ۴. آزاد کردن هندل. |
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

    for (int i = 1; i < m_settings.pivot_lookback - 1; i++) // حلقه
    {
        // برای معامله خرید، دنبال یک دره (پیوت کف) می‌گردیم
        if (is_buy && tenkan_values[i] < tenkan_values[i - 1] && tenkan_values[i] < tenkan_values[i + 1]) // دره
        {
            if (tenkan_handle != m_ichimoku_handle) IndicatorRelease(tenkan_handle); // آزاد
            return tenkan_values[i]; // بازگشت
        }
        // برای معامله فروش، دنبال یک قله (پیوت سقف) می‌گردیم
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
//| محاسبه حد ضرر ATR با تایم فریم دلخواه                           |
//| این تابع SL رو بر اساس ATR محاسبه می‌کنه. اگر تایم فریم متفاوت باشه، هندل موقت ATR می‌سازه. |
//| مراحل: ۱. چک فعال بودن پویا. ۲. اگر ساده، هندل چک کن و کپی ATR. ۳. اگر پویا، هندل موقت بساز و EMA محاسبه کن. ۴. رژیم نوسان رو تعیین و SL رو برگردون. |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateAtrStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe)
{
    // اگر حالت پویای SL (رژیم نوسان) غیرفعال باشد، از منطق ساده قبلی استفاده کن
    if (!m_settings.enable_sl_vol_regime) // چک ساده
    {
        // ✅✅✅ بادیگارد شماره ۱: بررسی اعتبار هندل ✅✅✅
        int atr_handle = m_atr_handle; // پیش‌فرض
        if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
        {
            MqlParam params[1]; // پارامتر
            params[0].type = TYPE_INT; params[0].integer_value = m_settings.atr_filter_period; // دوره
            atr_handle = IndicatorCreate(m_symbol, timeframe, IND_ATR, 1, params); // موقت
            if (atr_handle == INVALID_HANDLE) // چک
            {
                Log("خطای بحرانی در CalculateAtrStopLoss: هندل ATR نامعتبر است! پریود ATR در تنظیمات ورودی را بررسی کنید."); // لاگ
                return 0.0; // امن
            }
        }
        
        double atr_buffer[]; // بافر
        if(CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) < 1) // کپی
        {
            Log("داده ATR برای محاسبه حد ضرر ساده موجود نیست. (تابع CopyBuffer شکست خورد)"); // لاگ
            if (atr_handle != m_atr_handle) IndicatorRelease(atr_handle); // آزاد
            return 0.0; // صفر
        }
        
        if (atr_handle != m_atr_handle) IndicatorRelease(atr_handle); // آزاد نهایی
        
        double atr_value = atr_buffer[0]; // مقدار
        return is_buy ? entry_price - (atr_value * m_settings.sl_atr_multiplier) : entry_price + (atr_value * m_settings.sl_atr_multiplier); // SL
    }

    // --- منطق جدید: SL پویا بر اساس رژیم نوسان (این بخش هندل جداگانه خود را دارد و ایمن است) ---
    int history_size = m_settings.sl_vol_regime_ema_period + 5; // اندازه
    double atr_values[], ema_values[]; // آرایه‌ها

    int atr_sl_handle = iATR(m_symbol, timeframe, m_settings.sl_vol_regime_atr_period); // هندل ATR پویا در تایم فریم
    if (atr_sl_handle == INVALID_HANDLE || CopyBuffer(atr_sl_handle, 0, 0, history_size, atr_values) < history_size) // چک و کپی
    {
        Log("داده کافی برای محاسبه SL پویا موجود نیست."); // لاگ
        if(atr_sl_handle != INVALID_HANDLE) 
            IndicatorRelease(atr_sl_handle); // آزاد
        return 0.0; // صفر
    }
    
    IndicatorRelease(atr_sl_handle); // آزاد
    ArraySetAsSeries(atr_values, true);  // سری

    if(SimpleMAOnBuffer(history_size, 0, m_settings.sl_vol_regime_ema_period, MODE_EMA, atr_values, ema_values) < 1) // EMA
    {
         Log("خطا در محاسبه EMA روی ATR."); // لاگ
         return 0.0; // صفر
    }

    double current_atr = atr_values[1];  // ATR فعلی
    double ema_atr = ema_values[1];      // EMA

    bool is_high_volatility = (current_atr > ema_atr); // چک بالا
    double final_multiplier = is_high_volatility ? m_settings.sl_high_vol_multiplier : m_settings.sl_low_vol_multiplier; // ضریب

    Log("رژیم نوسان: " + (is_high_volatility ? "بالا" : "پایین") + ". ضریب SL نهایی: " + (string)final_multiplier); // لاگ

    return is_buy ? entry_price - (current_atr * final_multiplier) : entry_price + (current_atr * final_multiplier); // SL پویا
}

//+------------------------------------------------------------------+
//| (جایگزین شد) مدیر کل گرفتن حد مجاز تلاقی بر اساس حالت انتخابی      |
//| این تابع تلرانس تلاقی رو بر اساس حالت (دستی، کومو، ATR) محاسبه می‌کنه. |
//| مراحل: ۱. سوئیچ حالت. ۲. محاسبه بر اساس حالت انتخابی. |
//+------------------------------------------------------------------+
double CStrategyManager::GetTalaqiTolerance(int reference_shift)
{
    switch(m_settings.talaqi_calculation_mode) // سوئیچ
    {
        case TALAQI_MODE_MANUAL: // دستی
            return m_settings.talaqi_distance_in_points * SymbolInfoDouble(m_symbol, SYMBOL_POINT); // دستی
        
        case TALAQI_MODE_KUMO: // کومو
            return CalculateDynamicTolerance(reference_shift); // پویا
        
        case TALAQI_MODE_ATR: // ATR
            return CalculateAtrTolerance(reference_shift);     // ATR
            
        default: // پیش‌فرض
            return 0.0; // صفر
    }
}


//+------------------------------------------------------------------+
//| (اتوماتیک) محاسبه حد مجاز تلاقی بر اساس ضخامت ابر کومو            |
//| این تابع ضخامت کومو رو در شیفت گذشته محاسبه می‌کنه و تلرانس رو بر اساس ضریب برمی‌گردونه. |
//| مراحل: ۱. چک ضریب. ۲. کپی سنکو A و B. ۳. محاسبه ضخامت. ۴. اعمال ضریب. |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateDynamicTolerance(int reference_shift)
{
    // اگر ضریب کومو صفر یا منفی باشه، یعنی این روش غیرفعاله
    if(m_settings.talaqi_kumo_factor <= 0) return 0.0; // چک ضریب

    // آرایه‌ها برای نگهداری مقادیر سنکو اسپن A و B در گذشته
    double senkou_a_buffer[], senkou_b_buffer[]; // بافرها

    // از متاتریدر می‌خوایم که مقدار سنکو A و B رو در "نقطه X" تاریخی به ما بده
    // بافر 2 = Senkou Span A
    // بافر 3 = Senkou Span B
    if(CopyBuffer(m_ichimoku_handle, 2, reference_shift, 1, senkou_a_buffer) < 1 || 
       CopyBuffer(m_ichimoku_handle, 3, reference_shift, 1, senkou_b_buffer) < 1)
    {
       Log("داده کافی برای محاسبه ضخامت کومو در گذشته وجود ندارد."); // لاگ
       return 0.0; // اگر داده نبود، مقدار صفر برمی‌گردونیم تا تلاقی چک نشه
    }

    // گام ۱: محاسبه ضخامت کومو در "نقطه X"
    double kumo_thickness = MathAbs(senkou_a_buffer[0] - senkou_b_buffer[0]); // ضخامت

    // اگر ضخامت کومو صفر بود (مثلا در کراس سنکوها)، یه مقدار خیلی کوچیک برگردون
    if(kumo_thickness == 0) return SymbolInfoDouble(m_symbol, SYMBOL_POINT); // کوچک

    // گام ۲: محاسبه حد مجاز تلاقی بر اساس ضریب ورودی کاربر
    double tolerance = kumo_thickness * m_settings.talaqi_kumo_factor; // تلرانس

    return tolerance; // بازگشت
}


//+------------------------------------------------------------------+
//| (حالت مسابقه‌ای) اضافه کردن سیگنال جدید به لیست نامزدها            |
//| این تابع سیگنال جدید رو به لیست اضافه می‌کنه و لاگ می‌زنه. |
//| مراحل: ۱. تغییر اندازه آرایه. ۲. مقداردهی مشخصات. ۳. لاگ و رسم. |
//+------------------------------------------------------------------+
void CStrategyManager::AddOrUpdatePotentialSignal(bool is_buy)
{
    // وظیفه: این تابع هر سیگنال جدیدی که پیدا می‌شود را به لیست نامزدها اضافه می‌کند
    
    // گام اول: یک نامزد جدید به انتهای لیست اضافه کن
    int total = ArraySize(m_potential_signals); // تعداد
    ArrayResize(m_potential_signals, total + 1); // تغییر
    
    // گام دوم: مشخصات نامزد جدید را مقداردهی کن
    m_potential_signals[total].time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou_period); // زمان
    m_potential_signals[total].is_buy = is_buy; // نوع
    m_potential_signals[total].grace_candle_count = 0; // شمارنده مهلت از صفر شروع می‌شود
    
    // لاگ کردن افزودن نامزد جدید به مسابقه
    Log("[حالت مسابقه‌ای] سیگنال نامزد جدید " + (is_buy ? "خرید" : "فروش") + " به لیست انتظار مسابقه اضافه شد. تعداد کل نامزدها: " + (string)ArraySize(m_potential_signals)); // لاگ
    
    // یک مستطیل برای نمایش سیگنال اولیه روی چارت رسم کن
    if(m_symbol == _Symbol && m_visual_manager != NULL) // چک
    m_visual_manager.DrawTripleCrossRectangle(is_buy, m_settings.chikou_period); // رسم

}

//+------------------------------------------------------------------+
//| (نسخه نهایی و ضد ضربه) محاسبه حد مجاز تلاقی بر اساس ATR
//| این تابع تلرانس رو بر اساس ATR در شیفت گذشته محاسبه می‌کنه. اگر هندل نامعتبر، صفر برمی‌گردونه. |
//| مراحل: ۱. چک ضریب. ۲. چک هندل. ۳. کپی بافر ATR. ۴. محاسبه تلرانس. |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateAtrTolerance(int reference_shift)
{
    if(m_settings.talaqi_atr_multiplier <= 0) return 0.0; // چک ضریب
    
    // ✅✅✅ بادیگارد شماره ۳: بررسی اعتبار هندل ✅✅✅
    if (m_atr_handle == INVALID_HANDLE) // چک
    {
        Log("محاسبه تلورانس ATR ممکن نیست چون هندل آن نامعتبر است. پریود ATR در تنظیمات ورودی را بررسی کنید."); // لاگ
        return 0.0; // امن
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
//| تابع اصلی "گیت کنترل نهایی" که تمام فیلترها را چک می‌کند       |
//| این تابع تمام فیلترهای فعال رو چک می‌کنه و اگر یکی رد بشه، سریع خارج میشه. تایم فریم رو تعیین و به فیلترها پاس میده. |
//| مراحل: ۱. تعیین تایم فریم فیلتر بر اساس زمینه. ۲. چک هر فیلتر فعال و اگر رد، بازگشت false. ۳. اگر همه پاس، true. |
//+------------------------------------------------------------------+
bool CStrategyManager::AreAllFiltersPassed(bool is_buy)
{
    // تعیین تایم فریم محاسبات بر اساس ورودی کاربر
    ENUM_TIMEFRAMES filter_tf = (m_settings.filter_context == FILTER_CONTEXT_HTF) 
                                ? m_settings.ichimoku_timeframe 
                                : m_settings.ltf_timeframe; // تایم فریم فیلتر

    if (m_settings.enable_kumo_filter) // چک کومو
    {
        if (!CheckKumoFilter(is_buy, filter_tf)) // چک با تایم فریم
        {
            Log("فیلتر کومو رد شد."); // لاگ
            return false; // رد
        }
    }

    if (m_settings.enable_atr_filter) // چک ATR
    {
        if (!CheckAtrFilter(filter_tf)) // چک با تایم فریم
        {
            Log("فیلتر ATR رد شد."); // لاگ
            return false; // رد
        }
    }

    if (m_settings.enable_adx_filter) // چک ADX
    {
        if (!CheckAdxFilter(is_buy, filter_tf)) // چک با تایم فریم
        {
            Log("فیلتر ADX رد شد."); // لاگ
            return false; // رد
        }
    }

    Log("✅ تمام فیلترهای فعال با موفقیت پاس شدند."); // لاگ موفقیت
    return true; // تایید
}


//+------------------------------------------------------------------+
//| تابع کمکی برای بررسی فیلتر ابر کومو با تایم فریم دلخواه        |
//| این تابع چک می‌کنه قیمت نسبت به ابر کومو در موقعیت درستی هست یا نه. اگر تایم فریم متفاوت، هندل موقت ایچیموکو می‌سازه. |
//| مراحل: ۱. اگر تایم فریم متفاوت، هندل موقت بساز. ۲. کپی سنکو A و B. ۳. محاسبه بالا/پایین کومو. ۴. چک موقعیت قیمت. ۵. آزاد هندل اگر موقت. |
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
            return false; // رد برای امنیت
        }
    }
    
    double senkou_a[], senkou_b[]; // بافرها
    // گرفتن مقدار سنکو A و B برای کندل فعلی (شیفت ۰)
    // بافر 2 = Senkou Span A , بافر 3 = Senkou Span B
    if(CopyBuffer(ichi_handle, 2, 0, 1, senkou_a) < 1 || 
       CopyBuffer(ichi_handle, 3, 0, 1, senkou_b) < 1)
    {
       Log("خطا: داده کافی برای فیلتر کومو موجود نیست."); // لاگ
       if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد
       return false; // رد
    }
    
    if (ichi_handle != m_ichimoku_handle) IndicatorRelease(ichi_handle); // آزاد نهایی
    
    double high_kumo = MathMax(senkou_a[0], senkou_b[0]); // بالا
    double low_kumo = MathMin(senkou_a[0], senkou_b[0]); // پایین
    double close_price = iClose(m_symbol, timeframe, 1); // بسته در تایم فریم

    if (is_buy) // خرید
    {
        // برای خرید، قیمت باید بالای ابر باشه
        return (close_price > high_kumo); // چک
    }
    else // فروش
    {
        // برای فروش، قیمت باید پایین ابر باشه
        return (close_price < low_kumo); // چک
    }
}

//+------------------------------------------------------------------+
//| (نسخه نهایی و ضد ضربه) تابع کمکی برای بررسی فیلتر ATR با تایم فریم |
//| این تابع چک می‌کنه ATR فعلی از حداقل آستانه بیشتر باشه یا نه. اگر تایم فریم متفاوت، هندل موقت ATR می‌سازه. |
//| مراحل: ۱. چک هندل و ساخت موقت اگر لازم. ۲. کپی بافر ATR. ۳. محاسبه آستانه و چک. ۴. آزاد هندل اگر موقت. |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckAtrFilter(ENUM_TIMEFRAMES timeframe)
{
    // ✅✅✅ بادیگارد شماره ۲: بررسی اعتبار هندل ✅✅✅
    int atr_handle = m_atr_handle; // پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
    {
        MqlParam params[1]; // پارامتر
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.atr_filter_period; // دوره
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
    
    if (atr_handle != m_atr_handle) IndicatorRelease(atr_handle); // آزاد نهایی
    
    double current_atr = atr_value_buffer[0]; // ATR
    
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT); // پوینت
    double min_atr_threshold = m_settings.atr_filter_min_value_pips * point; // آستانه
    
    if(_Digits == 3 || _Digits == 5) // چک digits
    {
        min_atr_threshold *= 10; // تنظیم
    }

    return (current_atr >= min_atr_threshold); // چک
}

//+------------------------------------------------------------------+
//| (جدید) تابع کمکی برای بررسی فیلتر قدرت و جهت روند ADX با تایم فریم |
//| این تابع قدرت ADX و جهت DI+ و DI- رو چک می‌کنه تا روند با سیگنال همخوانی داشته باشه. اگر تایم فریم متفاوت، هندل موقت ADX می‌سازه. |
//| مراحل: ۱. چک و ساخت هندل موقت اگر لازم. ۲. کپی بافرهای ADX, DI+, DI-. ۳. چک قدرت و جهت. ۴. آزاد هندل اگر موقت. |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckAdxFilter(bool is_buy, ENUM_TIMEFRAMES timeframe) 
{  
    int adx_handle = m_adx_handle; // پیش‌فرض
    if (timeframe != m_settings.ichimoku_timeframe) // متفاوت
    {
        MqlParam params[1]; // پارامتر
        params[0].type = TYPE_INT; params[0].integer_value = m_settings.adx_period; // دوره
        adx_handle = IndicatorCreate(m_symbol, timeframe, IND_ADX, 1, params); // موقت
        if (adx_handle == INVALID_HANDLE) // چک
        {
            Log("خطا در ایجاد هندل ADX برای فیلتر در تایم فریم " + EnumToString(timeframe)); // لاگ
            return false; // رد
        }
    }
    
    double adx_buffer[1], di_plus_buffer[1], di_minus_buffer[1];  // بافرها
    
    // از هندل استفاده می‌کنیم
    if (CopyBuffer(adx_handle, 0, 1, 1, adx_buffer) < 1 ||  // کپی ADX
        CopyBuffer(adx_handle, 1, 1, 1, di_plus_buffer) < 1 ||  // DI+
        CopyBuffer(adx_handle, 2, 1, 1, di_minus_buffer) < 1) // DI-
    {
        Log("داده کافی برای فیلتر ADX موجود نیست."); // لاگ
        if (adx_handle != m_adx_handle) IndicatorRelease(adx_handle); // آزاد
        return false; // رد
    }
    
    if (adx_handle != m_adx_handle) IndicatorRelease(adx_handle); // آزاد نهایی
    
    // شرط ۱: آیا قدرت روند از حد آستانه ما بیشتر است؟
    if (adx_buffer[0] <= m_settings.adx_threshold)  // چک قدرت
    {
        return false; // رد
    }
    
    // شرط ۲: آیا جهت روند با جهت سیگنال ما یکی است؟
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
//| (جدید) تابع اصلی برای مدیریت خروج زودرس                        |
//| این تابع تمام پوزیشن‌های باز رو چک می‌کنه و اگر شرایط خروج زودرس برقرار باشه، پوزیشن رو می‌بنده. |
//| مراحل: ۱. حلقه روی پوزیشن‌ها از آخر به اول. ۲. چک نماد و مجیک. ۳. چک نوع و شرایط خروج. ۴. اگر بله، ببند. |
//+------------------------------------------------------------------+
void CStrategyManager::CheckForEarlyExit()
{
    // از آخر به اول روی پوزیشن ها حلقه میزنیم چون ممکن است یکی بسته شود
    for (int i = PositionsTotal() - 1; i >= 0; i--)  // حلقه پوزیشن‌ها
    {
        ulong ticket = PositionGetTicket(i); // تیکت
        // فقط پوزیشن های مربوط به همین اکسپرت و همین نماد را بررسی میکنیم
        if (PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number) // چک
        {
            if (PositionSelectByTicket(ticket)) // انتخاب
            {
                bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY); // نوع
                // آیا شرایط خروج زودرس فراهم است؟
                if (CheckChikouRsiExit(is_buy))  // چک خروج
                { 
                    Log("🚨 سیگنال خروج زودرس برای تیکت " + (string)ticket + " صادر شد. بستن معامله..."); // لاگ
                    m_trade.PositionClose(ticket);  // بستن
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| (جدید) تابع کمکی برای بررسی منطق خروج چیکو + RSI                |
//| این تابع چک می‌کنه آیا چیکو کراس کرده و RSI اشباع شده یا نه. برای خرید/فروش جدا چک می‌کنه. |
//| مراحل: ۱. گرفتن چیکو قیمت. ۲. کپی بافرهای تنکان، کیجون، RSI. ۳. چک کراس چیکو و سطح RSI. |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckChikouRsiExit(bool is_buy)
{
    // گرفتن داده های لازم از کندل تایید (کندل شماره ۱)
    double chikou_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1); // چیکو
    
    double tenkan_buffer[1], kijun_buffer[1], rsi_buffer[1]; // بافرها
    if(CopyBuffer(m_ichimoku_handle, 0, 1, 1, tenkan_buffer) < 1 ||
       CopyBuffer(m_ichimoku_handle, 1, 1, 1, kijun_buffer) < 1 ||
       CopyBuffer(m_rsi_exit_handle, 0, 1, 1, rsi_buffer) < 1)
    {
        return false; // اگر داده نباشد، خروجی در کار نیست
    }
    
    double tenkan = tenkan_buffer[0]; // تنکان
    double kijun = kijun_buffer[0]; // کیجون
    double rsi = rsi_buffer[0]; // RSI
    
    bool chikou_cross_confirms_exit = false; // فلگ چیکو
    bool rsi_confirms_exit = false; // فلگ RSI

    if (is_buy) // خرید، خروج نزولی
    {
        // شرط ۱: آیا قیمت (چیکو) به زیر خطوط تنکان و کیجون کراس کرده؟
        chikou_cross_confirms_exit = (chikou_price < MathMin(tenkan, kijun)); // چک نزولی
        // شرط ۲: آیا RSI هم از دست رفتن مومنتوم صعودی را تایید میکند؟
        rsi_confirms_exit = (rsi < m_settings.early_exit_rsi_oversold); // اشباع فروش
    }
    else // فروش، خروج صعودی
    {
        // شرط ۱: آیا قیمت (چیکو) به بالای خطوط تنکان و کیجون کراس کرده؟
        chikou_cross_confirms_exit = (chikou_price > MathMax(tenkan, kijun)); // چک صعودی
        // شرط ۲: آیا RSI هم از دست رفتن مومنتوم نزولی را تایید میکند؟
        rsi_confirms_exit = (rsi > m_settings.early_exit_rsi_overbought); // اشباع خرید
    }
    
    // اگر هر دو شرط برقرار باشند، سیگنال خروج صادر میشود
    return (chikou_cross_confirms_exit && rsi_confirms_exit); // بازگشت
}


//+------------------------------------------------------------------+
//| (جدید) بررسی تاییدیه نهایی با شکست ساختار در تایم فریم پایین      |
//| این تابع سیگنال ساختار بازار رو چک می‌کنه تا تاییدیه LTF رو بده. |
//| مراحل: ۱. پردازش بار جدید در تحلیلگر. ۲. چک نوع سیگنال با خرید/فروش. |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckLowerTfConfirmation(bool is_buy)
{
    // کتابخانه تحلیل ساختار را روی کندل جدید اجرا کن
    SMssSignal mss_signal = m_ltf_analyzer.ProcessNewBar(); // پردازش

    // اگر هیچ سیگنالی در تایم فریم پایین پیدا نشد، تاییدیه رد می‌شود
    if(mss_signal.type == MSS_NONE) // چک هیچ
    {
        return false; // رد
    }

    // اگر سیگنال اصلی ما "خرید" است...
    if (is_buy) // خرید
    {
        // ...ما دنبال یک شکست صعودی در تایم فریم پایین هستیم
        if (mss_signal.type == MSS_BREAK_HIGH || mss_signal.type == MSS_SHIFT_UP) // صعودی
        {
            Log("✅ تاییدیه تایم فریم پایین برای خرید دریافت شد (CHoCH)."); // لاگ
            return true; // تایید شد!
        }
    }
    else // فروش
    {
        // ...ما دنبال یک شکست نزولی در تایم فریم پایین هستیم
        if (mss_signal.type == MSS_BREAK_LOW || mss_signal.type == MSS_SHIFT_DOWN) // نزولی
        {
            Log("✅ تاییدیه تایم فریم پایین برای فروش دریافت شد (CHoCH)."); // لاگ
            return true; // تایید شد!
        }
    }

    // اگر سیگنال تایم فریم پایین در جهت سیگنال اصلی ما نبود، تاییدیه رد می‌شود
    return false; // رد
}

// این کد را به انتهای فایل IchimokuLogic.mqh اضافه کن

//+------------------------------------------------------------------+
//| (جدید) تابع واکسن: آیا داده‌های تمام تایم‌فریم‌ها آماده است؟       |
//| این تابع چک می‌کنه داده‌های HTF, LTF و فعلی حداقل ۲۰۰ بار داشته باشن. |
//| مراحل: ۱. لیست تایم فریم‌ها رو آماده کن. ۲. برای هر کدام چک بار و زمان. |
//+------------------------------------------------------------------+
bool CStrategyManager::IsDataReady()
{
    // لیست تمام تایم فریم هایی که اکسپرت استفاده میکنه
    ENUM_TIMEFRAMES timeframes_to_check[3]; // آرایه
    timeframes_to_check[0] = m_settings.ichimoku_timeframe; // HTF
    timeframes_to_check[1] = m_settings.ltf_timeframe;      // LTF
    timeframes_to_check[2] = PERIOD_CURRENT;                 // فعلی

    // حداقل تعداد کندل مورد نیاز برای تحلیل مطمئن
    int required_bars = 200;  // حداقل

    for(int i = 0; i < 3; i++) // حلقه
    {
        ENUM_TIMEFRAMES tf = timeframes_to_check[i]; // تایم
        
        // اگر تعداد کندل های موجود کمتر از حد نیاز بود یا تاریخچه کامل نبود
        if(iBars(m_symbol, tf) < required_bars || iTime(m_symbol, tf, 1) == 0) // چک
        {
            // Log("داده برای تایم فریم " + EnumToString(tf) + " هنوز آماده نیست.");
            return false; // نه آماده
        }
    }
    
    // اگر حلقه تمام شد و مشکلی نبود، یعنی همه چی آماده است
    return true;  // آماده
}

//+------------------------------------------------------------------+
//| چک می‌کند آیا در تایم فریم مشخص، کندل جدیدی تشکیل شده یا نه     |
//| این تابع ساده چک می‌کنه بار جدید اومده یا نه، و زمان رو آپدیت می‌کنه. |
//| مراحل: ۱. گرفتن زمان بار فعلی. ۲. مقایسه با آخرین زمان. ۳. اگر جدید، آپدیت و true. |
//+------------------------------------------------------------------+
bool CStrategyManager::IsNewBar(ENUM_TIMEFRAMES timeframe, datetime &last_bar_time)
{
    datetime current_bar_time = iTime(m_symbol, timeframe, 0); // زمان فعلی
    if (current_bar_time > last_bar_time) // چک جدید
    {
        last_bar_time = current_bar_time; // آپدیت
        return true; // جدید
    }
    return false; // قدیمی
}
