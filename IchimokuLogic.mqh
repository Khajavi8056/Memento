//+------------------------------------------------------------------+
//|                                     IchimokuLogic.mqh            |
//|                          © 2025, hipoalgoritm              |
//+------------------------------------------------------------------+
#property copyright "© 2025,hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "2.1" 
#include "set.mqh"
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Object.mqh>
#include "VisualManager.mqh"
#include <MovingAverages.mqh>
#include "MarketStructure.mqh"




// IchimokuLogic.mqh

struct SPotentialSignal
{
    datetime        time;
    bool            is_buy;
    int             grace_candle_count;
    double          invalidation_level; // ✅✅✅ این خط جدید رو اضافه کن ✅✅✅
    
    // سازنده کپی (Copy Constructor)
    SPotentialSignal(const SPotentialSignal &other)
    {
        time = other.time;
        is_buy = other.is_buy;
        grace_candle_count = other.grace_candle_count;
        invalidation_level = other.invalidation_level; // ✅✅✅ این خط جدید رو اضافه کن ✅✅✅
    }
    // سازنده پیش‌فرض (برای اینکه کد به مشکل نخوره)
    SPotentialSignal()
    {
       invalidation_level = 0.0; // مقداردهی اولیه
    }
};


 
/*struct SSettings
{
    string              symbols_list;
    int                 magic_number;
    bool                enable_logging;

    int                 tenkan;
    int                 kijun;
    int                 senkou;
    int                 chikou;

    E_Confirmation_Mode confirmation_type;
    int                 grace_candles;
    double              talaqi_distance_in_points;

    E_SL_Mode           stoploss_type;
    int                 sl_lookback;
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
//| کلاس مدیریت استراتژی برای یک نماد خاص (نسخه نهایی با MTF)          |
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
    int                 m_adx_handle;
    int                 m_rsi_exit_handle;

    // --- بافرهای داده ---
    double              m_tenkan_buffer[];
    double              m_kijun_buffer[];
    double              m_chikou_buffer[];
    double              m_high_buffer[];
    double              m_low_buffer[];
    
    // --- مدیریت سیگنال ---
    SPotentialSignal    m_signal;
    bool                m_is_waiting;
    SPotentialSignal    m_potential_signals[];
    CVisualManager* m_visual_manager;
    CMarketStructureShift m_ltf_analyzer;
    CMarketStructureShift m_grace_structure_analyzer;

    //--- توابع کمکی ---
    void Log(string message);
    bool IsDataReady();
    
    // --- منطق اصلی سیگنال ---
    bool CheckTripleCross(bool& is_buy);
    bool CheckFinalConfirmation(bool is_buy);
    bool CheckLowerTfConfirmation(bool is_buy);

    // --- فیلترهای ورود (با ورودی تایم فریم) ---
    bool AreAllFiltersPassed(bool is_buy);
    bool CheckKumoFilter(bool is_buy, ENUM_TIMEFRAMES timeframe);
    bool CheckAtrFilter(ENUM_TIMEFRAMES timeframe);
    bool CheckAdxFilter(bool is_buy, ENUM_TIMEFRAMES timeframe);

    // --- منطق خروج ---
    void CheckForEarlyExit();
    bool CheckChikouRsiExit(bool is_buy);

    //--- محاسبه استاپ لاس (با ورودی تایم فریم) ---
    double CalculateStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe);
    double CalculateAtrStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe);
    double GetTalaqiTolerance(int reference_shift);
    double CalculateAtrTolerance(int reference_shift);
    double CalculateDynamicTolerance(int reference_shift);
    double FindFlatKijun(ENUM_TIMEFRAMES timeframe);
    double FindPivotKijun(bool is_buy, ENUM_TIMEFRAMES timeframe);
    double FindPivotTenkan(bool is_buy, ENUM_TIMEFRAMES timeframe);
    double FindBackupStopLoss(bool is_buy, double buffer, ENUM_TIMEFRAMES timeframe);
    
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
}

//+------------------------------------------------------------------+
//| آپدیت کردن داشبورد                                                |
//+------------------------------------------------------------------+
void CStrategyManager::UpdateMyDashboard() 
{ 
    if (m_visual_manager != NULL)
    {
        m_visual_manager.UpdateDashboard();
    }
}
//================================================================


//+------------------------------------------------------------------+
//| مقداردهی اولیه (نسخه کامل با اندیکاتورهای نامرئی)                  |
//+------------------------------------------------------------------+
bool CStrategyManager::Init()
{
    // +++ بخش واکسیناسیون برای اطمینان از آمادگی داده‌ها (بدون تغییر) +++
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
    // +++ پایان بخش واکسیناسیون +++

    
    // تنظیمات اولیه شیء ترید (بدون تغییر)
    m_trade.SetExpertMagicNumber(m_settings.magic_number);
    m_trade.SetTypeFillingBySymbol(m_symbol);
    
    // --- =================================================================== ---
    // --- ✅ بخش اصلی تغییرات: ساخت هندل اندیکاتورها (حالت روح و عادی) ✅ ---
    // --- =================================================================== ---

    // 💡 **ایچیموکو: انتخاب بین حالت نمایشی یا حالت روح**

    // --- حالت ۱ (فعال): ایچیموکو روی چارت نمایش داده می‌شود ---
    m_ichimoku_handle = iIchimoku(m_symbol, m_settings.ichimoku_timeframe, m_settings.tenkan, m_settings.kijun, m_settings.senkou);

    /*
    // --- حالت ۲ (غیرفعال): ایچیموکو در پس‌زمینه محاسبه شده و روی چارت نمی‌آید (حالت روح) ---
    // برای فعال کردن این حالت، کد بالا را کامنت کرده و این بلاک را از کامنت خارج کنید.
    MqlParam ichimoku_params[3];
    ichimoku_params[0].type = TYPE_INT;
    ichimoku_params[0].integer_value = m_settings.tenkan;
    ichimoku_params[1].type = TYPE_INT;
    ichimoku_params[1].integer_value = m_settings.kijun;
    ichimoku_params[2].type = TYPE_INT;
    ichimoku_params[2].integer_value = m_settings.senkou;
    m_ichimoku_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ICHIMOKU, 3, ichimoku_params);
    */


    // 👻 **ساخت هندل ATR در حالت روح (نامرئی)**
    MqlParam atr_params[1];
    atr_params[0].type = TYPE_INT;
    atr_params[0].integer_value = m_settings.atr_filter;
    m_atr_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ATR, 1, atr_params);

    // 👻 **ساخت هندل ADX در حالت روح (نامرئی)**
    MqlParam adx_params[1];
    adx_params[0].type = TYPE_INT;
    adx_params[0].integer_value = m_settings.adx;
    m_adx_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_ADX, 1, adx_params);

    // 👻 **ساخت هندل RSI در حالت روح (نامرئی)**
    MqlParam rsi_params[2];
    rsi_params[0].type = TYPE_INT;
    rsi_params[0].integer_value = m_settings.early_exit_rsi;
    rsi_params[1].type = TYPE_INT;
    rsi_params[1].integer_value = PRICE_CLOSE; // applied_price
    m_rsi_exit_handle = IndicatorCreate(m_symbol, m_settings.ichimoku_timeframe, IND_RSI, 2, rsi_params);
    
    // --- =================================================================== ---
    // --- ✅ پایان بخش تغییرات ✅ ---
    // --- =================================================================== ---

    // بررسی نهایی اعتبار تمام هندل‌ها
    if (m_ichimoku_handle == INVALID_HANDLE || m_atr_handle == INVALID_HANDLE || m_adx_handle == INVALID_HANDLE || m_rsi_exit_handle == INVALID_HANDLE)
    {
        Log("خطا در ایجاد یک یا چند اندیکاتور. لطفاً تنظیمات را بررسی کنید.");
        return false;
    }

    // مقداردهی اولیه بافرها و کتابخانه‌های دیگر (بدون تغییر)
    ArraySetAsSeries(m_tenkan_buffer, true);
    ArraySetAsSeries(m_kijun_buffer, true);
    ArraySetAsSeries(m_chikou_buffer, true);
    ArraySetAsSeries(m_high_buffer, true);
    ArraySetAsSeries(m_low_buffer, true); 
    
    if (!m_visual_manager.Init())
    {
        Log("خطا در مقداردهی اولیه VisualManager.");
        return false;
    }

    if(m_symbol == _Symbol)
    {
        m_visual_manager.InitDashboard();
    }
    
    m_ltf_analyzer.Init(m_symbol, m_settings.ltf_timeframe);
    
    Log("با موفقیت مقداردهی اولیه شد.");
    return true;
}


