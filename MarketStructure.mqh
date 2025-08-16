//+------------------------------------------------------------------+
//|                                        MarketStructure.mqh       |
//|                 © 2025, Mohammad & Gemini (از پروژه قدیمی)        |
//|          کتابخانه مستقل برای تشخیص سقف/کف و شکست ساختار بازار      |
//+------------------------------------------------------------------+
#property copyright "© 2025, HipoAlgorithm"
#property link      "https://www.mql5.com"
#property version   "2.0" // نسخه کامل با ورودی‌های مستقل و توابع عمومی گسترده

/*
========================================================================================================
|                                                                                                      |
|                      --- راهنمای استفاده سریع از کتابخانه MarketStructure ---                          |
|                                                                                                      |
|   هدف: این کتابخانه به صورت یک "جعبه سیاه" (Black Box) عمل کرده و وظیفه آن پیدا کردن                   |
|   سقف‌ها و کف‌های چرخش (Swing Points) و تشخیص شکست ساختار بازار (MSS/BoS) در هر نماد و تایم فریمی است. |
|                                                                                                      |
|   مراحل استفاده:                                                                                       |
|                                                                                                      |
|   ۱. افزودن به پروژه:                                                                                  |
|      #include "MarketStructure.mqh"                                                                  |
|                                                                                                      |
|   ۲. ساخت یک نمونه از کلاس (در بخش متغیرهای سراسری اکسپرت):                                             |
|      CMarketStructureShift mss_analyzer;                                                             |
|                                                                                                      |
|   ۳. مقداردهی اولیه در تابع OnInit اکسپرت:                                                             |
|      // کتابخانه به صورت خودکار تنظیمات را از پنل ورودی می‌خواند.                                      |
|      mss_analyzer.Init(_Symbol, PERIOD_M5); // فقط نماد و تایم فریم مورد نظر را پاس دهید.               |
|                                                                                                      |
|   ۴. فراخوانی در تابع OnTimer یا OnTick اکسپرت (در هر کندل جدید):                                       |
|      SMssSignal signal = mss_analyzer.ProcessNewBar();                                               |
|                                                                                                      |
|   ۵. بررسی خروجی و استفاده از سیگنال:                                                                  |
|      if(signal.type != MSS_NONE)                                                                      |
|      {                                                                                                |
|          if(signal.type == MSS_SHIFT_UP)                                                              |
|          {                                                                                            |
|              // اینجا منطق ورود به معامله خرید را پیاده‌سازی کنید                                       |
|              Print("سیگنال MSS صعودی در قیمت ", signal.break_price, " دریافت شد!");                      |
|          }                                                                                            |
|      }                                                                                                |
|                                                                                                      |
========================================================================================================
*/

#include <Object.mqh>

//+------------------------------------------------------------------+
//|   بخش تنظیمات ورودی (Inputs) - کاملا مستقل و Plug & Play         |
//+------------------------------------------------------------------+
input group "---=== 🏛️ Market Structure Library Settings 🏛️ ===---"; // گروه اصلی برای تمام تنظیمات کتابخانه
input group "پارامترهای اصلی تحلیل"; // زیرگروه اول
input int    Inp_MSS_Swing_Length   = 10;   // طول تشخیص سقف/کف (تعداد کندل از هر طرف)
input group "تنظیمات نمایشی و لاگ"; // زیرگروه دوم
input bool   Inp_MSS_Enable_Drawing = true;  // ✅ فعال/غیرفعال کردن رسم روی چارت
input bool   Inp_MSS_Enable_Logging = false; // فعال/غیرفعال کردن لاگ‌های کتابخانه (برای دیباگ)
input group ""; // پایان گروه بندی

// --- ۱. تعریف خروجی‌های کتابخانه ---
enum E_MSS_SignalType
{
    MSS_NONE,         // هیچ سیگنالی وجود ندارد
    MSS_BREAK_HIGH,   // یک سقف شکسته شده (شکست ساختار ساده - BoS)
    MSS_BREAK_LOW,    // یک کف شکسته شده (شکست ساختار ساده - BoS)
    MSS_SHIFT_UP,     // تغییر ساختار به صعودی (MSS)
    MSS_SHIFT_DOWN    // تغییر ساختار به نزولی (MSS)
};

struct SMssSignal
{
    E_MSS_SignalType type;
    double           break_price;
    datetime         break_time;
    int              swing_bar_index;
    
    SMssSignal() { Reset(); }
    void Reset() { type=MSS_NONE; break_price=0.0; break_time=0; swing_bar_index=0; }
};

