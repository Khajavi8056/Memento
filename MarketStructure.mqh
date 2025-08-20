//+------------------------------------------------------------------+
//|                                        MarketStructure.mqh       |
//|                 © 2025, Mohammad & Gemini                        |
//+------------------------------------------------------------------+
#property copyright "© 2025, HipoAlgorithm" // حقوق کپی‌رایت کتابخانه
#property link      "https://www.mql5.com" // لینک مرتبط
#property version   "3.1" // نسخه با اصلاحات ارتقاء

#include <Object.mqh> // کتابخانه اشیاء برای رسم

//+------------------------------------------------------------------+
//| تنظیمات ورودی کتابخانه (مستقل)                                  |
//+------------------------------------------------------------------+
input group "---=== 🏛️ Market Structure Library Settings 🏛️ ===---"; // گروه تنظیمات کتابخانه
input group "پارامترهای اصلی تحلیل"; // زیرگروه پارامترها
input int    Inp_MSS_Swing_Length   = 10;   // طول تشخیص سقف/کف (تعداد کندل از هر طرف)
input group "تنظیمات نمایشی و لاگ"; // زیرگروه نمایشی
input bool   Inp_MSS_Enable_Drawing = true;  // فعال/غیرفعال کردن رسم روی چارت
input bool   Inp_MSS_Enable_Logging = false; // فعال/غیرفعال کردن لاگ‌های کتابخانه (برای دیباگ)
input group ""; // پایان گروه

// --- تعریف انواع سیگنال خروجی ---
enum E_MSS_SignalType
{
    MSS_NONE,         // هیچ سیگنالی
    MSS_BREAK_HIGH,   // شکست ساده صعودی (BoS)
    MSS_BREAK_LOW,    // شکست ساده نزولی (BoS)
    MSS_SHIFT_UP,     // تغییر به صعودی (MSS)
    MSS_SHIFT_DOWN    // تغییر به نزولی (MSS)
};

// MarketStructure.mqh

struct SMssSignal
{
    E_MSS_SignalType type;
    double           break_price;
    datetime         break_time;
    int              swing_bar_index;
    bool             new_swing_formed;
    bool             is_swing_high;    // <<<< ✅ این خط رو اینجا اضافه کن
    
    SMssSignal() { Reset(); } 
    void Reset() { type=MSS_NONE; break_price=0.0; break_time=0; swing_bar_index=0; new_swing_formed=false; is_swing_high=false; } // به ریست هم اضافش کن

    SMssSignal(const SMssSignal &other) 
    {
        type = other.type;
        break_price = other.break_price;
        break_time = other.break_time;
        swing_bar_index = other.swing_bar_index;
        new_swing_formed = other.new_swing_formed;
        is_swing_high = other.is_swing_high; // <<<< ✅ و اینجا هم برای کپی کردن
    }
};


//+------------------------------------------------------------------+
//| کلاس اصلی تحلیل ساختار بازار                                    |
//+------------------------------------------------------------------+
class CMarketStructureShift
{
private:
    int      m_swing_length; // طول تشخیص چرخش
    string   m_symbol; // نماد
    ENUM_TIMEFRAMES m_period; // تایم فریم
    bool     m_enable_logging; // فعال لاگ
    bool     m_enable_drawing; // فعال رسم
    long     m_chart_id; // ID چارت
    string   m_obj_prefix; // پیشوند اشیاء
    datetime m_last_bar_time; // زمان آخرین بار پردازش شده
    
    double   m_swing_highs_array[]; // آرایه آخرین سقف‌ها ([0] جدیدترین)
    double   m_swing_lows_array[]; // آرایه آخرین کف‌ها ([0] جدیدترین)
    
    double   m_last_swing_h; // آخرین سقف چرخش
    double   m_last_swing_l; // آخرین کف چرخش
    int      m_last_swing_h_index; // اندیس آخرین سقف
    int      m_last_swing_l_index; // اندیس آخرین کف

