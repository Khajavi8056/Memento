//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: VisualManager.mqh (Graphics Engine)     |
//|                    Version: 3.5 (Final Naming Fix)               |
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "3.5" // اصلاح نهایی نام کلاس‌ها و توابع

#include "set.mqh" 
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>
#include <ChartObjects\ChartObjectsArrows.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

// ---===== ثابت‌های طراحی داشبورد =====---
#define DASHBOARD_Y_POS 5       // فاصله داشبورد از بالای چارت
#define DASHBOARD_X_GAP 5       // فاصله افقی بین هر جعبه
#define BOX_WIDTH 90            // عرض هر جعبه
#define BOX_HEIGHT 25           // ارتفاع جعبه اصلی
#define SUB_PANEL_HEIGHT 35     // ارتفاع پنل زیرین (سود و زیان)
#define MEMENTO_OBJ_PREFIX "MEMENTO_UI_" // پیشوند کلی برای تمام اشیاء

// --- ساختار برای نگهداری نام اشیاء هر جعبه در داشبورد ---
struct SPanelBox
{
    string MainBoxName;
    string SymbolLabelName;
    string SubPanelName;
    string TradesLabelName;
    string PlLabelName;
};

//+------------------------------------------------------------------+
//| کلاس مدیریت گرافیک (بازنویسی شده)                                 |
//+------------------------------------------------------------------+
class CVisualManager
{
private:
    string              m_symbol;
    SSettings           m_settings;
    long                m_chart_id;
    
    // --- متغیرهای مخصوص داشبورد ---
    SPanelBox           m_panel_boxes[];
    string              m_symbols_list[];

public:
    CVisualManager(string symbol, SSettings &settings);
    ~CVisualManager();
    bool Init();
    void Deinit();
    void InitDashboard();
    void UpdateDashboard();
    void DrawTripleCrossRectangle(bool is_buy, int shift);
    void DrawConfirmationArrow(bool is_buy, int shift);
    void ClearSignalGraphics(int signal_shift);
    void DrawScanningArea(bool is_buy, int start_shift, int current_shift);
};

//+------------------------------------------------------------------+
//|                      پیاده‌سازی توابع کلاس                        |
//+------------------------------------------------------------------+
CVisualManager::CVisualManager(string symbol, SSettings &settings)
{
    m_symbol = symbol;
    m_settings = settings;
    m_chart_id = ChartID();
}
CVisualManager::~CVisualManager() {}

bool CVisualManager::Init()
{
 // غیرفعال کردن گرید چارت
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   
   // تنظیم رنگ کندل‌ها
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrGreen);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrGreen);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrRed);
   
    ChartSetInteger(m_chart_id, CHART_SHIFT, 1);
    return true;
}

void CVisualManager::Deinit()
{
    ObjectsDeleteAll(m_chart_id, MEMENTO_OBJ_PREFIX);
    ChartRedraw(m_chart_id);
}

