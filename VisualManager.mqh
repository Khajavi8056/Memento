//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: VisualManager.mqh (Graphics Engine)     |
//|                    Version: 3.0 (Interactive Chart Panel)        |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "3.0" // بازطراحی کامل UI و افزودن نمودار سود و زیان تعاملی

#include "set.mqh" 

// ---===== ثابت‌های طراحی =====---
#define DASHBOARD_Y_POS 30      
#define DASHBOARD_X_GAP 10      
#define BOX_WIDTH 95           
#define BOX_HEIGHT 28           
#define SUB_PANEL_HEIGHT 40     
#define MEMENTO_OBJ_PREFIX "MEMENTO_UI_"

// --- ساختارهای داده ---
struct SPanelBox { string MainBoxName, SymbolLabelName, SubPanelName, TradesLabelName, PlLabelName; };
struct SManagedObject { string ObjectName; long CreationBar; };
struct SDashboardData { int trades_count; double cumulative_pl; };

//+------------------------------------------------------------------+
//| کلاس مدیریت گرافیک                                               |
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
    
    // +++ متغیرهای جدید برای نمودار میله‌ای +++
    bool                m_is_barchart_visible;
    string              m_chart_button_name;
    string              m_chart_panel_bg_name;
    string              m_chart_panel_title_name;

    void ShowBarChart(bool show); // تابع کمکی برای نمایش/پنهان کردن نمودار

public:
    CVisualManager(string symbol, SSettings &settings);
    ~CVisualManager();

    bool Init();
    void Deinit();
    void InitDashboard();
    void UpdateDashboard();
    void DrawTripleCrossRectangle(bool is_buy, int shift);
    void DrawConfirmationArrow(bool is_buy, int shift);
    void DrawScanningArea(bool is_buy, int start_shift, int current_shift);
    void CleanupOldObjects(const int max_age_in_bars);
    int GetSymbolIndex(string symbol);
    void UpdateDashboardCache(int symbol_index, double deal_profit, double deal_commission, double deal_swap);
    
    // +++ تابع جدید برای مدیریت رویدادهای چارت +++
    void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
};

//+------------------------------------------------------------------+
//|                      پیاده‌سازی توابع کلاس                        |
//+------------------------------------------------------------------+
CVisualManager::CVisualManager(string symbol, SSettings &settings)
{
    m_symbol = symbol;
    m_settings = settings;
    m_is_barchart_visible = false; // نمودار در ابتدا پنهان است
    m_chart_button_name = MEMENTO_OBJ_PREFIX + "ChartToggleButton";
    m_chart_panel_bg_name = MEMENTO_OBJ_PREFIX + "ChartPanelBg";
    m_chart_panel_title_name = MEMENTO_OBJ_PREFIX + "ChartPanelTitle";
}

CVisualManager::~CVisualManager() { Deinit(); }
bool CVisualManager::Init() { ChartSetInteger(0, CHART_SHIFT, 1); ChartSetInteger(0, CHART_SHOW_GRID, false); return true; }
void CVisualManager::Deinit() { ObjectsDeleteAll(0, MEMENTO_OBJ_PREFIX); ChartRedraw(0); }

void CVisualManager::OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == m_chart_button_name)
    {
        m_is_barchart_visible = !m_is_barchart_visible;
        ObjectSetInteger(0, m_chart_button_name, OBJPROP_STATE, m_is_barchart_visible);
        ShowBarChart(m_is_barchart_visible);
        UpdateDashboard(); 
        ChartRedraw(0);
    }
}