    double   high(int index) { return iHigh(m_symbol, m_period, index); } // گرفتن سقف اندیس
    double   low(int index) { return iLow(m_symbol, m_period, index); } // گرفتن کف اندیس
    datetime time(int index) { return iTime(m_symbol, m_period, index); } // گرفتن زمان اندیس
    void     Log(string message); // تابع لاگ
    
    void drawSwingPoint(string objName,datetime time_param,double price,int arrCode, color clr,int direction); // رسم نقطه چرخش
    void drawBreakLevel(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction); // رسم خط شکست BoS
    void drawBreakLevel_MSS(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction); // رسم خط شکست MSS
    
public:
    void Init(string symbol, ENUM_TIMEFRAMES period); // مقداردهی اولیه
    SMssSignal ProcessNewBar(); // پردازش کندل جدید و بازگشت سیگنال
    double GetLastSwingHigh() const { return m_last_swing_h; } // گرفتن آخرین سقف
    double GetLastSwingLow() const { return m_last_swing_l; } // گرفتن آخرین کف
    int    GetLastSwingHighIndex() const { return m_last_swing_h_index; } // اندیس آخرین سقف
    int    GetLastSwingLowIndex() const { return m_last_swing_l_index; } // اندیس آخرین کف
    void   GetRecentHighs(double &highs[]) const { ArrayCopy(highs, m_swing_highs_array); } // کپی سقف‌ها
    void   GetRecentLows(double &lows[]) const { ArrayCopy(lows, m_swing_lows_array); } // کپی کف‌ها
    bool   IsUptrend() const; // چک روند صعودی
    bool   IsDowntrend() const; // چک روند نزولی
    double GetSecondLastSwingHigh() const; // [NEW] گرفتن دومین سقف آخر
    double GetSecondLastSwingLow() const; // [NEW] گرفتن دومین کف آخر
    bool   ScanPastForMSS(bool is_buy_direction, int lookback_bars, int &found_at_bar); // [NEW] اسکن گذشته برای MSS
};

//+------------------------------------------------------------------+
//| مقداردهی اولیه کلاس                                              |
//+------------------------------------------------------------------+
void CMarketStructureShift::Init(string symbol, ENUM_TIMEFRAMES period)
{
    m_symbol = symbol; // تنظیم نماد
    m_period = period; // تنظیم تایم فریم
    
    m_swing_length = Inp_MSS_Swing_Length > 2 ? Inp_MSS_Swing_Length : 10; // طول چرخش (حداقل 3)
    m_enable_logging = Inp_MSS_Enable_Logging; // تنظیم لاگ
    m_enable_drawing = Inp_MSS_Enable_Drawing; // تنظیم رسم
    
    m_chart_id = ChartID(); // ID چارت فعلی
    m_obj_prefix = "MSS_LIB_" + m_symbol + "_" + EnumToString(m_period) + "_"; // پیشوند اشیاء
    m_last_bar_time = 0; // ریست زمان آخرین بار
    m_last_swing_h = -1.0; // ریست آخرین سقف
    m_last_swing_l = -1.0; // ریست آخرین کف
    m_last_swing_h_index = 0; // ریست اندیس سقف
    m_last_swing_l_index = 0; // ریست اندیس کف
    
    // ریست آرایه‌ها
    ArrayFree(m_swing_highs_array); // آزاد سقف‌ها
    ArrayFree(m_swing_lows_array); // آزاد کف‌ها
    
    int highs_found = 0; // شمارنده سقف‌ها
    int lows_found = 0; // شمارنده کف‌ها
    
    // جستجو به عقب برای پیدا کردن حداقل دو سقف و کف اولیه
    for(int i = m_swing_length; i < 500 && (highs_found < 2 || lows_found < 2); i++) // حلقه به عقب
    {
        if(iBars(m_symbol, m_period) < i + m_swing_length + 1) break; // چک داده کافی
        
        bool is_high = true; // فلگ سقف
        bool is_low = true; // فلگ کف
        
        for(int j = 1; j <= m_swing_length; j++) // چک اطراف
        {
            if(high(i) <= high(i-j) || high(i) < high(i+j)) is_high = false; // چک سقف
            if(low(i) >= low(i-j) || low(i) > low(i+j)) is_low = false; // چک کف
        }
        
        if(is_high && highs_found < 2) // اگر سقف و کمتر از 2
        {
            double temp_high[1]; // آرایه موقت
            temp_high[0] = high(i); // مقدار سقف
            ArrayInsert(m_swing_highs_array, temp_high, 0); // اضافه به ابتدا
            highs_found++; // افزایش
        }
        
        if(is_low && lows_found < 2) // اگر کف و کمتر از 2
        {
            double temp_low[1]; // آرایه موقت
            temp_low[0] = low(i); // مقدار کف
            ArrayInsert(m_swing_lows_array, temp_low, 0); // اضافه به ابتدا
            lows_found++; // افزایش
        }
    }
    
    if(m_enable_logging) // اگر لاگ فعال
    {
       Print("مقداردهی اولیه MarketStructure انجام شد."); // چاپ
       Print("سقف‌های اولیه پیدا شده:"); // چاپ
       ArrayPrint(m_swing_highs_array); // چاپ آرایه
       Print("کف‌های اولیه پیدا شده:"); // چاپ
       ArrayPrint(m_swing_lows_array); // چاپ آرایه
    }
    
    Log("کتابخانه MarketStructure برای " + m_symbol + " در " + EnumToString(m_period) + " راه‌اندازی شد."); // لاگ راه‌اندازی
}