//+------------------------------------------------------------------+
//| (نسخه نهایی و بازنویسی شده) تابع اصلی پردازش کندل جدید             |
//+------------------------------------------------------------------+
void CStrategyManager::ProcessNewBar()
{
  if (!IsDataReady()) return;//واکسن
    // --- گام ۰: آماده‌سازی و بررسی اولیه ---

    // زمان باز شدن کندل فعلی را در تایم فریم اصلی (که کاربر تعیین کرده) دریافت می‌کنیم.
    datetime current_bar_time = iTime(m_symbol, m_settings.ichimoku_timeframe, 0);
    
    // اگر این کندل قبلاً پردازش شده، از تابع خارج می‌شویم تا از اجرای تکراری جلوگیری کنیم.
    if (current_bar_time == m_last_bar_time) 
        return; 
    
    // زمان کندل جدید را ذخیره می‌کنیم تا در تیک‌های بعدی دوباره پردازش نشود.
    m_last_bar_time = current_bar_time;
  
    // اگر قابلیت خروج زودرس فعال بود، پوزیشن‌های باز را بررسی می‌کنیم.
    if(m_settings.enable_early_exit)
    {
        CheckForEarlyExit();
    }

    // اگر این نمونه از کلاس، مسئول چارت اصلی است، اشیاء گرافیکی قدیمی را پاکسازی می‌کند.
    if(m_symbol == _Symbol && m_visual_manager != NULL)
    {
        m_visual_manager.CleanupOldObjects(200);
    }

    //================================================================//
    //                 انتخاب منطق بر اساس حالت مدیریت سیگنال           //
    //================================================================//

    // --- حالت اول: منطق جایگزینی (فقط یک سیگنال در حالت انتظار باقی می‌ماند) ---
    if (m_settings.signal_mode == MODE_REPLACE_SIGNAL)
    {
        bool is_new_signal_buy = false;
        
        // آیا یک سیگنال اولیه جدید (کراس سه‌گانه) پیدا شده است؟
        if (CheckTripleCross(is_new_signal_buy))
        {
            // اگر از قبل منتظر یک سیگنال بودیم و سیگنال جدید مخالف قبلی بود، سیگنال قبلی را کنسل می‌کنیم.
            if (m_is_waiting && is_new_signal_buy != m_signal.is_buy)
            {
                Log("سیگنال جدید و مخالف پیدا شد! سیگنال قبلی کنسل شد.");
                m_is_waiting = false;
            }
            
            // اگر در حالت انتظار نبودیم، سیگنال جدید را به عنوان سیگنال فعال در نظر می‌گیریم.
            if (!m_is_waiting)
            {
                m_is_waiting = true;
                m_signal.is_buy = is_new_signal_buy;
                m_signal.time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou);
                m_signal.grace_candle_count = 0;
                m_signal.invalidation_level = 0.0; // سطح ابطال را ریست می‌کنیم.

                // اگر حالت مهلت "ساختاری" انتخاب شده بود، سطح ابطال را همینجا تعیین می‌کنیم.
                if (m_settings.grace_mode == GRACE_BY_STRUCTURE)
                {
                    m_grace_structure_analyzer.ProcessNewBar(); // تحلیلگر ساختار را روی کندل جدید آپدیت می‌کنیم.
                    if (is_new_signal_buy)
                    {
                        m_signal.invalidation_level = m_grace_structure_analyzer.GetLastSwingLow();
                        Log("سطح ابطال برای سیگنال خرید: " + DoubleToString(m_signal.invalidation_level, _Digits));
                    }
                    else
                    {
                        m_signal.invalidation_level = m_grace_structure_analyzer.GetLastSwingHigh();
                        Log("سطح ابطال برای سیگنال فروش: " + DoubleToString(m_signal.invalidation_level, _Digits));
                    }
                }
                
                Log("سیگنال اولیه " + (m_signal.is_buy ? "خرید" : "فروش") + " پیدا شد. ورود به حالت انتظار...");
                if(m_symbol == _Symbol && m_visual_manager != NULL) 
                    m_visual_manager.DrawTripleCrossRectangle(m_signal.is_buy, m_settings.chikou);
            }
        }
    
        // این بخش فقط زمانی اجرا می‌شود که یک سیگنال معتبر در حالت انتظار داشته باشیم.
        if (m_is_waiting)
        {
            bool is_signal_expired = false;

            // --- گام ۱: بررسی انقضای سیگنال بر اساس حالت انتخابی کاربر ---
            if (m_settings.grace_mode == GRACE_BY_CANDLES)
            {
                if (m_signal.grace_candle_count >= m_settings.grace_candles)
                {
                    is_signal_expired = true;
                    Log("سیگنال به دلیل اتمام مهلت زمانی (تعداد کندل) منقضی شد.");
                }
            }
            else // حالت GRACE_BY_STRUCTURE
            {
                double current_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
                if (m_signal.invalidation_level > 0)
                {
                    if ((m_signal.is_buy && current_price < m_signal.invalidation_level) ||
                        (!m_signal.is_buy && current_price > m_signal.invalidation_level))
                    {
                        is_signal_expired = true;
                        Log("سیگنال به دلیل شکست سطح ابطال ساختاری (" + DoubleToString(m_signal.invalidation_level, _Digits) + ") منقضی شد.");
                    }
                }
            }

            // --- گام ۲: تصمیم‌گیری نهایی ---
            if (is_signal_expired)
            {
                m_is_waiting = false; // سیگنال منقضی شد، از حالت انتظار خارج شو.
            }
            // اگر سیگنال هنوز معتبر است، به دنبال تاییدیه نهایی می‌گردیم.
            else if (CheckFinalConfirmation(m_signal.is_buy))
            {
                Log("تاییدیه نهایی برای سیگنال " + (m_signal.is_buy ? "خرید" : "فروش") + " دریافت شد.");
                
                // [دروازه نهایی] حالا که تاییدیه داریم، سیگنال را از فیلترهای نهایی عبور می‌دهیم.
                if (AreAllFiltersPassed(m_signal.is_buy))
                {
                    Log("تمام فیلترها پاس شدند. ارسال دستور معامله...");
                    if(m_symbol == _Symbol && m_visual_manager != NULL) 
                        m_visual_manager.DrawConfirmationArrow(m_signal.is_buy, 1);
                    
                    OpenTrade(m_signal.is_buy);
                }
                else
                {
                    Log("❌ معامله توسط فیلترهای نهایی رد شد.");
                }
                
                m_is_waiting = false; // کار این سیگنال (چه موفق چه ناموفق) تمام شده است.
            }
            // اگر سیگنال نه منقضی شده و نه تایید شده است...
            else
            {
                // شمارنده کندل‌ها را فقط برای حالت مهلت زمانی افزایش می‌دهیم.
                if(m_settings.grace_mode == GRACE_BY_CANDLES)
                {
                     m_signal.grace_candle_count++;
                }
                // ناحیه اسکن روی چارت را آپدیت می‌کنیم.
                if(m_symbol == _Symbol && m_visual_manager != NULL) 
                    m_visual_manager.DrawScanningArea(m_signal.is_buy, m_settings.chikou, m_signal.grace_candle_count);
            }
        }
    }
    // --- حالت دوم: منطق مسابقه‌ای (هنوز از منطق قدیمی مهلت زمانی استفاده می‌کند) ---
    // نکته: پیاده‌سازی مهلت ساختاری در این حالت نیاز به تغییرات بیشتری در ساختار داده دارد که در آپدیت بعدی قابل انجام است.
