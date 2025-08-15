//+------------------------------------------------------------------+
//|                                        MarketStructure.mqh       |
//|                 © 2025, Mohammad & Gemini (از پروژه قدیمی)        |
//|          کتابخانه مستقل برای تشخیص سقف/کف و شکست ساختار بازار      |
//+------------------------------------------------------------------+
/*
==================================================================================
|                                                                                |
|                      --- راهنمای استفاده سریع از کتابخانه MSS ---                 |
|                                                                                |
|   هدف: این کتابخانه به صورت یک "جعبه سیاه" عمل کرده و وظیفه آن پیدا کردن         |
|   سقف‌ها و کف‌های چرخش (Swing Points) و تشخیص شکست ساختار بازار (MSS/BoS)        |
|   در هر نماد و تایم فریمی است.                                                   |
|                                                                                |
|   مراحل استفاده:                                                                |
|                                                                                |
|   ۱. افزودن به پروژه:                                                           |
|      #include "MarketStructure.mqh"                                            |
|                                                                                |
|   ۲. ساخت یک نمونه از کلاس:                                                      |
|      CMarketStructureShift mss_analyzer;                                       |
|                                                                                |
|   ۳. مقداردهی اولیه در OnInit:                                                  |
|      mss_analyzer.Init(_Symbol, PERIOD_M5, 10, true, true);                    |
|      // پارامترها: نماد، تایم فریم، طول تشخیص سقف/کف، فعالسازی لاگ، فعالسازی رسم |
|                                                                                |
|   ۴. فراخوانی در OnTimer یا OnTick:                                             |
|      // این تابع را در هر کندل جدید فراخوانی کنید.                               |
|      SMssSignal signal = mss_analyzer.ProcessNewBar();                         |
|                                                                                |
|   ۵. بررسی خروجی:                                                               |
|      // ساختار signal شامل اطلاعات کامل سیگنال است.                              |
|      if(signal.type != MSS_NONE)                                               |
|      {                                                                         |
|          if(signal.type == MSS_SHIFT_UP)                                       |
|          {                                                                     |
|              // اینجا منطق ورود به معامله خرید را پیاده‌سازی کنید                 |
|              Print("سیگنال تغییر ساختار به صعودی دریافت شد!");                    |
|          }                                                                     |
|      }                                                                         |
|                                                                                |
|   توابع عمومی دیگر:                                                             |
|    - GetLastSwingHigh()   : دریافت آخرین قیمت سقف چرخش                          |
|    - GetLastSwingLow()    : دریافت آخرین قیمت کف چرخش                           |
|    - GetRecentHighs(array): پر کردن یک آرایه با دو سقف آخر                        |
|                                                                                |
==================================================================================
*/

#include <Object.mqh>

// --- ۱. تعریف خروجی‌های کتابخانه ---
// این enum نوع سیگنالی که پیدا شده رو به ما میگه.
enum E_MSS_SignalType
{
    MSS_NONE,         // هیچ سیگنالی وجود ندارد
    MSS_BREAK_HIGH,   // یک سقف شکسته شده (شکست ساختار ساده - BoS)
    MSS_BREAK_LOW,    // یک کف شکسته شده (شکست ساختار ساده - BoS)
    MSS_SHIFT_UP,     // تغییر ساختار به صعودی (MSS)
    MSS_SHIFT_DOWN    // تغییر ساختار به نزولی (MSS)
};

// این ساختار، تمام اطلاعات یک سیگنال رو به صورت یکجا برمی‌گردونه.
struct SMssSignal
{
    E_MSS_SignalType type;          // نوع سیگنال
    double           break_price;   // قیمتی که شکسته شده
    datetime         break_time;    // زمان کندلی که سطح را شکسته
    int              swing_bar_index; // اندیس کندلی که سقف/کف در آن تشکیل شده
    
    // سازنده برای ریست کردن راحت
    SMssSignal()
    {
        type = MSS_NONE;
        break_price = 0.0;
        break_time = 0;
        swing_bar_index = 0;
    }
};

