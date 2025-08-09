//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: VisualManager.mqh (Graphics Engine)     |
//|                    Version: 2.1 (Final & Bulletproof)            |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "2.1" // بازنویسی کامل با توابع اصلی MQL5 و رفع تمام باگ‌ها

#include "set.mqh" 

// ---===== ثابت‌های طراحی (بدون تغییر) =====---
#define DASHBOARD_Y_POS 5       
#define DASHBOARD_X_GAP 5       
#define BOX_WIDTH 90            
#define BOX_HEIGHT 25           
#define SUB_PANEL_HEIGHT 35     
#define MEMENTO_OBJ_PREFIX "MEMENTO_UI_"

// --- ساختارهای داده (بدون تغییر) ---
struct SPanelBox
{
    string MainBoxName, SymbolLabelName, SubPanelName, TradesLabelName, PlLabelName;
};

struct SManagedObject
{
    string          ObjectName;
    long            CreationBar;
};

struct SDashboardData
{
    int    trades_count;
    double cumulative_pl;
};

//+------------------------------------------------------------------+
//| کلاس مدیریت گرافیک (با پیاده‌سازی بازنویسی شده)                    |
//+------------------------------------------------------------------+
class CVisualManager
{
private:
    string              m_symbol;
    SSettings           m_settings;
    SPanelBox           m_panel_boxes[];
    string              m_symbols_list[];
    SManagedObject      m_managed_objects[];
    SDashboardData      m_dashboard_data[];

public:
    CVisualManager(string symbol, SSettings &settings);
    ~CVisualManager();

    bool Init();
    void Deinit();
    
    // --- توابع داشبورد
    void InitDashboard();
    void UpdateDashboard();
    
    // --- توابع رسم اشیاء ماندگار
    void DrawTripleCrossRectangle(bool is_buy, int shift);
    void DrawConfirmationArrow(bool is_buy, int shift);
    
    // --- توابع رسم اشیاء موقت
    void DrawScanningArea(bool is_buy, int start_shift, int current_shift);
    
    // --- تابع پاکسازی
    void CleanupOldObjects(const int max_age_in_bars);
    
    // --- توابع مدیریت کش داشبورد
    int GetSymbolIndex(string symbol);
    void UpdateDashboardCache(int symbol_index, double deal_profit, double deal_commission, double deal_swap);
};

//+------------------------------------------------------------------+
//|                      پیاده‌سازی توابع کلاس                        |
//+------------------------------------------------------------------+
CVisualManager::CVisualManager(string symbol, SSettings &settings)
{
    m_symbol = symbol;
    m_settings = settings;
}

CVisualManager::~CVisualManager()
{
    Deinit();
}

bool CVisualManager::Init()
{
    ChartSetInteger(0, CHART_SHIFT, 1);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrGreen);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
    ChartSetInteger(0, CHART_COLOR_CHART_UP, clrGreen);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrRed);
    return true;
}

void CVisualManager::Deinit()
{
    ObjectsDeleteAll(0, MEMENTO_OBJ_PREFIX);
    ChartRedraw(0);
}