// IchimokuLogic.mqh -> داخل تابع ProcessNewBar

    // --- حالت دوم: منطق مسابقه‌ای (نسخه آپگرید شده با پشتیبانی از مهلت ساختاری) ---
    else if (m_settings.signal_mode == MODE_SIGNAL_CONTEST)
    {
        bool is_new_signal_buy = false;
        // اگر کراس سه‌گانه جدید پیدا شد
        if (CheckTripleCross(is_new_signal_buy))
        {
            // یک نامزد جدید به انتهای لیست اضافه می‌کنیم
            int total = ArraySize(m_potential_signals);
            ArrayResize(m_potential_signals, total + 1);
            m_potential_signals[total].time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou);
            m_potential_signals[total].is_buy = is_new_signal_buy;
            m_potential_signals[total].grace_candle_count = 0;
            m_potential_signals[total].invalidation_level = 0.0; // مقدار اولیه

            // اگر مهلت از نوع ساختاری باشد، سطح ابطال را محاسبه و ذخیره می‌کنیم
            if (m_settings.grace_mode == GRACE_BY_STRUCTURE)
            {
                m_grace_structure_analyzer.ProcessNewBar(); // تحلیلگر را آپدیت می‌کنیم
                if (is_new_signal_buy)
                {
                    m_potential_signals[total].invalidation_level = m_grace_structure_analyzer.GetLastSwingLow();
                }
                else
                {
                    m_potential_signals[total].invalidation_level = m_grace_structure_analyzer.GetLastSwingHigh();
                }
                Log("[حالت مسابقه‌ای] سیگنال نامزد جدید " + (is_new_signal_buy ? "خرید" : "فروش") + " با سطح ابطال " + DoubleToString(m_potential_signals[total].invalidation_level, _Digits) + " به لیست اضافه شد.");
            }
            else // اگر مهلت از نوع کندلی باشد
            {
                Log("[حالت مسابقه‌ای] سیگنال نامزد جدید " + (is_new_signal_buy ? "خرید" : "فروش") + " به لیست اضافه شد. تعداد کل نامزدها: " + (string)ArraySize(m_potential_signals));
            }

            // رسم مستطیل کراس روی چارت
            if(m_symbol == _Symbol && m_visual_manager != NULL)
                m_visual_manager.DrawTripleCrossRectangle(is_new_signal_buy, m_settings.chikou);
        }

        // اگر لیست نامزدها خالی نباشد
        if (ArraySize(m_potential_signals) > 0)
        {
            // حلقه از آخر به اول برای مدیریت نامزدها
            for (int i = ArraySize(m_potential_signals) - 1; i >= 0; i--)
            {
                bool is_signal_expired = false;
                
                // بررسی انقضا بر اساس مهلت ساختاری یا کندلی
                if (m_settings.grace_mode == GRACE_BY_CANDLES)
                {
                    if (m_potential_signals[i].grace_candle_count >= m_settings.grace_candles)
                    {
                        is_signal_expired = true;
                        Log("زمان نامزد " + (m_potential_signals[i].is_buy ? "خرید" : "فروش") + " به پایان رسید و حذف شد.");
                    }
                }
                else // GRACE_BY_STRUCTURE
                {
                    double current_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
                    if (m_potential_signals[i].invalidation_level > 0 &&
                        ((m_potential_signals[i].is_buy && current_price < m_potential_signals[i].invalidation_level) ||
                         (!m_potential_signals[i].is_buy && current_price > m_potential_signals[i].invalidation_level)))
                    {
                        is_signal_expired = true;
                        Log("سیگنال نامزد به دلیل شکست سطح ابطال ساختاری (" + DoubleToString(m_potential_signals[i].invalidation_level, _Digits) + ") منقضی شد و حذف می‌شود.");
                    }
                }

                if (is_signal_expired)
                {
                    ArrayRemove(m_potential_signals, i, 1);
                    continue; // به نامزد بعدی می‌رویم
                }
            
                // اگر سیگنال تاییدیه نهایی و فیلترها را با هم دریافت کند
                if (CheckFinalConfirmation(m_potential_signals[i].is_buy) && AreAllFiltersPassed(m_potential_signals[i].is_buy))
                {
                    Log("🏆 برنده مسابقه پیدا شد: سیگنال " + (m_potential_signals[i].is_buy ? "خرید" : "فروش"));
                
                    if (m_symbol == _Symbol && m_visual_manager != NULL)
                        m_visual_manager.DrawConfirmationArrow(m_potential_signals[i].is_buy, 1);
                    
                    OpenTrade(m_potential_signals[i].is_buy);
                    
                    // پاکسازی نامزدهای هم‌جهت با برنده
                    bool winner_is_buy = m_potential_signals[i].is_buy;
                    for (int j = ArraySize(m_potential_signals) - 1; j >= 0; j--)
                    {
                        if (m_potential_signals[j].is_buy == winner_is_buy)
                        {
                            ArrayRemove(m_potential_signals, j, 1);
                        }
                    }
                    Log("پاکسازی نامزدهای هم‌جهت با برنده انجام شد.");
                    
                    return; // چون معامله باز شده و نامزدها پاکسازی شدند، از تابع خارج می‌شویم
                }
                else
                {
                    // اگر سیگنال نه منقضی شده و نه تایید شده است
                    // شمارنده کندل‌ها را فقط برای حالت مهلت کندلی افزایش می‌دهیم
                    if (m_settings.grace_mode == GRACE_BY_CANDLES)
                    {
                        m_potential_signals[i].grace_candle_count++;
                    }
                    // ناحیه اسکن روی چارت را آپدیت می‌کنیم
                    if (m_symbol == _Symbol && m_visual_manager != NULL)
                        m_visual_manager.DrawScanningArea(m_potential_signals[i].is_buy, m_settings.chikou, m_potential_signals[i].grace_candle_count);
                }
            }
        }
    }

}