//+------------------------------------------------------------------+
//|   کلاس اصلی کتابخانه: جعبه سیاه تشخیص شکست ساختار                 |
//+------------------------------------------------------------------+
class CMarketStructureShift
{
private:
    // --- تنظیمات داخلی ---
    int      m_swing_length;      // تعداد کندل برای تشخیص سقف/کف
    string   m_symbol;
    ENUM_TIMEFRAMES m_period;
    bool     m_enable_logging;
    bool     m_enable_drawing;
    long     m_chart_id;
    string   m_obj_prefix;

    // --- متغیرهای وضعیت داخلی ---
    datetime m_last_bar_time;
    double   m_swing_highs_array[];
    double   m_swing_lows_array[];
    double   m_last_swing_h;
    double   m_last_swing_l;
    int      m_last_swing_h_index;
    int      m_last_swing_l_index;


    // --- توابع کمکی (خصوصی) ---
    double   high(int index) { return iHigh(m_symbol, m_period, index); }
    double   low(int index) { return iLow(m_symbol, m_period, index); }
    datetime time(int index) { return iTime(m_symbol, m_period, index); }
    void     Log(string message);
    
    // --- توابع گرافیکی (خصوصی) ---
    void drawSwingPoint(string objName,datetime time,double price,int arrCode, color clr,int direction);
    void drawBreakLevel(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction);
    void drawBreakLevel_MSS(string objName,datetime time1,double price1, datetime time2,double price2,color clr,int direction);
    
public:
    // --- رابط کاربری کلاس (دکمه‌های روی جعبه سیاه) ---
    void Init(string symbol, ENUM_TIMEFRAMES period, int swing_length = 10, bool enable_logging = false, bool enable_drawing = true);
    SMssSignal ProcessNewBar();

    // --- توابع عمومی برای دریافت اطلاعات از کتابخانه ---
    double GetLastSwingHigh() const { return m_last_swing_h; }
    double GetLastSwingLow() const { return m_last_swing_l; }
    int    GetLastSwingHighIndex() const { return m_last_swing_h_index; }
    int    GetLastSwingLowIndex() const { return m_last_swing_l_index; }
    void   GetRecentHighs(double &highs[]) const { ArrayCopy(highs, m_swing_highs_array); }
    void   GetRecentLows(double &lows[]) const { ArrayCopy(lows, m_swing_lows_array); }
};

//+------------------------------------------------------------------+
//| پیاده‌سازی توابع کلاس                                            |
//+------------------------------------------------------------------+

// کامنت: این تابع کتابخانه را با تنظیمات اولیه راه‌اندازی می‌کند.
void CMarketStructureShift::Init(string symbol, ENUM_TIMEFRAMES period, int swing_length, bool enable_logging, bool enable_drawing)
{
    m_symbol = symbol;                                       // نمادی که تحلیل می‌شود
    m_period = period;                                       // تایم فریمی که تحلیل می‌شود
    m_swing_length = swing_length > 2 ? swing_length : 10;   // حداقل باید ۲ کندل از هر طرف بررسی شود
    m_enable_logging = enable_logging;                       // فعال یا غیرفعال کردن لاگ‌ها
    m_enable_drawing = enable_drawing;                       // فعال یا غیرفعال کردن رسم روی چارت
    m_chart_id = ChartID();                                  // شناسه چارتی که اشیاء روی آن رسم می‌شوند
    m_obj_prefix = "MSS_LIB_" + m_symbol + "_" + EnumToString(m_period) + "_"; // پیشوند منحصر به فرد برای اشیاء گرافیکی
    m_last_bar_time = 0;                                     // ریست کردن زمان آخرین کندل پردازش شده
    m_last_swing_h = -1.0;                                   // ریست کردن آخرین سقف پیدا شده
    m_last_swing_l = -1.0;                                   // ریست کردن آخرین کف پیدا شده
    m_last_swing_h_index = 0;
    m_last_swing_l_index = 0;
    Log("کتابخانه MarketStructure برای " + m_symbol + " در تایم فریم " + EnumToString(m_period) + " با موفقیت راه‌اندازی شد.");
}

