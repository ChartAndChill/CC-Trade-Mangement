//+------------------------------------------------------------------+
//|                                       CC_TradingManagement.mq5   |
//|                        CC Trading Management  v4.40              |
//|                                                                  |
//|   YouTube : https://www.youtube.com/@ChartAndChill               |
//|   This tool is FREE - forever. Please subscribe to support it.   |
//+------------------------------------------------------------------+
#property copyright "ChartAndChill"
#property link      "https://www.youtube.com/@ChartAndChill"
#property version   "4.40"
#property description "CC Trading Management - risk & execution panel with a TradingView style position tool"
#property description "Tools: Sessions | POC + Value Area | VWAP | Hooman levels"
#property description "YouTube: @ChartAndChill - free forever, please subscribe."

#include <Trade\Trade.mqh>

//==================================================================
//                            INPUTS
//==================================================================
input group "===== Risk & Execution ====="
input double InpRiskPct      = 1.0;      // Risk per trade (%)
input double InpRR           = 2.0;      // Reward : Risk
input int    InpSLPts        = 200;      // Stop loss (points)
input int    InpLimitDist    = 100;      // Pending order distance (points)
input int    InpDeviation    = 20;       // Max slippage (points)
input ulong  InpMagic        = 1680;     // Magic number
input bool   InpTrailOn      = false;    // Trailing stop
input int    InpTrailStart   = 100;      // Trailing start (points)
input int    InpTrailStep    = 50;       // Trailing distance (points)

input group "===== Tools on start ====="
input bool   InpSessOn       = true;     // Session boxes
input bool   InpPocOn        = true;     // POC / Volume profile
input bool   InpVwapOn       = true;     // VWAP
input bool   InpHoomanOn     = true;     // Hooman levels
input bool   InpToolOn       = false;    // TP/SL tool (long) on start

input group "===== Tool settings ====="
input int    InpPOCBars      = 150;      // POC: bars in profile
input int    InpPOCBins      = 40;       // POC: price bins
input bool   InpPOCValueArea = true;     // POC: draw 70% value area
input int    InpVwapMaxBars  = 400;      // VWAP: max segments drawn
input int    InpSessDays     = 2;        // Sessions: days back
input int    InpConflPts     = 30;       // VWAP/POC confluence (points)

input group "===== Session hours (GMT) ====="
input int    InpAsiaOpen     = 0;        // Asia open (GMT hour)
input int    InpAsiaClose    = 9;        // Asia close (GMT hour)
input int    InpLonOpen      = 7;        // London open (GMT hour)
input int    InpLonClose     = 16;       // London close (GMT hour)
input int    InpNyOpen       = 13;       // New York open (GMT hour)
input int    InpNyClose      = 22;       // New York close (GMT hour)

input group "===== Panel colors ====="
input color  InpPanelBody    = C'96,118,168';   // Panel body (light navy blue)
input color  InpPanelHead    = C'40,56,96';     // Panel header / buttons (navy)
input color  InpPanelAccent  = C'255,204,0';    // Active toggle accent (gold)
input int    InpWelcomeSec   = 30;       // Welcome card duration (sec, 0=off)

input group "===== Chart colors ====="
input color  InpPocColor     = C'233,30,120';   // POC (deep pink)
input color  InpVwapColor    = C'224,168,20';   // VWAP (deep gold)
input color  InpAsiaColor    = C'46,125,225';   // Asia session box
input color  InpLonColor     = C'150,80,215';   // London session box
input color  InpNyColor      = C'240,140,30';   // New York session box
input int    InpSessOpacity  = 12;       // Session fill opacity % (0=off, 100=solid)
input bool   InpSessEdges    = true;     // Session high / low edge lines

input group "===== Position tool (TradingView style) ====="
input color  InpTpColor      = C'38,196,120';   // Target line / profit zone
input color  InpSlColor      = C'235,70,70';    // Stop line / loss zone
input color  InpEntryColor   = C'160,170,190';  // Entry line
input int    InpToolOpacity  = 22;       // Zone fill opacity %
input int    InpToolBars     = 25;       // Zone width (bars to the right)

input group "===== Hooman levels ====="
input color  InpHmHiLo       = C'255,220,0';    // 0% / 100% (yellow, solid)
input color  InpHmMid        = C'0,210,100';    // 50% (green, solid)
input color  InpHmQuarter    = C'255,220,0';    // 25% / 75% (yellow, dashed)
input color  InpHmEighth     = C'255,255,255';  // 12.5% steps (white, dashed)

input group "===== Strategy Tester only ====="
// A manual panel cannot trade in the Strategy Tester: OnChartEvent (button
// clicks) is never fired there. This built-in EMA-cross strategy runs ONLY
// inside the tester, so the product can be validated and back-tested.
// It has no effect whatsoever on a live or demo chart.
input bool   InpTesterAuto   = true;     // Auto strategy in Strategy Tester
input int    InpAutoFast     = 9;        // Auto: fast EMA period
input int    InpAutoSlow     = 21;       // Auto: slow EMA period
input double InpAutoAtrSL    = 1.5;      // Auto: stop loss = ATR x

//==================================================================
//                        CONSTANTS
//==================================================================
#define PX   "CCM_"      // panel
#define SP   "CCS_"      // sessions
#define PP   "CCP_"      // poc
#define VP   "CCV_"      // vwap
#define HP   "CCH_"      // hooman
#define TP_  "CCT_"      // position tool
#define WP   "CCW_"      // welcome card

#define PW      236      // panel width
#define HDR_H   32       // header height
#define PAD     12       // inner padding

#define FONT_UI  "Segoe UI"
#define FONT_NUM "Consolas"

#define MAX_RISK_PCT    3.0     // absolute ceiling per trade, % of capital
#define MAX_MARGIN_PCT  5.0     // share of free margin one order may use
#define TESTER_EQ_FLOOR 0.5     // tester strategy halts below this x start equity
#define TESTER_RISK_PCT 0.5     // risk per trade inside the tester
#define GUI_MS          300     // minimum interval between panel repaints
#define TOOLS_SEC       5       // heavy chart tools refresh interval

CTrade m_trade;

//==================================================================
//                             STATE
//==================================================================
//--- theme (derived from the panel colour inputs in InitTheme)
color gcBody,gcHead,gcText,gcHeadTx,gcLabel,gcFaint,gcLine;
color gcBtn,gcBtnTx,gcOn,gcOnTx,gcBuy,gcBuyTx,gcSell,gcSellTx;
color gcBuySoft,gcBuySoftTx,gcSellSoft,gcSellSoftTx,gcEdit,gcEditTx,gcBar;

//--- panel
int      gPX=0,gPY=24;
bool     gCollapsed=false;
int      gHeadCount=0;
string   gON[];
int      gOX[],gOY[];
bool     gDrag=false;
int      gDragDX=0,gDragDY=0;
uint     gLastGui=0;
datetime gLastTools=0;

//--- money management
double   gRisk=1.0;
int      gSLPts=200;
double   gRR=2.0;

//--- tools
bool     gSess=true,gPOC=true,gVWAP=true,gHooman=true;
double   gPocPrice=0,gVAH=0,gVAL=0;
double   gVwapVal=0;
double   gVwapLine[];
datetime gVwapTime[];
double   gVwapCumPV=0,gVwapCumV=0;
datetime gVwapDayDrawn=0;
int      gVwapPrevStart=0;

//--- hooman
datetime gHmDay=0,gHmT0=0;
double   gHmHigh=0,gHmLow=0,gHmShift=0;

//--- position tool
int      gTool=0;            // 0 off, 1 long, 2 short
bool     gToolLive=false;    // tracking a real position
ulong    gToolTicket=0;
double   gToolEntry=0,gToolSL=0,gToolTP=0;
datetime gToolT1=0,gToolT2=0;       // box time span
bool     gToolHide=false;           // overlay hidden while a position is open
double   bEntry=0,bSL=0,bTP=0;      // committed state (before the current drag)
datetime bT1=0,bT2=0;
double   gToolPosSL=0,gToolPosTP=0;   // last values seen on the position

//--- misc
datetime gLastBar=0;
int      gWelcomeLeft=0;
double   gDayClosed=0;
datetime gDayClosedStamp=0;

//--- tester
bool     gTester=false,gGui=true,gAutoOk=false,gFloorSaid=false;
double   gStartEquity=0;
int      hFast=INVALID_HANDLE,hSlow=INVALID_HANDLE,hAtr=INVALID_HANDLE;

//==================================================================
//                        SMALL UTILITIES
//==================================================================
color Blend(color a,color b,double t)
{
   if(t<0.0) t=0.0;
   if(t>1.0) t=1.0;
   uint va=(uint)a,vb=(uint)b;
   int r =(int)MathRound((va&0xFF)*(1.0-t)+(vb&0xFF)*t);
   int g =(int)MathRound(((va>>8)&0xFF)*(1.0-t)+((vb>>8)&0xFF)*t);
   int bl=(int)MathRound(((va>>16)&0xFF)*(1.0-t)+((vb>>16)&0xFF)*t);
   return((color)((bl<<16)|(g<<8)|r));
}

//--- perceived brightness 0..255
double Luma(color c)
{
   uint v=(uint)c;
   return(0.299*(v&0xFF)+0.587*((v>>8)&0xFF)+0.114*((v>>16)&0xFF));
}

//--- readable text colour for a given background
color TextOn(color bg)
{
   return((Luma(bg)>150.0)?(color)C'20,33,61':(color)C'246,250,248');
}

//--- MT5 chart objects have no alpha: fake it by mixing into the chart
//--- background and drawing behind the candles
color Translucent(color c,int opacityPct)
{
   int op=(int)MathMax(0,MathMin(opacityPct,100));
   color bg=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   return(Blend(bg,c,(double)op/100.0));
}

string Trim(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   return(s);
}

double ReadNum(string s)
{
   s=Trim(s);
   if(s=="") return(0);
   StringReplace(s,",",".");
   double v=StringToDouble(s);
   if(v<0) v=0;
   return(v);
}

int VolDigits()
{
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st<=0.0) return(2);
   int d=0;
   double x=st;
   while(x<1.0-1e-9 && d<8){ x*=10.0; d++; }
   return(d);
}

double MinLot(){ return(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)); }

double NormVol(double v)
{
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st<=0.0) st=0.01;
   if(v<mn) v=mn;
   v=MathFloor((v+1e-9)/st)*st;
   if(v<mn) v=mn;
   if(mx>0.0 && v>mx) v=mx;
   return(NormalizeDouble(v,VolDigits()));
}

double MinStopDist()
{
   long lvl=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double d=(double)lvl*pt;
   double spr=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(spr>d) d=spr;
   if(d<pt) d=pt;
   return(d);
}

double BarVolume(const MqlRates &r)
{
   double v=(r.real_volume>0)?(double)r.real_volume:(double)r.tick_volume;
   if(v<=0.0) v=1.0;
   return(v);
}

datetime RightEdge()
{
   long t=(long)iTime(_Symbol,PERIOD_CURRENT,0);
   if(t<=0) t=(long)TimeCurrent();
   return((datetime)(t+(long)PeriodSeconds()*3));
}

datetime BarsAhead(int n)
{
   long t=(long)iTime(_Symbol,PERIOD_CURRENT,0);
   if(t<=0) t=(long)TimeCurrent();
   return((datetime)(t+(long)PeriodSeconds()*n));
}

bool IsNewBar()
{
   datetime t=iTime(_Symbol,PERIOD_CURRENT,0);
   if(t==0) return(false);
   if(t!=gLastBar){ gLastBar=t; return(true); }
   return(false);
}

string Money(double v)
{
   string s=DoubleToString(MathAbs(v),2);
   return(((v<0)?"-":"+")+s);
}

//==================================================================
//                             THEME
//==================================================================
void InitTheme()
{
   gcBody   =InpPanelBody;
   gcHead   =InpPanelHead;
   gcText   =TextOn(gcBody);
   gcHeadTx =TextOn(gcHead);
   gcLabel  =Blend(gcText,gcBody,0.22);
   gcFaint  =Blend(gcText,gcBody,0.45);
   gcLine   =Blend(gcText,gcBody,0.78);
   gcBtn    =gcHead;
   gcBtnTx  =gcHeadTx;
   gcOn     =InpPanelAccent;
   gcOnTx   =TextOn(gcOn);
   gcBuy    =C'120,240,170';
   gcBuyTx  =C'8,40,28';
   gcSell   =C'238,78,78';
   gcSellTx =C'255,255,255';
   gcBuySoft  =Blend(gcBody,gcBuy,0.40);  gcBuySoftTx =TextOn(gcBuySoft);
   gcSellSoft =Blend(gcBody,gcSell,0.45); gcSellSoftTx=TextOn(gcSellSoft);
   gcEdit   =C'255,255,255';
   gcEditTx =C'20,33,61';
   gcBar    =Blend(gcBody,gcText,0.18);
}