//+------------------------------------------------------------------+
//| منطق فاز ۱: چک کردن کراس سه گانه (بازنویسی کامل و نهایی)         |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckTripleCross(bool& is_buy)
{
    // --- گام اول: آماده‌سازی داده‌ها ---

    // شیفت زمانی که می‌خوایم در گذشته بررسی کنیم (مثلاً ۲۶ کندل قبل)
    int shift = m_settings.chikou;
    
    // اگه به اندازه کافی کندل توی چارت نباشه، از تابع خارج می‌شیم
    if (iBars(m_symbol, m_settings.ichimoku_timeframe) < shift + 2) return false;

    // --- گام دوم: دریافت مقادیر ایچیموکو در گذشته ---

    // دو آرایه برای نگهداری مقادیر تنکان و کیجون در نقطه مرجع و کندل قبل از آن
    double tk_shifted[], ks_shifted[];
    
    // از متاتریدر می‌خوایم که ۲ مقدار آخر تنکان و کیجون رو از نقطه "شیفت" به ما بده
    if(CopyBuffer(m_ichimoku_handle, 0, shift, 2, tk_shifted) < 2 || 
       CopyBuffer(m_ichimoku_handle, 1, shift, 2, ks_shifted) < 2)
    {
       // اگر داده کافی وجود نداشت، ادامه نمی‌دهیم
       return false;
    }
       
    // مقدار تنکان و کیجون در نقطه مرجع (مثلاً کندل ۲۶ قبل)
    double tenkan_at_shift = tk_shifted[0];
    double kijun_at_shift = ks_shifted[0];
    
    // مقدار تنکان و کیجون در کندلِ قبل از نقطه مرجع (مثلاً کندل ۲۷ قبل)
    double tenkan_prev_shift = tk_shifted[1];
    double kijun_prev_shift = ks_shifted[1];

    // --- گام سوم: بررسی شرط اولیه (آیا در گذشته کراس یا تلاقی داشتیم؟) ---

    // آیا کراس صعودی اتفاق افتاده؟ (تنکان از پایین اومده بالای کیجون)
    bool is_cross_up = tenkan_prev_shift < kijun_prev_shift && tenkan_at_shift > kijun_at_shift;
    
    // آیا کراس نزولی اتفاق افتاده؟ (تنکان از بالا اومده پایین کیجون)
    bool is_cross_down = tenkan_prev_shift > kijun_prev_shift && tenkan_at_shift < kijun_at_shift;
    
    // آیا کلاً کراسی داشتیم؟ (یا صعودی یا نزولی، جهتش مهم نیست)
    bool is_tk_cross = is_cross_up || is_cross_down;

    // آیا دو خط خیلی به هم نزدیک بودن (تلاقی)؟
    double tolerance = GetTalaqiTolerance(shift);
    bool is_confluence = (tolerance > 0) ? (MathAbs(tenkan_at_shift - kijun_at_shift) <= tolerance) : false;

    // شرط اصلی اولیه: اگر نه کراسی داشتیم و نه تلاقی، پس سیگنالی در کار نیست و خارج می‌شویم
    if (!is_tk_cross && !is_confluence)
    {
        return false;
    }

    // --- گام چهارم: بررسی شرط نهایی (کراس چیکو اسپن از خطوط گذشته) ---

    // قیمت فعلی که نقش چیکو اسپن را برای گذشته بازی می‌کند (کلوز کندل شماره ۱)
    double chikou_now  = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
    // قیمت کندل قبل از آن (کلوز کندل شماره ۲)
    double chikou_prev = iClose(m_symbol, m_settings.ichimoku_timeframe, 2); 

    // بالاترین سطح بین تنکان و کیجون در نقطه مرجع
    double upper_line = MathMax(tenkan_at_shift, kijun_at_shift);
    // پایین‌ترین سطح بین تنکان و کیجون در نقطه مرجع
    double lower_line = MathMin(tenkan_at_shift, kijun_at_shift);

    // بررسی برای سیگنال خرید:
    // آیا قیمت فعلی (چیکو) از بالای هر دو خط عبور کرده؟
    bool chikou_crosses_up = chikou_now > upper_line && // شرط ۱: قیمت فعلی باید بالای هر دو خط باشد
                             chikou_prev < upper_line;    // شرط ۲: قیمت قبلی باید زیر بالاترین خط بوده باشد تا "کراس" معنی دهد
    
    if (chikou_crosses_up)
    {
        // اگر بله، نوع سیگنال ما خرید است
        is_buy = true;
        // و یک سیگنال معتبر پیدا کرده‌ایم
        return true; 
    }

    // بررسی برای سیگنال فروش:
    // آیا قیمت فعلی (چیکو) از پایین هر دو خط عبور کرده؟
    bool chikou_crosses_down = chikou_now < lower_line && // شرط ۱: قیمت فعلی باید پایین هر دو خط باشد
                               chikou_prev > lower_line;    // شرط ۲: قیمت قبلی باید بالای پایین‌ترین خط بوده باشد تا "کراس" معنی دهد
    
    if (chikou_crosses_down)
    {
        // اگر بله، نوع سیگنال ما فروش است
        is_buy = false;
        // و یک سیگنال معتبر پیدا کرده‌ایم
        return true; 
    }

    // اگر هیچکدام از شرط‌های کراس چیکو برقرار نبود، پس سیگنالی در کار نیست
    return false;
}


