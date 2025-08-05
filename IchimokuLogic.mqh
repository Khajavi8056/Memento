/+------------------------------------------------------------------+
//|                                     IchimokuLogic.mqh            |
//|                          © 2025, hipoalgoritm              |
//+------------------------------------------------------------------+
#property copyright "© 2025,hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "1.05" 
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
    double              m_high_buffer[]; // 
    double              m_low_buffer[];  // 
    
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
    string GetSymbol() const { return m_symbol; }
    void UpdateMyDashboard() { if (m_visual_manager != NULL) m_visual_manager.UpdateDashboard(); }
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
    // اگر نیاز به پاکسازی چیزی در آینده بود، اینجا قرار میگیرد
    if (m_visual_manager != NULL)
    {
        delete m_visual_manager;
        m_visual_manager = NULL;
    }
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه                                                   |
//+------------------------------------------------------------------+
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
    ArraySetAsSeries(m_high_buffer, true);
    ArraySetAsSeries(m_low_buffer, true); 
    if (!m_visual_manager.Init())
    {
        Log("خطا در مقداردهی اولیه VisualManager.");
        return false;
    }

    // ✅✅✅ بخش اصلاح شده ✅✅✅
    // فقط نمونه‌ای که نمادش با نماد چارت یکی است، داشبورد را می‌سازد
    if(m_symbol == _Symbol)
    {
         Print("--- DEBUG 1: Master instance found for '", m_symbol, "'. Calling InitDashboard...");
        m_visual_manager.InitDashboard();
    }
    
    Log("با موفقیت مقداردهی اولیه شد.");
    return true;
}

