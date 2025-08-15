//+------------------------------------------------------------------+
//|                                       MitigationOrderBlock.mqh   |
//|                    © 2025, Mohammad & Gemini (از پروژه قدیمی)     |
//|        کتابخانه مستقل برای تشخیص اردربلاک و سیگنال‌های میتیگیشن    |
//+------------------------------------------------------------------+
#property copyright "© 2025, HipoAlgorithm"
#property link      "https://www.mql5.com"
#property version   "2.0" // نسخه نهایی با نام‌گذاری دقیق و کامنت کامل

/*
========================================================================================================
|                                                                                                      |
|                     --- راهنمای استفاده سریع از کتابخانه MitigationOrderBlock ---                      |
|                                                                                                      |
|   هدف: این کتابخانه به صورت یک "جعبه سیاه" (Black Box) عمل کرده و وظیفه آن پیدا کردن                  |
|   اردربلاک‌های میتیگیشن (ناشی از شکست انفجاری یک ناحیه رنج) و صدور سیگنال معاملاتی                    |
|   در زمان برگشت قیمت به آن اردربلاک است.                                                              |
|                                                                                                      |
|   مراحل استفاده:                                                                                       |
|                                                                                                      |
|   ۱. افزودن به پروژه: #include "MitigationOrderBlock.mqh"                                             |
|   ۲. ساخت یک نمونه از کلاس: CMitigationOrderBlock mob_analyzer;                                       |
|   ۳. مقداردهی اولیه در OnInit: mob_analyzer.Init(_Symbol, _Period);                                   |
|   ۴. فراخوانی در OnTimer/OnTick: SMitigationSignal signal = mob_analyzer.ProcessNewBar();              |
|   ۵. بررسی خروجی: if(signal.type != MITIGATION_SIGNAL_NONE) { ... }                                  |
|                                                                                                      |
========================================================================================================
*/

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//|   بخش تنظیمات ورودی (Inputs) - کاملا مستقل و Plug & Play         |
//+------------------------------------------------------------------+
input group "---=== 🏛️ Mitigation Order Block Library Settings 🏛️ ===---"; // گروه اصلی برای تمام تنظیمات کتابخانه
input group "پارامترهای تشخیص اردربلاک";                                             // زیرگروه برای پارامترهای اصلی
input int    Inp_MOB_ConsolidationBars      = 7;                                 // تعداد کندل برای تشخیص ناحیه رنج
input double Inp_MOB_MaxConsolidationSpread = 50;                                // حداکثر گستردگی ناحیه رنج (به پوینت)
input int    Inp_MOB_BarsToWaitAfterBreakout= 3;                                 // تعداد کندل انتظار پس از شکست برای تایید قدرت
input double Inp_MOB_ImpulseMultiplier      = 1.0;                               // ضریب قدرت حرکت انفجاری
input group "تنظیمات معاملاتی (پیشنهادی)";                                         // زیرگروه برای تنظیمات معامله
input double Inp_MOB_StopLossDistance_Points = 1500;                             // فاصله حد ضرر از نقطه ورود (به پوینت)
input double Inp_MOB_TakeProfit_Points     = 1500;                             // فاصله حد سود از نقطه ورود (به پوینت)
input group "تنظیمات نمایشی و گرافیکی";                                            // زیرگروه برای تنظیمات گرافیکی
input color  Inp_MOB_BullishColor          = clrGreen;                         // رنگ اردربلاک صعودی (که منجر به سیگنال فروش می‌شود)
input color  Inp_MOB_BearishColor          = clrRed;                           // رنگ اردربلاک نزولی (که منجر به سیگنال خرید می‌شود)
input color  Inp_MOB_MitigatedColor        = clrGray;                          // رنگ اردربلاک استفاده شده
input color  Inp_MOB_LabelTextColor        = clrBlack;                         // رنگ متن روی اردربلاک
input group "";                                                                // پایان گروه بندی