//+------------------------------------------------------------------+
//| (نسخه آپگرید شده) مدیر کل تاییدیه نهایی                           |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckFinalConfirmation(bool is_buy)
{
    // بر اساس انتخاب کاربر در تنظیمات، روش تاییدیه را انتخاب کن
    switch(m_settings.entry_confirmation_mode)
    {
        // حالت ۱: استفاده از روش جدید و سریع (تایم فریم پایین)
        case CONFIRM_LOWER_TIMEFRAME:
            return CheckLowerTfConfirmation(is_buy);

        // حالت ۲: استفاده از روش قدیمی و کند (تایم فریم فعلی)
        case CONFIRM_CURRENT_TIMEFRAME:
        {
            // این بلاک کد، همان منطق قدیمی تابع است
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
                if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE) {
                    if (open_at_1 > tenkan_at_1 && open_at_1 > kijun_at_1 && close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                        return true;
                } else {
                    if (close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
                        return true;
                }
            }
            else
            {
                if (tenkan_at_1 >= kijun_at_1) return false;
                if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE) {
                    if (open_at_1 < tenkan_at_1 && open_at_1 < kijun_at_1 && close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                        return true;
                } else {
                    if (close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
                        return true;
                }
            }
            return false;
        }
    }
    return false; // حالت پیش‌فرض
}

//+------------------------------------------------------------------+
//| (نسخه نهایی با منطق انتخاب بهینه - کاملاً سازگار) محاسبه استاپ لاس |
//+------------------------------------------------------------------+


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

//+------------------------------------------------------------------+
//| باز کردن معامله (با مدیریت سرمایه اصلاح شده و دقیق)                |
//+------------------------------------------------------------------+
// کد کامل و نهایی برای جایگزینی تابع OpenTrade

void CStrategyManager::OpenTrade(bool is_buy)
{
    if(CountTotalTrades() >= m_settings.max_total_trades || CountSymbolTrades() >= m_settings.max_trades_per_symbol)
    {
        Log("رسیدن به حد مجاز معاملات. معامله جدید باز نشد.");
        return;
    }

    double entry_price = is_buy ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);

    // --- ✅ بخش هوشمند انتخاب تایم فریم برای استاپ لاس ---
    ENUM_TIMEFRAMES selected_sl_tf;
    if (m_settings.sl_timeframe_source == MTF_ICHIMOKU)
    {
        selected_sl_tf = m_settings.ichimoku_timeframe;
    }
    else // MTF_CONFIRMATION
    {
        selected_sl_tf = m_settings.ltf_timeframe;
    }
    Log("تایم فریم انتخاب شده برای استاپ لاس: " + EnumToString(selected_sl_tf));
    // --- پایان بخش هوشمند ---

    double sl = CalculateStopLoss(is_buy, entry_price, selected_sl_tf); // ✅ پاس دادن تایم فریم

    if(sl == 0)
    {
        Log("خطا در محاسبه استاپ لاس. معامله باز نشد.");
        return;
    }

    // ... بقیه کد تابع OpenTrade بدون تغییر ...
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (m_settings.risk_percent_per_trade / 100.0);
    double loss_for_one_lot = 0;
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
    if(is_buy) { m_trade.Buy(lot_size, m_symbol, 0, sl, tp, comment); }
    else { m_trade.Sell(lot_size, m_symbol, 0, sl, tp, comment); }
    if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE) { Log("معامله " + comment + " با لات " + DoubleToString(lot_size, 2) + " با موفقیت باز شد."); }
    else { Log("خطا در باز کردن معامله " + comment + ": " + (string)m_trade.ResultRetcode() + " - " + m_trade.ResultComment()); }
}




// کد کامل و نهایی برای جایگزینی تمام توابع محاسبه استاپ لاس

double CStrategyManager::CalculateStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe)
{
    if (m_settings.stoploss_type == MODE_SIMPLE)
    {
        double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        return FindBackupStopLoss(is_buy, buffer, timeframe);
    }
    if (m_settings.stoploss_type == MODE_ATR)
    {
        double sl_price = CalculateAtrStopLoss(is_buy, entry_price, timeframe);
        if (sl_price == 0)
        {
            Log("محاسبه ATR SL با خطا مواجه شد. استفاده از روش پشتیبان...");
            double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            return FindBackupStopLoss(is_buy, buffer, timeframe);
        }
        return sl_price;
    }

    Log("شروع فرآیند انتخاب استاپ لاس بهینه...");
    double candidates[];
    int count = 0;
    double sl_candidate = 0;
    double buffer = m_settings.sl_buffer_multiplier * SymbolInfoDouble(m_symbol, SYMBOL_POINT);

    sl_candidate = FindFlatKijun(timeframe);
    if (sl_candidate > 0) { ArrayResize(candidates, count + 1); candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; count++; }

    sl_candidate = FindPivotKijun(is_buy, timeframe);
    if (sl_candidate > 0) { ArrayResize(candidates, count + 1); candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; count++; }

    sl_candidate = FindPivotTenkan(is_buy, timeframe);
    if (sl_candidate > 0) { ArrayResize(candidates, count + 1); candidates[count] = is_buy ? sl_candidate - buffer : sl_candidate + buffer; count++; }

    sl_candidate = FindBackupStopLoss(is_buy, buffer, timeframe);
    if (sl_candidate > 0) { ArrayResize(candidates, count + 1); candidates[count] = sl_candidate; count++; }

    sl_candidate = CalculateAtrStopLoss(is_buy, entry_price, timeframe);
    if (sl_candidate > 0) { ArrayResize(candidates, count + 1); candidates[count] = sl_candidate; count++; }

    if (count == 0) { Log("خطا: هیچ کاندیدای اولیه‌ای برای استاپ لاس پیدا نشد."); return 0.0; }

    double valid_candidates[];
    int valid_count = 0;
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double spread = (double)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * point;
    double min_safe_distance = spread + buffer; 

    for (int i = 0; i < count; i++) {
        double current_sl = candidates[i];
        if ((is_buy && current_sl >= entry_price) || (!is_buy && current_sl <= entry_price)) continue; 
        if (MathAbs(entry_price - current_sl) < min_safe_distance) { current_sl = is_buy ? entry_price - min_safe_distance : entry_price + min_safe_distance; }
        ArrayResize(valid_candidates, valid_count + 1); valid_candidates[valid_count] = current_sl; valid_count++;
    }

    if (valid_count == 0) { Log("خطا: پس از فیلترینگ، هیچ کاندیدای معتبری برای استاپ لاس باقی نماند."); return 0.0; }

    double best_sl_price = 0.0;
    double smallest_distance = DBL_MAX;
    for (int i = 0; i < valid_count; i++) {
        double distance = MathAbs(entry_price - valid_candidates[i]);
        if (distance < smallest_distance) { smallest_distance = distance; best_sl_price = valid_candidates[i]; }
    }

    Log("✅ استاپ لاس بهینه پیدا شد: " + DoubleToString(best_sl_price, _Digits));
    return best_sl_price;
}

double CStrategyManager::FindBackupStopLoss(bool is_buy, double buffer, ENUM_TIMEFRAMES timeframe)
{
    int bars_to_check = m_settings.sl_lookback;
    if (iBars(m_symbol, timeframe) < bars_to_check + 1) return 0;

    for (int i = 1; i <= bars_to_check; i++) {
        bool is_candle_bullish = (iClose(m_symbol, timeframe, i) > iOpen(m_symbol, timeframe, i));
        bool is_candle_bearish = (iClose(m_symbol, timeframe, i) < iOpen(m_symbol, timeframe, i));

        if (is_buy && is_candle_bearish) { return iLow(m_symbol, timeframe, i) - buffer; }
        else if (!is_buy && is_candle_bullish) { return iHigh(m_symbol, timeframe, i) + buffer; }
    }

    Log("هیچ کندل رنگ مخالفی پیدا نشد. از روش سقف/کف مطلق استفاده می‌شود.");
    CopyHigh(m_symbol, timeframe, 1, bars_to_check, m_high_buffer);
    CopyLow(m_symbol, timeframe, 1, bars_to_check, m_low_buffer);
    if(is_buy) { return m_low_buffer[ArrayMinimum(m_low_buffer, 0, bars_to_check)] - buffer; }
    else { return m_high_buffer[ArrayMaximum(m_high_buffer, 0, bars_to_check)] + buffer; }
}

