//+------------------------------------------------------------------+
//|                                                                  |
//|                    Project: Memento (By HipoAlgorithm)           |
//|                    File: VisualManager.mqh (Graphics Engine)     |
//|                    Version: 1.0 (Persistent Objects & Perf. Opt.)|
//|                    © 2025, Mohammad & Gemini                     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "© 2025, hipoalgoritm"
#property link      "https://www.mql5.com"
#property version   "1.0" // بازنویسی کامل با قابلیت اشیاء ماندگار و پاکسازی دوره‌ای

#include "set.mqh" 
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>
#include <ChartObjects\ChartObjectsArrows.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>

// ---===== ثابت‌های طراحی =====---
#define DASHBOARD_Y_POS 5       
#define DASHBOARD_X_GAP 5       
#define BOX_WIDTH 90            
#define BOX_HEIGHT 25           
#define SUB_PANEL_HEIGHT 35     
#define MEMENTO_OBJ_PREFIX "MEMENTO_UI_"

// --- ساختار برای نگهداری نام اشیاء هر جعبه در داشبورد ---
struct SPanelBox
{
    string MainBoxName, SymbolLabelName, SubPanelName, TradesLabelName, PlLabelName;
};

// --- ساختار برای مدیریت اشیاء گرافیکی کشیده شده ---
struct SManagedObject
{
    string          ObjectName;     // نام شیء
    long            CreationBar;    // شماره کندلی که شیء در آن ساخته شده
};

struct SDashboardData
{
    int    trades_count;
    double cumulative_pl;
};


//+------------------------------------------------------------------+
//| کلاس مدیریت گرافیک (بازنویسی کامل)                                |
//+------------------------------------------------------------------+
class CVisualManager
{
private:
    string              m_symbol;
    SSettings           m_settings;

    // --- متغیرهای داشبورد
    SPanelBox           m_panel_boxes[];
    string              m_symbols_list[];
    
    // --- آرایه برای ردیابی اشیاء ماندگار
    

    // --- آرایه برای ردیابی اشیاء ماندگار
    SManagedObject      m_managed_objects[];
    
    // +++ این دو خط جدید را اینجا اضافه کن +++
    SDashboardData      m_dashboard_data[];  // دفترچه حسابداری ما
    // +++ پایان بخش اضافه شده +++




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
    
    // --- توابع رسم اشیاء موقت (که نباید در لیست ردیابی ثبت شوند)
    void DrawScanningArea(bool is_buy, int start_shift, int current_shift);
    
    // --- تابع پاکسازی
   void CleanupOldObjects(const int max_age_in_bars);


    

    // این تابع ایندکس یک نماد رو در آرایه‌های ما پیدا می‌کنه
    int GetSymbolIndex(string symbol)
    {
        for(int i = 0; i < ArraySize(m_symbols_list); i++)
        {
            if(m_symbols_list[i] == symbol)
                return i;
        }
        return -1; // اگر پیدا نشد
    }

    // این تابع دفترچه حسابداری ما رو برای یک نماد آپدیت می‌کنه
    void UpdateDashboardCache(int symbol_index, double deal_profit, double deal_commission, double deal_swap)
    {
        if(symbol_index >= 0 && symbol_index < ArraySize(m_dashboard_data))
        {
            m_dashboard_data[symbol_index].trades_count++;
            m_dashboard_data[symbol_index].cumulative_pl += deal_profit + deal_commission + deal_swap;
        }
    }
    // +++ پایان بخش اضافه شده +++



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
    // در زمان نابودی شیء، تمام اشیاء گرافیکی مربوطه را پاک می‌کنیم
    Deinit();
}

bool CVisualManager::Init()
{
    ChartSetInteger(0, CHART_SHIFT, 1);
    
    // تنظیمات ظاهری چارت (اختیاری)
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrGreen);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
    ChartSetInteger(0, CHART_COLOR_CHART_UP, clrGreen);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrRed);
    
    return true;
}

void CVisualManager::Deinit()
{
    // پاک کردن تمام اشیائی که با پیشوند مخصوص این اکسپرت ساخته شده‌اند
    ObjectsDeleteAll(0, MEMENTO_OBJ_PREFIX);
    ChartRedraw(0);
}