// --- انواع شمارشی و ساختارهای داده ---
enum EMitigationBlockDirection { MB_BULLISH, MB_BEARISH };                         // جهت اردربلاک (صعودی یا نزولی)
enum EMitigationSignalType { MITIGATION_SIGNAL_NONE, MITIGATION_SIGNAL_BUY, MITIGATION_SIGNAL_SELL }; // نوع سیگنال خروجی

// ساختار برای نگهداری اطلاعات کامل یک اردربلاک
struct SMitigationBlockInfo
{
    string      name;                   // نام منحصر به فرد آبجکت مستطیل
    string      label_name;             // نام منحصر به فرد آبجکت متن
    EMitigationBlockDirection direction;// جهت اردربلاک
    double      top_price;              // قیمت بالای اردربلاک
    double      bottom_price;           // قیمت پایین اردربلاک
    datetime    start_time;             // زمان شروع اردربلاک
    datetime    end_time;               // زمان انقضای اردربلاک (برای حذف از چارت)
    bool        is_mitigated;           // آیا این اردربلاک استفاده شده است؟
};

// ساختار برای برگرداندن سیگنال معاملاتی به اکسپرت اصلی
struct SMitigationSignal
{
    EMitigationSignalType type;        // نوع سیگنال (خرید، فروش یا هیچکدام)
    double      entry_price;           // قیمت پیشنهادی برای ورود
    double      sl_price;              // قیمت پیشنهادی برای حد ضرر
    double      tp_price;              // قیمت پیشنهادی برای حد سود
    
    // سازنده پیش‌فرض برای ریست کردن مقادیر
    SMitigationSignal() { type = MITIGATION_SIGNAL_NONE; entry_price=0; sl_price=0; tp_price=0; }
};

//+------------------------------------------------------------------+
//|   کلاس اصلی کتابخانه: جعبه سیاه تشخیص اردربلاک و میتیگیشن          |
//+------------------------------------------------------------------+
class CMitigationOrderBlock
{
private:
    // --- تنظیمات داخلی که از ورودی‌ها خوانده می‌شوند ---
    string   m_symbol;                                // نماد معاملاتی
    ENUM_TIMEFRAMES m_period;                           // تایم فریم تحلیل
    long     m_chart_id;                                // شناسه چارت برای رسم اشیاء
    string   m_obj_prefix;                              // پیشوند برای نام‌گذاری اشیاء گرافیکی
    int      m_consolidation_bars;                      // تعداد کندل برای تشخیص رنج
    double   m_max_consolidation_spread_points;         // حداکثر گستردگی رنج
    int      m_bars_to_wait;                            // تعداد کندل انتظار بعد از شکست
    double   m_impulse_multiplier;                      // ضریب قدرت حرکت
    double   m_stoploss_points;                         // فاصله حد ضرر
    double   m_takeprofit_points;                       // فاصله حد سود
    color    m_bullish_color, m_bearish_color, m_mitigated_color, m_label_color; // رنگ‌های گرافیکی

    // --- متغیرهای وضعیت داخلی برای دنبال کردن فرآیند ---
    datetime m_last_bar_time;                           // زمان آخرین کندل پردازش شده برای جلوگیری از اجرای تکراری
    double   m_range_high;                              // سقف ناحیه رنج شناسایی شده
    double   m_range_low;                               // کف ناحیه رنج شناسایی شده
    bool     m_is_breakout_detected;                    // آیا شکستی از ناحیه رنج اتفاق افتاده است؟
    double   m_last_impulse_high;                       // سقف ناحیه رنج در زمان شکست (برای ایجاد اردربلاک)
    double   m_last_impulse_low;                        // کف ناحیه رنج در زمان شکست (برای ایجاد اردربلاک)
    datetime m_breakout_timestamp;                      // زمان دقیق وقوع شکست
    
    SMitigationBlockInfo m_order_blocks[];              // آرایه برای نگهداری تمام اردربلاک‌های فعال روی چارت