double CStrategyManager::FindFlatKijun(ENUM_TIMEFRAMES timeframe)
{
    int handle = iIchimoku(m_symbol, timeframe, m_settings.tenkan, m_settings.kijun, m_settings.senkou);
    if(handle == INVALID_HANDLE) return 0.0;
    double values[];
    if (CopyBuffer(handle, 1, 1, m_settings.flat_kijun, values) < m_settings.flat_kijun) { IndicatorRelease(handle); return 0.0; }
    IndicatorRelease(handle);
    ArraySetAsSeries(values, true);
    int flat_count = 1;
    for (int i = 1; i < m_settings.flat_kijun; i++) {
        if (values[i] == values[i - 1]) {
            flat_count++;
            if (flat_count >= m_settings.flat_kijun_min_length) return values[i];
        } else { flat_count = 1; }
    }
    return 0.0;
}

double CStrategyManager::FindPivotKijun(bool is_buy, ENUM_TIMEFRAMES timeframe)
{
    int handle = iIchimoku(m_symbol, timeframe, m_settings.tenkan, m_settings.kijun, m_settings.senkou);
    if(handle == INVALID_HANDLE) return 0.0;
    double values[];
    if (CopyBuffer(handle, 1, 1, m_settings.pivot_lookback, values) < m_settings.pivot_lookback) { IndicatorRelease(handle); return 0.0; }
    IndicatorRelease(handle);
    ArraySetAsSeries(values, true);
    for (int i = 1; i < m_settings.pivot_lookback - 1; i++) {
        if (is_buy && values[i] < values[i - 1] && values[i] < values[i + 1]) return values[i];
        if (!is_buy && values[i] > values[i - 1] && values[i] > values[i + 1]) return values[i];
    }
    return 0.0;
}

double CStrategyManager::FindPivotTenkan(bool is_buy, ENUM_TIMEFRAMES timeframe)
{
    int handle = iIchimoku(m_symbol, timeframe, m_settings.tenkan, m_settings.kijun, m_settings.senkou);
    if(handle == INVALID_HANDLE) return 0.0;
    double values[];
    if (CopyBuffer(handle, 0, 1, m_settings.pivot_lookback, values) < m_settings.pivot_lookback) { IndicatorRelease(handle); return 0.0; }
    IndicatorRelease(handle);
    ArraySetAsSeries(values, true);
    for (int i = 1; i < m_settings.pivot_lookback - 1; i++) {
        if (is_buy && values[i] < values[i - 1] && values[i] < values[i + 1]) return values[i];
        if (!is_buy && values[i] > values[i - 1] && values[i] > values[i + 1]) return values[i];
    }
    return 0.0;
}