void CVisualManager::InitDashboard()
{
    if(!m_settings.enable_dashboard) return;
    
    StringSplit(m_settings.symbols_list, ',', m_symbols_list);
    int total_symbols = ArraySize(m_symbols_list);
    if(total_symbols == 0) return;
    
    ArrayResize(m_panel_boxes, total_symbols);
    ArrayResize(m_dashboard_data, total_symbols);
    
    int current_x = DASHBOARD_X_GAP;

    for(int i = 0; i < total_symbols; i++)
    {
        string sym = m_symbols_list[i];
        StringTrimLeft(sym);
        StringTrimRight(sym);
        
        string base_name = MEMENTO_OBJ_PREFIX + sym;
        m_panel_boxes[i].MainBoxName      = base_name + "_MainBox";
        m_panel_boxes[i].SymbolLabelName  = base_name + "_SymbolLabel";
        m_panel_boxes[i].SubPanelName     = base_name + "_SubPanel";
        m_panel_boxes[i].TradesLabelName  = base_name + "_TradesLabel";
        m_panel_boxes[i].PlLabelName      = base_name + "_PlLabel";

        ObjectCreate(0, m_panel_boxes[i].MainBoxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_XDISTANCE, current_x);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_XSIZE, BOX_WIDTH);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_YSIZE, BOX_HEIGHT);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_COLOR, clrGray);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_BGCOLOR, clrSteelBlue);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_ZORDER, 100);

        ObjectCreate(0, m_panel_boxes[i].SymbolLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_TEXT, sym);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_XDISTANCE, current_x + BOX_WIDTH / 2);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT / 2);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_COLOR, clrWhite);
        ObjectSetString(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_ZORDER, 101);

        ObjectCreate(0, m_panel_boxes[i].SubPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_XDISTANCE, current_x + 5);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_XSIZE, BOX_WIDTH - 10);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_YSIZE, SUB_PANEL_HEIGHT);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_COLOR, clrSlateGray);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_BGCOLOR, clrDarkSlateGray);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_ZORDER, 99);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, true);

        ObjectCreate(0, m_panel_boxes[i].TradesLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_TEXT, "Trades: 0");
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_XDISTANCE, current_x + 10);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT + 10);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_COLOR, clrWhite);
        ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_ZORDER, 100);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, true);

        ObjectCreate(0, m_panel_boxes[i].PlLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_TEXT, "P/L: 0.0");
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_XDISTANCE, current_x + 10);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT + 25);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_COLOR, clrWhite);
        ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_ZORDER, 100);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, true);
        
        current_x += BOX_WIDTH + DASHBOARD_X_GAP;
        
        if(!HistorySelect(0, TimeCurrent())) continue;
        int trades_count = 0;
        double cumulative_pl = 0;
        uint total_deals = HistoryDealsTotal();
        for(uint j = 0; j < total_deals; j++)
        {
            ulong ticket = HistoryDealGetTicket(j);
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == sym && HistoryDealGetInteger(ticket, DEAL_MAGIC) == (long)m_settings.magic_number && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
                trades_count++;
                cumulative_pl += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
        }
        m_dashboard_data[i].trades_count = trades_count;
        m_dashboard_data[i].cumulative_pl = cumulative_pl;
    }
    ChartRedraw(0);
}

void CVisualManager::UpdateDashboard()
{
    if(!m_settings.enable_dashboard || ArraySize(m_symbols_list) == 0) return;
    for(int i = 0; i < ArraySize(m_symbols_list); i++)
    {
        string sym = m_symbols_list[i];
        long magic = (long)m_settings.magic_number;
        color box_color = clrSteelBlue; 
        if(PositionSelect(sym) && PositionGetInteger(POSITION_MAGIC) == magic)
        {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) box_color = m_settings.bullish_color;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) box_color = m_settings.bearish_color;
        }
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_BGCOLOR, box_color);
        int trades_count = m_dashboard_data[i].trades_count;
        double cumulative_pl = m_dashboard_data[i].cumulative_pl;
        bool show_sub_panel = trades_count > 0;
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, !show_sub_panel);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, !show_sub_panel);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, !show_sub_panel);
        if(show_sub_panel)
        {
            ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_TEXT, "Trades: " + (string)trades_count);
            ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_TEXT, "P/L: " + DoubleToString(cumulative_pl, 2));
            ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_COLOR, cumulative_pl >= 0 ? clrLime : clrRed);
        }
    }
    ChartRedraw(0);
}

void CVisualManager::DrawTripleCrossRectangle(bool is_buy, int shift)
{
    string obj_name = MEMENTO_OBJ_PREFIX + m_symbol + "_SignalRect_" + (string)iTime(m_symbol, _Period, shift);
    datetime time1 = iTime(m_symbol, _Period, shift + 1);
    datetime time2 = iTime(m_symbol, _Period, shift);
    double high = iHigh(m_symbol, _Period, shift); 
    double low = iLow(m_symbol, _Period, shift);
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double buffer = 10 * point * m_settings.object_size_multiplier;

    if(ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time1, low - buffer, time2, high + buffer))
    {
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID); 
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 1); 
        ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);

        int total = ArraySize(m_managed_objects);
        ArrayResize(m_managed_objects, total + 1);
        m_managed_objects[total].ObjectName = obj_name;
        m_managed_objects[total].CreationBar = (long)iBars(m_symbol, _Period);
    }
}