    // --- توابع کمکی برای دسترسی ساده به داده‌های قیمت ---
    double   high(int i) { return iHigh(m_symbol, m_period, i); }
    double   low(int i) { return iLow(m_symbol, m_period, i); }
    double   close(int i) { return iClose(m_symbol, m_period, i); }
    datetime time(int i) { return iTime(m_symbol, m_period, i); }
    
    // --- توابع داخلی برای مدیریت گرافیک ---
    void     drawOrderBlock(SMitigationBlockInfo &ob);
    void     updateOrderBlockDrawing(SMitigationBlockInfo &ob);
    
public:
    // --- توابع عمومی (رابط کاربری کتابخانه) ---
    void Init(string symbol, ENUM_TIMEFRAMES period); // تابع راه‌اندازی
    SMitigationSignal ProcessNewBar();                // تابع اصلی پردازش که در هر کندل جدید فراخوانی می‌شود
};

//+------------------------------------------------------------------+
//| تابع راه‌اندازی: تنظیمات اولیه کلاس را مقداردهی می‌کند.            |
//+------------------------------------------------------------------+
void CMitigationOrderBlock::Init(string symbol, ENUM_TIMEFRAMES period)
{
    m_symbol = symbol;                                       // نماد معاملاتی را در متغیر داخلی کلاس ذخیره کن
    m_period = period;                                       // تایم فریم تحلیل را در متغیر داخلی کلاس ذخیره کن
    m_chart_id = ChartID();                                  // شناسه چارت فعلی را برای عملیات گرافیکی بگیر
    
    // خواندن تمام تنظیمات از متغیرهای ورودی (Inputs) که در بالای فایل تعریف شده‌اند
    m_consolidation_bars = Inp_MOB_ConsolidationBars;
    m_max_consolidation_spread_points = Inp_MOB_MaxConsolidationSpread;
    m_bars_to_wait = Inp_MOB_BarsToWaitAfterBreakout;
    m_impulse_multiplier = Inp_MOB_ImpulseMultiplier;
    m_stoploss_points = Inp_MOB_StopLossDistance_Points;
    m_takeprofit_points = Inp_MOB_TakeProfit_Points;
    m_bullish_color = Inp_MOB_BullishColor;
    m_bearish_color = Inp_MOB_BearishColor;
    m_mitigated_color = Inp_MOB_MitigatedColor;
    m_label_color = Inp_MOB_LabelTextColor;

    // ایجاد یک پیشوند منحصر به فرد برای تمام اشیاء گرافیکی این کتابخانه
    m_obj_prefix = "MOB_LIB_" + m_symbol + "_" + EnumToString(m_period) + "_";
    
    // ریست کردن تمام متغیرهای وضعیت داخلی برای شروع کار
    m_last_bar_time = 0;
    m_range_high = 0;
    m_range_low = 0;
    m_is_breakout_detected = false;
    m_breakout_timestamp = 0;
}