double CStrategyManager::CalculateAtrStopLoss(bool is_buy, double entry_price, ENUM_TIMEFRAMES timeframe)
{
    if (!m_settings.enable_sl_vol_regime)
    {
        int atr_handle_sl = iATR(m_symbol, timeframe, m_settings.atr_filter); // از پریود فیلتر استفاده میکنیم چون پریود جدا ندارد
        if(atr_handle_sl == INVALID_HANDLE) return 0.0;
        double atr_buffer[];
        if(CopyBuffer(atr_handle_sl, 0, 1, 1, atr_buffer) < 1) { IndicatorRelease(atr_handle_sl); return 0.0; }
        IndicatorRelease(atr_handle_sl);
        double atr_value = atr_buffer[0];
        return is_buy ? entry_price - (atr_value * m_settings.sl_atr_multiplier) : entry_price + (atr_value * m_settings.sl_atr_multiplier);
    }

    int history_size = m_settings.sl_vol_regime_ema + 5;
    double atr_values[], ema_values[];
    int atr_sl_handle = iATR(m_symbol, timeframe, m_settings.sl_vol_regime_atr);
    if (atr_sl_handle == INVALID_HANDLE || CopyBuffer(atr_sl_handle, 0, 0, history_size, atr_values) < history_size)
    {
        if(atr_sl_handle != INVALID_HANDLE) IndicatorRelease(atr_sl_handle);
        return 0.0;
    }
    IndicatorRelease(atr_sl_handle);
    ArraySetAsSeries(atr_values, true); 
    if(SimpleMAOnBuffer(history_size, 0, m_settings.sl_vol_regime_ema, MODE_EMA, atr_values, ema_values) < 1) return 0.0;
    double current_atr = atr_values[1]; 
    double ema_atr = ema_values[1];     
    bool is_high_volatility = (current_atr > ema_atr);
    double final_multiplier = is_high_volatility ? m_settings.sl_high_vol_multiplier : m_settings.sl_low_vol_multiplier;
    return is_buy ? entry_price - (current_atr * final_multiplier) : entry_price + (current_atr * final_multiplier);
}
//+------------------------------------------------------------------+
//| پیدا کردن سطح کیجون سن فلت (صاف)                                  |
//+------------------------------------------------------------------+
double CStrategyManager::FindFlatKijun()
{
    double kijun_values[];
    if (CopyBuffer(m_ichimoku_handle, 1, 1, m_settings.flat_kijun, kijun_values) < m_settings.flat_kijun)
        return 0.0;

    ArraySetAsSeries(kijun_values, true);

    int flat_count = 1;
    for (int i = 1; i < m_settings.flat_kijun; i++)
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

////+------------------------------------------------------------------+
//| (جایگزین شد) مدیر کل گرفتن حد مجاز تلاقی بر اساس حالت انتخابی      |
//+------------------------------------------------------------------+
double CStrategyManager::GetTalaqiTolerance(int reference_shift)
{
    switch(m_settings.talaqi_calculation_mode)
    {
        case TALAQI_MODE_MANUAL:
            return m_settings.talaqi_distance_in_points * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
        
        case TALAQI_MODE_KUMO:
            return CalculateDynamicTolerance(reference_shift); // روش مبتنی بر کومو
        
        case TALAQI_MODE_ATR:
            return CalculateAtrTolerance(reference_shift);     // روش جدید مبتنی بر ATR
            
        default:
            return 0.0;
    }
}


//+------------------------------------------------------------------+
//| (اتوماتیک) محاسبه حد مجاز تلاقی بر اساس ضخامت ابر کومو            |
//|                  (نسخه نهایی و هوشمند)                           |
//+------------------------------------------------------------------+
double CStrategyManager::CalculateDynamicTolerance(int reference_shift)
{
    // اگر ضریب کومو صفر یا منفی باشه، یعنی این روش غیرفعاله
    if(m_settings.talaqi_kumo_factor <= 0) return 0.0;

    // آرایه‌ها برای نگهداری مقادیر سنکو اسپن A و B در گذشته
    double senkou_a_buffer[], senkou_b_buffer[];

    // از متاتریدر می‌خوایم که مقدار سنکو A و B رو در "نقطه X" تاریخی به ما بده
    // بافر 2 = Senkou Span A
    // بافر 3 = Senkou Span B
    if(CopyBuffer(m_ichimoku_handle, 2, reference_shift, 1, senkou_a_buffer) < 1 || 
       CopyBuffer(m_ichimoku_handle, 3, reference_shift, 1, senkou_b_buffer) < 1)
    {
       Log("داده کافی برای محاسبه ضخامت کومو در گذشته وجود ندارد.");
       return 0.0; // اگر داده نبود، مقدار صفر برمی‌گردونیم تا تلاقی چک نشه
    }

    // گام ۱: محاسبه ضخامت کومو در "نقطه X"
    double kumo_thickness = MathAbs(senkou_a_buffer[0] - senkou_b_buffer[0]);

    // اگر ضخامت کومو صفر بود (مثلا در کراس سنکوها)، یه مقدار خیلی کوچیک برگردون
    if(kumo_thickness == 0) return SymbolInfoDouble(m_symbol, SYMBOL_POINT);

    // گام ۲: محاسبه حد مجاز تلاقی بر اساس ضریب ورودی کاربر
    double tolerance = kumo_thickness * m_settings.talaqi_kumo_factor;

    return tolerance;
}


//+------------------------------------------------------------------+
//| (حالت مسابقه‌ای) اضافه کردن سیگنال جدید به لیست نامزدها            |
//+------------------------------------------------------------------+
void CStrategyManager::AddOrUpdatePotentialSignal(bool is_buy)
{
    // وظیفه: این تابع هر سیگنال جدیدی که پیدا می‌شود را به لیست نامزدها اضافه می‌کند
    
    // گام اول: یک نامزد جدید به انتهای لیست اضافه کن
    int total = ArraySize(m_potential_signals);
    ArrayResize(m_potential_signals, total + 1);
    
    // گام دوم: مشخصات نامزد جدید را مقداردهی کن
    m_potential_signals[total].time = iTime(m_symbol, m_settings.ichimoku_timeframe, m_settings.chikou);
    m_potential_signals[total].is_buy = is_buy;
    m_potential_signals[total].grace_candle_count = 0; // شمارنده مهلت از صفر شروع می‌شود
    
    // لاگ کردن افزودن نامزد جدید به مسابقه
    Log("[حالت مسابقه‌ای] سیگنال نامزد جدید " + (is_buy ? "خرید" : "فروش") + " به لیست انتظار مسابقه اضافه شد. تعداد کل نامزدها: " + (string)ArraySize(m_potential_signals));
    
    // یک مستطیل برای نمایش سیگنال اولیه روی چارت رسم کن
    if(m_symbol == _Symbol && m_visual_manager != NULL)
    m_visual_manager.DrawTripleCrossRectangle(is_buy, m_settings.chikou);

}

//+------------------------------------------------------------------+
//| (نسخه نهایی و ضد ضربه) محاسبه حد مجاز تلاقی بر اساس ATR
//+------------------------------------------------------------------+
double CStrategyManager::CalculateAtrTolerance(int reference_shift)
{
    if(m_settings.talaqi_atr_multiplier <= 0) return 0.0;
    
    // ✅✅✅ بادیگARD شماره ۳: بررسی اعتبار هندل ✅✅✅
    if (m_atr_handle == INVALID_HANDLE)
    {
        Log("محاسبه تلورانس ATR ممکن نیست چون هندل آن نامعتبر است. پریود ATR در تنظیمات ورودی را بررسی کنید.");
        return 0.0; // بازگشت امن
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



//==================================================================
//  تابع اصلی "گیت کنترل نهایی" که تمام فیلترها را چک می‌کند (نسخه آپگرید شده)
//==================================================================
// کد کامل و نهایی برای جایگزینی تابع AreAllFiltersPassed

bool CStrategyManager::AreAllFiltersPassed(bool is_buy)
{
    // --- ✅ بخش هوشمند انتخاب تایم فریم برای فیلترها ---
    ENUM_TIMEFRAMES selected_filter_tf;
    if (m_settings.filter_timeframe_source == MTF_ICHIMOKU)
    {
        selected_filter_tf = m_settings.ichimoku_timeframe;
    }
    else // MTF_CONFIRMATION
    {
        selected_filter_tf = m_settings.ltf_timeframe;
    }
    Log("تایم فریم انتخاب شده برای فیلترها: " + EnumToString(selected_filter_tf));
    // --- پایان بخش هوشمند ---

    if (m_settings.enable_kumo_filter)
    {
        if (!CheckKumoFilter(is_buy, selected_filter_tf))
        {
            Log("فیلتر کومو رد شد.");
            return false;
        }
    }

    if (m_settings.enable_atr_filter)
    {
        if (!CheckAtrFilter(selected_filter_tf))
        {
            Log("فیلتر ATR رد شد.");
            return false;
        }
    }
    
    if (m_settings.enable_adx_filter)
    {
        if (!CheckAdxFilter(is_buy, selected_filter_tf))
        {
            Log("فیلتر ADX رد شد.");
            return false;
        }
    }
    
    Log("✅ تمام فیلترهای فعال با موفقیت پاس شدند.");
    return true;
}

//==================================================================
//  تابع کمکی برای بررسی فیلتر ابر کومو
//==================================================================
// کد کامل و نهایی برای جایگزینی توابع فیلتر

bool CStrategyManager::CheckKumoFilter(bool is_buy, ENUM_TIMEFRAMES timeframe)
{
    // از هندل اصلی کلاس استفاده می‌کنیم چون پریودهاش با تنظیمات یکی هست
    double senkou_a[], senkou_b[];
    if(CopyBuffer(m_ichimoku_handle, 2, 0, 1, senkou_a) < 1 || 
       CopyBuffer(m_ichimoku_handle, 3, 0, 1, senkou_b) < 1)
    {
       Log("خطا: داده کافی برای فیلتر کومو موجود نیست.");
       return false;
    }
    
    double high_kumo = MathMax(senkou_a[0], senkou_b[0]);
    double low_kumo = MathMin(senkou_a[0], senkou_b[0]);
    double close_price = iClose(m_symbol, timeframe, 1); // ✅ استفاده از تایم فریم ورودی

    if (is_buy)
    {
        return (close_price > high_kumo);
    }
    else
    {
        return (close_price < low_kumo);
    }
}


bool CStrategyManager::CheckAtrFilter(ENUM_TIMEFRAMES timeframe)
{
    // چون پریود ATR فیلتر ممکن است متفاوت باشد، یک هندل محلی می‌سازیم
    int atr_handle_filter = iATR(m_symbol, timeframe, m_settings.atr_filter);
    if(atr_handle_filter == INVALID_HANDLE) return false;
    
    double atr_value_buffer[];
    if(CopyBuffer(atr_handle_filter, 0, 1, 1, atr_value_buffer) < 1)
    {
       IndicatorRelease(atr_handle_filter);
       return false;
    }
    IndicatorRelease(atr_handle_filter);

    double current_atr = atr_value_buffer[0];
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double min_atr_threshold = m_settings.atr_filter_min_value_pips * point;
    
    if(_Digits == 3 || _Digits == 5)
    {
        min_atr_threshold *= 10;
    }

    return (current_atr >= min_atr_threshold);
}


bool CStrategyManager::CheckAdxFilter(bool is_buy, ENUM_TIMEFRAMES timeframe) 
{  
    int adx_handle_filter = iADX(m_symbol, timeframe, m_settings.adx);
    if(adx_handle_filter == INVALID_HANDLE) return false;

    double adx_buffer[1], di_plus_buffer[1], di_minus_buffer[1];  
    
    if (CopyBuffer(adx_handle_filter, 0, 1, 1, adx_buffer) < 1 || 
        CopyBuffer(adx_handle_filter, 1, 1, 1, di_plus_buffer) < 1 || 
        CopyBuffer(adx_handle_filter, 2, 1, 1, di_minus_buffer) < 1)
    {
        IndicatorRelease(adx_handle_filter);
        return false;
    }
    IndicatorRelease(adx_handle_filter);
    
    if (adx_buffer[0] <= m_settings.adx_threshold) 
    {
        return false;
    }
    
    if (is_buy)
    {
        return (di_plus_buffer[0] > di_minus_buffer[0]);
    }
    else
    {
        return (di_minus_buffer[0] > di_plus_buffer[0]);
    }
}
//+------------------------------------------------------------------+
//| (جدید) تابع اصلی برای مدیریت خروج زودرس
//+------------------------------------------------------------------+
void CStrategyManager::CheckForEarlyExit()
{
    // از آخر به اول روی پوزیشن ها حلقه میزنیم چون ممکن است یکی بسته شود
    for (int i = PositionsTotal() - 1; i >= 0; i--) 
    {
        ulong ticket = PositionGetTicket(i);
        // فقط پوزیشن های مربوط به همین اکسپرت و همین نماد را بررسی میکنیم
        if (PositionGetString(POSITION_SYMBOL) == m_symbol && PositionGetInteger(POSITION_MAGIC) == (long)m_settings.magic_number)
        {
            if (PositionSelectByTicket(ticket))
            {
                bool is_buy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
                // آیا شرایط خروج زودرس فراهم است؟
                if (CheckChikouRsiExit(is_buy)) 
                { 
                    Log("🚨 سیگنال خروج زودرس برای تیکت " + (string)ticket + " صادر شد. بستن معامله...");
                    m_trade.PositionClose(ticket); 
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| (جدید) تابع کمکی برای بررسی منطق خروج چیکو + RSI
//+------------------------------------------------------------------+
bool CStrategyManager::CheckChikouRsiExit(bool is_buy)
{
    // گرفتن داده های لازم از کندل تایید (کندل شماره ۱)
    double chikou_price = iClose(m_symbol, m_settings.ichimoku_timeframe, 1);
    
    double tenkan_buffer[1], kijun_buffer[1], rsi_buffer[1];
    if(CopyBuffer(m_ichimoku_handle, 0, 1, 1, tenkan_buffer) < 1 ||
       CopyBuffer(m_ichimoku_handle, 1, 1, 1, kijun_buffer) < 1 ||
       CopyBuffer(m_rsi_exit_handle, 0, 1, 1, rsi_buffer) < 1)
    {
        return false; // اگر داده نباشد، خروجی در کار نیست
    }
    
    double tenkan = tenkan_buffer[0];
    double kijun = kijun_buffer[0];
    double rsi = rsi_buffer[0];
    
    bool chikou_cross_confirms_exit = false;
    bool rsi_confirms_exit = false;

    if (is_buy) // برای یک معامله خرید، به دنبال سیگنال خروج نزولی هستیم
    {
        // شرط ۱: آیا قیمت (چیکو) به زیر خطوط تنکان و کیجون کراس کرده؟
        chikou_cross_confirms_exit = (chikou_price < MathMin(tenkan, kijun));
        // شرط ۲: آیا RSI هم از دست رفتن مومنتوم صعودی را تایید میکند؟
        rsi_confirms_exit = (rsi < m_settings.early_exit_rsi_oversold);
    }
    else // برای یک معامله فروش، به دنبال سیگنال خروج صعودی هستیم
    {
        // شرط ۱: آیا قیمت (چیکو) به بالای خطوط تنکان و کیجون کراس کرده؟
        chikou_cross_confirms_exit = (chikou_price > MathMax(tenkan, kijun));
        // شرط ۲: آیا RSI هم از دست رفتن مومنتوم نزولی را تایید میکند؟
        rsi_confirms_exit = (rsi > m_settings.early_exit_rsi_overbought);
    }
    
    // اگر هر دو شرط برقرار باشند، سیگنال خروج صادر میشود
    return (chikou_cross_confirms_exit && rsi_confirms_exit);
}


//+------------------------------------------------------------------+
//| (جدید) بررسی تاییدیه نهایی با شکست ساختار در تایم فریم پایین      |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckLowerTfConfirmation(bool is_buy)
{
    // کتابخانه تحلیل ساختار را روی کندل جدید اجرا کن
    SMssSignal mss_signal = m_ltf_analyzer.ProcessNewBar();

    // اگر هیچ سیگنالی در تایم فریم پایین پیدا نشد، تاییدیه رد می‌شود
    if(mss_signal.type == MSS_NONE)
    {
        return false;
    }

    // اگر سیگنال اصلی ما "خرید" است...
    if (is_buy)
    {
        // ...ما دنبال یک شکست صعودی در تایم فریم پایین هستیم
        if (mss_signal.type == MSS_BREAK_HIGH || mss_signal.type == MSS_SHIFT_UP)
        {
            Log("✅ تاییدیه تایم فریم پایین برای خرید دریافت شد (CHoCH).");
            return true; // تایید شد!
        }
    }
    else // اگر سیگنال اصلی ما "فروش" است...
    {
        // ...ما دنبال یک شکست نزولی در تایم فریم پایین هستیم
        if (mss_signal.type == MSS_BREAK_LOW || mss_signal.type == MSS_SHIFT_DOWN)
        {
            Log("✅ تاییدیه تایم فریم پایین برای فروش دریافت شد (CHoCH).");
            return true; // تایید شد!
        }
    }

    // اگر سیگنال تایم فریم پایین در جهت سیگنال اصلی ما نبود، تاییدیه رد می‌شود
    return false;
}

// این کد را به انتهای فایل IchimokuLogic.mqh اضافه کن

//+------------------------------------------------------------------+
//| (جدید) تابع واکسن: آیا داده‌های تمام تایم‌فریم‌ها آماده است؟       |
//+------------------------------------------------------------------+
bool CStrategyManager::IsDataReady()
{
    // لیست تمام تایم فریم هایی که اکسپرت استفاده میکنه
    ENUM_TIMEFRAMES timeframes_to_check[3];
    timeframes_to_check[0] = m_settings.ichimoku_timeframe; // تایم فریم اصلی ایچیموکو
    timeframes_to_check[1] = m_settings.ltf_timeframe;      // تایم فریم تاییدیه ساختار
    timeframes_to_check[2] = PERIOD_CURRENT;                 // تایم فریم چارت فعلی

    // حداقل تعداد کندل مورد نیاز برای تحلیل مطمئن
    int required_bars = 200; 

    for(int i = 0; i < 3; i++)
    {
        ENUM_TIMEFRAMES tf = timeframes_to_check[i];
        
        // اگر تعداد کندل های موجود کمتر از حد نیاز بود یا تاریخچه کامل نبود
        if(iBars(m_symbol, tf) < required_bars || iTime(m_symbol, tf, 1) == 0)
        {
            // Log("داده برای تایم فریم " + EnumToString(tf) + " هنوز آماده نیست.");
            return false; // یعنی داده آماده نیست، پس از تابع خارج شو
        }
    }
    
    // اگر حلقه تمام شد و مشکلی نبود، یعنی همه چی آماده است
    return true; 
}