//+------------------------------------------------------------------+
//| پردازش کندل جدید (اصلاح شده)                                    |
//+------------------------------------------------------------------+
SMssSignal CMarketStructureShift::ProcessNewBar()
{
    SMssSignal result; // نتیجه سیگنال
    datetime current_bar_time = iTime(m_symbol, m_period, 0); // زمان فعلی
    if (current_bar_time == m_last_bar_time) return result; // اگر همان، خروج
    m_last_bar_time = current_bar_time; // آپدیت زمان

    const int curr_bar = m_swing_length; // بار فعلی برای چک
    if (iBars(m_symbol, m_period) < curr_bar * 2 + 1) return result; // چک داده کافی

    bool isSwingHigh = true, isSwingLow = true; // فلگ‌ها

    for (int a = 1; a <= m_swing_length; a++) // چک اطراف
    {
        if ((high(curr_bar) <= high(curr_bar - a)) || (high(curr_bar) < high(curr_bar + a))) isSwingHigh = false; // چک سقف
        if ((low(curr_bar) >= low(curr_bar - a)) || (low(curr_bar) > low(curr_bar + a))) isSwingLow = false; // چک کف
    }

    if (isSwingHigh) // اگر سقف جدید
    {
        m_last_swing_h = high(curr_bar); // تنظیم سقف
        m_last_swing_h_index = curr_bar; // اندیس
        Log("سقف چرخش جدید: " + DoubleToString(m_last_swing_h, _Digits)); // لاگ
        if (m_enable_drawing) drawSwingPoint(m_obj_prefix + TimeToString(time(curr_bar)), time(curr_bar), m_last_swing_h, 77, clrBlue, -1); // رسم

        // [MODIFIED] منطق برای آپدیت آرایه با چک اندازه
        if(ArraySize(m_swing_highs_array) > 0)
        {
           if(ArraySize(m_swing_highs_array) == 1) ArrayResize(m_swing_highs_array, 2);
           m_swing_highs_array[1] = m_swing_highs_array[0];
        }
        else ArrayResize(m_swing_highs_array, 2);
        m_swing_highs_array[0] = m_last_swing_h;
        result.new_swing_formed = true; // [NEW] اعلام تشکیل سوینگ جدید
    }
    
    if (isSwingLow) // اگر کف جدید
    {
        m_last_swing_l = low(curr_bar); // تنظیم کف
        m_last_swing_l_index = curr_bar; // اندیس
        Log("کف چرخش جدید: " + DoubleToString(m_last_swing_l, _Digits)); // لاگ
        if (m_enable_drawing) drawSwingPoint(m_obj_prefix + TimeToString(time(curr_bar)), time(curr_bar), m_last_swing_l, 77, clrRed, +1); // رسم

        // [MODIFIED] منطق برای آپدیت آرایه با چک اندازه
        if(ArraySize(m_swing_lows_array) > 0)
        {
           if(ArraySize(m_swing_lows_array) == 1) ArrayResize(m_swing_lows_array, 2);
           m_swing_lows_array[1] = m_swing_lows_array[0];
        }
        else ArrayResize(m_swing_lows_array, 2);
        m_swing_lows_array[0] = m_last_swing_l;
        result.new_swing_formed = true; // [NEW] اعلام تشکیل سوینگ جدید
    }

    double Ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK); // قیمت Ask
    double Bid = SymbolInfoDouble(m_symbol, SYMBOL_BID); // قیمت Bid

    if (m_last_swing_h > 0 && Ask > m_last_swing_h) // شکست سقف
    {
        Log("شکست سقف در قیمت " + DoubleToString(m_last_swing_h, _Digits)); // لاگ
        
        bool isMSS_High = IsUptrend(); // چک MSS صعودی
        if (isMSS_High) {
            result.type = MSS_SHIFT_UP; // تغییر به صعودی
            if (m_enable_drawing) drawBreakLevel_MSS(m_obj_prefix + "MSS_UP_" + TimeToString(time(0)), time(m_last_swing_h_index), m_last_swing_h, time(0), m_last_swing_h, clrDarkGreen, -1); // رسم
        } else {
            result.type = MSS_BREAK_HIGH; // شکست ساده صعودی
            if (m_enable_drawing) drawBreakLevel(m_obj_prefix + "BOS_UP_" + TimeToString(time(0)), time(m_last_swing_h_index), m_last_swing_h, time(0), m_last_swing_h, clrBlue, -1); // رسم
        }
        
        result.break_price = m_last_swing_h; // قیمت شکست
        result.break_time = time(0); // زمان
        result.swing_bar_index = m_last_swing_h_index; // اندیس
        m_last_swing_h = -1.0; // ریست
    }
    else if (m_last_swing_l > 0 && Bid < m_last_swing_l) // شکست کف
    {
        Log("شکست کف در قیمت " + DoubleToString(m_last_swing_l, _Digits)); // لاگ
        
        bool isMSS_Low = IsDowntrend(); // چک MSS نزولی
        if (isMSS_Low) {
            result.type = MSS_SHIFT_DOWN; // تغییر به نزولی
            if (m_enable_drawing) drawBreakLevel_MSS(m_obj_prefix + "MSS_DOWN_" + TimeToString(time(0)), time(m_last_swing_l_index), m_last_swing_l, time(0), m_last_swing_l, clrBlack, +1); // رسم
        } else {
            result.type = MSS_BREAK_LOW; // شکست ساده نزولی
            if (m_enable_drawing) drawBreakLevel(m_obj_prefix + "BOS_DOWN_" + TimeToString(time(0)), time(m_last_swing_l_index), m_last_swing_l, time(0), m_last_swing_l, clrRed, +1); // رسم
        }

        result.break_price = m_last_swing_l; // قیمت
        result.break_time = time(0); // زمان
        result.swing_bar_index = m_last_swing_l_index; // اندیس
        m_last_swing_l = -1.0; // ریست
    }


      // [MODIFIED] این بخش را به انتهای تابع ProcessNewBar در MarketStructure.mqh اضافه کنید
      if (isSwingHigh)
      {
          result.new_swing_formed = true;
          result.is_swing_high = true;
      }
      if (isSwingLow)
      {
          result.new_swing_formed = true;
          result.is_swing_high = false;
      }

