//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: VisualManager.mqh (Graphics Engine)     |
//|                    Version: 4.0 (Responsive & Regime-Aware)      |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "4.0"

#include "set.mqh"

// --- ثابت‌های طراحی پایه (قابل مقیاس‌پذیری) ---
#define BASE_DASHBOARD_Y_POS 30
#define BASE_DASHBOARD_X_GAP 10
#define BASE_BOX_WIDTH 95
#define BASE_BOX_HEIGHT 28
#define BASE_SUB_PANEL_HEIGHT 40
#define MEMENTO_OBJ_PREFIX "MEMENTO_UI_"

// --- ساختارهای داده ---
struct SPanelBox { string MainBoxName, SymbolLabelName, SubPanelName, TradesLabelName, PlLabelName; };
struct SManagedObject { string ObjectName; long CreationBar; ENUM_TIMEFRAMES Timeframe; };
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
    
    // آبجکت‌های مربوط به نمایشگر رژیم بازار
    string              m_regime_panel_bg_name;
    string              m_regime_panel_label_name;

    bool                m_is_barchart_visible;
    string              m_chart_button_name;
    string              m_chart_panel_bg_name;
    string              m_chart_panel_title_name;

    void ShowBarChart(bool show);
    void CreateManagedObject(string obj_name, long creation_bar, ENUM_TIMEFRAMES timeframe);
    
public:
    CVisualManager(string symbol, SSettings &settings);
    ~CVisualManager();

    bool Init();
    void Deinit();
    void InitDashboard();
    void UpdateDashboard();
    
    // --- تابع جدید برای آپدیت وضعیت رژیم بازار ---
    void UpdateRegimeStatus(string text, color clr);

    void DrawTripleCrossRectangle(bool is_buy, int shift, ENUM_TIMEFRAMES timeframe);
    void DrawConfirmationArrow(bool is_buy, int shift, ENUM_TIMEFRAMES timeframe);
    void DrawScanningArea(bool is_buy, int start_shift, int current_shift, ENUM_TIMEFRAMES timeframe);
    void CleanupOldObjects(const int max_age_in_bars, ENUM_TIMEFRAMES timeframe);
    int GetSymbolIndex(string symbol);
    void UpdateDashboardCache(int symbol_index, double deal_profit, double deal_commission, double deal_swap);
    void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
};

//+------------------------------------------------------------------+
//|                      پیاده‌سازی توابع کلاس                        |
//+------------------------------------------------------------------+
CVisualManager::CVisualManager(string symbol, SSettings &settings)
{
    m_symbol = symbol;
    m_settings = settings;
    m_is_barchart_visible = false;
    
    // تعریف نام آبجکت‌ها در کانستراکتور
    m_regime_panel_bg_name = MEMENTO_OBJ_PREFIX + "RegimePanelBg";
    m_regime_panel_label_name = MEMENTO_OBJ_PREFIX + "RegimePanelLabel";
    m_chart_button_name = MEMENTO_OBJ_PREFIX + "ChartToggleButton";
    m_chart_panel_bg_name = MEMENTO_OBJ_PREFIX + "ChartPanelBg";
    m_chart_panel_title_name = MEMENTO_OBJ_PREFIX + "ChartPanelTitle";
}

CVisualManager::~CVisualManager() { Deinit(); }

bool CVisualManager::Init()
{
    ChartSetInteger(0, CHART_SHIFT, 1);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    return true;
}