//==================================================================
//                        PANEL PRIMITIVES
//   All coordinates are RELATIVE to the panel origin (gPX,gPY).
//   Controls get a higher Z-order than the background, so a click is
//   never swallowed by the panel body.
//==================================================================
void Reg(string name,int rx,int ry)
{
   int i=ArraySize(gON);
   ArrayResize(gON,i+1);
   ArrayResize(gOX,i+1);
   ArrayResize(gOY,i+1);
   gON[i]=name; gOX[i]=rx; gOY[i]=ry;
}

void MkR(string t,int x,int y,int w,int h,color bg,color bd)
{
   string n=PX+t;
   ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,gPX+x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,gPY+y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,bd);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,0);
   Reg(n,x,y);
}

void MkLabel(string t,int x,int y,string tx,color c,int s,string font,ENUM_ANCHOR_POINT anc)
{
   string n=PX+t;
   ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,gPX+x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,gPY+y);
   ObjectSetString (0,n,OBJPROP_TEXT,tx);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,s);
   ObjectSetString (0,n,OBJPROP_FONT,font);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,anc);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,1);
   Reg(n,x,y);
}

void MkL(string t,int x,int y,string tx,color c,int s)
{ MkLabel(t,x,y,tx,c,s,FONT_UI,ANCHOR_LEFT_UPPER); }

void MkLR(string t,int x,int y,string tx,color c,int s)
{ MkLabel(t,x,y,tx,c,s,FONT_NUM,ANCHOR_RIGHT_UPPER); }

void MkB(string t,int x,int y,int w,int h,string tx,color bg,color fg,int fs)
{
   string n=PX+t;
   ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,gPX+x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,gPY+y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString (0,n,OBJPROP_TEXT,tx);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,fg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,Blend(bg,gcText,0.25));
   ObjectSetString (0,n,OBJPROP_FONT,FONT_UI);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_STATE,false);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,2);
   Reg(n,x,y);
}

void MkE(string t,int x,int y,int w,int h)
{
   string n=PX+t;
   ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_EDIT,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,gPX+x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,gPY+y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString (0,n,OBJPROP_TEXT,"");          // empty - ready to type
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,gcEdit);
   ObjectSetInteger(0,n,OBJPROP_COLOR,gcEditTx);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,gcHead);
   ObjectSetString (0,n,OBJPROP_FONT,FONT_NUM);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_ALIGN,ALIGN_CENTER);
   ObjectSetInteger(0,n,OBJPROP_READONLY,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,2);
   Reg(n,x,y);
}

void SetT(string t,string v)
{
   string n=PX+t;
   if(ObjectFind(0,n)<0) return;
   if(ObjectGetString(0,n,OBJPROP_TEXT)!=v) ObjectSetString(0,n,OBJPROP_TEXT,v);
}
void SetC(string t,color c)
{
   string n=PX+t;
   if(ObjectFind(0,n)<0) return;
   if((color)ObjectGetInteger(0,n,OBJPROP_COLOR)!=c) ObjectSetInteger(0,n,OBJPROP_COLOR,c);
}
void SetBg(string t,color c)
{
   string n=PX+t;
   if(ObjectFind(0,n)>=0) ObjectSetInteger(0,n,OBJPROP_BGCOLOR,c);
}
string GetT(string t)
{
   string n=PX+t;
   if(ObjectFind(0,n)<0) return("");
   return(ObjectGetString(0,n,OBJPROP_TEXT));
}

void Sep(string id,int y){ MkR(id,PAD,y,PW-2*PAD,1,gcLine,gcLine); }

void Cap(string id,int y,string tx,color acc)
{
   MkR(id+"a",PAD,y+1,3,8,acc,acc);
   MkL(id,PAD+8,y,tx,gcFaint,7);
}

void Row(string id,int y,string lab,string val,color vc)
{
   MkL (id+"L",PAD,y,lab,gcLabel,8);
   MkLR(id+"V",PW-PAD,y,val,vc,8);
}

//==================================================================
//                          PANEL LAYOUT
//==================================================================
void DrawPanel()
{
   ArrayFree(gON); ArrayFree(gOX); ArrayFree(gOY);
   ObjectsDeleteAll(0,PX);

   int inner=PW-2*PAD;
   int half=(inner-6)/2;
   int third=(inner-8)/3;
   int bh=24;
   int stMinus=PW-PAD-96, stValue=PW-PAD-28, stPlus=PW-PAD-20;

   color accBlue=C'120,185,255', accGold=InpPanelAccent, accPink=C'255,130,190';
   color accWhite=C'255,255,255', accRed=C'255,110,100', accMint=C'150,245,190';

   //--- header (drag handle) ---------------------------------------
   MkR("hdr",0,0,PW,HDR_H,gcHead,gcHead);
   MkL("ttl",PAD,9,"CC TRADING MANAGEMENT",gcHeadTx,9);
   MkR("led",PW-PAD-32,13,7,7,gcFaint,gcFaint);
   MkB("min",PW-PAD-18,8,18,17,"-",Blend(gcHead,gcHeadTx,0.25),gcHeadTx,8);
   gHeadCount=ArraySize(gON);

   //--- body ---------------------------------------------------------
   MkR("bg",0,HDR_H,PW,600,gcBody,gcLine);

   int y=HDR_H+8;
   MkL ("ck",PAD,y,"--:--:-- UTC",gcFaint,8);
   MkLR("ss",PW-PAD,y,"---",gcText,8);
   y+=18;

   //--- account ------------------------------------------------------
   Sep("s1",y); y+=9;
   Cap("c1",y,"ACCOUNT",accBlue); y+=13;
   Row("bal",y,"Balance","---",gcText);          y+=14;
   Row("eq" ,y,"Equity","---",gcText);           y+=14;
   Row("fl" ,y,"Floating P/L","---",gcText);     y+=14;
   Row("dy" ,y,"Today P/L","---",gcText);        y+=16;

   //--- money management --------------------------------------------
   Sep("s2",y); y+=9;
   Cap("c2",y,"MONEY MANAGEMENT",accMint); y+=13;

   MkL ("rkL",PAD,y+4,"Risk",gcLabel,8);
   MkB ("rkm",stMinus,y,20,19,"-",gcBtn,gcBtnTx,9);
   MkLR("rkV",stValue,y+4,"1.00 %",gcText,9);
   MkB ("rkp",stPlus,y,20,19,"+",gcBtn,gcBtnTx,9);
   y+=22;
   MkL ("slL",PAD,y+4,"Stop loss",gcLabel,8);
   MkB ("slm",stMinus,y,20,19,"-",gcBtn,gcBtnTx,9);
   MkLR("slV",stValue,y+4,"200 p",gcText,9);
   MkB ("slp",stPlus,y,20,19,"+",gcBtn,gcBtnTx,9);
   y+=22;
   MkL ("rrL",PAD,y+4,"Reward : Risk",gcLabel,8);
   MkB ("rrm",stMinus,y,20,19,"-",gcBtn,gcBtnTx,9);
   MkLR("rrV",stValue,y+4,"1:2.0",gcText,9);
   MkB ("rrp",stPlus,y,20,19,"+",gcBtn,gcBtnTx,9);
   y+=23;
   Row("rm",y,"Risk amount","---",gcSell);       y+=14;
   Row("al",y,"Auto lot","---",gcText);          y+=16;
   MkR("rbBg",PAD,y,inner,4,gcBar,gcBar);
   MkR("rbFg",PAD,y,1,4,gcBuy,gcBuy);
   y+=12;

   //--- position tool -------------------------------------------------
   Sep("s3",y); y+=9;
   Cap("c3",y,"TP / SL TOOL",accGold); y+=13;
   Row("te",y,"Entry","---",gcText);             y+=14;
   Row("ts",y,"Stop","---",gcSell);              y+=14;
   Row("tt",y,"Target","---",gcBuy);             y+=14;
   Row("tr",y,"R : R","---",gcText);             y+=16;

   //--- execution ----------------------------------------------------
   Sep("s4",y); y+=9;
   Cap("c4",y,"EXECUTION",accWhite); y+=13;
   MkL("lotL",PAD,y+5,"Lot",gcLabel,8);
   MkL("lotH",PAD+32,y+6,"empty = auto",gcFaint,7);
   MkE("elot",PW-PAD-86,y,86,21);
   y+=25;
   MkB("buy" ,PAD,y,half,bh,"BUY",gcBuy,gcBuyTx,9);
   MkB("sell",PAD+half+6,y,half,bh,"SELL",gcSell,gcSellTx,9);
   y+=bh+8;
   MkL("limL",PAD,y+5,"Limit",gcLabel,8);
   MkL("limH",PAD+40,y+6,"empty = auto",gcFaint,7);
   MkE("elim",PW-PAD-86,y,86,21);
   y+=25;
   MkB("blm",PAD,y,half,bh,"BUY LMT",gcBuySoft,gcBuySoftTx,8);
   MkB("slmt",PAD+half+6,y,half,bh,"SELL LMT",gcSellSoft,gcSellSoftTx,8);
   y+=bh+8;

   //--- manage -------------------------------------------------------
   Sep("s5",y); y+=9;
   Cap("c5",y,"MANAGE OPEN RISK",accRed); y+=13;
   MkB("c25",PAD,y,third,22,"25%",gcBtn,gcBtnTx,8);
   MkB("c50",PAD+third+4,y,third,22,"50%",gcBtn,gcBtnTx,8);
   MkB("cal",PAD+2*(third+4),y,third,22,"CLOSE",gcSell,gcSellTx,8);
   y+=25;
   MkB("be",PAD,y,half,22,"BREAK EVEN",gcBtn,gcBtnTx,8);
   MkB("dp",PAD+half+6,y,half,22,"DEL PEND",gcBtn,gcBtnTx,8);
   y+=28;

   //--- tools --------------------------------------------------------
   Sep("s6",y); y+=9;
   Cap("c6",y,"TOOLS",accPink); y+=13;
   MkB("ts",PAD,y,third,22,"SESSIONS",gSess?gcOn:gcBtn,gSess?gcOnTx:gcBtnTx,7);
   MkB("tp",PAD+third+4,y,third,22,"POC",gPOC?gcOn:gcBtn,gPOC?gcOnTx:gcBtnTx,7);
   MkB("tv",PAD+2*(third+4),y,third,22,"VWAP",gVWAP?gcOn:gcBtn,gVWAP?gcOnTx:gcBtnTx,7);
   y+=25;
   MkB("th",PAD,y,third,22,"HOOMAN",gHooman?gcOn:gcBtn,gHooman?gcOnTx:gcBtnTx,7);
   MkB("thr",PAD+third+4,y,third,22,"HM RESET",gcBtn,gcBtnTx,7);
   MkB("tps",PAD+2*(third+4),y,third,22,"TP/SL",gcBtn,gcBtnTx,7);
   y+=26;

   //--- status + footer ---------------------------------------------
   Sep("s7",y); y+=8;
   MkL("st",PAD,y,"Ready",gcFaint,7); y+=15;
   MkL("yt",PAD,y,"YouTube: @ChartAndChill",InpPanelAccent,8); y+=14;
   MkL("fr",PAD,y,"Free forever - please subscribe",gcFaint,7); y+=14;

   ObjectSetInteger(0,PX+"bg",OBJPROP_YSIZE,y-HDR_H);
   ApplyCollapse();
}

int PanelHeight()
{
   if(gCollapsed) return(HDR_H);
   if(ObjectFind(0,PX+"bg")<0) return(HDR_H);
   return(HDR_H+(int)ObjectGetInteger(0,PX+"bg",OBJPROP_YSIZE));
}

void ApplyPos()
{
   int n=ArraySize(gON);
   for(int i=0;i<n;i++)
   {
      ObjectSetInteger(0,gON[i],OBJPROP_XDISTANCE,gPX+gOX[i]);
      ObjectSetInteger(0,gON[i],OBJPROP_YDISTANCE,gPY+gOY[i]);
   }
}

void ApplyCollapse()
{
   int n=ArraySize(gON);
   for(int i=gHeadCount;i<n;i++)
      ObjectSetInteger(0,gON[i],OBJPROP_TIMEFRAMES,gCollapsed?OBJ_NO_PERIODS:OBJ_ALL_PERIODS);
   SetT("min",gCollapsed?"+":"-");
}

void ClampPos()
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   int h=PanelHeight();
   if(gPX>cw-PW) gPX=cw-PW;
   if(gPX<0)     gPX=0;
   if(gPY>ch-h)  gPY=ch-h;        // keep the whole panel visible
   if(gPY<0)     gPY=0;
}

void SavePos()
{
   GlobalVariableSet("CCTM_PX",(double)gPX);
   GlobalVariableSet("CCTM_PY",(double)gPY);
   GlobalVariableSet("CCTM_COL",gCollapsed?1.0:0.0);
}

void LoadPos()
{
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   gPX=cw-PW-14;
   gPY=24;
   if(GlobalVariableCheck("CCTM_PX"))  gPX=(int)GlobalVariableGet("CCTM_PX");
   if(GlobalVariableCheck("CCTM_PY"))  gPY=(int)GlobalVariableGet("CCTM_PY");
   if(GlobalVariableCheck("CCTM_COL")) gCollapsed=(GlobalVariableGet("CCTM_COL")>0.5);
}

