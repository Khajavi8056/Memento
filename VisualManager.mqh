//+------------------------------------------------------------------+
//|                                     VisualManager.mqh            |
//|                          © 2025, hipoalgoritm               |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "1.04" // نسخه نهایی با اصلاحات کتابخانه پایه

#include "set.mqh" 
#include <Object.mqh>
#include <ChartObjects\ChartObject.mqh>
#include <Trade\Trade.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh> // برای رسم مستطیل
#include <ChartObjects\ChartObjectsArrows.mqh>   // برای رسم فلش

//--- نام‌های ثابت برای اشیاء
#define RECT_PREFIX        "M_RECT_"
#define SCAN_PREFIX        "M_SCAN_"
#define CONFIRM_PREFIX     "M_CONFIRM_"

//+------------------------------------------------------------------+
//| کلاس مدیریت گرافیک                                               |
//+------------------------------------------------------------------+
class CVisualManager
{
private:
    string              m_symbol;
    SSettings           m_settings;
    long                m_chart_id;

    string GetObjectName(string prefix, int shift);

public:
    CVisualManager(string symbol, SSettings &settings);
    bool Init();
    void ClearGraphics();
    void DrawTripleCrossRectangle(bool is_buy, int shift);
    void DrawScanningArea(bool is_buy, int start_shift, int current_shift);
    void DrawConfirmationArrow(bool is_buy, int shift);

    ~CVisualManager();
};

//+------------------------------------------------------------------+
//| کانستراکتور کلاس                                                 |
//+------------------------------------------------------------------+
CVisualManager::CVisualManager(string symbol, SSettings &settings)
{
    m_symbol = symbol;
    m_settings = settings;
    m_chart_id = ChartID();
}

//+------------------------------------------------------------------+
//| دیستراکتور کلاس                                                  |
//+------------------------------------------------------------------+
CVisualManager::~CVisualManager()
{
    ClearGraphics();
    ChartRedraw(m_chart_id);
}

//+------------------------------------------------------------------+
//| مقداردهی اولیه                                                   |
//+------------------------------------------------------------------+
bool CVisualManager::Init()
{
    ChartSetInteger(m_chart_id, CHART_AUTOSCROLL, 0);
    ChartSetInteger(m_chart_id, CHART_SHIFT, 1);
    return true;
}

//+------------------------------------------------------------------+
//| ساخت نام منحصر به فرد برای اشیاء                                 |
//+------------------------------------------------------------------+
string CVisualManager::GetObjectName(string prefix, int shift)
{
    datetime time = iTime(m_symbol, _Period, shift);
    return prefix + m_symbol + "_" + (string)time;
}

//+------------------------------------------------------------------+
//| پاکسازی گرافیک                                                   |
//+------------------------------------------------------------------+
void CVisualManager::ClearGraphics()
{
    ObjectsDeleteAll(m_chart_id, RECT_PREFIX + m_symbol + "_");
    ObjectsDeleteAll(m_chart_id, SCAN_PREFIX + m_symbol + "_");
    ObjectsDeleteAll(m_chart_id, CONFIRM_PREFIX + m_symbol + "_");
}

//+------------------------------------------------------------------+
//| رسم مربع کراس سه گانه (کوچک و ثابت)                               |
//+------------------------------------------------------------------+
void CVisualManager::DrawTripleCrossRectangle(bool is_buy, int shift)
{
    ClearGraphics();

    datetime cross_time = iTime(m_symbol, _Period, shift);
    string obj_name = GetObjectName(RECT_PREFIX, shift);

    double high = iHigh(m_symbol, _Period, shift);
    double low = iLow(m_symbol, _Period, shift);

    CChartObjectRectangle rect;
    if (rect.Create(m_chart_id, obj_name, 0, cross_time, high, (datetime)(cross_time + PeriodSeconds(_Period) * m_settings.object_size_multiplier), low))
    {
        rect.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        rect.Style(STYLE_SOLID);
        rect.Width(1);
        // اصلاح شد: به جای rect.Fill از تابع اصلی ObjectSetInteger استفاده می‌کنیم
        ObjectSetInteger(m_chart_id, obj_name, OBJPROP_BACK, false);
    }
}


//+------------------------------------------------------------------+
//| رسم ناحیه اسکن (مربع بزرگ شیشه‌ای)                                 |
//+------------------------------------------------------------------+
void CVisualManager::DrawScanningArea(bool is_buy, int start_shift, int current_shift)
{
    string obj_name = GetObjectName(SCAN_PREFIX, start_shift);
    ObjectDelete(m_chart_id, obj_name);

    datetime start_time = iTime(m_symbol, _Period, start_shift);
    datetime end_time = iTime(m_symbol, _Period, start_shift - m_settings.grace_period_candles);

    double max_high = iHigh(m_symbol, _Period, start_shift);
    double min_low = iLow(m_symbol, _Period, start_shift);

    for (int i = 1; i <= m_settings.grace_period_candles; i++)
    {
        int check_shift = start_shift - i;
        if(check_shift < 0) break;
        double current_high = iHigh(m_symbol, _Period, check_shift);
        double current_low = iLow(m_symbol, _Period, check_shift);
        if (current_high > max_high) max_high = current_high;
        if (current_low < min_low) min_low = current_low;
    }

    CChartObjectRectangle rect;
    if (rect.Create(m_chart_id, obj_name, 0, start_time, max_high, end_time, min_low))
    {
        rect.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        rect.Style(STYLE_DOT);
        rect.Width(1);
        // اصلاح شد: به جای rect.Fill و rect.BgColor از توابع اصلی استفاده می‌کنیم
        ObjectSetInteger(m_chart_id, obj_name, OBJPROP_BACK, true); // فعال کردن حالت پس زمینه
        ObjectSetInteger(m_chart_id, obj_name, OBJPROP_BGCOLOR, is_buy ? ColorToARGB(m_settings.bullish_color, 200) : ColorToARGB(m_settings.bearish_color, 200)); // تنظیم رنگ پس زمینه
    }

    string v_line_name = obj_name + "_VLine";
    ObjectDelete(m_chart_id, v_line_name);

    datetime scan_time = iTime(m_symbol, _Period, start_shift - current_shift);
    ObjectCreate(m_chart_id, v_line_name, OBJ_VLINE, 0, scan_time, 0);
    ObjectSetInteger(m_chart_id, v_line_name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(m_chart_id, v_line_name, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(m_chart_id, v_line_name, OBJPROP_WIDTH, 1);
}


//+------------------------------------------------------------------+
//| رسم فلش تأیید نهایی                                              |
//+------------------------------------------------------------------+
void CVisualManager::DrawConfirmationArrow(bool is_buy, int shift)
{
    string obj_name = GetObjectName(CONFIRM_PREFIX, shift);

    double price = is_buy ? iLow(m_symbol, _Period, shift) - (10 * SymbolInfoDouble(m_symbol, SYMBOL_POINT)) : iHigh(m_symbol, _Period, shift) + (10 * SymbolInfoDouble(m_symbol, SYMBOL_POINT));

    uchar code = is_buy ? 233 : 234;

    CChartObjectArrow arrow;
    if (arrow.Create(m_chart_id, obj_name, 0, iTime(m_symbol, _Period, shift), price, code))
    {
        arrow.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        arrow.Width(2);
    }
}