return result; //  
}
//+------------------------------------------------------------------+
//| تابع لاگ کتابخانه                                                |
//+------------------------------------------------------------------+
void CMarketStructureShift::Log(string message)
{
    if (m_enable_logging) // اگر فعال
    {
        Print("[MSS Lib][", m_symbol, "][", EnumToString(m_period), "]: ", message); // چاپ
    }
}

//+------------------------------------------------------------------+
//| چک روند صعودی (اصلاح شده)                                       |
//+------------------------------------------------------------------+
bool CMarketStructureShift::IsUptrend() const
{
    if (ArraySize(m_swing_highs_array) < 2 || ArraySize(m_swing_lows_array) < 2) return false; // چک حداقل 2 عضو
    // چک سقف جدید > سقف قدیمی و کف جدید > کف قدیمی
    return (m_swing_highs_array[0] > m_swing_highs_array[1] && m_swing_lows_array[0] > m_swing_lows_array[1]);
}

//+------------------------------------------------------------------+
//| چک روند نزولی (اصلاح شده)                                       |
//+------------------------------------------------------------------+
bool CMarketStructureShift::IsDowntrend() const
{
    if (ArraySize(m_swing_highs_array) < 2 || ArraySize(m_swing_lows_array) < 2) return false; // چک حداقل 2 عضو
    // چک سقف جدید < سقف قدیمی و کف جدید < کف قدیمی
    return (m_swing_highs_array[0] < m_swing_highs_array[1] && m_swing_lows_array[0] < m_swing_lows_array[1]);
}