void CVisualManager::InitDashboard()
{
    if(!m_settings.enable_dashboard) return;
    StringSplit(m_settings.symbols_list, ',', m_symbols_list);
    int total_symbols = ArraySize(m_symbols_list);
    if(total_symbols == 0) return;
    ArrayResize(m_panel_boxes, total_symbols);
    int current_x = DASHBOARD_X_GAP;

    for(int i = 0; i < total_symbols; i++)
    {
        string sym = m_symbols_list[i];
        string base_name = MEMENTO_OBJ_PREFIX + sym;
        m_panel_boxes[i].MainBoxName      = base_name + "_MainBox";
        m_panel_boxes[i].SymbolLabelName  = base_name + "_SymbolLabel";
        m_panel_boxes[i].SubPanelName     = base_name + "_SubPanel";
        m_panel_boxes[i].TradesLabelName  = base_name + "_TradesLabel";
        m_panel_boxes[i].PlLabelName      = base_name + "_PlLabel";

        // ✅✅✅ اصلاح شد: استفاده از نام صحیح کلاس CChartObjectRectLabel ✅✅✅
        CChartObjectRectLabel main_box;
        main_box.Create(m_chart_id, m_panel_boxes[i].MainBoxName, 0, current_x, DASHBOARD_Y_POS, BOX_WIDTH, BOX_HEIGHT);
        main_box.Color(clrGray); main_box.BackColor(clrDimGray);
        main_box.Corner(CORNER_LEFT_UPPER); main_box.Z_Order(0);

        CChartObjectLabel symbol_label;
        symbol_label.Create(m_chart_id, m_panel_boxes[i].SymbolLabelName, 0, current_x + BOX_WIDTH / 2, DASHBOARD_Y_POS + BOX_HEIGHT / 2);
        symbol_label.Description(sym); symbol_label.Color(clrWhite);
        symbol_label.Font("Arial"); symbol_label.FontSize(10);
        symbol_label.Anchor(ANCHOR_CENTER); symbol_label.Z_Order(1);
        
        // ✅✅✅ اصلاح شد: استفاده از نام صحیح کلاس CChartObjectRectLabel ✅✅✅
        CChartObjectRectLabel sub_panel;
        sub_panel.Create(m_chart_id, m_panel_boxes[i].SubPanelName, 0, current_x + 5, DASHBOARD_Y_POS + BOX_HEIGHT, BOX_WIDTH - 10, SUB_PANEL_HEIGHT);
        sub_panel.Color(ColorToARGB(clrBlack, 100)); sub_panel.BackColor(ColorToARGB(clrBlack, 50));
        sub_panel.Corner(CORNER_LEFT_UPPER); sub_panel.Z_Order(-1);
        ObjectSetInteger(m_chart_id, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, true);

        CChartObjectLabel trades_label, pl_label;
        trades_label.Create(m_chart_id, m_panel_boxes[i].TradesLabelName, 0, current_x + 10, DASHBOARD_Y_POS + BOX_HEIGHT + 10);
        pl_label.Create(m_chart_id, m_panel_boxes[i].PlLabelName, 0, current_x + 10, DASHBOARD_Y_POS + BOX_HEIGHT + 25);
        trades_label.Description("Trades: 0"); pl_label.Description("P/L: 0.0");
        trades_label.Color(clrWhite); pl_label.Color(clrWhite);
        trades_label.Font("Arial"); pl_label.Font("Arial");
        trades_label.FontSize(8); pl_label.FontSize(8);
        trades_label.Anchor(ANCHOR_LEFT); pl_label.Anchor(ANCHOR_LEFT);
        trades_label.Z_Order(0);
        ObjectSetInteger(m_chart_id, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, true);
        ObjectSetInteger(m_chart_id, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, true);
        
        current_x += BOX_WIDTH + DASHBOARD_X_GAP;
    }
    ChartRedraw(m_chart_id);
}

void CVisualManager::UpdateDashboard()
{
    if(!m_settings.enable_dashboard) { Deinit(); return; }
    if(ArraySize(m_symbols_list) == 0) return;

    for(int i = 0; i < ArraySize(m_symbols_list); i++)
    {
        string sym = m_symbols_list[i];
        long magic = m_settings.magic_number;
        color box_color = clrDimGray;
        if(PositionSelect(sym) && PositionGetInteger(POSITION_MAGIC) == magic)
        {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) box_color = clrDarkGreen;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) box_color = clrMaroon;
        }
        ObjectSetInteger(m_chart_id, m_panel_boxes[i].MainBoxName, OBJPROP_BGCOLOR, box_color);

        if(!HistorySelect(0, TimeCurrent())) continue;
        int trades_count = 0;
        double cumulative_pl = 0;
        uint total_deals = HistoryDealsTotal();
        for(uint j = 0; j < total_deals; j++)
        {
            ulong ticket = HistoryDealGetTicket(j);
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == sym && HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic && HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
                trades_count++;
                cumulative_pl += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
        }
        
        bool show_sub_panel = trades_count > 0;
        ObjectSetInteger(m_chart_id, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, !show_sub_panel);
        ObjectSetInteger(m_chart_id, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, !show_sub_panel);
        ObjectSetInteger(m_chart_id, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, !show_sub_panel);
        if(show_sub_panel)
        {
            ObjectSetString(m_chart_id, m_panel_boxes[i].TradesLabelName, OBJPROP_TEXT, "Trades: " + (string)trades_count);
            ObjectSetString(m_chart_id, m_panel_boxes[i].PlLabelName, OBJPROP_TEXT, "P/L: " + DoubleToString(cumulative_pl, 2));
            ObjectSetInteger(m_chart_id, m_panel_boxes[i].PlLabelName, OBJPROP_COLOR, cumulative_pl >= 0 ? clrLime : clrRed);
        }
    }
}