// کامنت: این تابع اصلی است که در هر کندل جدید باید فراخوانی شود تا سیگنال‌ها را بررسی کند.
SMssSignal CMarketStructureShift::ProcessNewBar()
{
    // کامنت: یک ساختار خالی برای سیگنال خروجی ایجاد می‌کنیم.
    SMssSignal result;

    // کامنت: چک می‌کنیم که آیا کندل جدیدی تشکیل شده است یا خیر.
    datetime current_bar_time = iTime(m_symbol, m_period, 0);
    if (current_bar_time == m_last_bar_time)
        return result; // اگر کندل تکراری بود، یک سیگنال خالی (NONE) برمی‌گردانیم.
        
    m_last_bar_time = current_bar_time;

    // --- بخش ۱: پیدا کردن سقف و کف چرخش (منطق اصلی از کد قدیمی) ---
    const int curr_bar = m_swing_length; // کندل مرکزی که می‌خواهیم آن را به عنوان سقف/کف بالقوه بررسی کنیم.
    bool isSwingHigh = true, isSwingLow = true;

    // کامنت: یک حلقه برای بررسی کندل‌های سمت چپ و راست کندل مرکزی اجرا می‌کنیم.
    for (int a = 1; a <= m_swing_length; a++)
    {
        int right_index = curr_bar - a; // اندیس کندل‌های جدیدتر
        int left_index = curr_bar + a;  // اندیس کندل‌های قدیمی‌تر

        // کامنت: شرط پیدا کردن سقف چرخش (باید از تمام همسایه‌ها بلندتر باشد).
        if ((high(curr_bar) <= high(right_index)) || (high(curr_bar) < high(left_index)))
            isSwingHigh = false;
        
        // کامنت: شرط پیدا کردن کف چرخش (باید از تمام همسایه‌ها کوتاه‌تر باشد).
        if ((low(curr_bar) >= low(right_index)) || (low(curr_bar) > low(left_index)))
            isSwingLow = false;
    }

    // کامنت: اگر یک سقف چرخش پیدا شد، آن را ذخیره و روی چارت رسم می‌کنیم.
    if (isSwingHigh)
    {
        m_last_swing_h = high(curr_bar);
        m_last_swing_h_index = curr_bar;
        Log("سقف چرخش جدید در قیمت " + DoubleToString(m_last_swing_h, _Digits) + " پیدا شد.");
        if(m_enable_drawing) drawSwingPoint(m_obj_prefix + TimeToString(time(curr_bar)), time(curr_bar), high(curr_bar), 77, clrBlue, -1);

        // کامنت: دو سقف آخر را برای تشخیص MSS در آرایه نگهداری می‌کنیم.
        if (ArraySize(m_swing_highs_array) < 2)
            ArrayAdd(m_swing_highs_array, m_last_swing_h);
        else {
            ArrayRemove(m_swing_highs_array, 0, 1);
            ArrayAdd(m_swing_highs_array, m_last_swing_h);
        }
    }
    // کامنت: اگر یک کف چرخش پیدا شد، آن را ذخیره و روی چارت رسم می‌کنیم.
    if (isSwingLow)
    {
        m_last_swing_l = low(curr_bar);
        m_last_swing_l_index = curr_bar;
        Log("کف چرخش جدید در قیمت " + DoubleToString(m_last_swing_l, _Digits) + " پیدا شد.");
        if(m_enable_drawing) drawSwingPoint(m_obj_prefix + TimeToString(time(curr_bar)), time(curr_bar), low(curr_bar), 77, clrRed, +1);

        // کامنت: دو کف آخر را برای تشخیص MSS در آرایه نگهداری می‌کنیم.
        if (ArraySize(m_swing_lows_array) < 2)
            ArrayAdd(m_swing_lows_array, m_last_swing_l);
        else {
            ArrayRemove(m_swing_lows_array, 0, 1);
            ArrayAdd(m_swing_lows_array, m_last_swing_l);
        }
    }

    // --- بخش ۲: تشخیص شکست و سیگنال‌دهی ---
    double Ask = NormalizeDouble(SymbolInfoDouble(m_symbol, SYMBOL_ASK), _Digits);
    double Bid = NormalizeDouble(SymbolInfoDouble(m_symbol, SYMBOL_BID), _Digits);

    // کامنت: بررسی شکست سقف (سیگنال خرید).
    if (m_last_swing_h > 0 && Ask > m_last_swing_h)
    {
        Log("شکست سقف در قیمت " + DoubleToString(m_last_swing_h, _Digits) + " اتفاق افتاد.");
        
        // کامنت: چک می‌کنیم آیا این شکست یک تغییر ساختار (MSS) است یا یک شکست ساده (BoS).
        bool isMSS_High = false;
        if (ArraySize(m_swing_highs_array) >= 2 && ArraySize(m_swing_lows_array) >= 2)
        {
            isMSS_High = m_swing_highs_array[1] > m_swing_highs_array[0] && m_swing_lows_array[1] > m_swing_lows_array[0];
        }

        if (isMSS_High) {
            result.type = MSS_SHIFT_UP; // نوع سیگنال: تغییر ساختار به صعودی
            Log("تشخیص: تغییر ساختار به صعودی (MSS UP)");
            if(m_enable_drawing) drawBreakLevel_MSS(m_obj_prefix + "MSS_UP_" + TimeToString(time(0)), time(m_last_swing_h_index), m_last_swing_h, time(0), m_last_swing_h, clrDarkGreen, -1);
        } else {
            result.type = MSS_BREAK_HIGH; // نوع سیگنال: شکست ساده سقف
            Log("تشخیص: شکست ساده ساختار (BoS UP)");
            if(m_enable_drawing) drawBreakLevel(m_obj_prefix + "BOS_UP_" + TimeToString(time(0)), time(m_last_swing_h_index), m_last_swing_h, time(0), m_last_swing_h, clrBlue, -1);
        }
        
        // کامنت: اطلاعات سیگنال را در ساختار خروجی پر می‌کنیم.
        result.break_price = m_last_swing_h;
        result.break_time = time(0);
        result.swing_bar_index = m_last_swing_h_index;
        
        m_last_swing_h = -1.0; // کامنت: سقف را ریست می‌کنیم تا سیگنال تکراری صادر نشود.
    }
    // کامنت: بررسی شکست کف (سیگنال فروش).
    else if (m_last_swing_l > 0 && Bid < m_last_swing_l)
    {
        Log("شکست کف در قیمت " + DoubleToString(m_last_swing_l, _Digits) + " اتفاق افتاد.");

        bool isMSS_Low = false;
        if (ArraySize(m_swing_highs_array) >= 2 && ArraySize(m_swing_lows_array) >= 2)
        {
            isMSS_Low = m_swing_highs_array[1] < m_swing_highs_array[0] && m_swing_lows_array[1] < m_swing_lows_array[0];
        }

        if (isMSS_Low) {
            result.type = MSS_SHIFT_DOWN; // نوع سیگنال: تغییر ساختار به نزولی
            Log("تشخیص: تغییر ساختار به نزولی (MSS DOWN)");
            if(m_enable_drawing) drawBreakLevel_MSS(m_obj_prefix + "MSS_DOWN_" + TimeToString(time(0)), time(m_last_swing_l_index), m_last_swing_l, time(0), m_last_swing_l, clrBlack, +1);
        } else {
            result.type = MSS_BREAK_LOW; // نوع سیگنال: شکست ساده کف
            Log("تشخیص: شکست ساده ساختار (BoS DOWN)");
            if(m_enable_drawing) drawBreakLevel(m_obj_prefix + "BOS_DOWN_" + TimeToString(time(0)), time(m_last_swing_l_index), m_last_swing_l, time(0), m_last_swing_l, clrRed, +1);
        }

        result.break_price = m_last_swing_l;
        result.break_time = time(0);
        result.swing_bar_index = m_last_swing_l_index;
        
        m_last_swing_l = -1.0; // کامنت: کف را ریست می‌کنیم.
    }

    // کامنت: در نهایت، ساختار سیگنال (که ممکن است خالی یا پر باشد) را برمی‌گردانیم.
    return result;
}