//+------------------------------------------------------------------+
//| تابع اصلی پردازش کندل جدید                                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| تابع اصلی پردازش کندل جدید (نسخه هوشمند شده برای سیگنال مخالف)   |
//+------------------------------------------------------------------+
void CStrategyManager::ProcessNewBar()
{
    // --- گام ۱: چک کردن اینکه آیا کندل جدیدی تشکیل شده است یا نه ---
    datetime current_bar_time = iTime(m_symbol, _Period, 0);
    if (current_bar_time == m_last_bar_time)
    {
        // اگر زمان کندل فعلی با زمان آخرین کندل بررسی شده یکی بود، یعنی کندل جدیدی نداریم. پس از تابع خارج شو.
        return;
    }
    // اگر کندل جدید بود، زمان آن را در حافظه ذخیره کن تا در بررسی بعدی استفاده شود.
    m_last_bar_time = current_bar_time;

    // --- گام ۲: آپدیت کردن داشبورد (فقط توسط نمونه اصلی اکسپرت) ---
        // --- گام ۰: پاکسازی اشیاء گرافیکی قدیمی ---
    if(m_visual_manager != NULL) m_visual_manager.CleanupOldObjects(200);


    // --- گام ۳: بررسی وجود سیگنال جدید در هر کندل ---
    // این بخش همیشه اجرا می‌شود تا هیچ سیگنال جدیدی را از دست ندهیم.
    
    bool is_new_signal_buy = false; // متغیری برای نگهداری جهت سیگنال جدید
    
    // آیا تابع CheckTripleCross یک سیگنال جدید (چه خرید چه فروش) پیدا کرده است؟
    if (CheckTripleCross(is_new_signal_buy))
    {
        // اگر سیگنال جدیدی پیدا شد، حالا باید تصمیم بگیریم با آن چه کنیم.
        
        // آیا از قبل منتظر تایید یک سیگنال دیگر بودیم؟ (یعنی m_is_waiting=true بود؟)
        if (m_is_waiting)
        {
            // اگر بله، آیا سیگنال جدید پیدا شده، مخالف سیگنال قبلی است؟
            // (مثلاً منتظر تایید "فروش" بودیم ولی الان سیگنال "خرید" آمده)
            if (is_new_signal_buy != m_signal.is_buy)
            {
                // اگر سیگنال‌ها مخالف هم بودند، سیگنال قدیمی دیگر ارزشی ندارد.
                Log("سیگنال جدید و مخالف پیدا شد! سیگنال قبلی " + (m_signal.is_buy ? "خرید" : "فروش") + " کنسل شد.");
                
                // وضعیت انتظار را ریست کن تا برای سیگنال جدید آماده شویم.
                m_is_waiting = false; 
            }
        }
        
        // اگر در حالت انتظار نبودیم (چه از اول، چه به خاطر اینکه سیگنال قبلی همین الان کنسل شد)...
        if (!m_is_waiting)
        {
            // وضعیت را به "در حال انتظار" تغییر بده
            m_is_waiting = true;
            
            // مشخصات سیگنال جدید را در ساختار m_signal ذخیره کن
            m_signal.time = iTime(m_symbol, _Period, m_settings.chikou_period);
            m_signal.is_buy = is_new_signal_buy;
            m_signal.grace_candle_count = 0; // شمارنده کندل‌های انتظار را صفر کن
            
            Log("سیگنال اولیه " + (m_signal.is_buy ? "خرید" : "فروش") + " در کندل " + TimeToString(m_signal.time) + " پیدا شد.");
            
            // یک مستطیل روی چارت برای نمایش محل سیگنال اولیه رسم کن
            m_visual_manager.DrawTripleCrossRectangle(m_signal.is_buy, m_settings.chikou_period);
        }
    }
    
    // --- گام ۴: مدیریت وضعیت انتظار (اگر در حال انتظار برای تایید هستیم) ---
    if (m_is_waiting)
    {
        // ناحیه اسکن و انتظار را روی چارت رسم کن تا کاربر بداند اکسپرت منتظر است.
        m_visual_manager.DrawScanningArea(m_signal.is_buy, m_settings.chikou_period, m_signal.grace_candle_count);
        
        // آیا تعداد کندل‌های انتظار از حد مجاز (grace_period) بیشتر شده است؟
        if (m_signal.grace_candle_count >= m_settings.grace_period_candles)
        {
            // اگر بله، یعنی زمان تایید به پایان رسیده و سیگنال منقضی شده است.
            m_is_waiting = false; // از حالت انتظار خارج شو.
            
            Log("زمان تأیید سیگنال " + (m_signal.is_buy ? "خرید" : "فروش") + " به پایان رسید و سیگنال رد شد.");
        }
        // اگر زمان تمام نشده، آیا تاییدیه نهایی صادر شده است؟
        else if (CheckFinalConfirmation(m_signal.is_buy))
        {
            // اگر بله، سیگنال ما تایید نهایی شده است!
            m_is_waiting = false; // از حالت انتظار خارج شو.
            m_visual_manager.DrawConfirmationArrow(m_signal.is_buy, 1); // یک فلش تایید روی چارت رسم کن.
            Log("سیگنال " + (m_signal.is_buy ? "خرید" : "فروش") + " تأیید نهایی شد. در حال باز کردن معامله.");
            OpenTrade(m_signal.is_buy); // دستور باز کردن معامله را صادر کن.
        }
        else
        {
            // اگر نه زمان تمام شده و نه تاییدیه آمده، یک واحد به شمارنده کندل‌های انتظار اضافه کن و منتظر کندل بعدی بمان.
            m_signal.grace_candle_count++;
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
    int shift = m_settings.chikou_period;
    
    // اگه به اندازه کافی کندل توی چارت نباشه، از تابع خارج می‌شیم
    if (iBars(m_symbol, _Period) < shift + 2) return false;

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
    double chikou_now  = iClose(m_symbol, _Period, 1);
    // قیمت کندل قبل از آن (کلوز کندل شماره ۲)
    double chikou_prev = iClose(m_symbol, _Period, 2); 

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
//| منطق فاز ۲: چک کردن تأیید نهایی (بازنویسی کامل و نهایی)          |
//+------------------------------------------------------------------+
bool CStrategyManager::CheckFinalConfirmation(bool is_buy)
{
    // --- گام اول: آماده‌سازی داده‌ها ---

    // اگه کمتر از ۲ کندل در چارت باشه، نمی‌تونیم بررسی کنیم
    if (iBars(m_symbol, _Period) < 2) return false;

    // مقادیر ایچیموکو و کندل رو برای "کندل تاییدیه" (کندل شماره ۱) دریافت می‌کنیم
    CopyBuffer(m_ichimoku_handle, 0, 1, 1, m_tenkan_buffer);
    CopyBuffer(m_ichimoku_handle, 1, 1, 1, m_kijun_buffer);
    
    double tenkan_at_1 = m_tenkan_buffer[0];
    double kijun_at_1 = m_kijun_buffer[0];
    double open_at_1 = iOpen(m_symbol, _Period, 1);
    double close_at_1 = iClose(m_symbol, _Period, 1);
    
    // --- گام دوم: بررسی منطق برای سیگنال خرید ---
    if (is_buy)
    {
        // شرط اولیه خرید: تنکان باید بالای کیجون باشه. اگه نباشه، سیگنال خرید اعتبار نداره
        if (tenkan_at_1 <= kijun_at_1) return false;
        
        // حالا بر اساس تنظیمات ورودی، موقعیت کندل رو چک می‌کنیم
        if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE)
        {
            // در این حالت، برای تایید خرید، باید هم قیمت باز شدن و هم بسته شدن کندل، بالای هر دو خط باشه
            // استفاده از && (وَ) یعنی تمام این ۴ شرط باید همزمان برقرار باشن
            if (open_at_1 > tenkan_at_1 && open_at_1 > kijun_at_1 && 
                close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
            {
                return true; // تایید شد! سیگنال خرید معتبر است
            }
        }
        else // این حالت یعنی MODE_CLOSE_ONLY
        {
            // در این حالت، فقط کافیه قیمت بسته شدن کندل، بالای هر دو خط باشه
            if (close_at_1 > tenkan_at_1 && close_at_1 > kijun_at_1)
            {
                return true; // تایید شد!
            }
        }
    }
    // --- گام سوم: بررسی منطق برای سیگنال فروش ---
    else // این بخش زمانی اجرا میشه که is_buy برابر با false باشه (یعنی سیگنال فروش داریم)
    {
        // شرط اولیه فروش: تنکان باید پایین کیجون باشه. اگه نباشه، سیگنال فروش اعتبار نداره
        if (tenkan_at_1 >= kijun_at_1) return false;
        
        // حالا بر اساس تنظیمات ورودی، موقعیت کندل رو چک می‌کنیم
        if (m_settings.confirmation_type == MODE_OPEN_AND_CLOSE)
        {
            // برای تایید فروش، باید هم قیمت باز شدن و هم بسته شدن کندل، پایین هر دو خط باشه
            if (open_at_1 < tenkan_at_1 && open_at_1 < kijun_at_1 && 
                close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
            {
                return true; // تایید شد! سیگنال فروش معتبر است
            }
        }
        else // این حالت یعنی MODE_CLOSE_ONLY
        {
            // در این حالت، فقط کافیه قیمت بسته شدن کندل، پایین هر دو خط باشه
            if (close_at_1 < tenkan_at_1 && close_at_1 < kijun_at_1)
            {
                return true; // تایید شد!
            }
        }
    }
    
    // اگر کد به اینجا برسه، یعنی هیچکدام از شرط‌های تایید برقرار نبوده
    return false;
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

//---+//+------------------------------------------------------------------+
//| تابع استاپ لاس پشتیبان (بازنویسی کامل بر اساس منطق رنگ مخالف)   |
//+------------------------------------------------------------------+
double CStrategyManager::FindBackupStopLoss(bool is_buy, double buffer)
{
    // تعداد کندلی که می‌خواهیم در گذشته برای پیدا کردن استاپ لاس جستجو کنیم.
    int bars_to_check = m_settings.sl_lookback_period;
    
    // اگر تعداد کندل‌های موجود در چارت کافی نیست، از تابع خارج می‌شویم.
    if (iBars(m_symbol, _Period) < bars_to_check + 1) return 0;
    
    // یک حلقه 'for' می‌سازیم که از کندل شماره ۱ (کندل قبلی) شروع به حرکت به عقب می‌کند.
    for (int i = 1; i <= bars_to_check; i++)
    {
        // رنگ کندلی که در حال بررسی آن هستیم را مشخص می‌کنیم.
        bool is_candle_bullish = (iClose(m_symbol, _Period, i) > iOpen(m_symbol, _Period, i));
        bool is_candle_bearish = (iClose(m_symbol, _Period, i) < iOpen(m_symbol, _Period, i));

        // اگر معامله ما از نوع "خرید" (Buy) باشد...
        if (is_buy)
        {
            // ...پس ما به دنبال اولین کندل با رنگ مخالف، یعنی کندل "نزولی" (Bearish) هستیم.
            if (is_candle_bearish)
            {
                // به محض پیدا کردن اولین کندل نزولی، استاپ لاس را چند پوینت زیر کفِ (Low) همان کندل قرار می‌دهیم.
                double sl_price = iLow(m_symbol, _Period, i) - buffer;
                Log("استاپ لاس ساده: اولین کندل نزولی در شیفت " + (string)i + " پیدا شد.");
                
                // قیمت محاسبه شده را برمی‌گردانیم و کار تابع تمام می‌شود.
                return sl_price;
            }
        }
        // اگر معامله ما از نوع "فروش" (Sell) باشد...
        else // is_sell
        {
            // ...پس ما به دنبال اولین کندل با رنگ مخالف، یعنی کندل "صعودی" (Bullish) هستیم.
            if (is_candle_bullish)
            {
                // به محض پیدا کردن اولین کندل صعودی، استاپ لاس را چند پوینت بالای سقفِ (High) همان کندل قرار می‌دهیم.
                double sl_price = iHigh(m_symbol, _Period, i) + buffer;
                Log("استاپ لاس ساده: اولین کندل صعودی در شیفت " + (string)i + " پیدا شد.");
                
                // قیمت محاسبه شده را برمی‌گردانیم و کار تابع تمام می‌شود.
                return sl_price;
            }
        }
    }
    
    // --- بخش پشتیبانِ پشتیبان ---
    // اگر حلقه 'for' تمام شود و کد به اینجا برسد، یعنی در کل بازه مورد بررسی، هیچ کندل رنگ مخالفی پیدا نشده است.
    // (مثلاً در یک روند خیلی قوی که همه کندل‌ها یک رنگ هستند)
    // در این حالت اضطراری، برای اینکه بدون استاپ لاس نمانیم، از روش قدیمی (پیدا کردن بالاترین/پایین‌ترین قیمت) استفاده می‌کنیم.
    Log("هیچ کندل رنگ مخالفی برای استاپ لاس ساده پیدا نشد. از روش سقف/کف مطلق استفاده می‌شود.");
    
    // داده‌های سقف و کف کندل‌ها را در آرایه‌ها کپی می‌کنیم.
    CopyHigh(m_symbol, _Period, 1, bars_to_check, m_high_buffer);
    CopyLow(m_symbol, _Period, 1, bars_to_check, m_low_buffer);

    if(is_buy)
    {
       // برای خرید، ایندکس پایین‌ترین کندل را پیدا کرده و قیمت Low آن را برمی‌گردانیم.
       int min_index = ArrayMinimum(m_low_buffer, 0, bars_to_check);
       return m_low_buffer[min_index] - buffer;
    }
    else
    {
       // برای فروش، ایندکس بالاترین کندل را پیدا کرده و قیمت High آن را برمی‌گردانیم.
       int max_index = ArrayMaximum(m_high_buffer, 0, bars_to_check);
       return m_high_buffer[max_index] + buffer;
    }
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

//+------------------------------------------------------------------+
//| باز کردن معامله (با مدیریت سرمایه اصلاح شده و دقیق)                |
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
    
    // ✅✅✅ بخش کلیدی و اصلاح شده ✅✅✅

    // --- گام ۱: محاسبه ریسک به ازای هر معامله به پول حساب ---
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = balance * (m_settings.risk_percent_per_trade / 100.0);

    // --- گام ۲: محاسبه میزان ضرر برای ۱ لات معامله با این استاپ لاس ---
    double loss_for_one_lot = 0;
    string base_currency = AccountInfoString(ACCOUNT_CURRENCY);
    // از تابع تخصصی متاتریدر برای این کار استفاده می‌کنیم
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

    // --- گام ۳: محاسبه حجم دقیق لات بر اساس ریسک و میزان ضرر ۱ لات ---
    double lot_size = NormalizeDouble(risk_amount / loss_for_one_lot, 2);

    // --- گام ۴: نرمال‌سازی و گرد کردن لات بر اساس محدودیت‌های بروکر ---
    double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    // اطمینان از اینکه لات در محدوده مجاز است
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
    
    // گرد کردن لات بر اساس گام مجاز بروکر
    lot_size = MathRound(lot_size / lot_step) * lot_step;

    if(lot_size < min_lot)
    {
        Log("حجم محاسبه شده (" + DoubleToString(lot_size,2) + ") کمتر از حداقل لات مجاز (" + DoubleToString(min_lot,2) + ") است. معامله باز نشد.");
        return;
    }

    // --- گام ۵: محاسبه حد سود و ارسال معامله ---
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
    
    // لاگ کردن نتیجه
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