void CVisualManager::DrawConfirmationArrow(bool is_buy, int shift)
{
    string obj_name = MEMENTO_OBJ_PREFIX + m_symbol + "_ConfirmArrow_" + (string)iTime(m_symbol, _Period, shift);
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double offset = 15 * point * m_settings.object_size_multiplier;
    double price = is_buy ? iLow(m_symbol, _Period, shift) - offset : iHigh(m_symbol, _Period, shift) + offset;
    uchar code = is_buy ? 233 : 234; // Wingdings font codes for solid arrows

    if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, iTime(m_symbol, _Period, shift), price))
    {
        ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, code);
        ObjectSetString(0, obj_name, OBJPROP_FONT, "Wingdings");
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, (int)(10 * m_settings.object_size_multiplier));
        
        int total = ArraySize(m_managed_objects);
        ArrayResize(m_managed_objects, total + 1);
        m_managed_objects[total].ObjectName = obj_name;
        m_managed_objects[total].CreationBar = (long)iBars(m_symbol, _Period);
    }
}
// +++ این تابع را با نسخه نهایی و ۱۰۰٪ صحیح جایگزین کن +++
void CVisualManager::DrawScanningArea(bool is_buy, int start_shift, int current_shift)
{
    string base_name = MEMENTO_OBJ_PREFIX + m_symbol + "_Scan_" + (string)iTime(m_symbol, _Period, start_shift);
    string rect_name = base_name + "_Rect"; 
    string vline_name = base_name + "_VLine";
    
    ObjectDelete(0, rect_name); 
    ObjectDelete(0, vline_name);

    datetime time_start_rect = iTime(m_symbol, _Period, start_shift);
    datetime time_end_rect = time_start_rect - (datetime)(m_settings.grace_period_candles + 1) * PeriodSeconds(_Period);
    
    // --- بخش جدید و اصلاح شده برای پیدا کردن سقف و کف ---
    double max_high = 0;
    double min_low = 999999; // یک عدد بسیار بزرگ برای شروع
    
    MqlRates rates[];
    // کپی کردن کندل‌های مورد نیاز برای بررسی (از کندل تاییدیه تا کندل فعلی در حال اسکن)
    int bars_to_copy = start_shift; 
    if(CopyRates(m_symbol, _Period, 1, bars_to_copy, rates) > 0)
    {
        // حلقه دستی برای پیدا کردن بالاترین سقف و پایین‌ترین کف
        for(int i = 0; i < ArraySize(rates); i++)
        {
            if(rates[i].high > max_high)
                max_high = rates[i].high;
            if(rates[i].low < min_low)
                min_low = rates[i].low;
        }
    }
    // --- پایان بخش اصلاح شده ---

    if(max_high > 0 && min_low < 999999 && ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, time_end_rect, min_low, time_start_rect, max_high))
    {
        ObjectSetInteger(0, rect_name, OBJPROP_COLOR, is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        ObjectSetInteger(0, rect_name, OBJPROP_STYLE, STYLE_DOT); 
        ObjectSetInteger(0, rect_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, rect_name, OBJPROP_FILL, false); // مستطیل توخالی
    }

    datetime scan_time = iTime(m_symbol, _Period, 1);
    if(ObjectCreate(0, vline_name, OBJ_VLINE, 0, scan_time, 0))
    {
        ObjectSetInteger(0, vline_name, OBJPROP_COLOR, clrWhite); 
        ObjectSetInteger(0, vline_name, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, vline_name, OBJPROP_WIDTH, 2);
    }
}

void CVisualManager::CleanupOldObjects(const int max_age_in_bars)
{
    if (max_age_in_bars <= 0) return;
    long current_bar_count = (long)iBars(m_symbol, _Period);
    for (int i = ArraySize(m_managed_objects) - 1; i >= 0; i--)
    {
        if (current_bar_count - m_managed_objects[i].CreationBar >= max_age_in_bars)
        {
            ObjectDelete(0, m_managed_objects[i].ObjectName);
            ArrayRemove(m_managed_objects, i, 1);
        }
    }
}

int CVisualManager::GetSymbolIndex(string symbol)
{
    for(int i = 0; i < ArraySize(m_symbols_list); i++)
    {
        if(m_symbols_list[i] == symbol) return i;
    }
    return -1;
}

void CVisualManager::UpdateDashboardCache(int symbol_index, double deal_profit, double deal_commission, double deal_swap)
{
    if(symbol_index >= 0 && symbol_index < ArraySize(m_dashboard_data))
    {
        m_dashboard_data[symbol_index].trades_count++;
        m_dashboard_data[symbol_index].cumulative_pl += deal_profit + deal_commission + deal_swap;
    }
}