// کامنت: تابع برای لاگ کردن پیام‌ها در صورت فعال بودن.
void CMarketStructureShift::Log(string message)
{
    if(m_enable_logging)
    {
        Print("[MSS Lib][", m_symbol, "][", EnumToString(m_period), "]: ", message);
    }
}


// --- پیاده‌سازی کامل توابع گرافیکی (بدون هیچ تغییری در منطق) ---

void CMarketStructureShift::drawSwingPoint(string objName,datetime time_param,double price,int arrCode,
   color clr,int direction){
   if (ObjectFind(m_chart_id,objName) < 0){
      ObjectCreate(m_chart_id,objName,OBJ_ARROW,0,time_param,price);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_ARROWCODE,arrCode);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_FONTSIZE,10);
      
      if (direction > 0) {ObjectSetInteger(m_chart_id,objName,OBJPROP_ANCHOR,ANCHOR_TOP);}
      if (direction < 0) {ObjectSetInteger(m_chart_id,objName,OBJPROP_ANCHOR,ANCHOR_BOTTOM);}
      
      string text = "BoS";
      string objName_Descr = objName + text;
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time_param,price);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,10);
      
      if (direction > 0) {
         ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,"  "+text);
         ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      }
      if (direction < 0) {
         ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,"  "+text);
         ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
      }
   }
   ChartRedraw(m_chart_id);
}