bool InHeader(int mx,int my)
{
   if(mx<gPX || mx>gPX+PW) return(false);
   if(my<gPY || my>gPY+HDR_H) return(false);
   int bx=gPX+PW-PAD-18;
   if(mx>=bx && mx<=bx+18 && my>=gPY+8 && my<=gPY+25) return(false);
   return(true);
}

void Say(string msg)   { SetT("st",msg); SetC("st",gcLabel); Print("[CC] ",msg); }
void SayOk(string msg) { SetT("st",msg); SetC("st",gcBuy);   Print("[CC] ",msg); }
void SayErr(string msg){ SetT("st",msg); SetC("st",gcSell);  Print("[CC] BLOCKED: ",msg); }

//==================================================================
//                         WELCOME CARD
//==================================================================
void WLabel(string t,int x,int y,string tx,color c,int s)
{
   string n=WP+t;
   ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,n,OBJPROP_TEXT,tx);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,s);
   ObjectSetString (0,n,OBJPROP_FONT,FONT_UI);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_CENTER);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,5);
}

void WRect(string t,int x,int y,int w,int h,color bg,color bd)
{
   string n=WP+t;
   ObjectDelete(0,n);
   ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,bd);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,n,OBJPROP_ZORDER,4);
}

void ShowWelcome()
{
   if(InpWelcomeSec<=0) return;
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   int w=430,h=206;
   int x=(cw-w)/2; if(x<10) x=10;
   int y=(ch-h)/3; if(y<10) y=10;
   int cx=x+w/2;

   WRect("bg",x,y,w,h,gcBody,gcHead);
   WRect("hb",x,y,w,38,gcHead,gcHead);
   WLabel("t1",cx,y+19,"CC TRADING MANAGEMENT",gcHeadTx,13);
   WLabel("t2",cx,y+58,"This tool is 100% FREE - and it always will be.",gcText,9);
   WLabel("t3",cx,y+84,"All I ask in return: subscribe to my channel",gcLabel,9);
   WLabel("t4",cx,y+110,"youtube.com/@ChartAndChill",InpPanelAccent,12);
   WLabel("t5",cx,y+138,"Your subscribe keeps this tool free for everyone.",gcFaint,8);

   string b=WP+"ok";
   ObjectDelete(0,b);
   ObjectCreate(0,b,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,b,OBJPROP_XDISTANCE,cx-60);
   ObjectSetInteger(0,b,OBJPROP_YDISTANCE,y+h-46);
   ObjectSetInteger(0,b,OBJPROP_XSIZE,120);
   ObjectSetInteger(0,b,OBJPROP_YSIZE,26);
   ObjectSetString (0,b,OBJPROP_TEXT,"START TRADING");
   ObjectSetInteger(0,b,OBJPROP_BGCOLOR,gcHead);
   ObjectSetInteger(0,b,OBJPROP_COLOR,gcHeadTx);
   ObjectSetInteger(0,b,OBJPROP_BORDER_COLOR,gcHead);
   ObjectSetString (0,b,OBJPROP_FONT,FONT_UI);
   ObjectSetInteger(0,b,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,b,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,b,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,b,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,b,OBJPROP_STATE,false);
   ObjectSetInteger(0,b,OBJPROP_ZORDER,6);

   gWelcomeLeft=InpWelcomeSec;
}

void HideWelcome()
{
   ObjectsDeleteAll(0,WP);
   gWelcomeLeft=0;
   ChartRedraw();
}

//==================================================================
//                             INIT
//==================================================================
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagic);
   m_trade.SetDeviationInPoints(InpDeviation<1?1:InpDeviation);
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetAsyncMode(false);
   m_trade.LogLevel(LOG_LEVEL_ERRORS);

   gRisk  =MathMax(0.01,MathMin(InpRiskPct,20.0));
   gSLPts =(int)MathMax(1,InpSLPts);
   gRR    =MathMax(0.1,InpRR);
   gSess=InpSessOn; gPOC=InpPocOn; gVWAP=InpVwapOn; gHooman=InpHoomanOn;

   InitTheme();

   gTester=(bool)MQLInfoInteger(MQL_TESTER);
   gGui=(!gTester || (bool)MQLInfoInteger(MQL_VISUAL_MODE));

   if(gGui)
   {
      ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true);
      ChartSetInteger(0,CHART_EVENT_OBJECT_DELETE,true);
      LoadPos();
      DrawPanel();
      ClampPos();
      ApplyPos();
   }

   gLastBar=iTime(_Symbol,PERIOD_CURRENT,0);

   if(gGui)
   {
      RefreshTools(true);
      UpdInfo();
      UpdClock();
      if(InpToolOn && gTool==0) ToolPlace(1);
      ToolButton();
      ChartRedraw();
   }

   if(gTester && InpTesterAuto) ArmAutoStrategy();

   int ur=UninitializeReason();
   if(gGui && !gTester &&
      ur!=REASON_CHARTCHANGE && ur!=REASON_PARAMETERS && ur!=REASON_RECOMPILE)
      ShowWelcome();

   if(!gTester)
   {
      Print("+--------------------------------------------------------+");
      Print("|            CC TRADING MANAGEMENT  v4.40                |");
      Print("|   FREE forever - please subscribe on YouTube:          |");
      Print("|            youtube.com/@ChartAndChill                  |");
      Print("|   Drag the panel by its title bar. Drag the coloured   |");
      Print("|   TP / SL lines on the chart to move them.             |");
      Print("+--------------------------------------------------------+");
      EventSetMillisecondTimer(500);
   }
   return(INIT_SUCCEEDED);
}

void ArmAutoStrategy()
{
   int fast=(int)MathMax(2,MathMin(InpAutoFast,500));
   int slow=(int)MathMax(3,MathMin(InpAutoSlow,1000));
   if(slow<=fast) slow=fast+1;
   hFast=iMA (_Symbol,PERIOD_CURRENT,fast,0,MODE_EMA,PRICE_CLOSE);
   hSlow=iMA (_Symbol,PERIOD_CURRENT,slow,0,MODE_EMA,PRICE_CLOSE);
   hAtr =iATR(_Symbol,PERIOD_CURRENT,14);
   gAutoOk=(hFast!=INVALID_HANDLE && hSlow!=INVALID_HANDLE && hAtr!=INVALID_HANDLE);
   gStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   gFloorSaid=false;
   if(gRisk>TESTER_RISK_PCT) gRisk=TESTER_RISK_PCT;
   Print("[CC] Strategy Tester mode: auto strategy ",(gAutoOk?"armed":"unavailable"),
         " (EMA ",fast,"/",slow,", SL ",DoubleToString(InpAutoAtrSL,2)," x ATR, risk ",
         DoubleToString(gRisk,2),"% capped at ",DoubleToString(MAX_RISK_PCT,1),"%)");
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(hFast!=INVALID_HANDLE) IndicatorRelease(hFast);
   if(hSlow!=INVALID_HANDLE) IndicatorRelease(hSlow);
   if(hAtr !=INVALID_HANDLE) IndicatorRelease(hAtr);
   ObjectsDeleteAll(0,PX);  ObjectsDeleteAll(0,SP);
   ObjectsDeleteAll(0,PP);  ObjectsDeleteAll(0,VP);  ObjectsDeleteAll(0,HP);
   ObjectsDeleteAll(0,TP_); ObjectsDeleteAll(0,WP);
   ChartSetInteger(0,CHART_MOUSE_SCROLL,true);
   ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,false);
   ChartRedraw();
}

//==================================================================
//                            EVENTS
//   One refresh path for tick and timer, throttled to GUI_MS, and the
//   heavy chart tools only on a new bar or every TOOLS_SEC seconds.
//==================================================================
void Refresh(bool fromTimer)
{
   if(!gGui) return;

   uint now=GetTickCount();
   if(now-gLastGui<GUI_MS && !fromTimer) return;
   gLastGui=now;

   bool nb=IsNewBar();
   bool heavy=(nb || TimeCurrent()-gLastTools>=TOOLS_SEC);

   UpdClock();
   UpdInfo();
   if(heavy){ RefreshTools(nb); gLastTools=TimeCurrent(); }
   else      RefreshLight();
   ChartRedraw();
}

void OnTimer()
{
   if(gWelcomeLeft>0)
   {
      static uint lastSec=0;
      uint now=GetTickCount();
      if(now-lastSec>=1000){ lastSec=now; gWelcomeLeft--; if(gWelcomeLeft<=0) HideWelcome(); }
   }
   Refresh(true);
   if(InpTrailOn) Trail();
}

void OnTick()
{
   if(gTester && gAutoOk) AutoStrategy(IsNewBar());
   Refresh(false);
   if(InpTrailOn && !gGui) Trail();
}

//==================================================================
//                        CHART EVENTS
//==================================================================
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   //--- mouse: panel drag + live zone preview while a tool line is dragged
   if(id==CHARTEVENT_MOUSE_MOVE)
   {
      int mx=(int)lparam,my=(int)dparam;
      int state=(int)StringToInteger(sparam);
      bool lmb=((state&1)!=0);
      if(lmb)
      {
         if(!gDrag)
         {
            if(InHeader(mx,my))
            {
               gDrag=true; gDragDX=mx-gPX; gDragDY=my-gPY;
               ChartSetInteger(0,CHART_MOUSE_SCROLL,false);
            }
            else if(gTool!=0) ToolPreview();
         }
         else
         {
            gPX=mx-gDragDX; gPY=my-gDragDY;
            ClampPos(); ApplyPos(); ChartRedraw();
         }
      }
      else if(gDrag)
      {
         gDrag=false;
         ChartSetInteger(0,CHART_MOUSE_SCROLL,true);
         SavePos();
      }
      return;
   }

   if(id==CHARTEVENT_CHART_CHANGE)
   {
      ClampPos(); ApplyPos();
      if(gTool!=0) ToolLabels();          // pixel pills follow scroll / zoom
      if(gSess)    SessPills();
      ChartRedraw();
      return;
   }

   //--- a chart line was dragged and released
   if(id==CHARTEVENT_OBJECT_DRAG)
   {
      if(StringFind(sparam,TP_)==0){ ToolDragged(sparam); return; }
      if(StringFind(sparam,HP)==0) { HoomanDragged(sparam); return; }
      return;
   }

   //--- one of our chart objects was deleted by the user: rebuild it
   if(id==CHARTEVENT_OBJECT_DELETE)
   {
      if(StringFind(sparam,TP_)==0 && gTool!=0){ ToolDrawAll(); ChartRedraw(); }
      if(StringFind(sparam,HP)==0 && gHooman)  { HoomanDraw();  ChartRedraw(); }
      return;
   }

   if(id==CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(sparam==PX+"elot")
      {
         double v=ReadNum(GetT("elot"));
         if(v>0) Say("Manual lot: "+DoubleToString(NormVol(v),VolDigits()));
         else    Say("Lot field empty - auto risk lot");
      }
      if(sparam==PX+"elim")
      {
         double v=ReadNum(GetT("elim"));
         if(v>0) Say("Limit price: "+DoubleToString(v,_Digits));
         else    Say("Limit field empty - auto distance");
      }
      UpdInfo(); ChartRedraw();
      return;
   }

   if(id!=CHARTEVENT_OBJECT_CLICK) return;
   if(StringFind(sparam,PX)!=0 && StringFind(sparam,WP)!=0) return;

   ObjectSetInteger(0,sparam,OBJPROP_STATE,false);
   if(gDrag){ gDrag=false; ChartSetInteger(0,CHART_MOUSE_SCROLL,true); SavePos(); }

   if(sparam==WP+"ok"){ HideWelcome(); return; }

   if(sparam==PX+"min")
   {
      gCollapsed=!gCollapsed;
      ApplyCollapse(); ClampPos(); ApplyPos(); SavePos(); ChartRedraw();
      return;
   }

   //--- steppers
   if(sparam==PX+"rkm"){ gRisk=MathMax(0.05,gRisk-0.05);  ToolRefit(); UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"rkp"){ gRisk=MathMin(20.0,gRisk+0.05);  ToolRefit(); UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"slm"){ gSLPts=(int)MathMax(1,gSLPts-10); ToolRefit(); UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"slp"){ gSLPts+=10;                       ToolRefit(); UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"rrm"){ gRR=MathMax(0.1,gRR-0.1);         ToolRefit(); UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"rrp"){ gRR=MathMin(50.0,gRR+0.1);        ToolRefit(); UpdInfo(); ChartRedraw(); return; }

   //--- position tool
   if(sparam==PX+"tps"){ ToolCycle(); UpdInfo(); ChartRedraw(); return; }

   //--- execution
   if(sparam==PX+"buy" ){ XMarket(true);  UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"sell"){ XMarket(false); UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"blm" ){ XLimit(true);   UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"slmt"){ XLimit(false);  UpdInfo(); ChartRedraw(); return; }

   //--- manage
   if(sparam==PX+"c25"){ XClose(0.25);  UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"c50"){ XClose(0.50);  UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"cal"){ XClose(1.00);  UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"be" ){ XBreakEven();  UpdInfo(); ChartRedraw(); return; }
   if(sparam==PX+"dp" ){ XDelPending(); UpdInfo(); ChartRedraw(); return; }

   //--- tool toggles
   if(sparam==PX+"ts"){ gSess=!gSess; Tog("ts",gSess); if(gSess) DrawSessions(); else ObjectsDeleteAll(0,SP); ChartRedraw(); return; }
   if(sparam==PX+"tp"){ gPOC=!gPOC;   Tog("tp",gPOC);  if(gPOC) UpdPOC(); else { ObjectsDeleteAll(0,PP); gPocPrice=0; gVAH=0; gVAL=0; } ChartRedraw(); return; }
   if(sparam==PX+"tv"){ gVWAP=!gVWAP; Tog("tv",gVWAP); if(gVWAP) UpdVWAP(true); else { ObjectsDeleteAll(0,VP); gVwapVal=0; gVwapDayDrawn=0; } ChartRedraw(); return; }
   if(sparam==PX+"th"){ gHooman=!gHooman; Tog("th",gHooman); if(gHooman){ gHmDay=0; HoomanDraw(); } else ObjectsDeleteAll(0,HP); ChartRedraw(); return; }
   if(sparam==PX+"thr"){ gHmShift=0; if(gHooman) HoomanDraw(); Say("Hooman levels reset"); ChartRedraw(); return; }
}