void CVisualManager::DrawTripleCrossRectangle(bool is_buy, int shift)
{
    string obj_name = MEMENTO_OBJ_PREFIX + m_symbol + "_SignalRect_" + (string)iTime(m_symbol, _Period, shift);
    double high = iHigh(m_symbol, _Period, shift); double low = iLow(m_symbol, _Period, shift);
    double window_height = ChartGetDouble(m_chart_id, CHART_PRICE_MAX) - ChartGetDouble(m_chart_id, CHART_PRICE_MIN);
    if(window_height <= 0) window_height = SymbolInfoDouble(m_symbol, SYMBOL_ASK) * 0.01;
    double buffer = window_height * 0.02;
    CChartObjectRectangle rect;
    if(rect.Create(m_chart_id, obj_name, 0, iTime(m_symbol, _Period, shift), high + buffer, iTime(m_symbol, _Period, shift-1), low - buffer))
    {
        rect.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        rect.Style(STYLE_SOLID); rect.Width(1); rect.Background(true);
    }
}

void CVisualManager::DrawScanningArea(bool is_buy, int start_shift, int current_shift)
{
    string base_name = MEMENTO_OBJ_PREFIX + m_symbol + "_Scan_" + (string)iTime(m_symbol, _Period, start_shift);
    string rect_name = base_name + "_Rect"; string vline_name = base_name + "_VLine";
    ObjectDelete(m_chart_id, rect_name); ObjectDelete(m_chart_id, vline_name);
    datetime start_time = iTime(m_symbol, _Period, start_shift);
    datetime end_time = start_time + (datetime)(m_settings.grace_period_candles + 1) * PeriodSeconds(_Period);
    double max_high = iHigh(m_symbol, _Period, start_shift); double min_low = iLow(m_symbol, _Period, start_shift);
    for(int i = 1; i <= m_settings.grace_period_candles; i++)
    {
        int check_shift = start_shift - i;
        if(iBars(m_symbol, _Period) <= check_shift || check_shift < 0) continue;
        max_high = MathMax(max_high, iHigh(m_symbol, _Period, check_shift));
        min_low = MathMin(min_low, iLow(m_symbol, _Period, check_shift));
    }
    CChartObjectRectangle rect;
    if(rect.Create(m_chart_id, rect_name, 0, start_time, max_high, end_time, min_low))
    {
        rect.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        rect.Style(STYLE_DOT); rect.Background(true);
        ObjectSetInteger(m_chart_id, rect_name, OBJPROP_BGCOLOR, is_buy ? ColorToARGB(m_settings.bullish_color, 220) : ColorToARGB(m_settings.bearish_color, 220));
    }
    datetime scan_time = iTime(m_symbol, _Period, start_shift - current_shift);
    CChartObjectVLine vline;
    if(vline.Create(m_chart_id, vline_name, 0, scan_time))
    {
        vline.Color(clrWhite); vline.Style(STYLE_DASH);
    }
}

void CVisualManager::ClearSignalGraphics(int signal_shift)
{
    string base_name_rect = MEMENTO_OBJ_PREFIX + m_symbol + "_SignalRect_" + (string)iTime(m_symbol, _Period, signal_shift);
    string base_name_scan = MEMENTO_OBJ_PREFIX + m_symbol + "_Scan_" + (string)iTime(m_symbol, _Period, signal_shift);
    ObjectDelete(m_chart_id, base_name_rect);
    ObjectsDeleteAll(m_chart_id, base_name_scan);
}

void CVisualManager::DrawConfirmationArrow(bool is_buy, int shift)
{
    ClearSignalGraphics(m_settings.chikou_period);
    string obj_name = MEMENTO_OBJ_PREFIX + m_symbol + "_ConfirmArrow_" + (string)iTime(m_symbol, _Period, shift);
    double offset = 10 * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double price = is_buy ? iLow(m_symbol, _Period, shift) - offset : iHigh(m_symbol, _Period, shift) + offset;
    uchar code = is_buy ? 223 : 224;
    CChartObjectArrow arrow;
    // ✅✅✅ اصلاح شد: کد freccia به صورت مستقیم در تابع Create پاس داده می‌شود ✅✅✅
    if(arrow.Create(m_chart_id, obj_name, 0, iTime(m_symbol, _Period, shift), price, code))
    {
        arrow.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        arrow.Width(2);
    }
}