void CMarketStructureShift::drawBreakLevel(string objName,datetime time1,double price1,
   datetime time2,double price2,color clr,int direction){
   if (ObjectFind(m_chart_id,objName) < 0){
      ObjectCreate(m_chart_id,objName,OBJ_ARROWED_LINE,0,time1,price1,time2,price2);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_TIME,0,time1);
      ObjectSetDouble(m_chart_id,objName,OBJPROP_PRICE,0,price1);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_TIME,1,time2);
      ObjectSetDouble(m_chart_id,objName,OBJPROP_PRICE,1,price2);

      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_WIDTH,2);
      
      string text = "Break";
      string objName_Descr = objName + text;
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time2,price2);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,10);
      
      if (direction > 0) {
         ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  ");
         ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
      }
      if (direction < 0) {
         ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  ");
         ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);
      }
   }
   ChartRedraw(m_chart_id);
}

void CMarketStructureShift::drawBreakLevel_MSS(string objName,datetime time1,double price1,
   datetime time2,double price2,color clr,int direction){
   if (ObjectFind(m_chart_id,objName) < 0){
      ObjectCreate(m_chart_id,objName,OBJ_ARROWED_LINE,0,time1,price1,time2,price2);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_TIME,0,time1);
      ObjectSetDouble(m_chart_id,objName,OBJPROP_PRICE,0,price1);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_TIME,1,time2);
      ObjectSetDouble(m_chart_id,objName,OBJPROP_PRICE,1,price2);

      ObjectSetInteger(m_chart_id,objName,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName,OBJPROP_WIDTH,4);
      
      string text = "Break (MSS)";
      string objName_Descr = objName + text;
      ObjectCreate(m_chart_id,objName_Descr,OBJ_TEXT,0,time2,price2);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_COLOR,clr);
      ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_FONTSIZE,13);
      
      if (direction > 0) {
         ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  ");
         ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
      }
      if (direction < 0) {
         ObjectSetString(m_chart_id,objName_Descr,OBJPROP_TEXT,text+"  ");
         ObjectSetInteger(m_chart_id,objName_Descr,OBJPROP_ANCHOR,ANCHOR_RIGHT_LOWER);
      }
   }
   ChartRedraw(m_chart_id);
}