//+------------------------------------------------------------------+
//| [NEW] گرفتن دومین سقف آخر                                        |
//+------------------------------------------------------------------+
double CMarketStructureShift::GetSecondLastSwingHigh() const
{
    if (ArraySize(m_swing_highs_array) < 2) return -1.0; // چک اندازه آرایه
    return m_swing_highs_array[1]; // بازگشت دومین عضو
}

//+------------------------------------------------------------------+
//| [NEW] گرفتن دومین کف آخر                                         |
//+------------------------------------------------------------------+
double CMarketStructureShift::GetSecondLastSwingLow() const
{
    if (ArraySize(m_swing_lows_array) < 2) return -1.0; // چک اندازه آرایه
    return m_swing_lows_array[1]; // بازگشت دومین عضو
}

//+------------------------------------------------------------------+
//| [NEW] اسکن گذشته برای پیدا کردن MSS                               |
//+------------------------------------------------------------------+
bool CMarketStructureShift::ScanPastForMSS(bool is_buy_direction, int lookback_bars, int &found_at_bar)
{
    found_at_bar = -1; // ریست اندیس
    if (lookback_bars <= 0) return false; // چک ورودی

    int total_bars = iBars(m_symbol, m_period); // تعداد بارها
    if (total_bars < lookback_bars) lookback_bars = total_bars - 1; // تنظیم نگاه به عقب

    for (int i = 1; i <= lookback_bars; i++) // حلقه به عقب
    {
        const int curr_bar = i; // بار فعلی اسکن
        if (total_bars < curr_bar + m_swing_length * 2 + 1) continue; // چک داده

        bool isSwingHigh = true, isSwingLow = true; // فلگ‌ها

        for (int a = 1; a <= m_swing_length; a++) // چک اطراف
        {
            if ((high(curr_bar) <= high(curr_bar - a)) || (high(curr_bar) < high(curr_bar + a))) isSwingHigh = false;
            if ((low(curr_bar) >= low(curr_bar - a)) || (low(curr_bar) > low(curr_bar + a))) isSwingLow = false;
        }

        double temp_high = isSwingHigh ? high(curr_bar) : 0;
        double temp_low = isSwingLow ? low(curr_bar) : 0;

        // چک شکست در جهت مورد نظر
        if (is_buy_direction && temp_high > 0 && IsUptrend()) // برای خرید و MSS صعودی
        {
            found_at_bar = curr_bar; // تنظیم اندیس
            return true; // پیدا شد
        }
        else if (!is_buy_direction && temp_low > 0 && IsDowntrend()) // برای فروش و MSS نزولی
        {
            found_at_bar = curr_bar; // تنظیم اندیس
            return true; // پیدا شد
        }
    }

    return false; // پیدا نشد
}