// +++ این تابع را به طور کامل جایگزین کن +++
void CVisualManager::InitDashboard()
{
    if(!m_settings.enable_dashboard) return;
    
    StringSplit(m_settings.symbols_list, ',', m_symbols_list);
    int total_symbols = ArraySize(m_symbols_list);
    if(total_symbols == 0) return;
    
    // آماده‌سازی آرایه‌ها
    ArrayResize(m_panel_boxes, total_symbols);
    ArrayResize(m_dashboard_data, total_symbols); // <- این خط جدید است
    
    int current_x = DASHBOARD_X_GAP;

    for(int i = 0; i < total_symbols; i++)
    {
        string sym = m_symbols_list[i];
        StringTrimLeft(sym);
        StringTrimRight(sym);
        
        // --- بخش ساخت اشیاء گرافیکی (بدون تغییر) ---
        string base_name = MEMENTO_OBJ_PREFIX + sym;
        m_panel_boxes[i].MainBoxName      = base_name + "_MainBox";
        m_panel_boxes[i].SymbolLabelName  = base_name + "_SymbolLabel";
        m_panel_boxes[i].SubPanelName     = base_name + "_SubPanel";
        m_panel_boxes[i].TradesLabelName  = base_name + "_TradesLabel";
        m_panel_boxes[i].PlLabelName      = base_name + "_PlLabel";

        CChartObjectRectLabel main_box;
        main_box.Create(0, m_panel_boxes[i].MainBoxName, 0, current_x, DASHBOARD_Y_POS, BOX_WIDTH, BOX_HEIGHT);
        main_box.Color(clrGray); 
        main_box.BackColor(clrSteelBlue);
        main_box.Corner(CORNER_LEFT_UPPER); 
        main_box.Z_Order(100); 

        CChartObjectLabel symbol_label;
        symbol_label.Create(0, m_panel_boxes[i].SymbolLabelName, 0, current_x + BOX_WIDTH / 2, DASHBOARD_Y_POS + BOX_HEIGHT / 2);
        symbol_label.Description(sym); 
        symbol_label.Color(clrWhite);
        symbol_label.Font("Arial"); 
        symbol_label.FontSize(10);
        symbol_label.Anchor(ANCHOR_CENTER); 
        symbol_label.Z_Order(101);

        CChartObjectRectLabel sub_panel;
        sub_panel.Create(0, m_panel_boxes[i].SubPanelName, 0, current_x + 5, DASHBOARD_Y_POS + BOX_HEIGHT, BOX_WIDTH - 10, SUB_PANEL_HEIGHT);
        sub_panel.Color(clrSlateGray); 
        sub_panel.BackColor(clrDarkSlateGray);
        sub_panel.Corner(CORNER_LEFT_UPPER); 
        sub_panel.Z_Order(99); 
        ObjectSetInteger(0, m_panel_boxes[i].SubPanelName, OBJPROP_HIDDEN, true);

        CChartObjectLabel trades_label, pl_label;
        trades_label.Create(0, m_panel_boxes[i].TradesLabelName, 0, current_x + 10, DASHBOARD_Y_POS + BOX_HEIGHT + 10);
        pl_label.Create(0, m_panel_boxes[i].PlLabelName, 0, current_x + 10, DASHBOARD_Y_POS + BOX_HEIGHT + 25);
        trades_label.Description("Trades: 0"); 
        pl_label.Description("P/L: 0.0");
        trades_label.Color(clrWhite); 
        pl_label.Color(clrWhite);
        trades_label.Font("Arial"); 
        pl_label.Font("Arial");
        trades_label.FontSize(8); 
        pl_label.FontSize(8);
        trades_label.Anchor(ANCHOR_LEFT); 
        pl_label.Anchor(ANCHOR_LEFT);
        trades_label.Z_Order(100); 
        ObjectSetInteger(0, m_panel_boxes[i].TradesLabelName, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, m_panel_boxes[i].PlLabelName, OBJPROP_HIDDEN, true);
        
        current_x += BOX_WIDTH + DASHBOARD_X_GAP;
        
        // --- بخش جدید: حسابداری اولیه و پر کردن دفترچه ---
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

// +++ این تابع را به طور کامل جایگزین کن +++
// +++ این تابع را به طور کامل جایگزین کن +++
void CVisualManager::UpdateDashboard()
{
    if(!m_settings.enable_dashboard || ArraySize(m_symbols_list) == 0) return;

    for(int i = 0; i < ArraySize(m_symbols_list); i++)
    {
        string sym = m_symbols_list[i];
        long magic = (long)m_settings.magic_number;
        
        // --- بخش آپدیت رنگ جعبه اصلی (بدون تغییر) ---
        color box_color = clrSteelBlue; 
        if(PositionSelect(sym) && PositionGetInteger(POSITION_MAGIC) == magic)
        {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) box_color = m_settings.bullish_color;
            else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) box_color = m_settings.bearish_color;
        }
        ObjectSetInteger(0, m_panel_boxes[i].MainBoxName, OBJPROP_BGCOLOR, box_color);

        // --- بخش جدید: خواندن اطلاعات از دفترچه (کش) ---
        int trades_count = m_dashboard_data[i].trades_count;
        double cumulative_pl = m_dashboard_data[i].cumulative_pl;
        
        // --- بخش نمایش پنل زیرین بر اساس داده‌های دفترچه ---
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
    double high = iHigh(m_symbol, _Period, shift); 
    double low = iLow(m_symbol, _Period, shift);
    double window_height = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
    if(window_height <= 0) window_height = SymbolInfoDouble(m_symbol, SYMBOL_ASK) * 0.01;
    double buffer = window_height * 0.02;

    CChartObjectRectangle rect;
    if(rect.Create(0, obj_name, 0, iTime(m_symbol, _Period, shift), high + buffer, iTime(m_symbol, _Period, shift+1), low - buffer))
    {
        rect.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        rect.Style(STYLE_SOLID); 
        rect.Width(1); 
        rect.Background(true);
        ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, is_buy ? ColorToARGB(m_settings.bullish_color, 240) : ColorToARGB(m_settings.bearish_color, 240));

        // ثبت شیء در لیست ردیابی
        int total = ArraySize(m_managed_objects);
        ArrayResize(m_managed_objects, total + 1);
        m_managed_objects[total].ObjectName = obj_name;
        m_managed_objects[total].CreationBar = (long)iBars(m_symbol, _Period);
    }
}