//+------------------------------------------------------------------+
//|   کلاس اصلی کتابخانه: جعبه سیاه تشخیص شکست ساختار                 |
//+------------------------------------------------------------------+
class CMarketStructureShift
{
private:
    int      m_swing_length;
    string   m_symbol;
    ENUM_TIMEFRAMES m_period;
    bool     m_enable_logging;
    bool     m_enable_drawing;
    long     m_chart_id;
    string   m_obj_prefix;
    datetime m_last_bar_time;
    
    double   m_swing_highs_array[];
    double   m_swing_lows_array[];
    
    double   m_last_swing_h;
    double   m_last_swing_l;
    int      m_last_swing_h_index;
    int      m_last_swing_l_index;

    double   high(int index) { return iHigh(m_symbol, m_period, index); }
    double   low(int index) { return iLow(m_symbol, m_period, index); }
    datetime time(int index) { return iTime(m_symbol, m_period, index); }
    void     Log(string message);
    
    void drawSwingPoint(string objName,datetime time_param,double price,int arrCode, color clr,int direction);
    void drawBreakLevel(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction);
    void drawBreakLevel_MSS(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction);
    
public:
    void Init(string symbol, ENUM_TIMEFRAMES period);
    SMssSignal ProcessNewBar();

    // --- توابع عمومی جدید برای کاربردهای بیشتر ---
    double GetLastSwingHigh() const { return m_last_swing_h; }
    double GetLastSwingLow() const { return m_last_swing_l; }
    int    GetLastSwingHighIndex() const { return m_last_swing_h_index; }
    int    GetLastSwingLowIndex() const { return m_last_swing_l_index; }
    void   GetRecentHighs(double &highs[]) const { ArrayCopy(highs, m_swing_highs_array); }
    void   GetRecentLows(double &lows[]) const { ArrayCopy(lows, m_swing_lows_array); }
    bool   IsUptrend() const;
    bool   IsDowntrend() const;
};

//+------------------------------------------------------------------+
//| پیاده‌سازی توابع کلاس                                            |
//+------------------------------------------------------------------+
// MarketStructure.mqh -> جایگزین تابع Init فعلی

void CMarketStructureShift::Init(string symbol, ENUM_TIMEFRAMES period)
{
    m_symbol = symbol;
    m_period = period;
    
    m_swing_length = Inp_MSS_Swing_Length > 2 ? Inp_MSS_Swing_Length : 10;
    m_enable_logging = Inp_MSS_Enable_Logging;
    m_enable_drawing = Inp_MSS_Enable_Drawing;
    
    m_chart_id = ChartID();
    m_obj_prefix = "MSS_LIB_" + m_symbol + "_" + EnumToString(m_period) + "_";
    m_last_bar_time = 0;
    m_last_swing_h = -1.0;
    m_last_swing_l = -1.0;
    m_last_swing_h_index = 0;
    m_last_swing_l_index = 0;
    
    // --- ✅ بخش حیاتی: پر کردن آرایه‌ها با داده‌های تاریخی در لحظه شروع ✅ ---
    ArrayFree(m_swing_highs_array);
    ArrayFree(m_swing_lows_array);
    
    int highs_found = 0;
    int lows_found = 0;
    
    // از کندل فعلی شروع به جستجو به عقب می‌کنیم تا 200 کندل قبل
    for(int i = m_swing_length; i < 200 && (highs_found < 2 || lows_found < 2); i++)
    {
        bool is_high = true;
        bool is_low = true;
        
        // چک کردن شرایط سقف/کف
        for(int j = 1; j <= m_swing_length; j++)
        {
            if(high(i) <= high(i-j) || high(i) < high(i+j)) is_high = false;
            if(low(i) >= low(i-j) || low(i) > low(i+j)) is_low = false;
        }
        
        if(is_high && highs_found < 2)
        {
            // سقف پیدا شده رو به اول آرایه اضافه می‌کنیم
            ArrayInsert(m_swing_highs_array, 0, 1);
            m_swing_highs_array[0] = high(i);
            highs_found++;
        }
        
        if(is_low && lows_found < 2)
        {
            // کف پیدا شده رو به اول آرایه اضافه می‌کنیم
            ArrayInsert(m_swing_lows_array, 0, 1);
            m_swing_lows_array[0] = low(i);
            lows_found++;
        }
    }
    
    if(m_enable_logging)
    {
       Print("مقداردهی اولیه MarketStructure انجام شد.");
       Print("سقف‌های اولیه پیدا شده:");
       ArrayPrint(m_swing_highs_array);
       Print("کف‌های اولیه پیدا شده:");
       ArrayPrint(m_swing_lows_array);
    }
    // --- پایان بخش حیاتی ---
    
    Log("کتابخانه MarketStructure برای " + m_symbol + " در " + EnumToString(m_period) + " راه‌اندازی شد.");
}