void Tog(string id,bool on)
{
   SetBg(id,on?gcOn:gcBtn);
   SetC (id,on?gcOnTx:gcBtnTx);
}

//==================================================================
//                        PANEL REFRESH
//==================================================================
void UpdInfo()
{
   if(!gGui) return;

   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   double eq =AccountInfoDouble(ACCOUNT_EQUITY);
   string cur=AccountInfoString(ACCOUNT_CURRENCY);

   double fl=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      fl+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   }
   SetT("balV",DoubleToString(bal,2));
   SetT("eqV" ,DoubleToString(eq,2));
   SetT("flV" ,DoubleToString(fl,2));
   SetC("flV" ,(fl>0)?gcBuy:((fl<0)?gcSell:gcText));
   double dp=TodayClosed()+fl;
   SetT("dyV",DoubleToString(dp,2));
   SetC("dyV",(dp>0)?gcBuy:((dp<0)?gcSell:gcText));

   //--- money management ---------------------------------------------
   SetT("rkV",DoubleToString(gRisk,2)+" %");
   SetT("slV",IntegerToString(gSLPts)+" p");
   SetT("rrV","1:"+DoubleToString(gRR,1));

   double riskMoney=0;
   double lot=AutoLot(riskMoney);
   SetT("rmV",DoubleToString(riskMoney,2)+" "+cur);

   double typed=ReadNum(GetT("elot"));
   if(typed>0){ SetT("alL","Manual lot"); SetT("alV",DoubleToString(NormVol(typed),VolDigits())); SetC("alV",gcOn); }
   else       { SetT("alL","Auto lot");   SetT("alV",DoubleToString(lot,VolDigits()));           SetC("alV",gcText); }

   int inner=PW-2*PAD;
   double frac=MathMin(gRisk/5.0,1.0);
   int fw=(int)MathMax(1,MathRound(inner*frac));
   if(ObjectFind(0,PX+"rbFg")>=0)
   {
      ObjectSetInteger(0,PX+"rbFg",OBJPROP_XSIZE,fw);
      color bc=(gRisk<=1.0)?gcBuy:((gRisk<=2.0)?gcOn:gcSell);
      ObjectSetInteger(0,PX+"rbFg",OBJPROP_BGCOLOR,bc);
      ObjectSetInteger(0,PX+"rbFg",OBJPROP_BORDER_COLOR,bc);
   }
   double want=RiskBase()*gRisk/100.0;
   bool over=(want>0.0 && riskMoney>want*1.10);
   SetT("rmL",over?"Risk amount (min lot!)":"Risk amount");
   SetC("rmL",over?gcSell:gcLabel);

   //--- position tool rows ------------------------------------------
   ToolSync();
   ToolPanelRows();

   //--- trade-ready light -------------------------------------------
   string why=TradeBlockReason();
   color lc=(why=="")?gcBuy:gcSell;
   if(ObjectFind(0,PX+"led")>=0)
   {
      ObjectSetInteger(0,PX+"led",OBJPROP_BGCOLOR,lc);
      ObjectSetInteger(0,PX+"led",OBJPROP_BORDER_COLOR,lc);
      ObjectSetString (0,PX+"led",OBJPROP_TOOLTIP,(why=="")?"Ready to trade":why);
   }
   static string lastWhy="";
   if(why!=lastWhy){ lastWhy=why; if(why!="") SayErr(why); else Say("Ready to trade"); }
}

double TodayClosed()
{
   datetime now=TimeCurrent();
   if(now-gDayClosedStamp<5) return(gDayClosed);
   gDayClosedStamp=now;
   datetime d0=iTime(_Symbol,PERIOD_D1,0);
   if(d0<=0) d0=(datetime)(((long)now/86400)*86400);
   double p=0;
   if(HistorySelect(d0,now+60))
   {
      for(int i=HistoryDealsTotal()-1;i>=0;i--)
      {
         ulong t=HistoryDealGetTicket(i);
         if(t==0) continue;
         if(HistoryDealGetInteger(t,DEAL_MAGIC)!=(long)InpMagic) continue;
         if(HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol) continue;
         if(HistoryDealGetInteger(t,DEAL_ENTRY)==DEAL_ENTRY_IN) continue;
         p+=HistoryDealGetDouble(t,DEAL_PROFIT)+HistoryDealGetDouble(t,DEAL_SWAP)+HistoryDealGetDouble(t,DEAL_COMMISSION);
      }
   }
   gDayClosed=p;
   return(p);
}

void UpdClock()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(),dt);
   long spr=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   SetT("ck",StringFormat("%02d:%02d:%02d UTC  spr %d",dt.hour,dt.min,dt.sec,(int)spr));

   int h=dt.hour;
   bool asia=InSessionHour(h,InpAsiaOpen,InpAsiaClose);
   bool lon =InSessionHour(h,InpLonOpen ,InpLonClose);
   bool ny  =InSessionHour(h,InpNyOpen  ,InpNyClose);
   string s="CLOSED"; color sc=gcFaint;
   if(lon&&ny)        { s="LONDON + NY";   sc=Blend(InpLonColor,InpNyColor,0.5); }
   else if(asia&&lon) { s="ASIA + LONDON"; sc=Blend(InpAsiaColor,InpLonColor,0.5); }
   else if(ny)        { s="NEW YORK";      sc=InpNyColor; }
   else if(lon)       { s="LONDON";        sc=InpLonColor; }
   else if(asia)      { s="ASIA";          sc=InpAsiaColor; }
   // make the session colour readable on the panel body
   if(MathAbs(Luma(sc)-Luma(gcBody))<60.0) sc=Blend(sc,gcText,0.55);
   SetT("ss",s); SetC("ss",sc);
}

bool InSessionHour(int h,int open,int close)
{
   if(open==close) return(false);
   if(open<close)  return(h>=open && h<close);
   return(h>=open || h<close);
}

void RefreshLight()
{
   if(gVWAP) UpdVWAPLast();
   if(gSess) SessPills();
   if(gTool!=0) ToolRefresh();
}

void RefreshTools(bool newBar)
{
   if(gSess)   DrawSessions();
   if(gPOC)    UpdPOC();
   if(gVWAP)   UpdVWAP(newBar);
   if(gPOC && gVWAP) ChkConfluence();
   if(gHooman) HoomanDraw();
   if(gTool!=0) ToolRefresh();
}

//--- shared helpers for horizontal lines and text tags
void HLineAt(string n,double price,color c,ENUM_LINE_STYLE st,int wd)
{
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
   ObjectSetDouble (0,n,OBJPROP_PRICE,0,price);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_STYLE,st);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,wd);
}

void TagAt(string n,datetime t,double price,string txt,color c,int fs,ENUM_ANCHOR_POINT anc,bool back)
{
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_TEXT,0,t,price);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,anc);
      ObjectSetString (0,n,OBJPROP_FONT,FONT_NUM);
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_BACK,back);
   }
   ObjectMove(0,n,0,t,price);
   if(ObjectGetString(0,n,OBJPROP_TEXT)!=txt) ObjectSetString(0,n,OBJPROP_TEXT,txt);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
}

//==================================================================
//   SESSIONS
//   A soft translucent box over each session's own high / low with
//   dotted high and low edges and a small name pill in the corner
//   showing the session's range. Hours are GMT inputs; the server
//   offset comes from TimeTradeServer(), a live clock, so weekends and
//   quote gaps cannot skew it (TimeCurrent() is the last tick and is
//   days old on a Saturday). Drawn on H1 and lower only.
//==================================================================
long ServerGmtOffset()
{
   long off=(long)TimeTradeServer()-(long)TimeGMT();
   return((long)MathRound((double)off/900.0)*900);      // nearest 15 minutes
}

void DrawSessions()
{
   if(PeriodSeconds()>3600){ ObjectsDeleteAll(0,SP); return; }
   int days=(int)MathMax(1,MathMin(InpSessDays,10));
   long off=ServerGmtOffset();
   long gmtNow=(long)TimeGMT();
   long gmtMid=gmtNow-(gmtNow%86400);
   for(int d=0;d<10;d++)
   {
      string sfx=IntegerToString(d);
      if(d>=days){ SessDrop("a"+sfx); SessDrop("l"+sfx); SessDrop("n"+sfx); continue; }
      long base=gmtMid-(long)d*86400;
      SessBox("a"+sfx,base,off,InpAsiaOpen,InpAsiaClose,"ASIA"    ,InpAsiaColor);
      SessBox("l"+sfx,base,off,InpLonOpen ,InpLonClose ,"LONDON"  ,InpLonColor);
      SessBox("n"+sfx,base,off,InpNyOpen  ,InpNyClose  ,"NEW YORK",InpNyColor);
   }
}

void SessDrop(string id)
{
   ObjectDelete(0,SP+id);
   ObjectDelete(0,SP+id+"h");
   ObjectDelete(0,SP+id+"l");
   ObjectDelete(0,SP+id+"p");
}

void SessBox(string id,long gmtBase,long off,int hOpen,int hClose,string title,color c)
{
   if(hOpen==hClose){ SessDrop(id); return; }
   long t1l=gmtBase+(long)hOpen*3600+off;
   long t2l=gmtBase+(long)hClose*3600+off;
   if(hClose<hOpen) t2l+=86400;                       // session crossing midnight
   datetime t1=(datetime)t1l,t2=(datetime)t2l;

   datetime last=iTime(_Symbol,PERIOD_CURRENT,0);
   if(last<=0){ SessDrop(id); return; }
   datetime now=last+PeriodSeconds();                 // end of the live bar
   if(t1>=now){ SessDrop(id); return; }               // not started yet
   datetime te=(t2>now)?now:t2;

   int total=Bars(_Symbol,PERIOD_CURRENT);
   if(total<10 || t1<iTime(_Symbol,PERIOD_CURRENT,total-1)){ SessDrop(id); return; }

   // te-1: the bar that ENDS at the close, not the first bar after it
   int i2=iBarShift(_Symbol,PERIOD_CURRENT,t1,false);
   int i1=iBarShift(_Symbol,PERIOD_CURRENT,te-1,false);
   if(i1<0 || i2<0 || i2<i1){ SessDrop(id); return; }
   while(i2>i1 && iTime(_Symbol,PERIOD_CURRENT,i2)<t1) i2--;   // skip a gap
   datetime bStart=iTime(_Symbol,PERIOD_CURRENT,i2);
   if(bStart<t1){ SessDrop(id); return; }

   int cnt=i2-i1+1;
   int ih=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,cnt,i1);
   int il=iLowest (_Symbol,PERIOD_CURRENT,MODE_LOW ,cnt,i1);
   if(ih<0 || il<0){ SessDrop(id); return; }
   double ph=iHigh(_Symbol,PERIOD_CURRENT,ih),pl=iLow(_Symbol,PERIOD_CURRENT,il);
   if(ph<=0.0 || pl<=0.0 || ph<=pl){ SessDrop(id); return; }
   datetime left=(bStart>t1)?bStart:t1;

   RectAt(SP+id,left,ph,te,pl,Translucent(c,InpSessOpacity),true);

   if(InpSessEdges)
   {
      color ec=Translucent(c,55);
      SegAt(SP+id+"h",left,ph,te,ph,ec,STYLE_DOT,1);
      SegAt(SP+id+"l",left,pl,te,pl,ec,STYLE_DOT,1);
   }
   else { ObjectDelete(0,SP+id+"h"); ObjectDelete(0,SP+id+"l"); }

   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   string txt=title+"   "+DoubleToString((ph-pl)/pt,0)+" p";
   PillXY(SP+id+"p",0,0,txt,c,7,false);              // text / colour; placed below
   SessPlace(id);
}