void CVisualManager::Deinit()
{
    ObjectsDeleteAll(0, MEMENTO_OBJ_PREFIX);
    ChartRedraw(0);
}

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
    
    // --- بخش هوشمند و واکنش‌گرا ---
    long chart_width = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
    double scale_factor = 1.0;
    
    // محاسبه عرض مورد نیاز برای داشبورد (شامل پنل رژیم)
    double required_width = (BASE_BOX_WIDTH + BASE_DASHBOARD_X_GAP) * total_symbols + 25 + BASE_DASHBOARD_X_GAP + 170; // 170 برای پنل رژیم
    if (required_width > chart_width)
    {
        scale_factor = chart_width / required_width;
    }
    
    // مقیاس‌دهی به ابعاد بر اساس اندازه چارت
    int box_width = (int)(BASE_BOX_WIDTH * scale_factor);
    int x_gap = (int)(BASE_DASHBOARD_X_GAP * scale_factor);
    int box_height = BASE_BOX_HEIGHT; // ارتفاع ثابت می‌ماند
    int sub_panel_height = BASE_SUB_PANEL_HEIGHT; // ارتفاع ساب‌پنل ثابت
    int y_pos = BASE_DASHBOARD_Y_POS;
    
    int current_x = x_gap;
    
    // --- استایل‌های طراحی ---
    color main_bg_color = C'26,30,38';      
    color main_border_color = C'55,65,81';  
    color sub_bg_color = C'17,20,25';       
    color text_color_bright = clrWhite;     
    color text_color_dim = clrSilver;  

    // --- ایجاد دکمه چارت (بدون تغییر) ---
    ObjectCreate(0, m_chart_button_name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_XDISTANCE, current_x);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_YDISTANCE, y_pos);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_XSIZE, 25);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_YSIZE, box_height);
    ObjectSetString(0, m_chart_button_name, OBJPROP_TEXT, "📈");
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_BGCOLOR, main_bg_color);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_BORDER_COLOR, main_border_color);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, m_chart_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    current_x += 25 + x_gap;

    // --- ایجاد پنل رژیم بازار ---
    int regime_width = (int)(170 * scale_factor);
    ObjectCreate(0, m_regime_panel_bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, m_regime_panel_bg_name, OBJPROP_XDISTANCE, current_x);
    ObjectSetInteger(0, m_regime_panel_bg_name, OBJPROP_YDISTANCE, y_pos);
    ObjectSetInteger(0, m_regime_panel_bg_name, OBJPROP_XSIZE, regime_width);
    ObjectSetInteger(0, m_regime_panel_bg_name, OBJPROP_YSIZE, box_height);
    ObjectSetInteger(0, m_regime_panel_bg_name, OBJPROP_COLOR, main_border_color);
    ObjectSetInteger(0, m_regime_panel_bg_name, OBJPROP_BGCOLOR, C'10,10,10');
    ObjectSetInteger(0, m_regime_panel_bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    ObjectCreate(0, m_regime_panel_label_name, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, m_regime_panel_label_name, OBJPROP_TEXT, "Regime: UNDEFINED");
    ObjectSetInteger(0, m_regime_panel_label_name, OBJPROP_XDISTANCE, current_x + regime_width / 2);
    ObjectSetInteger(0, m_regime_panel_label_name, OBJPROP_YDISTANCE, y_pos + box_height / 2);
    ObjectSetInteger(0, m_regime_panel_label_name, OBJPROP_COLOR, clrGray);
    ObjectSetString(0, m_regime_panel_label_name, OBJPROP_FONT, "Calibri");
    ObjectSetInteger(0, m_regime_panel_label_name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, m_regime_panel_label_name, OBJPROP_ANCHOR, ANCHOR_CENTER);

    current_x += regime_width + x_gap;

    // --- ایجاد پنل نمادها (با ابعاد مقیاس‌پذیر) ---
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
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_YDISTANCE, y_pos);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_XSIZE, box_width);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_YSIZE, box_height);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_COLOR, main_border_color);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_BGCOLOR, main_bg_color);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_ZORDER, 100);

        ObjectCreate(0, m_panel_boxes[i].SymbolLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_TEXT, sym);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_XDISTANCE, current_x + box_width / 2);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_YDISTANCE, y_pos + box_height / 2);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_COLOR, text_color_bright);
        ObjectSetString(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_FONTSIZE, 12);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, m_panel_boxes[i].SymbolLabelName, OBJPROP_ZORDER, 101);

        ObjectCreate(0, m_panel_boxes[i].SubPanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_XDISTANCE, current_x);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_YDISTANCE, y_pos + box_height);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_XSIZE, box_width);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_YSIZE, sub_panel_height);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_COLOR, main_border_color);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_BGCOLOR, sub_bg_color);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_ZORDER, 99);
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, true);

        ObjectCreate(0, m_panel_boxes[i].TradesLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_TEXT, "Trades: 0");
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_XDISTANCE, current_x + 5);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_YDISTANCE, y_pos + box_height + 10);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_COLOR, text_color_dim);
        ObjectSetString(0, m_panel_boxes[i].TradesLabelName, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, true);

        ObjectCreate(0, m_panel_boxes[i].PlLabelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_TEXT, "P/L: 0.0");
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_XDISTANCE, current_x + 5);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_YDISTANCE, y_pos + box_height + 22);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_COLOR, text_color_dim);
        ObjectSetString(0, m_panel_boxes[i].PlLabelName, OBJPROP_FONT, "Calibri");
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, true);
        
        current_x += box_width + x_gap;
        
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
    
    int chart_panel_y = y_pos + box_height + sub_panel_height + 10;
    int chart_panel_width = (box_width + x_gap) * total_symbols + 25;
    int chart_panel_height = 25 + (20 * total_symbols);
    
    ObjectCreate(0, m_chart_panel_bg_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_XDISTANCE, x_gap);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_YDISTANCE, chart_panel_y);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_XSIZE, chart_panel_width);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_YSIZE, chart_panel_height);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_BGCOLOR, sub_bg_color);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_COLOR, main_border_color);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, m_chart_panel_bg_name, OBJPROP_ZORDER, 90);

    ObjectCreate(0, m_chart_panel_title_name, OBJ_LABEL, 0, 0, 0);
    ObjectSetString(0, m_chart_panel_title_name, OBJPROP_TEXT, "P/L Distribution");
    ObjectSetInteger(0, m_chart_panel_title_name, OBJPROP_XDISTANCE, x_gap + chart_panel_width/2);
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