SMssSignal CMarketStructureShift::ProcessNewBar()
{
    SMssSignal result;
    datetime current_bar_time = iTime(m_symbol, m_period, 0);
    if (current_bar_time == m_last_bar_time) return result;
    m_last_bar_time = current_bar_time;

    const int curr_bar = m_swing_length;
    if (iBars(m_symbol, m_period) < curr_bar * 2 + 1) return result;

    bool isSwingHigh = true, isSwingLow = true;

    for (int a = 1; a <= m_swing_length; a++)
    {
        if ((high(curr_bar) <= high(curr_bar - a)) || (high(curr_bar) < high(curr_bar + a))) isSwingHigh = false;
        if ((low(curr_bar) >= low(curr_bar - a)) || (low(curr_bar) > low(curr_bar + a))) isSwingLow = false;
    }

    if (isSwingHigh)
    {
        m_last_swing_h = high(curr_bar);
        m_last_swing_h_index = curr_bar;
        Log("سقف چرخش جدید: " + DoubleToString(m_last_swing_h, _Digits));
        if (m_enable_drawing) drawSwingPoint(m_obj_prefix + TimeToString(time(curr_bar)), time(curr_bar), m_last_swing_h, 77, clrBlue, -1);
        
        // منطق اکسپرت اصلی برای آرایه سقف‌ها
        if (ArraySize(m_swing_highs_array) == 2){
            ArrayRemove(m_swing_highs_array,0,1);
            ArrayResize(m_swing_highs_array,ArraySize(m_swing_highs_array)+1);
            m_swing_highs_array[ArraySize(m_swing_highs_array)-1] = m_last_swing_h;
            if (m_enable_logging) { Print("POPULATED! New swing high prices data is as below:"); ArrayPrint(m_swing_highs_array, _Digits, " , "); }
        } else {
            ArrayResize(m_swing_highs_array,ArraySize(m_swing_highs_array)+1);
            m_swing_highs_array[ArraySize(m_swing_highs_array)-1] = m_last_swing_h;
        }

    }
    if (isSwingLow)
    {
        m_last_swing_l = low(curr_bar);
        m_last_swing_l_index = curr_bar;
        Log("کف چرخش جدید: " + DoubleToString(m_last_swing_l, _Digits));
        if (m_enable_drawing) drawSwingPoint(m_obj_prefix + TimeToString(time(curr_bar)), time(curr_bar), m_last_swing_l, 77, clrRed, +1);

        // منطق اکسپرت اصلی برای آرایه کف‌ها
        if (ArraySize(m_swing_lows_array) == 2){
            ArrayRemove(m_swing_lows_array,0,1);
            ArrayResize(m_swing_lows_array,ArraySize(m_swing_lows_array)+1);
            m_swing_lows_array[ArraySize(m_swing_lows_array)-1] = m_last_swing_l;
            if (m_enable_logging) { Print("POPULATED! New swing low prices data is as below:"); ArrayPrint(m_swing_lows_array, _Digits, " , "); }
        } else {
            ArrayResize(m_swing_lows_array,ArraySize(m_swing_lows_array)+1);
            m_swing_lows_array[ArraySize(m_swing_lows_array)-1] = m_last_swing_l;
        }
    }

    double Ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    double Bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

    if (m_last_swing_h > 0 && Ask > m_last_swing_h)
    {
        Log("شکست سقف در قیمت " + DoubleToString(m_last_swing_h, _Digits));
        
        bool isMSS_High = IsUptrend(); // از تابع خود کلاس استفاده کن
        if (isMSS_High) {
            result.type = MSS_SHIFT_UP;
            Log("تشخیص: تغییر ساختار به صعودی (MSS UP)");
            if (m_enable_drawing) drawBreakLevel_MSS(m_obj_prefix + "MSS_UP_" + TimeToString(time(0)), time(m_last_swing_h_index), m_last_swing_h, time(0), m_last_swing_h, clrDarkGreen, -1);
        } else {
            result.type = MSS_BREAK_HIGH;
            Log("تشخیص: شکست ساده ساختار (BoS UP)");
            if (m_enable_drawing) drawBreakLevel(m_obj_prefix + "BOS_UP_" + TimeToString(time(0)), time(m_last_swing_h_index), m_last_swing_h, time(0), m_last_swing_h, clrBlue, -1);
        }
        
        result.break_price = m_last_swing_h;
        result.break_time = time(0);
        result.swing_bar_index = m_last_swing_h_index;
        
        m_last_swing_h = -1.0;
    }
    else if (m_last_swing_l > 0 && Bid < m_last_swing_l)
    {
        Log("شکست کف در قیمت " + DoubleToString(m_last_swing_l, _Digits));
        
        bool isMSS_Low = IsDowntrend(); // از تابع خود کلاس استفاده کن
        if (isMSS_Low) {
            result.type = MSS_SHIFT_DOWN;
            Log("تشخیص: تغییر ساختار به نزولی (MSS DOWN)");
            if (m_enable_drawing) drawBreakLevel_MSS(m_obj_prefix + "MSS_DOWN_" + TimeToString(time(0)), time(m_last_swing_l_index), m_last_swing_l, time(0), m_last_swing_l, clrBlack, +1);
        } else {
            result.type = MSS_BREAK_LOW;
            Log("تشخیص: شکست ساده ساختار (BoS DOWN)");
            if (m_enable_drawing) drawBreakLevel(m_obj_prefix + "BOS_DOWN_" + TimeToString(time(0)), time(m_last_swing_l_index), m_last_swing_l, time(0), m_last_swing_l, clrRed, +1);
        }

        result.break_price = m_last_swing_l;
        result.break_time = time(0);
        result.swing_bar_index = m_last_swing_l_index;
        
        m_last_swing_l = -1.0;
    }

    return result;
}