//--- put the name pill inside the top-left corner of its box
void SessPlace(string id)
{
   string r=SP+id,n=SP+id+"p";
   if(ObjectFind(0,r)<0 || ObjectFind(0,n)<0) return;
   datetime t1=(datetime)ObjectGetInteger(0,r,OBJPROP_TIME,0);
   datetime t2=(datetime)ObjectGetInteger(0,r,OBJPROP_TIME,1);
   double ph=ObjectGetDouble(0,r,OBJPROP_PRICE,0);
   int x1=0,y1=0,x2=0,y2=0;
   bool ok=ChartTimePriceToXY(0,0,t1,ph,x1,y1) && ChartTimePriceToXY(0,0,t2,ph,x2,y2);
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int x=x1+4;
   if(x<4 && x2>60) x=4;                              // box starts off screen: keep the tag readable
   string txt=ObjectGetString(0,n,OBJPROP_TEXT);
   color c=(color)ObjectGetInteger(0,n,OBJPROP_BGCOLOR);
   PillXY(n,x,y1+4,txt,c,7,ok && x<cw && x2>0);
}

void SessPills()
{
   for(int d=0;d<10;d++)
   {
      string s=IntegerToString(d);
      SessPlace("a"+s); SessPlace("l"+s); SessPlace("n"+s);
   }
}

//--- bounded line segment drawn behind the candles
void SegAt(string n,datetime t1,double p1,datetime t2,double p2,color c,ENUM_LINE_STYLE st,int wd)
{
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_TREND,0,t1,p1,t2,p2);
      ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
   ObjectMove(0,n,0,t1,p1);
   ObjectMove(0,n,1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_STYLE,st);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,wd);
}

//--- filled (fill=true) or outlined rectangle drawn behind the candles
void RectAt(string n,datetime t1,double p1,datetime t2,double p2,color c,bool fill)
{
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_RECTANGLE,0,t1,p1,t2,p2);
      ObjectSetInteger(0,n,OBJPROP_FILL,fill);
      ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,n,OBJPROP_BACK,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   }
   ObjectMove(0,n,0,t1,p1);
   ObjectMove(0,n,1,t2,p2);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
}

//==================================================================
//   POC + VALUE AREA
//==================================================================
void UpdPOC()
{
   int bins=(int)MathMax(5,MathMin(InpPOCBins,500));
   int bars=(int)MathMin(MathMax(InpPOCBars,10),Bars(_Symbol,PERIOD_CURRENT));
   if(bars<10) return;
   MqlRates r[];
   ArraySetAsSeries(r,false);
   int n=CopyRates(_Symbol,PERIOD_CURRENT,0,bars,r);
   if(n<10) return;

   double hi=-DBL_MAX,lo=DBL_MAX;
   for(int i=0;i<n;i++){ if(r[i].high>hi) hi=r[i].high; if(r[i].low<lo) lo=r[i].low; }
   if(hi<=lo) return;
   double bs=(hi-lo)/bins;
   if(bs<=0.0) return;

   double vb[];
   ArrayResize(vb,bins);
   ArrayInitialize(vb,0.0);
   double total=0;
   for(int i=0;i<n;i++)
   {
      double v=BarVolume(r[i]);
      int b1=(int)MathFloor((r[i].low -lo)/bs);
      int b2=(int)MathFloor((r[i].high-lo)/bs);
      if(b1<0) b1=0; if(b2<0) b2=0;
      if(b1>bins-1) b1=bins-1; if(b2>bins-1) b2=bins-1;
      if(b2<b1){ int tmp=b1; b1=b2; b2=tmp; }
      double share=v/(double)(b2-b1+1);
      for(int b=b1;b<=b2;b++) vb[b]+=share;
      total+=v;
   }
   int mx=0; double mv=vb[0];
   for(int b=1;b<bins;b++) if(vb[b]>mv){ mv=vb[b]; mx=b; }
   gPocPrice=NormalizeDouble(lo+(mx+0.5)*bs,_Digits);

   int up=mx,dn=mx; double acc=vb[mx],target=total*0.70;
   while(acc<target && (dn>0 || up<bins-1))
   {
      double vUp=(up<bins-1)?vb[up+1]:-1.0;
      double vDn=(dn>0)?vb[dn-1]:-1.0;
      if(vUp<0 && vDn<0) break;
      if(vUp>=vDn){ up++; acc+=vb[up]; } else { dn--; acc+=vb[dn]; }
   }
   gVAH=NormalizeDouble(lo+(up+1)*bs,_Digits);
   gVAL=NormalizeDouble(lo+dn*bs,_Digits);

   PocLine("poc",gPocPrice,InpPocColor,STYLE_SOLID,2,"POC");
   if(InpPOCValueArea)
   {
      color va=Blend(InpPocColor,C'255,255,255',0.42);
      PocLine("vah",gVAH,va,STYLE_DASH,1,"VAH");
      PocLine("val",gVAL,va,STYLE_DASH,1,"VAL");
   }
   else
   {
      ObjectDelete(0,PP+"vah"); ObjectDelete(0,PP+"vahL");
      ObjectDelete(0,PP+"val"); ObjectDelete(0,PP+"valL");
   }
}

void PocLine(string tag,double price,color c,ENUM_LINE_STYLE st,int wd,string title)
{
   if(price<=0) return;
   HLineAt(PP+tag,price,c,st,wd);
   TagAt(PP+tag+"L",RightEdge(),price,title+" "+DoubleToString(price,_Digits),c,7,ANCHOR_LEFT_LOWER,true);
}

//==================================================================
//   VWAP  (session anchored, incremental drawing)
//   Closed bars never change, so only the last segment is moved and
//   only new segments are created - the old version moved hundreds of
//   objects on every bar, which is what made the chart lag.
//==================================================================
void UpdVWAP(bool rebuild)
{
   datetime d0=iTime(_Symbol,PERIOD_D1,0);
   if(d0<=0) return;

   int n=Bars(_Symbol,PERIOD_CURRENT,d0,TimeCurrent());
   if(n<1) n=1;
   if(n>3000) n=3000;

   MqlRates r[];
   ArraySetAsSeries(r,false);
   int got=CopyRates(_Symbol,PERIOD_CURRENT,0,n,r);
   if(got<1) return;

   ArrayResize(gVwapLine,got);
   ArrayResize(gVwapTime,got);
   double cum=0,cvol=0;
   for(int i=0;i<got;i++)
   {
      double tp=(r[i].high+r[i].low+r[i].close)/3.0;
      double v=BarVolume(r[i]);
      if(i==got-1){ gVwapCumPV=cum; gVwapCumV=cvol; }
      cum+=tp*v; cvol+=v;
      gVwapLine[i]=(cvol>0.0)?(cum/cvol):tp;
      gVwapTime[i]=r[i].time;
   }
   gVwapVal=NormalizeDouble(gVwapLine[got-1],_Digits);

   if(d0!=gVwapDayDrawn || rebuild)
   {
      if(d0!=gVwapDayDrawn){ ObjectsDeleteAll(0,VP+"s"); gVwapPrevStart=0; }
      gVwapDayDrawn=d0;
   }

   int drawMax=(int)MathMax(20,MathMin(InpVwapMaxBars,3000));
   int start=(int)MathMax(1,got-drawMax);

   // segments that slid out of the window
   if(gVwapPrevStart>0 && gVwapPrevStart<start)
      for(int i=gVwapPrevStart;i<start;i++) ObjectDelete(0,VwapSegName(gVwapTime[i]));
   gVwapPrevStart=start;

   for(int i=start;i<got;i++)
   {
      string s=VwapSegName(gVwapTime[i]);
      bool exists=(ObjectFind(0,s)>=0);
      if(!exists)
      {
         ObjectCreate(0,s,OBJ_TREND,0,gVwapTime[i-1],gVwapLine[i-1],gVwapTime[i],gVwapLine[i]);
         ObjectSetInteger(0,s,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,s,OBJPROP_WIDTH,2);
         ObjectSetInteger(0,s,OBJPROP_BACK,true);
         ObjectSetInteger(0,s,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,s,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,s,OBJPROP_COLOR,InpVwapColor);
      }
      else if(i>=got-2 || rebuild)          // only the live tail moves
      {
         ObjectMove(0,s,0,gVwapTime[i-1],gVwapLine[i-1]);
         ObjectMove(0,s,1,gVwapTime[i]  ,gVwapLine[i]);
      }
   }
   VwapTag();
}

string VwapSegName(datetime t){ return(VP+"s"+IntegerToString((long)t)); }

void UpdVWAPLast()
{
   int n=ArraySize(gVwapLine);
   if(n<1) return;
   double h=iHigh(_Symbol,PERIOD_CURRENT,0),l=iLow(_Symbol,PERIOD_CURRENT,0),c=iClose(_Symbol,PERIOD_CURRENT,0);
   if(h<=0.0 || l<=0.0 || c<=0.0) return;
   long rv=iRealVolume(_Symbol,PERIOD_CURRENT,0),tv=iTickVolume(_Symbol,PERIOD_CURRENT,0);
   double v=(rv>0)?(double)rv:(double)tv;
   if(v<=0.0) v=1.0;
   double cv=gVwapCumV+v;
   if(cv<=0.0) return;
   gVwapLine[n-1]=(gVwapCumPV+(h+l+c)/3.0*v)/cv;
   gVwapTime[n-1]=iTime(_Symbol,PERIOD_CURRENT,0);
   gVwapVal=NormalizeDouble(gVwapLine[n-1],_Digits);
   if(n>=2)
   {
      string s=VwapSegName(gVwapTime[n-1]);
      if(ObjectFind(0,s)>=0)
      {
         ObjectMove(0,s,0,gVwapTime[n-2],gVwapLine[n-2]);
         ObjectMove(0,s,1,gVwapTime[n-1],gVwapLine[n-1]);
      }
   }
   VwapTag();
}

void VwapTag()
{
   if(gVwapVal<=0) return;
   TagAt(VP+"tag",RightEdge(),gVwapVal,"VWAP "+DoubleToString(gVwapVal,_Digits),InpVwapColor,7,ANCHOR_LEFT_LOWER,true);
}

void ChkConfluence()
{
   string n=VP+"conf";
   if(gPocPrice<=0 || gVwapVal<=0){ ObjectDelete(0,n); return; }
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(MathAbs(gVwapVal-gPocPrice)>(double)MathMax(1,InpConflPts)*pt){ ObjectDelete(0,n); return; }
   double mid=(gVwapVal+gPocPrice)/2.0;
   datetime t=iTime(_Symbol,PERIOD_CURRENT,0);
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_ARROW,0,t,mid);
      ObjectSetInteger(0,n,OBJPROP_ARROWCODE,159);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_COLOR,C'138,60,200');
   }
   ObjectMove(0,n,0,t,mid);
}

//==================================================================
//   HOOMAN LEVELS
//   Yesterday's high/low (yellow, solid) split in halves (50% green,
//   solid), quarters (yellow, dashed) and eighths (white, dashed),
//   extended from yesterday into today. Drag any line and the whole
//   ladder moves with it; HM RESET puts it back.
//==================================================================
void HoomanCalc()
{
   datetime d1=iTime(_Symbol,PERIOD_D1,1);
   if(d1<=0) return;
   if(d1==gHmDay) return;
   double dh[],dl[];
   ArraySetAsSeries(dh,false); ArraySetAsSeries(dl,false);
   if(CopyHigh(_Symbol,PERIOD_D1,1,1,dh)<1) return;
   if(CopyLow (_Symbol,PERIOD_D1,1,1,dl)<1) return;
   if(dh[0]<=dl[0]) return;
   gHmHigh=dh[0]; gHmLow=dl[0]; gHmT0=d1; gHmDay=d1; gHmShift=0;
}

double HoomanLevel(int i)                     // i = 0..8  ->  0% .. 100%
{
   return(NormalizeDouble(gHmLow+(gHmHigh-gHmLow)*i/8.0+gHmShift,_Digits));
}

void HoomanStyle(int i,color &c,ENUM_LINE_STYLE &st,int &wd)
{
   if(i==0 || i==8){ c=InpHmHiLo;   st=STYLE_SOLID; wd=2; return; }
   if(i==4)        { c=InpHmMid;    st=STYLE_SOLID; wd=2; return; }
   if(i==2 || i==6){ c=InpHmQuarter;st=STYLE_DASH;  wd=1; return; }
   c=InpHmEighth; st=STYLE_DASH; wd=1;
}