void CVisualManager::UpdateRegimeStatus(string text, color clr)
{
    if (ObjectFind(0, m_regime_panel_label_name) >= 0)
    {
        ObjectSetString(0, m_regime_panel_label_name, OBJPROP_TEXT, "Regime: " + text);
        ObjectSetInteger(0, m_regime_panel_label_name, OBJPROP_COLOR, clr);
        ChartRedraw(0);
    }
}

void CVisualManager::DrawTripleCrossRectangle(bool is_buy, int shift, ENUM_TIMEFRAMES timeframe)
{
    string obj_name_rect = MEMENTO_OBJ_PREFIX + m_symbol + "_SignalRect_" + (string)iTime(m_symbol, timeframe, shift);
    string obj_name_arrow = MEMENTO_OBJ_PREFIX + m_symbol + "_SignalArrow_" + (string)iTime(m_symbol, timeframe, shift);
    
    ObjectDelete(0, obj_name_rect);
    ObjectDelete(0, obj_name_arrow);

    datetime time1 = iTime(m_symbol, timeframe, shift + 1);
    datetime time2 = iTime(m_symbol, timeframe, shift);
    double high = iHigh(m_symbol, timeframe, shift); 
    double low = iLow(m_symbol, timeframe, shift);
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double buffer = 10 * point * m_settings.object_size_multiplier;
    
    if(ObjectCreate(0, obj_name_rect, OBJ_RECTANGLE, 0, time1, low - buffer, time2, high + buffer))
    {
        ObjectSetInteger(0, obj_name_rect, OBJPROP_COLOR, is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        ObjectSetInteger(0, obj_name_rect, OBJPROP_STYLE, STYLE_SOLID); 
        ObjectSetInteger(0, obj_name_rect, OBJPROP_WIDTH, 1); 
        ObjectSetInteger(0, obj_name_rect, OBJPROP_BACK, true);
        ObjectSetInteger(0, obj_name_rect, OBJPROP_FILL, false);
        CreateManagedObject(obj_name_rect, (long)iBars(m_symbol, timeframe), timeframe);
    }
    
    double arrow_offset = 5 * point * m_settings.object_size_multiplier;
    double price = is_buy ? low - arrow_offset : high + arrow_offset;
    uchar code = is_buy ? 211 : 212;
    
    if(ObjectCreate(0, obj_name_arrow, OBJ_ARROW, 0, time2, price))
    {
        ObjectSetInteger(0, obj_name_arrow, OBJPROP_ARROWCODE, code);
        ObjectSetString(0, obj_name_arrow, OBJPROP_FONT, "Wingdings");
        ObjectSetInteger(0, obj_name_arrow, OBJPROP_COLOR, is_buy ? clrGreen : clrRed); 
        ObjectSetInteger(0, obj_name_arrow, OBJPROP_WIDTH, (int)(2 * m_settings.object_size_multiplier)); 
        CreateManagedObject(obj_name_arrow, (long)iBars(m_symbol, timeframe), timeframe);
    }
}

void CVisualManager::DrawConfirmationArrow(bool is_buy, int shift, ENUM_TIMEFRAMES timeframe)
{
    string obj_name = MEMENTO_OBJ_PREFIX + m_symbol + "_ConfirmArrow_" + (string)iTime(m_symbol, timeframe, shift);
    ObjectDelete(0, obj_name);
    
    double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double offset = 15 * point * m_settings.object_size_multiplier;
    double price = is_buy ? iLow(m_symbol, timeframe, shift) - offset : iHigh(m_symbol, timeframe, shift) + offset;
    
    double candle_range = MathAbs(iHigh(m_symbol, timeframe, shift) - iLow(m_symbol, timeframe, shift));
    double final_offset = candle_range * 0.5;
    price = is_buy ? iLow(m_symbol, timeframe, shift) - final_offset : iHigh(m_symbol, timeframe, shift) + final_offset;
    
    uchar code = 181;
    color arrow_color = is_buy ? m_settings.bullish_color : m_settings.bearish_color;

    if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, iTime(m_symbol, timeframe, shift), price))
    {
        ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, code);
        ObjectSetString(0, obj_name, OBJPROP_FONT, "Wingdings");
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, arrow_color);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, (int)(5 * m_settings.object_size_multiplier));
        CreateManagedObject(obj_name, (long)iBars(m_symbol, timeframe), timeframe);
    }
}