//+------------------------------------------------------------------+
//| رسم نقطه چرخش                                                    |
//+------------------------------------------------------------------+
void CMarketStructureShift::drawSwingPoint(string objName,datetime time_param,double price,int arrCode, color clr,int direction)
{
   if(ObjectFind(m_chart_id,objName) < 0) { // اگر شیء وجود ندارد
      ObjectCreate(m_chart_id,objName,OBJ_ARROW,0,time_param,price); // ایجاد فلش
      ObjectSetInteger(m_chart_id,objName,OBJPROP_ARROWCODE,arrCode); // کد فلش
      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr); // رنگ
      ObjectSetInteger(m_chart_id,objName,OBJPROP_FONTSIZE,10); // اندازه فونت
      if(direction > 0) ObjectSetInteger(m_chart_id,objName,OBJPROP_ANCHOR,ANCHOR_TOP); // لنگر بالا
      if(direction < 0) ObjectSetInteger(m_chart_id,objName,OBJPROP_ANCHOR,ANCHOR_BOTTOM); // لنگر پایین
      
      string text = "Swing"; // متن
      string objName_Descr = objName + text; // نام توصیفی
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time_param,price); // ایجاد متن
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr); // رنگ متن
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,10); // اندازه
      if(direction > 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,"  "+text); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); } // متن بالا
      if(direction < 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,"  "+text); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER); } // متن پایین
   }
   ChartRedraw(m_chart_id); // بازسازی چارت
}

//+------------------------------------------------------------------+
//| رسم خط شکست BoS                                                   |
//+------------------------------------------------------------------+
void CMarketStructureShift::drawBreakLevel(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction)
{
   if(ObjectFind(m_chart_id,objName) < 0) { // اگر شیء وجود ندارد
      ObjectCreate(m_chart_id,objName,OBJ_ARROWED_LINE,0,time1,price1,time2,price2); // ایجاد خط فلش‌دار
      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr); // رنگ
      ObjectSetInteger(m_chart_id,objName,OBJPROP_WIDTH,2); // عرض
      string text = "BoS"; // متن
      string objName_Descr = objName + text; // نام
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time2,price2); // ایجاد متن
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr); // رنگ
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,10); // اندازه
      if(direction > 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); } // متن بالا
      if(direction < 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER); } // متن پایین
   }
   ChartRedraw(m_chart_id); // بازسازی
}

//+------------------------------------------------------------------+
//| رسم خط شکست MSS                                                   |
//+------------------------------------------------------------------+
void CMarketStructureShift::drawBreakLevel_MSS(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction)
{
   if(ObjectFind(m_chart_id,objName) < 0) { // اگر شیء وجود ندارد
      ObjectCreate(m_chart_id,objName,OBJ_ARROWED_LINE,0,time1,price1,time2,price2); // ایجاد خط
      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr); // رنگ
      ObjectSetInteger(m_chart_id,objName,OBJPROP_WIDTH,4); // عرض بیشتر برای MSS
      string text = "MSS"; // متن
      string objName_Descr = objName + text; // نام
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time2,price2); // ایجاد متن
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr); // رنگ
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,13); // اندازه بزرگتر
      if(direction > 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); } // متن
      if(direction < 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER); } // متن
   }
   ChartRedraw(m_chart_id); // بازسازی
}