void CVisualManager::ShowBarChart(bool show)
{
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_HIDDEN, !show);
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_HIDDEN, !show);

    for(int i=0; i < ArraySize(m_symbols_list); i++)
    {
        string sym = m_symbols_list[i];
        ObjectSetInteger(0, MEMENTO_OBJ_PREFIX + sym + "_BarRect", OBJPROP_HIDDEN, !show);
        ObjectSetInteger(0, MEMENTO_OBJ_PREFIX + sym + "_BarLabel", OBJPROP_HIDDEN, !show);
    }
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
    
    color main_bg_color = C'26,30,38';      
    color main_border_color = C'55,65,81';  
    color sub_bg_color = C'17,20,25';       
    color text_color_bright = clrWhite;     
    color text_color_dim = clrSilver;       

    ObjectCreate(0, m_chart_button_name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_XDISTANCE, current_x);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_YDISTANCE, DASHBOARD_Y_POS);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_XSIZE, 25);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_YSIZE, BOX_HEIGHT);
    ObjectSetString(0, m_chart_button_name, OBJPROP_TEXT, "📈");
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_BGCOLOR, main_bg_color);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_BORDER_COLOR, main_border_color);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    current_x += 25 + DASHBOARD_X_GAP;

    for(int i = 0; i < total_symbols; i++)
    {
        string sym = m_symbols_list[i];
        StringTrimLeft(sym); StringTrimRight(sym);
        
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
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_COLOR, main_border_color);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_BGCOLOR, main_bg_color);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_ZORDER, 100);

        ObjectCreate(0, m_panel_boxes[i].SymbolLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_TEXT, sym);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_XDISTANCE, current_x + BOX_WIDTH / 2);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT / 2);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_COLOR, text_color_bright);
        ObjectSetString(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_FONTSIZE, 12);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_ZORDER, 101);

        ObjectCreate(0, m_panel_boxes[i].SubPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_XDISTANCE, current_x);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_XSIZE, BOX_WIDTH);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_YSIZE, SUB_PANEL_HEIGHT);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_COLOR, main_border_color);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_BGCOLOR, sub_bg_color);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_ZORDER, 99);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, true);

        ObjectCreate(0, m_panel_boxes[i].TradesLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_TEXT, "Trades: 0");
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_XDISTANCE, current_x + 5);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT + 10);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_COLOR, text_color_dim);
        ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_ZORDER, 100);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, true);

        ObjectCreate(0, m_panel_boxes[i].PlLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_TEXT, "P/L: 0.0");
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_XDISTANCE, current_x + 5);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_YDISTANCE, DASHBOARD_Y_POS + BOX_HEIGHT + 22);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_COLOR, text_color_dim);
        ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_ZORDER, 100);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, true);
        
        current_x += BOX_WIDTH + DASHBOARD_X_GAP;
        
        if(!HistorySelect(0, TimeCurrent())) continue;
        int trades_count = 0;
        double cumulative_pl = 0;
        uint total_deals = HistoryDealsTotal();
        for(uint j = 0; j < total_deals; j++) {
            ulong ticket = HistoryDealGetTicket(j);
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == sym && HistoryDealGetInteger(ticket, DEAL_MAGIC) == (long)m_settings.magic_number && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
                trades_count++;
                cumulative_pl += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
        }
        m_dashboard_data[i].trades_count = trades_count;
        m_dashboard_data[i].cumulative_pl = cumulative_pl;
    }
    
    int chart_panel_y = DASHBOARD_Y_POS + BOX_HEIGHT + SUB_PANEL_HEIGHT + 10;
    int chart_panel_width = (BOX_WIDTH + DASHBOARD_X_GAP) * total_symbols + 25;
    int chart_panel_height = 25 + (20 * total_symbols);
    
    ObjectCreate(0, m_chart_panel_bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_XDISTANCE, DASHBOARD_X_GAP);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_YDISTANCE, chart_panel_y);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_XSIZE, chart_panel_width);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_YSIZE, chart_panel_height);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_BGCOLOR, sub_bg_color);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_COLOR, main_border_color);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_ZORDER, 90);

    ObjectCreate(0, m_chart_panel_title_name, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, m_chart_panel_title_name, OBJPROP_TEXT, "P/L Distribution");
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_XDISTANCE, DASHBOARD_X_GAP + chart_panel_width/2);
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_YDISTANCE, chart_panel_y + 12);
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_COLOR, text_color_bright);
    ObjectSetString(0, m_chart_panel_title_name, OBJPROP_FONT, "Calibri");
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_ZORDER, 91);
    
    for(int i=0; i < total_symbols; i++) {
        string sym = m_symbols_list[i];
        ObjectCreate(0, MEMENTO_OBJ_PREFIX + sym + "_BarRect", OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectCreate(0, MEMENTO_OBJ_PREFIX + sym + "_BarLabel", OBJ_LABEL, 0, 0, 0);
    }
    ShowBarChart(false);
    ChartRedraw(0);
}