void HoomanDraw()
{
   HoomanCalc();
   if(gHmHigh<=gHmLow || gHmT0<=0) return;
   datetime tR=RightEdge();
   for(int i=0;i<=8;i++)
   {
      double p=HoomanLevel(i);
      color c; ENUM_LINE_STYLE st; int wd;
      HoomanStyle(i,c,st,wd);
      string n=HP+"l"+IntegerToString(i);
      if(ObjectFind(0,n)<0)
      {
         ObjectCreate(0,n,OBJ_TREND,0,gHmT0,p,tR,p);
         ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,true);
         ObjectSetInteger(0,n,OBJPROP_BACK,false);
         ObjectSetInteger(0,n,OBJPROP_SELECTABLE,true);      // drag the ladder
         ObjectSetInteger(0,n,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
         ObjectSetString (0,n,OBJPROP_TOOLTIP,"Hooman "+DoubleToString(i*12.5,1)+"% - drag to move all");
      }
      ObjectMove(0,n,0,gHmT0,p);
      ObjectMove(0,n,1,tR,p);
      ObjectSetInteger(0,n,OBJPROP_COLOR,c);
      ObjectSetInteger(0,n,OBJPROP_STYLE,st);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,wd);

      string pct=(i%2==0)?IntegerToString(i*25/2):DoubleToString(i*12.5,1);
      TagAt(HP+"t"+IntegerToString(i),tR,p,pct+"%  "+DoubleToString(p,_Digits),c,7,ANCHOR_LEFT_LOWER,false);
   }
}

void HoomanDragged(string name)
{
   string id=StringSubstr(name,StringLen(HP));
   if(StringSubstr(id,0,1)!="l") return;
   int i=(int)StringToInteger(StringSubstr(id,1));
   if(i<0 || i>8) return;
   double p0=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
   double p1=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double p=(MathAbs(p0-p1)<pt/2.0)?p0:(p0+p1)/2.0;   // body drag or an endpoint
   double base=gHmLow+(gHmHigh-gHmLow)*i/8.0;
   gHmShift=NormalizeDouble(p-base,_Digits);
   HoomanDraw();
   Say("Hooman levels moved "+DoubleToString(gHmShift/pt,0)+" pts");
   ChartRedraw();
}

//==================================================================
//   TP / SL TOOL  (TradingView style)
//   One toggle in TOOLS cycles OFF -> LONG -> SHORT. The draggable
//   parts are full-width horizontal lines - the smoothest thing MT5
//   can drag: grab the Target or Stop line anywhere and pull it, grab
//   the Entry line to move the whole tool, grab the grey handle on
//   either side of the box to make it wider or narrower. The green
//   profit box, red loss box, pills and P&L line follow live.
//   Planner while flat (BUY / SELL use its levels and lot); attached
//   to the real position once one exists, where moving Stop / Target
//   modifies the position.
//==================================================================
void ToolPlace(int dir)
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(ask<=0.0 || bid<=0.0 || pt<=0.0){ SayErr("No price"); return; }

   ObjectsDeleteAll(0,TP_);
   gTool=dir; gToolLive=false; gToolTicket=0; gToolHide=false;
   double entry=(dir==1)?ask:bid;
   double d=MathMax((double)gSLPts*pt,MinStopDist());
   gToolEntry=NormalizeDouble(entry,_Digits);
   gToolSL=NormalizeDouble((dir==1)?entry-d:entry+d,_Digits);
   gToolTP=NormalizeDouble((dir==1)?entry+d*gRR:entry-d*gRR,_Digits);
   gToolT1=iTime(_Symbol,PERIOD_CURRENT,0);
   gToolT2=BarsAhead((int)MathMax(5,InpToolBars));
   ToolCommit();
   ToolDrawAll();
   ToolButton();
   Say((dir==1?"LONG":"SHORT")+" tool - drag the lines, side handles set the width");
}

//--- the TOOLS toggle: OFF -> LONG -> SHORT -> OFF, or show / hide while live
void ToolCycle()
{
   if(gToolLive || ToolHasPosition())
   {
      gToolHide=!gToolHide;
      if(gToolHide){ ObjectsDeleteAll(0,TP_); gToolLive=false; gToolTicket=0; gTool=0; Say("TP/SL overlay hidden"); }
      else         { ToolSync(); Say("TP/SL overlay shown"); }
      ToolButton();
      return;
   }
   if(gTool==0)      ToolPlace(1);
   else if(gTool==1) ToolPlace(2);
   else { ToolClear(); Say("TP/SL tool off"); }
   ToolButton();
}

bool ToolHasPosition()
{
   long type=0; double open=0,sl=0,tp=0,vol=0; datetime when=0;
   return(FindOurPosition(type,open,sl,tp,when,vol)!=0);
}

//--- label + colour of the toggle button
void ToolButton()
{
   string t="TP/SL"; color bg=gcBtn,fg=gcBtnTx;
   if(gToolHide)            { t="TP/SL"; }
   else if(gToolLive)       { t="LIVE";  bg=gcOn;       fg=gcOnTx; }
   else if(gTool==1)        { t="LONG";  bg=gcBuySoft;  fg=gcBuySoftTx; }
   else if(gTool==2)        { t="SHORT"; bg=gcSellSoft; fg=gcSellSoftTx; }
   SetT("tps",t); SetBg("tps",bg); SetC("tps",fg);
}

void ToolCommit()  { bEntry=gToolEntry; bSL=gToolSL; bTP=gToolTP; bT1=gToolT1; bT2=gToolT2; }
void ToolRestore() { gToolEntry=bEntry; gToolSL=bSL; gToolTP=bTP; gToolT1=bT1; gToolT2=bT2; }

void ToolClear()
{
   gTool=0; gToolLive=false; gToolTicket=0;
   gToolEntry=0; gToolSL=0; gToolTP=0; gToolPosSL=0; gToolPosTP=0;
   ObjectsDeleteAll(0,TP_);
   ToolButton();
}

//--- planner levels follow the steppers until a line is dragged
void ToolRefit()
{
   if(gTool==0 || gToolLive) return;
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double d=MathMax((double)gSLPts*pt,MinStopDist());
   bool lng=(gTool==1);
   gToolSL=NormalizeDouble(lng?gToolEntry-d:gToolEntry+d,_Digits);
   gToolTP=NormalizeDouble(lng?gToolEntry+d*gRR:gToolEntry-d*gRR,_Digits);
   ToolCommit();
   ToolDrawAll();
}

ulong FindOurPosition(long &type,double &open,double &sl,double &tp,datetime &when,double &vol)
{
   ulong best=0; datetime bt=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      datetime t=(datetime)PositionGetInteger(POSITION_TIME);
      if(best==0 || t>bt)
      {
         best=tk; bt=t;
         type=PositionGetInteger(POSITION_TYPE);
         open=PositionGetDouble(POSITION_PRICE_OPEN);
         sl=PositionGetDouble(POSITION_SL);
         tp=PositionGetDouble(POSITION_TP);
         when=t;
         vol=PositionGetDouble(POSITION_VOLUME);
      }
   }
   return(best);
}

//--- attach to / detach from the real position (called every refresh)
void ToolSync()
{
   long type=0; double open=0,sl=0,tp=0,vol=0; datetime when=0;
   ulong tk=FindOurPosition(type,open,sl,tp,when,vol);
   if(tk==0)
   {
      if(gToolLive){ ToolClear(); Say("Position closed - tool cleared"); }
      if(gToolHide){ gToolHide=false; ToolButton(); }
      return;
   }
   if(gToolHide) return;

   bool lng=(type==POSITION_TYPE_BUY);
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double d=MathMax((double)gSLPts*pt,MinStopDist());

   if(!gToolLive || gToolTicket!=tk)
   {
      ObjectsDeleteAll(0,TP_);
      gToolLive=true; gToolTicket=tk; gTool=lng?1:2;
      gToolEntry=open;
      gToolSL=(sl>0)?sl:NormalizeDouble(lng?open-d:open+d,_Digits);
      gToolTP=(tp>0)?tp:NormalizeDouble(lng?open+d*gRR:open-d*gRR,_Digits);
      gToolPosSL=sl; gToolPosTP=tp;
      int sh=iBarShift(_Symbol,PERIOD_CURRENT,when,false);
      gToolT1=(sh>=0)?iTime(_Symbol,PERIOD_CURRENT,sh):iTime(_Symbol,PERIOD_CURRENT,0);
      gToolT2=BarsAhead((int)MathMax(5,InpToolBars));
      ToolCommit();
      ToolDrawAll();
      ToolButton();
      Say("TP/SL attached to position #"+IntegerToString((long)tk));
      return;
   }
   bool changed=false;
   if(sl>0 && MathAbs(sl-gToolPosSL)>=pt/2.0){ gToolSL=sl; changed=true; }
   if(tp>0 && MathAbs(tp-gToolPosTP)>=pt/2.0){ gToolTP=tp; changed=true; }
   gToolPosSL=sl; gToolPosTP=tp;
   if(MathAbs(open-gToolEntry)>=pt/2.0){ gToolEntry=open; changed=true; }
   if(changed){ ToolCommit(); ToolDrawAll(); }
}

//--- visual box (never selectable: the lines take the mouse)
void ToolBox(string id,double pA,double pB,color c)
{
   RectAt(TP_+id,gToolT1,pA,gToolT2,pB,Translucent(c,InpToolOpacity),true);
}

//--- draggable full-width level
void ToolHLine(string id,double price,color c,int wd,ENUM_LINE_STYLE st,bool drag)
{
   string n=TP_+id;
   bool fresh=(ObjectFind(0,n)<0);
   if(fresh)
   {
      ObjectCreate(0,n,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,n,OBJPROP_BACK,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_ZORDER,3);
   }
   ObjectSetDouble (0,n,OBJPROP_PRICE,0,price);
   ObjectSetInteger(0,n,OBJPROP_COLOR,c);
   ObjectSetInteger(0,n,OBJPROP_WIDTH,wd);
   ObjectSetInteger(0,n,OBJPROP_STYLE,st);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,drag);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,drag);      // always armed: one gesture drags it
   ObjectSetString (0,n,OBJPROP_TOOLTIP,drag?"Drag":"");
}

//--- draggable side handle: a short vertical segment from stop to target
void ToolEdge(string id,datetime t)
{
   string n=TP_+id;
   double lo=MathMin(gToolSL,gToolTP),hi=MathMax(gToolSL,gToolTP);
   bool fresh=(ObjectFind(0,n)<0);
   if(fresh)
   {
      ObjectCreate(0,n,OBJ_TREND,0,t,lo,t,hi);
      ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,n,OBJPROP_BACK,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,true);
      ObjectSetInteger(0,n,OBJPROP_SELECTED,true);
      ObjectSetInteger(0,n,OBJPROP_ZORDER,3);
      ObjectSetString (0,n,OBJPROP_TOOLTIP,"Drag to change the box width");
   }
   ObjectMove(0,n,0,t,lo);
   ObjectMove(0,n,1,t,hi);
   ObjectSetInteger(0,n,OBJPROP_SELECTED,true);
   ObjectSetInteger(0,n,OBJPROP_COLOR,C'150,155,170');
   ObjectSetInteger(0,n,OBJPROP_WIDTH,3);
   ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
}

//--- TradingView style labels: filled pills centred in the box, a grey
//--- two-line P&L pill on the entry, and a dashed line from the entry
//--- point to the current price. Pills live in pixel space, so they are
//--- re-placed on every refresh and whenever the chart scrolls or zooms.
void ToolLabels()
{
   if(gTool==0) return;
   bool lng=(gTool==1);
   double lot=ToolLot();
   ENUM_ORDER_TYPE ot=lng?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double pTP=0,pSL=0,pNow=0;
   if(!OrderCalcProfit(ot,_Symbol,lot,gToolEntry,gToolTP,pTP)) pTP=0;
   if(!OrderCalcProfit(ot,_Symbol,lot,gToolEntry,gToolSL,pSL)) pSL=0;
   double cur=lng?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(gToolLive && PositionSelectByTicket(gToolTicket))
      pNow=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   else if(cur<=0.0 || !OrderCalcProfit(ot,_Symbol,lot,gToolEntry,cur,pNow)) pNow=0;

   double pctTP=(gToolEntry>0)?MathAbs(gToolTP-gToolEntry)/gToolEntry*100.0:0;
   double pctSL=(gToolEntry>0)?MathAbs(gToolSL-gToolEntry)/gToolEntry*100.0:0;
   double rr=(MathAbs(gToolSL-gToolEntry)>0)?MathAbs(gToolTP-gToolEntry)/MathAbs(gToolSL-gToolEntry):0;

   string sTP="Target: "+DoubleToString(gToolTP,_Digits)+" ("+DoubleToString(pctTP,2)+"%) "+
              DoubleToString(MathAbs(gToolTP-gToolEntry)/pt,0)+", Amount: "+DoubleToString(MathAbs(pTP),2);
   string sSL="Stop: "+DoubleToString(gToolSL,_Digits)+" ("+DoubleToString(pctSL,2)+"%) "+
              DoubleToString(MathAbs(gToolSL-gToolEntry)/pt,0)+", Amount: "+DoubleToString(MathAbs(pSL),2);
   string sM1="Open P&L: "+Money(pNow)+", Qty: "+DoubleToString(lot,VolDigits());
   string sM2="Risk/Reward Ratio: "+DoubleToString(rr,2);

   //--- pixel geometry of the box
   int x1=0,x2=0,yE=0,yT=0,yS=0,d=0;
   bool ok=ChartTimePriceToXY(0,0,gToolT1,gToolEntry,x1,yE);
   ok=ChartTimePriceToXY(0,0,gToolT2,gToolEntry,x2,d) && ok;
   ok=ChartTimePriceToXY(0,0,gToolT1,gToolTP,d,yT) && ok;
   ok=ChartTimePriceToXY(0,0,gToolT1,gToolSL,d,yS) && ok;
   int xc=(x1+x2)/2;

   PillXY(TP_+"pt" ,xc-PillW(sTP,8)/2,lng?yT+3:yT-21,sTP,InpTpColor,8,ok);
   PillXY(TP_+"ps" ,xc-PillW(sSL,8)/2,lng?yS-21:yS+3,sSL,InpSlColor,8,ok);
   PillXY(TP_+"pm1",xc-PillW(sM1,8)/2,yE-19,sM1,C'110,114,126',8,ok);
   PillXY(TP_+"pm2",xc-PillW(sM2,8)/2,yE+1 ,sM2,C'110,114,126',8,ok);

   //--- dashed line from the entry point to the current price
   datetime tNow=iTime(_Symbol,PERIOD_CURRENT,0);
   string n=TP_+"pnl";
   if(cur>0.0 && tNow>0)
   {
      if(ObjectFind(0,n)<0)
      {
         ObjectCreate(0,n,OBJ_TREND,0,gToolT1,gToolEntry,tNow,cur);
         ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false);
         ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DASH);
         ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,n,OBJPROP_COLOR,C'150,155,170');
         ObjectSetInteger(0,n,OBJPROP_BACK,false);
         ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      }
      ObjectMove(0,n,0,gToolT1,gToolEntry);
      ObjectMove(0,n,1,tNow,cur);
   }
}