void CMarketStructureShift::Log(string message)
{
    if (m_enable_logging)
    {
        Print("[MSS Lib][", m_symbol, "][", EnumToString(m_period), "]: ", message);
    }
}

// --- توابع عمومی جدید ---
bool CMarketStructureShift::IsUptrend() const
{
    if (ArraySize(m_swing_highs_array) < 2 || ArraySize(m_swing_lows_array) < 2) return false;
    // روند صعودی = سقف جدید > سقف قدیمی و کف جدید > کف قدیمی
    return (m_swing_highs_array[ArraySize(m_swing_highs_array)-1] > m_swing_highs_array[ArraySize(m_swing_highs_array)-2] && m_swing_lows_array[ArraySize(m_swing_lows_array)-1] > m_swing_lows_array[ArraySize(m_swing_lows_array)-2]);
}

bool CMarketStructureShift::IsDowntrend() const
{
    if (ArraySize(m_swing_highs_array) < 2 || ArraySize(m_swing_lows_array) < 2) return false;
    // روند نزولی = سقف جدید < سقف قدیمی و کف جدید < کف قدیمی
    return (m_swing_highs_array[ArraySize(m_swing_highs_array)-1] < m_swing_highs_array[ArraySize(m_swing_highs_array)-2] && m_swing_lows_array[ArraySize(m_swing_lows_array)-1] < m_swing_lows_array[ArraySize(m_swing_lows_array)-2]);
}

// --- پیاده‌سازی کامل توابع گرافیکی (بدون تغییر در منطق) ---
void CMarketStructureShift::drawSwingPoint(string objName,datetime time_param,double price,int arrCode, color clr,int direction)
{
   if(ObjectFind(m_chart_id,objName) < 0)
     {
      ObjectCreate(m_chart_id,objName,OBJ_ARROW,0,time_param,price);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_ARROWCODE,arrCode);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_FONTSIZE,10);
      if(direction > 0) ObjectSetInteger(m_chart_id,objName,OBJPROP_ANCHOR,ANCHOR_TOP);
      if(direction < 0) ObjectSetInteger(m_chart_id,objName,OBJPROP_ANCHOR,ANCHOR_BOTTOM);
      
      string text = "BoS";
      string objName_Descr = objName + text;
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time_param,price);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,10);
      if(direction > 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,"  "+text); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); }
      if(direction < 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,"  "+text); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER); }
     }
   ChartRedraw(m_chart_id);
}
void CMarketStructureShift::drawBreakLevel(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction)
{
   if(ObjectFind(m_chart_id,objName) < 0)
     {
      ObjectCreate(m_chart_id,objName,OBJ_ARROWED_LINE,0,time1,price1,time2,price2);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_WIDTH,2);
      string text = "Break";
      string objName_Descr = objName + text;
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time2,price2);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,10);
      if(direction > 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); }
      if(direction < 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER); }
     }
   ChartRedraw(m_chart_id);
}
void CMarketStructureShift::drawBreakLevel_MSS(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction)
{
   if(ObjectFind(m_chart_id,objName) < 0)
     {
      ObjectCreate(m_chart_id,objName,OBJ_ARROWED_LINE,0,time1,price1,time2,price2);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_WIDTH,4);
      string text = "Break (MSS)";
      string objName_Descr = objName + text;
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time2,price2);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,13);
      if(direction > 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER); }
      if(direction < 0) { ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  "); ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER); }
     }





دو خطا دارم در این کد 


variable expected	MarketStructure.mqh	172	46
   built-in: bool ArrayInsert(T&[...],const T&[...],uint,uint,uint)	MarketStructure.mqh	172	46
variable expected	MarketStructure.mqh	180	45
   built-in: bool ArrayInsert(T&[...],const T&[...],uint,uint,uint)	MarketStructure.mqh	180	45

   ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