void CVisualManager::UpdateDashboard()
{
    if(!m_settings.enable_dashboard || ArraySize(m_symbols_list) == 0) return;
    
    int total_symbols = ArraySize(m_symbols_list);
    int current_x = DASHBOARD_X_GAP + 25 + DASHBOARD_X_GAP;

    for(int i = 0; i < total_symbols; i++)
    {
        string sym = m_symbols_list[i];
        long magic = (long)m_settings.magic_number;
        color box_color = C'26,30,38';
        color text_color = clrWhite;

        if(PositionSelect(sym) && PositionGetInteger(POSITION_MAGIC) == magic) {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                box_color = m_settings.bullish_color;
                text_color = clrBlack;
            } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                box_color = m_settings.bearish_color;
                text_color = clrWhite;
            }
        }
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_BGCOLOR, box_color);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_COLOR, text_color);
        
        int trades_count = m_dashboard_data[i].trades_count;
        double cumulative_pl = m_dashboard_data[i].cumulative_pl;
        bool show_sub_panel = trades_count > 0;
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, !show_sub_panel);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, !show_sub_panel);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, !show_sub_panel);
        
        if(show_sub_panel) {
            ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_TEXT, "Trades: " + (string)trades_count);
            ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_TEXT, "P/L: " + DoubleToString(cumulative_pl, 2));
            ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_COLOR, cumulative_pl >= 0 ? C'4,180,95' : C'240,82,90');
        }
        current_x += BOX_WIDTH + DASHBOARD_X_GAP;
    }
    
    if(m_is_barchart_visible)
    {
        double max_abs_pl = 0;
        for(int i=0; i < ArraySize(m_dashboard_data); i++)
        {
            if(MathAbs(m_dashboard_data[i].cumulative_pl) > max_abs_pl)
                max_abs_pl = MathAbs(m_dashboard_data[i].cumulative_pl);
        }
        if(max_abs_pl == 0) max_abs_pl = 1;

        int max_bar_width = BOX_WIDTH * 2;
        int current_y = DASHBOARD_Y_POS + BOX_HEIGHT + SUB_PANEL_HEIGHT + 10 + 30;

        for(int i=0; i < total_symbols; i++)
        {
            string sym = m_symbols_list[i];
            double pl = m_dashboard_data[i].cumulative_pl;
            string bar_rect_name = MEMENTO_OBJ_PREFIX + sym + "_BarRect";
            string bar_label_name = MEMENTO_OBJ_PREFIX + sym + "_BarLabel";
            
            int bar_width = (int)((MathAbs(pl) / max_abs_pl) * max_bar_width);
            color bar_color = (pl >= 0) ? C'4,180,95' : C'240,82,90';

            ObjectSetInteger(0, bar_rect_name, OBJPROP_XDISTANCE, DASHBOARD_X_GAP + 70);
            ObjectSetInteger(0, bar_rect_name, OBJPROP_YDISTANCE, current_y);
            ObjectSetInteger(0, bar_rect_name, OBJPROP_XSIZE, bar_width);
            ObjectSetInteger(0, bar_rect_name, OBJPROP_YSIZE, 15);
            ObjectSetInteger(0, bar_rect_name, OBJPROP_BGCOLOR, bar_color);
            ObjectSetInteger(0, bar_rect_name, OBJPROP_COLOR, C'55,65,81');
            ObjectSetInteger(0, bar_rect_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, bar_rect_name, OBJPROP_ZORDER, 92);
            
            string label_text = StringFormat("%s : %.2f", sym, pl);
            ObjectSetString(0, bar_label_name, OBJPROP_TEXT, label_text);
            ObjectSetInteger(0, bar_label_name, OBJPROP_XDISTANCE, DASHBOARD_X_GAP + 65);
            ObjectSetInteger(0, bar_label_name, OBJPROP_YDISTANCE, current_y + 8);
            ObjectSetInteger(0, bar_label_name, OBJPROP_COLOR, clrSilver);
            ObjectSetString(0, bar_label_name, OBJPROP_FONT, "Calibri");
            ObjectSetInteger(0, bar_label_name, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, bar_label_name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
            ObjectSetInteger(0, bar_label_name, OBJPROP_ZORDER, 93);
            
            current_y += 20;
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
    uchar code = is_buy ? 233 : 234;
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

void CVisualManager::DrawScanningArea(bool is_buy, int start_shift, int current_shift)
{
    string base_name = MEMENTO_OBJ_PREFIX + m_symbol + "_Scan_" + (string)iTime(m_symbol, _Period, start_shift);
    string rect_name = base_name + "_Rect"; 
    string vline_name = base_name + "_VLine";
    
    ObjectDelete(0, rect_name); 
    ObjectDelete(0, vline_name);
    datetime time_start_rect = iTime(m_symbol, _Period, start_shift);
    datetime time_end_rect = time_start_rect - (datetime)(m_settings.grace_period_candles + 1) * PeriodSeconds(_Period);
    
    double max_high = 0;
    double min_low = 999999;
    
    MqlRates rates[];
    int bars_to_copy = start_shift; 
    if(CopyRates(m_symbol, _Period, 1, bars_to_copy, rates) > 0)
    {
        for(int i = 0; i < ArraySize(rates); i++)
        {
            if(rates[i].high > max_high) max_high = rates[i].high;
            if(rates[i].low < min_low) min_low = rates[i].low;
        }
    }
    
    if(max_high > 0 && min_low < 999999 && ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, time_end_rect, min_low, time_start_rect, max_high))
    {
        ObjectSetInteger(0, rect_name, OBJPROP_COLOR, is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        ObjectSetInteger(0, rect_name, OBJPROP_STYLE, STYLE_DOT); 
        ObjectSetInteger(0, rect_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, rect_name, OBJPROP_FILL, false);
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