//+------------------------------------------------------------------+
//| تابع اصلی پردازش: این تابع باید در هر کندل جدید فراخوانی شود.    |
//+------------------------------------------------------------------+
SMitigationSignal CMitigationOrderBlock::ProcessNewBar()
{
    SMitigationSignal signal_result;                             // یک ساختار خالی برای سیگنال خروجی بساز
    datetime current_bar_time = time(0);                         // زمان کندل فعلی را بگیر
    if (current_bar_time == m_last_bar_time) return signal_result; // اگر کندل جدید نیست، از تابع خارج شو
    m_last_bar_time = current_bar_time;                          // زمان کندل جدید را ذخیره کن

    // --- فاز ۱: تشخیص ناحیه رنج (Consolidation) ---
    // این بخش فقط زمانی اجرا می‌شود که منتظر یک شکست نباشیم و ناحیه رنجی از قبل مشخص نشده باشد
    if (!m_is_breakout_detected && m_range_high == 0)
    {
        bool is_consolidated = true; // فرض اولیه این است که بازار رنج است
        // حلقه برای بررسی کندل‌ها در بازه تعریف شده
        for (int i = 1; i < m_consolidation_bars; i++) {
            // اگر فاصله سقف دو کندل متوالی زیاد باشد، بازار رنج نیست
            if (MathAbs(high(i) - high(i + 1)) > m_max_consolidation_spread_points * _Point) {
                is_consolidated = false; break; // از حلقه خارج شو
            }
            // اگر فاصله کف دو کندل متوالی زیاد باشد، بازار رنج نیست
            if (MathAbs(low(i) - low(i + 1)) > m_max_consolidation_spread_points * _Point) {
                is_consolidated = false; break; // از حلقه خارج شو
            }
        }
        // اگر پس از بررسی تمام کندل‌ها، بازار همچنان رنج بود
        if (is_consolidated) {
            // بالاترین سقف و پایین‌ترین کف این ناحیه را پیدا و ذخیره کن
            m_range_high = high(iBarShift(m_symbol, m_period, time(1)) + ArrayMaximum(iHigh(m_symbol, m_period, 1, m_consolidation_bars), 0, m_consolidation_bars));
            m_range_low = low(iBarShift(m_symbol, m_period, time(1)) + ArrayMinimum(iLow(m_symbol, m_period, 1, m_consolidation_bars), 0, m_consolidation_bars));
        }
    }

    // --- فاز ۲: تشخیص شکست (Breakout) ---
    // این بخش زمانی اجرا می‌شود که یک ناحیه رنج معتبر پیدا کرده باشیم
    if (m_range_high > 0 && !m_is_breakout_detected) {
        // اگر قیمت بسته شدن کندل قبلی، از محدوده رنج خارج شده باشد
        if (close(1) > m_range_high || close(1) < m_range_low) {
            m_is_breakout_detected = true;               // وضعیت را به "منتظر تایید شکست" تغییر بده
            m_breakout_timestamp = time(1);              // زمان دقیق شکست را ثبت کن
            m_last_impulse_high = m_range_high;          // سقف ناحیه رنج را برای بعدا ذخیره کن
            m_last_impulse_low = m_range_low;            // کف ناحیه رنج را برای بعدا ذخیره کن
        }
    }

    // --- فاز ۳: تایید حرکت انفجاری و ایجاد اردربلاک ---
    // این بخش زمانی اجرا می‌شود که یک شکست اتفاق افتاده و به اندازه کافی کندل از آن گذشته باشد
    if (m_is_breakout_detected && (time(0) - m_breakout_timestamp) >= m_bars_to_wait * PeriodSeconds(m_period))
    {
        bool is_impulsive = false;                        // آیا حرکت به اندازه کافی قدرتمند بوده است؟
        EMitigationBlockDirection direction = MB_BULLISH; // جهت اردربلاک را مشخص کن
        double impulse_range = m_last_impulse_high - m_last_impulse_low; // اندازه ناحیه رنج
        
        // حلقه برای بررسی کندل‌های بعد از شکست
        for (int i = 1; i <= m_bars_to_wait; i++) {
            // اگر قیمت با قدرت به سمت بالا حرکت کرده باشد
            if (close(i) > m_last_impulse_high + impulse_range * m_impulse_multiplier) {
                is_impulsive = true; direction = MB_BEARISH; break; // یک اردربلاک نزولی ایجاد کن (که سیگنال خرید می‌دهد)
            }
            // اگر قیمت با قدرت به سمت پایین حرکت کرده باشد
            if (close(i) < m_last_impulse_low - impulse_range * m_impulse_multiplier) {
                is_impulsive = true; direction = MB_BULLISH; break; // یک اردربلاک صعودی ایجاد کن (که سیگنال فروش می‌دهد)
            }
        }

        // اگر حرکت به اندازه کافی انفجاری بود
        if (is_impulsive)
        {
            SMitigationBlockInfo new_ob; // یک ساختار جدید برای اردربلاک بساز
            new_ob.direction = direction; // جهت آن را مشخص کن
            new_ob.top_price = m_last_impulse_high; // سقف آن را مشخص کن
            new_ob.bottom_price = m_last_impulse_low; // کف آن را مشخص کن
            new_ob.start_time = iTime(m_symbol, m_period, iBarShift(m_symbol, m_period, m_breakout_timestamp) + m_consolidation_bars); // زمان شروع آن را مشخص کن
            new_ob.end_time = new_ob.start_time + (long)ChartGetInteger(0, CHART_VISIBLE_BARS) * PeriodSeconds(m_period); // زمان انقضای آن را مشخص کن
            new_ob.is_mitigated = false; // این اردربلاک هنوز استفاده نشده است
            new_ob.name = m_obj_prefix + TimeToString(new_ob.start_time); // یک نام منحصر به فرد برایش بساز
            new_ob.label_name = new_ob.name + "_label"; // یک نام برای متن آن بساز
            
            // اردربلاک جدید را به آرایه اردربلاک‌های فعال اضافه کن
            int size = ArraySize(m_order_blocks);
            ArrayResize(m_order_blocks, size + 1);
            m_order_blocks[size] = new_ob;
            // و آن را روی چارت رسم کن
            drawOrderBlock(m_order_blocks[size]);
        }
        
        // ریست کردن متغیرها برای پیدا کردن ناحیه رنج بعدی
        m_range_high = 0; m_range_low = 0; m_is_breakout_detected = false;
    }

    // --- فاز ۴: بررسی میتیگیشن و صدور سیگنال ---
    // روی تمام اردربلاک‌های فعال از آخر به اول حلقه بزن
    for (int i = ArraySize(m_order_blocks) - 1; i >= 0; i--)
    {
        SMitigationBlockInfo &ob = m_order_blocks[i]; // یک ارجاع به اردربلاک فعلی بگیر
        if (ob.is_mitigated) continue;               // اگر قبلا استفاده شده، نادیده‌اش بگیر

        // اگر اردربلاک منقضی شده، آن را از چارت و از آرایه حذف کن
        if (time(0) > ob.end_time) {
            ObjectDelete(m_chart_id, ob.name); ObjectDelete(m_chart_id, ob.label_name);
            ArrayRemove(m_order_blocks, i, 1);
            continue;
        }

        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);      // قیمت فعلی خرید
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);      // قیمت فعلی فروش
        double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);  // اندازه پوینت

        // اگر یک اردربلاک نزولی داریم و قیمت به بالای آن نفوذ کرده (سیگنال خرید)
        if (ob.direction == MB_BEARISH && ask > ob.top_price)
        {
            signal_result.type = MITIGATION_SIGNAL_BUY;                         // نوع سیگنال را خرید تعیین کن
            signal_result.entry_price = ask;                                    // قیمت ورود را مشخص کن
            signal_result.sl_price = ask - m_stoploss_points * point;           // حد ضرر را محاسبه کن
            signal_result.tp_price = ask + m_takeprofit_points * point;         // حد سود را محاسبه کن
            ob.is_mitigated = true;                                             // این اردربلاک را به عنوان "استفاده شده" علامت بزن
            updateOrderBlockDrawing(ob);                                        // ظاهر آن را روی چارت آپدیت کن
            break;                                                              // از حلقه خارج شو چون در هر کندل فقط یک سیگنال می‌خواهیم
        }
        // اگر یک اردربلاک صعودی داریم و قیمت به پایین آن نفوذ کرده (سیگنال فروش)
        else if (ob.direction == MB_BULLISH && bid < ob.bottom_price)
        {
            signal_result.type = MITIGATION_SIGNAL_SELL;                        // نوع سیگنال را فروش تعیین کن
            signal_result.entry_price = bid;                                    // قیمت ورود را مشخص کن
            signal_result.sl_price = bid + m_stoploss_points * point;           // حد ضرر را محاسبه کن
            signal_result.tp_price = bid - m_takeprofit_points * point;         // حد سود را محاسبه کن
            ob.is_mitigated = true;                                             // این اردربلاک را به عنوان "استفاده شده" علامت بزن
            updateOrderBlockDrawing(ob);                                        // ظاهر آن را روی چارت آپدیت کن
            break;                                                              // از حلقه خارج شو
        }
    }
    
    return signal_result; // ساختار سیگنال را به اکسپرت اصلی برگردان
}