void CVisualManager::DrawConfirmationArrow(bool is_buy, int shift)
{
    string obj_name = MEMENTO_OBJ_PREFIX + m_symbol + "_ConfirmArrow_" + (string)iTime(m_symbol, _Period, shift);
    double offset = 15 * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
    double price = is_buy ? iLow(m_symbol, _Period, shift) - offset : iHigh(m_symbol, _Period, shift) + offset;
    uchar code = is_buy ? SYMBOL_ARROWUP : SYMBOL_ARROWDOWN;

    CChartObjectArrow arrow;
    if(arrow.Create(0, obj_name, 0, iTime(m_symbol, _Period, shift), price, code))
    {
        arrow.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        arrow.Width(2);
        
        // ثبت شیء در لیست ردیابی
        int total = ArraySize(m_managed_objects);
        ArrayResize(m_managed_objects, total + 1);
        m_managed_objects[total].ObjectName = obj_name;
        m_managed_objects[total].CreationBar = (long)iBars(m_symbol, _Period);
    }
}

void CVisualManager::DrawScanningArea(bool is_buy, int start_shift, int current_shift)
{
    // این تابع اشیاء موقت می‌سازد و آنها را مدیریت می‌کند و نیازی به ثبت در لیست ردیابی ندارد
    string base_name = MEMENTO_OBJ_PREFIX + m_symbol + "_Scan_" + (string)iTime(m_symbol, _Period, start_shift);
    string rect_name = base_name + "_Rect"; 
    string vline_name = base_name + "_VLine";
    
    ObjectDelete(0, rect_name); 
    ObjectDelete(0, vline_name);

    datetime start_time = iTime(m_symbol, _Period, start_shift);
    datetime end_time = start_time + (datetime)(m_settings.grace_period_candles + 1) * PeriodSeconds(_Period);
    
    double max_high = iHigh(m_symbol, _Period, start_shift);
    double min_low = iLow(m_symbol, _Period, start_shift);
    for(int i = 1; i <= current_shift; i++)
    {
        int check_shift = start_shift - i;
        if(iBars(m_symbol, _Period) <= check_shift || check_shift < 0) continue;
        max_high = MathMax(max_high, iHigh(m_symbol, _Period, check_shift));
        min_low = MathMin(min_low, iLow(m_symbol, _Period, check_shift));
    }
    
    CChartObjectRectangle rect;
    if(rect.Create(0, rect_name, 0, start_time, max_high, end_time, min_low))
    {
        rect.Color(is_buy ? m_settings.bullish_color : m_settings.bearish_color);
        rect.Style(STYLE_DOT); 
        rect.Background(true);
        ObjectSetInteger(0, rect_name, OBJPROP_BGCOLOR, is_buy ? ColorToARGB(m_settings.bullish_color, 220) : ColorToARGB(m_settings.bearish_color, 220));
    }

    datetime scan_time = iTime(m_symbol, _Period, start_shift - current_shift);
    CChartObjectVLine vline;
    if(vline.Create(0, vline_name, 0, scan_time))
    {
        vline.Color(clrWhite); 
        vline.Style(STYLE_DASH);
    }
}

void CVisualManager::CleanupOldObjects(const int max_age_in_bars)
{
    if (max_age_in_bars <= 0) return; // اگر عدد نامعتبر بود، کاری نکن
    
    long current_bar_count = (long)iBars(m_symbol, _Period);

    // از آخر به اول حلقه میزنیم تا حذف کردن از آرایه به مشکل نخوره
    for (int i = ArraySize(m_managed_objects) - 1; i >= 0; i--)
    {
        // اگه عمر شیء از حد مجاز بیشتر بود
        if (current_bar_count - m_managed_objects[i].CreationBar >= max_age_in_bars)
        {
            // ۱. از روی چارت پاکش کن
            ObjectDelete(0, m_managed_objects[i].ObjectName);
            
            // ۲. از لیست ردیابی هم پاکش کن
            ArrayRemove(m_managed_objects, i, 1);
        }
    }
}