void CVisualManager::DrawScanningArea(bool is_buy, int start_shift, int current_shift, ENUM_TIMEFRAMES timeframe)
{
    string rect_name = MEMENTO_OBJ_PREFIX + m_symbol + "_ScanningRect";
    
    ObjectDelete(0, rect_name);
    
    if (current_shift < 1 || current_shift > start_shift) return;

    double max_high = 0;
    double min_low = 999999;
    
    MqlRates rates[];
    int bars_to_copy = start_shift - current_shift + 1;
    if(CopyRates(m_symbol, timeframe, current_shift, bars_to_copy, rates) > 0)
    {
        for(int i = 0; i < ArraySize(rates); i++)
        {
            if(rates[i].high > max_high) max_high = rates[i].high;
            if(rates[i].low < min_low) min_low = rates[i].low;
        }
    }

    if(max_high > 0 && min_low < 999999)
    {
        datetime time_start_rect = iTime(m_symbol, timeframe, start_shift);
        datetime time_end_rect = iTime(m_symbol, timeframe, current_shift);
        
        if(ObjectCreate(0, rect_name, OBJ_RECTANGLE, 0, time_start_rect, min_low, time_end_rect, max_high))
        {
            color scan_color = is_buy ? clrLightSkyBlue : clrPaleGoldenrod;
            ObjectSetInteger(0, rect_name, OBJPROP_COLOR, scan_color);
            ObjectSetInteger(0, rect_name, OBJPROP_STYLE, STYLE_SOLID); 
            ObjectSetInteger(0, rect_name, OBJPROP_WIDTH, 1); 
            ObjectSetInteger(0, rect_name, OBJPROP_BACK, true);
            ObjectSetInteger(0, rect_name, OBJPROP_FILL, true);
            ObjectSetInteger(0, rect_name, OBJPROP_SELECTABLE, false);
            CreateManagedObject(rect_name, (long)iBars(m_symbol, timeframe), timeframe);
        }
    }
}

void CVisualManager::CleanupOldObjects(const int max_age_in_bars, ENUM_TIMEFRAMES timeframe)
{
    if (max_age_in_bars <= 0) return;
    long current_bar_count = (long)iBars(m_symbol, timeframe);
    for (int i = ArraySize(m_managed_objects) - 1; i >= 0; i--)
    {
        if (m_managed_objects[i].Timeframe == timeframe && 
            current_bar_count - m_managed_objects[i].CreationBar >= max_age_in_bars)
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

void CVisualManager::CreateManagedObject(string obj_name, long creation_bar, ENUM_TIMEFRAMES timeframe)
{
    int total = ArraySize(m_managed_objects);
    ArrayResize(m_managed_objects, total + 1);
    m_managed_objects[total].ObjectName = obj_name;
    m_managed_objects[total].CreationBar = creation_bar;
    m_managed_objects[total].Timeframe = timeframe;
}