// --- پیاده‌سازی کامل توابع گرافیکی (با کامنت‌های خط به خط) ---
void CMitigationOrderBlock::drawOrderBlock(SMitigationBlockInfo &ob)
{
    if (ObjectFind(m_chart_id, ob.name) >= 0) return; // اگر آبجکت از قبل وجود داشت، دوباره رسم نکن
    color ob_color = (ob.direction == MB_BULLISH) ? m_bullish_color : m_bearish_color; // رنگ مناسب را بر اساس جهت اردربلاک انتخاب کن

    // ساخت آبجکت مستطیل برای نمایش اردربلاک
    ObjectCreate(m_chart_id, ob.name, OBJ_RECTANGLE, 0, ob.start_time, ob.top_price, ob.end_time, ob.bottom_price);
    ObjectSetInteger(m_chart_id, ob.name, OBJPROP_COLOR, ob_color);         // رنگ کادر مستطیل را تنظیم کن
    ObjectSetInteger(m_chart_id, ob.name, OBJPROP_FILL, true);              // قابلیت پر شدن داخل مستطیل را فعال کن
    ObjectSetInteger(m_chart_id, ob.name, OBJPROP_BACK, true);              // مستطیل را به پس‌زمینه چارت ببر تا جلوی کندل‌ها را نگیرد

    // ساخت آبجکت متن برای نمایش لیبل اردربلاک
    string label_text = (ob.direction == MB_BULLISH) ? "Bullish OB" : "Bearish OB"; // متن لیبل را تعیین کن
    datetime label_time = ob.start_time + 1 * PeriodSeconds(m_period);         // مکان زمانی لیبل (کمی بعد از شروع اردربلاک)
    double label_price = ob.top_price;                                         // مکان قیمتی لیبل (بالای اردربلاک)
    ObjectCreate(m_chart_id, ob.label_name, OBJ_TEXT, 0, label_time, label_price);
    ObjectSetString(m_chart_id, ob.label_name, OBJPROP_TEXT, label_text);       // متن لیبل را تنظیم کن
    ObjectSetInteger(m_chart_id, ob.label_name, OBJPROP_COLOR, m_label_color);  // رنگ متن را تنظیم کن
    ObjectSetInteger(m_chart_id, ob.label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER); // نقطه لنگر متن را گوشه بالا-چپ قرار بده
    ObjectSetInteger(m_chart_id, ob.label_name, OBJPROP_FONTSIZE, 8);           // اندازه فونت را تنظیم کن
    ChartRedraw(m_chart_id);                                                    // چارت را دوباره رسم کن تا تغییرات نمایش داده شود
}

void CMitigationOrderBlock::updateOrderBlockDrawing(SMitigationBlockInfo &ob)
{
    // رنگ مستطیل اردربلاک را به رنگ "استفاده شده" (خاکستری) تغییر بده
    ObjectSetInteger(m_chart_id, ob.name, OBJPROP_COLOR, m_mitigated_color);
    // متن لیبل را بگیر و کلمه "Mitigated" را به ابتدای آن اضافه کن
    string old_text = ObjectGetString(m_chart_id, ob.label_name, OBJPROP_TEXT);
    ObjectSetString(m_chart_id, ob.label_name, OBJPROP_TEXT, "Mitigated " + old_text);
    // چارت را دوباره رسم کن تا تغییرات نمایش داده شود
    ChartRedraw(m_chart_id);
}