//--- pixel-space text pills (used by the position tool and the sessions)
int PillW(string text,int fs){ return((int)(StringLen(text)*0.78*fs)+16); }

void PillXY(string n,int x,int y,string text,color bg,int fs,bool visible)
{
   int w=PillW(text,fs),h=fs*2+2;
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS);
   bool vis=visible && (x+w>0 && x<cw && y+h>0 && y<ch);
   if(ObjectFind(0,n)<0)
   {
      ObjectCreate(0,n,OBJ_EDIT,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_READONLY,true);
      ObjectSetInteger(0,n,OBJPROP_ALIGN,ALIGN_CENTER);
      ObjectSetString (0,n,OBJPROP_FONT,FONT_UI);
      ObjectSetInteger(0,n,OBJPROP_FONTSIZE,fs);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,n,OBJPROP_ZORDER,4);
   }
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_COLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,TextOn(bg));
   if(ObjectGetString(0,n,OBJPROP_TEXT)!=text) ObjectSetString(0,n,OBJPROP_TEXT,text);
   ObjectSetInteger(0,n,OBJPROP_TIMEFRAMES,vis?OBJ_ALL_PERIODS:OBJ_NO_PERIODS);
}

//--- everything from the current state
void ToolDrawAll(){ ToolDrawExcept(""); }

//--- everything except the object under the mouse
void ToolDrawExcept(string skip)
{
   if(gTool==0) return;
   ToolBox("zp",gToolEntry,gToolTP,InpTpColor);
   ToolBox("zl",gToolEntry,gToolSL,InpSlColor);
   if(skip!="tp") ToolHLine("tp",gToolTP,InpTpColor,2,STYLE_SOLID,true);
   if(skip!="sl") ToolHLine("sl",gToolSL,InpSlColor,2,STYLE_SOLID,true);
   if(skip!="en") ToolHLine("en",gToolEntry,InpEntryColor,1,STYLE_DASH,!gToolLive);
   if(skip!="tl") ToolEdge("tl",gToolT1);
   if(skip!="tr") ToolEdge("tr",gToolT2);
   ToolLabels();
}

//--- periodic upkeep: labels (live P/L) and keep the box ahead of price
void ToolRefresh()
{
   if(gTool==0) return;
   if(bT2<BarsAhead(3))
   {
      bT2=BarsAhead((int)MathMax(5,InpToolBars));
      gToolT2=bT2;
      ToolDrawAll();
      return;
   }
   ToolLabels();
}

//--- lot the tool represents
double ToolLot()
{
   if(gToolLive && PositionSelectByTicket(gToolTicket)) return(PositionGetDouble(POSITION_VOLUME));
   double typed=ReadNum(GetT("elot"));
   if(typed>0) return(NormVol(typed));
   double rm=0;
   return(LotByRisk((gTool==1)?ORDER_TYPE_BUY:ORDER_TYPE_SELL,gToolEntry,gToolSL,rm));
}

//--- which handle no longer matches the state = the one being dragged
string ToolDraggedObj()
{
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   long per=PeriodSeconds();
   string n;
   n=TP_+"tp"; if(ObjectFind(0,n)>=0 && MathAbs(ObjectGetDouble(0,n,OBJPROP_PRICE,0)-gToolTP)>=pt/2.0) return("tp");
   n=TP_+"sl"; if(ObjectFind(0,n)>=0 && MathAbs(ObjectGetDouble(0,n,OBJPROP_PRICE,0)-gToolSL)>=pt/2.0) return("sl");
   n=TP_+"en"; if(ObjectFind(0,n)>=0 && MathAbs(ObjectGetDouble(0,n,OBJPROP_PRICE,0)-gToolEntry)>=pt/2.0) return("en");
   n=TP_+"tl"; if(ObjectFind(0,n)>=0 && MathAbs((long)ObjectGetInteger(0,n,OBJPROP_TIME,0)-(long)gToolT1)>=per/2) return("tl");
   n=TP_+"tr"; if(ObjectFind(0,n)>=0 && MathAbs((long)ObjectGetInteger(0,n,OBJPROP_TIME,0)-(long)gToolT2)>=per/2) return("tr");
   return("");
}

//--- read one handle and work out the tool it describes
bool ToolDerive(string id,double &nE,double &nS,double &nT,datetime &nT1,datetime &nT2)
{
   string n=TP_+id;
   if(ObjectFind(0,n)<0) return(false);
   long per=PeriodSeconds();
   nE=gToolEntry; nS=gToolSL; nT=gToolTP; nT1=gToolT1; nT2=gToolT2;

   if(id=="tp")      nT=NormalizeDouble(ObjectGetDouble(0,n,OBJPROP_PRICE,0),_Digits);
   else if(id=="sl") nS=NormalizeDouble(ObjectGetDouble(0,n,OBJPROP_PRICE,0),_Digits);
   else if(id=="en")
   {
      if(gToolLive) return(false);                         // the fill price is fixed
      double p=NormalizeDouble(ObjectGetDouble(0,n,OBJPROP_PRICE,0),_Digits);
      double d=p-gToolEntry;
      nE=p; nS=NormalizeDouble(gToolSL+d,_Digits); nT=NormalizeDouble(gToolTP+d,_Digits);
   }
   else if(id=="tl")
   {
      nT1=(datetime)ObjectGetInteger(0,n,OBJPROP_TIME,0);
      if((long)nT2-(long)nT1<per*3) nT1=(datetime)((long)nT2-per*3);
   }
   else if(id=="tr")
   {
      nT2=(datetime)ObjectGetInteger(0,n,OBJPROP_TIME,0);
      if((long)nT2-(long)nT1<per*3) nT2=(datetime)((long)nT1+per*3);
   }
   else return(false);
   return(true);
}

bool ToolValid(double e,double s,double t)
{
   double minD=MinStopDist();
   if(gTool==1) return(t>e+minD && s<e-minD);
   return(t<e-minD && s>e+minD);
}

//--- live follow while the mouse is still down on a handle
void ToolPreview()
{
   if(gTool==0) return;
   string id=ToolDraggedObj();
   if(id=="") return;
   double nE,nS,nT; datetime nT1,nT2;
   if(!ToolDerive(id,nE,nS,nT,nT1,nT2)) return;
   if(!ToolValid(nE,nS,nT)) return;
   gToolEntry=nE; gToolSL=nS; gToolTP=nT; gToolT1=nT1; gToolT2=nT2;
   ToolDrawExcept(id);
   ToolPanelRows();
   ChartRedraw();
}

//--- mouse released on a handle: validate, apply, commit
void ToolDragged(string name)
{
   if(gTool==0) return;
   string id=StringSubstr(name,StringLen(TP_));
   double nE,nS,nT; datetime nT1,nT2;
   if(!ToolDerive(id,nE,nS,nT,nT1,nT2)){ ToolDrawAll(); ChartRedraw(); return; }
   if(!ToolValid(nE,nS,nT))
   {
      SayErr("Stop and Target must stay on their side of the entry");
      ToolRestore(); ToolDrawAll(); UpdInfo(); ChartRedraw();
      return;
   }
   gToolEntry=nE; gToolSL=nS; gToolTP=nT; gToolT1=nT1; gToolT2=nT2;
   if(gToolLive && (MathAbs(nS-bSL)>0 || MathAbs(nT-bTP)>0)) ToolApply();
   ToolCommit();
   ToolDrawAll();
   UpdInfo();
   ChartRedraw();
}

//--- push the tool's stop / target onto the real position
void ToolApply()
{
   if(!PositionSelectByTicket(gToolTicket)) return;
   double curSL=PositionGetDouble(POSITION_SL),curTP=PositionGetDouble(POSITION_TP);
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(MathAbs(curSL-gToolSL)<pt/2.0 && MathAbs(curTP-gToolTP)<pt/2.0) return;

   long ty=PositionGetInteger(POSITION_TYPE);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double minD=MinStopDist();
   bool ok=(ty==POSITION_TYPE_BUY)?(gToolSL<bid-minD && gToolTP>bid+minD):(gToolSL>ask+minD && gToolTP<ask-minD);
   if(!ok)
   {
      SayErr("Level too close to the market price");
      if(curSL>0) gToolSL=curSL;
      if(curTP>0) gToolTP=curTP;
      return;
   }
   if(m_trade.PositionModify(gToolTicket,gToolSL,gToolTP))
   {
      gToolPosSL=gToolSL; gToolPosTP=gToolTP;
      SayOk("Position #"+IntegerToString((long)gToolTicket)+" SL/TP updated");
   }
   else
   {
      SayErr("Modify failed "+IntegerToString(m_trade.ResultRetcode())+": "+m_trade.ResultRetcodeDescription());
      if(curSL>0) gToolSL=curSL;
      if(curTP>0) gToolTP=curTP;
   }
}

//--- panel rows for the tool
void ToolPanelRows()
{
   if(gTool==0)
   {
      SetT("teV","---"); SetT("tsV","---"); SetT("ttV","---"); SetT("trV","---");
      SetT("teL","Entry");
      return;
   }
   bool lng=(gTool==1);
   double lot=ToolLot();
   ENUM_ORDER_TYPE ot=lng?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double pTP=0,pSL=0;
   if(!OrderCalcProfit(ot,_Symbol,lot,gToolEntry,gToolTP,pTP)) pTP=0;
   if(!OrderCalcProfit(ot,_Symbol,lot,gToolEntry,gToolSL,pSL)) pSL=0;
   double pctTP=(gToolEntry>0)?MathAbs(gToolTP-gToolEntry)/gToolEntry*100.0:0;
   double pctSL=(gToolEntry>0)?MathAbs(gToolSL-gToolEntry)/gToolEntry*100.0:0;
   double rr=(MathAbs(gToolSL-gToolEntry)>0)?MathAbs(gToolTP-gToolEntry)/MathAbs(gToolSL-gToolEntry):0;

   SetT("teL",(lng?"Entry (LONG":"Entry (SHORT")+(gToolLive?" live)":")"));
   SetT("teV",DoubleToString(gToolEntry,_Digits));
   SetT("tsV","-"+DoubleToString(pctSL,2)+"%  "+Money(pSL));
   SetT("ttV","+"+DoubleToString(pctTP,2)+"%  "+Money(pTP));
   SetT("trV","1:"+DoubleToString(rr,2)+"  "+DoubleToString(lot,VolDigits())+" lot");
}

//==================================================================
//                       MONEY MANAGEMENT
//==================================================================
double RiskBase()
{
   double bal=AccountInfoDouble(ACCOUNT_BALANCE),eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(bal<=0.0) return(eq);
   if(eq <=0.0) return(bal);
   return(MathMin(bal,eq));
}

//--- money lost on 1.00 lot from entry to stop, priced by the broker
double LossPerLot(ENUM_ORDER_TYPE type,double entry,double slPrice)
{
   if(entry<=0.0 || slPrice<=0.0 || entry==slPrice) return(0.0);
   ENUM_ORDER_TYPE t=(type==ORDER_TYPE_SELL || type==ORDER_TYPE_SELL_LIMIT)?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   double profit=0;
   if(OrderCalcProfit(t,_Symbol,1.0,entry,slPrice,profit) && profit!=0.0) return(MathAbs(profit));
   double tv=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),ts=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double d=MathAbs(entry-slPrice);
   if(tv>0.0 && ts>0.0) return(d/ts*tv);
   return(0.0);
}

double LotByRisk(ENUM_ORDER_TYPE type,double entry,double slPrice,double &riskMoney)
{
   riskMoney=0;
   double base=RiskBase(),lpl=LossPerLot(type,entry,slPrice);
   if(base<=0.0 || lpl<=0.0) return(MinLot());
   double lot=NormVol(base*gRisk/100.0/lpl);
   double ceiling=NormVol(base*MAX_RISK_PCT/100.0/lpl);
   if(lot>ceiling) lot=ceiling;
   if(lot<MinLot()) lot=MinLot();
   riskMoney=lpl*lot;
   return(lot);
}

//--- auto lot shown in the panel: from the tool when placed, else from SL points
double AutoLot(double &riskMoney)
{
   riskMoney=0;
   if(gTool!=0 && gToolEntry>0 && gToolSL>0)
      return(LotByRisk((gTool==1)?ORDER_TYPE_BUY:ORDER_TYPE_SELL,gToolEntry,gToolSL,riskMoney));
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   if(gSLPts<=0 || pt<=0.0 || ask<=0.0) return(MinLot());
   return(LotByRisk(ORDER_TYPE_BUY,ask,ask-(double)gSLPts*pt,riskMoney));
}

//--- lot the buttons send: typed wins, then tool, then SL points
double TradeLot(bool isBuy,double entry,double sl)
{
   double typed=ReadNum(GetT("elot"));
   if(typed>0) return(NormVol(typed));
   double rm=0;
   return(LotByRisk(isBuy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,entry,sl,rm));
}

//--- stop / target for a market order: from the planner tool when it
//--- matches the direction, else from the steppers
void PlanLevels(bool isBuy,double ref,double &sl,double &tp)
{
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double dist=MathMax((double)gSLPts*pt,MinStopDist());
   bool useTool=(gTool!=0 && !gToolLive && ((gTool==1)==isBuy));
   if(useTool)
   {
      sl=gToolSL; tp=gToolTP;
      // shift with the actual fill price so the distances are what was planned
      double d=ref-gToolEntry;
      sl=NormalizeDouble(sl+d,_Digits); tp=NormalizeDouble(tp+d,_Digits);
      return;
   }
   sl=NormalizeDouble(isBuy?ref-dist:ref+dist,_Digits);
   tp=(gRR>0)?NormalizeDouble(isBuy?ref+dist*gRR:ref-dist*gRR,_Digits):0;
}

double LimitPrice(bool isBuy)
{
   double typed=ReadNum(GetT("elim"));
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double dist=MathMax((double)MathMax(1,InpLimitDist)*pt,MinStopDist());
   double price=(typed>0)?typed:0;
   if(price<=0 && gTool!=0 && !gToolLive && ((gTool==1)==isBuy)) price=gToolEntry;  // tool entry
   if(price<=0) price=isBuy?(bid-dist):(ask+dist);
   if(isBuy  && price>bid-MinStopDist()) price=bid-dist;
   if(!isBuy && price<ask+MinStopDist()) price=ask+dist;
   return(NormalizeDouble(price,_Digits));
}

//==================================================================
//                     TRADE CHECKS + EXECUTION
//==================================================================
string TradeBlockReason()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return("AutoTrading is OFF - press the AutoTrading button");
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))           return("EA not allowed to trade - tick Allow Algo Trading");
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))   return("Trading disabled for this account");
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT))    return("Broker disabled algo trading on this account");
   long tm=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(tm==SYMBOL_TRADE_MODE_DISABLED)  return(_Symbol+": trading disabled");
   if(tm==SYMBOL_TRADE_MODE_CLOSEONLY) return(_Symbol+": close only");
   if(SymbolInfoDouble(_Symbol,SYMBOL_ASK)<=0.0 || SymbolInfoDouble(_Symbol,SYMBOL_BID)<=0.0)
      return("No price for "+_Symbol+" - market closed?");
   return("");
}

bool TradeReady()
{
   string why=TradeBlockReason();
   if(why=="") return(true);
   SayErr(why);
   return(false);
}

bool MarginOk(ENUM_ORDER_TYPE type,double lot,double price)
{
   double need=0;
   if(!OrderCalcMargin(type,_Symbol,lot,price,need)) return(true);
   double have=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(need>have){ SayErr("Not enough margin: need "+DoubleToString(need,2)+" have "+DoubleToString(have,2)); return(false); }
   return(true);
}

bool SendOrder(bool isBuy,bool pending,double lot,double price,double sl,double tp)
{
   ENUM_ORDER_TYPE_FILLING fb[3]={ORDER_FILLING_FOK,ORDER_FILLING_IOC,ORDER_FILLING_RETURN};
   int fill=0,requote=0;
   for(int i=0;i<8;i++)
   {
      bool ok;
      if(!pending) ok=isBuy?m_trade.Buy (lot,_Symbol,0.0,sl,tp,"CC Buy"):m_trade.Sell(lot,_Symbol,0.0,sl,tp,"CC Sell");
      else         ok=isBuy?m_trade.BuyLimit (lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"CC BuyLmt")
                           :m_trade.SellLimit(lot,price,_Symbol,sl,tp,ORDER_TIME_GTC,0,"CC SellLmt");
      if(ok) return(true);
      uint rc=m_trade.ResultRetcode();
      if(rc==TRADE_RETCODE_INVALID_FILL && fill<3){ m_trade.SetTypeFilling(fb[fill]); fill++; continue; }
      if((rc==TRADE_RETCODE_REQUOTE || rc==TRADE_RETCODE_PRICE_CHANGED || rc==TRADE_RETCODE_PRICE_OFF) && !pending && requote<2){ requote++; continue; }
      return(false);
   }
   return(false);
}

void ReportFail(string what)
{
   SayErr(what+" failed "+IntegerToString(m_trade.ResultRetcode())+": "+m_trade.ResultRetcodeDescription());
}

void XMarket(bool isBuy)
{
   Print("[CC] ",(isBuy?"BUY":"SELL")," button pressed");
   if(!TradeReady()) return;
   double ref=isBuy?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double sl=0,tp=0;
   PlanLevels(isBuy,ref,sl,tp);
   double lot=TradeLot(isBuy,ref,sl);
   if(lot<=0){ SayErr("Invalid lot size"); return; }
   if(!MarginOk(isBuy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,lot,ref)) return;
   if(SendOrder(isBuy,false,lot,0.0,sl,tp)) SayOk((isBuy?"BUY ":"SELL ")+DoubleToString(lot,VolDigits())+" filled");
   else ReportFail(isBuy?"Buy":"Sell");
}

void XLimit(bool isBuy)
{
   Print("[CC] ",(isBuy?"BUY LIMIT":"SELL LIMIT")," button pressed");
   if(!TradeReady()) return;
   double price=LimitPrice(isBuy);
   if(price<=0){ SayErr("Invalid limit price"); return; }
   double sl=0,tp=0;
   PlanLevels(isBuy,price,sl,tp);
   double lot=TradeLot(isBuy,price,sl);
   if(lot<=0){ SayErr("Invalid lot size"); return; }
   if(!MarginOk(isBuy?ORDER_TYPE_BUY_LIMIT:ORDER_TYPE_SELL_LIMIT,lot,price)) return;
   if(SendOrder(isBuy,true,lot,price,sl,tp)) SayOk((isBuy?"BUY LIMIT @":"SELL LIMIT @")+DoubleToString(price,_Digits));
   else ReportFail(isBuy?"Buy limit":"Sell limit");
}

void XClose(double frac)
{
   int done=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      double vol=PositionGetDouble(POSITION_VOLUME);
      if(frac>=1.0){ if(m_trade.PositionClose(tk)) done++; continue; }
      double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
      if(st<=0) st=0.01;
      double cv=MathFloor((vol*frac+1e-9)/st)*st;
      if(cv<mn) cv=mn;
      if(cv>=vol){ if(m_trade.PositionClose(tk)) done++; continue; }
      if(m_trade.PositionClosePartial(tk,NormalizeDouble(cv,VolDigits()))) done++;
   }
   if(done>0) SayOk((frac>=1.0?"Closed ":"Partial close ")+IntegerToString(done)+" position(s)");
   else       Say("No position to close");
}

void XBreakEven()
{
   int done=0;
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT),minD=MinStopDist();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      double op=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
      {
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),nsl=NormalizeDouble(op+pt,_Digits);
         if(bid-nsl<minD) continue;
         if(sl>0 && nsl<=sl) continue;
         if(m_trade.PositionModify(tk,nsl,tp)) done++;
      }
      else
      {
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),nsl=NormalizeDouble(op-pt,_Digits);
         if(nsl-ask<minD) continue;
         if(sl>0 && nsl>=sl) continue;
         if(m_trade.PositionModify(tk,nsl,tp)) done++;
      }
   }
   if(done>0) SayOk("Break even applied to "+IntegerToString(done));
   else       Say("Nothing to move to break even");
}

void XDelPending()
{
   int done=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong tk=OrderGetTicket(i);
      if(tk==0) continue;
      if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC)!=(long)InpMagic) continue;
      if(m_trade.OrderDelete(tk)) done++;
   }
   if(done>0) SayOk("Deleted "+IntegerToString(done)+" pending order(s)");
   else       Say("No pending orders");
}

void Trail()
{
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT),minD=MinStopDist();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      double op=PositionGetDouble(POSITION_PRICE_OPEN),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
      {
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
         if((bid-op)/pt<InpTrailStart) continue;
         double nsl=NormalizeDouble(bid-(double)InpTrailStep*pt,_Digits);
         if(bid-nsl<minD) continue;
         if(sl>0 && nsl-sl<pt) continue;
         m_trade.PositionModify(tk,nsl,tp);
      }
      else
      {
         double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         if((op-ask)/pt<InpTrailStart) continue;
         double nsl=NormalizeDouble(ask+(double)InpTrailStep*pt,_Digits);
         if(nsl-ask<minD) continue;
         if(sl>0 && sl-nsl<pt) continue;
         m_trade.PositionModify(tk,nsl,tp);
      }
   }
}

//==================================================================
//   TESTER-ONLY STRATEGY  (EMA cross, ATR stop, risk sized)
//==================================================================
void AutoStrategy(bool newBar)
{
   if(!newBar) return;
   if(gStartEquity>0.0 && AccountInfoDouble(ACCOUNT_EQUITY)<gStartEquity*TESTER_EQ_FLOOR)
   {
      if(!gFloorSaid){ gFloorSaid=true; Print("[CC] tester strategy halted: equity below ",DoubleToString(TESTER_EQ_FLOOR*100.0,0),"% of start"); }
      return;
   }
   double f[2],s[2],a[1];             // static arrays: index 0 = older bar
   if(CopyBuffer(hFast,0,1,2,f)<2) return;
   if(CopyBuffer(hSlow,0,1,2,s)<2) return;
   if(CopyBuffer(hAtr ,0,1,1,a)<1) return;
   bool up=(f[0]<=s[0] && f[1]>s[1]),dn=(f[0]>=s[0] && f[1]<s[1]);
   if(!up && !dn) return;

   bool haveBuy=false,haveSell=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) haveBuy=true; else haveSell=true;
   }
   if(up && haveBuy) return;
   if(dn && haveSell) return;
   if(haveBuy || haveSell) AutoCloseAll();

   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ref=up?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(ref<=0.0 || pt<=0.0) return;
   double spread=SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(spread<0.0) spread=0.0;
   double slDist=a[0]*MathMax(0.2,InpAutoAtrSL);
   double floorDist=MathMax(MinStopDist(),MathMax(5.0*spread,10.0*pt));
   if(slDist<floorDist) slDist=floorDist;
   if(slDist<=0.0) return;

   double sl=NormalizeDouble(up?ref-slDist:ref+slDist,_Digits);
   double tp=NormalizeDouble(up?ref+slDist*gRR:ref-slDist*gRR,_Digits);
   ENUM_ORDER_TYPE type=up?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double rm=0;
   double lot=LotByRisk(type,ref,sl,rm);
   lot=CapLotToMargin(type,lot,ref);
   if(lot<=0.0) return;
   if(!SendOrder(up,false,lot,0.0,sl,tp))
      Print("[CC] auto order rejected ",m_trade.ResultRetcode(),": ",m_trade.ResultRetcodeDescription(),
            " lot=",DoubleToString(lot,VolDigits())," sl=",DoubleToString(sl,_Digits)," tp=",DoubleToString(tp,_Digits));
}

void AutoCloseAll()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic) continue;
      m_trade.PositionClose(tk);
   }
}

double CapLotToMargin(ENUM_ORDER_TYPE type,double lot,double price)
{
   double need=0;
   if(!OrderCalcMargin(type,_Symbol,lot,price,need) || need<=0.0) return(lot);
   double cap=AccountInfoDouble(ACCOUNT_MARGIN_FREE)*MAX_MARGIN_PCT/100.0;
   if(need<=cap) return(lot);
   double scaled=NormVol(lot*cap/need),mn=MinLot();
   if(scaled<mn) scaled=mn;
   if(OrderCalcMargin(type,_Symbol,scaled,price,need) && need>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) return(0.0);
   return(scaled);
}
//+------------------------------------------------------------------+
