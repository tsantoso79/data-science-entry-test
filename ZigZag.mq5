//------------------------------------------------------------------
//|                                                       ZigZag.mq5 |
//|                   Copyright 2006-2014, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//------------------------------------------------------------------
#property copyright "2006-2014, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property strict

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4
// plot(0) -> zzC (red), plots 1 & 2 hidden (calc), plot(3) -> zzA (yellow)
#property indicator_type1   DRAW_SECTION
#property indicator_color1  Red
#property indicator_type2   DRAW_NONE
#property indicator_type3   DRAW_NONE
#property indicator_type4   DRAW_SECTION
#property indicator_color4  Yellow

//---- inputs
input int  Depth_input      = 90;
input int  LK_Back_inHours  = 12;
input bool display          = false;

/*============================= Buffers =============================*/
double zzC[];   // plot 0
double zzH[];   // calc
double zzL[];   // calc
double zzA[];   // plot 3

/*============================ Structures ===========================*/
struct RatioMetrics
  {
   double displacement;
   double sum_piecewise;
   double dn_ratio;
   double dn_ratio2;
   double dn_ratio4;
   double dn_ratio8;
   double dn_ratioZ;
   double dd_ratio;

   double updwn_2hr_ratio;
   double updwn_4hr_ratio;
   double updwn_8hr_ratio;
   double updwn_24hr_ratio;
   double zza_ratio;

   double first_segment;
   double first_segment_zza;

   void Reset()
     {
      displacement      = 0.0;
      sum_piecewise     = 0.0;
      dn_ratio          = 0.0;
      dn_ratio2         = 0.0;
      dn_ratio4         = 0.0;
      dn_ratio8         = 0.0;
      dn_ratioZ         = 0.0;
      dd_ratio          = 0.0;
      updwn_2hr_ratio   = 0.0;
      updwn_4hr_ratio   = 0.0;
      updwn_8hr_ratio   = 0.0;
      updwn_24hr_ratio  = 0.0;
      zza_ratio         = 0.0;
      first_segment     = 0.0;
      first_segment_zza = 0.0;
     }
  };

RatioMetrics metrics;

/*============================= Vars ================================*/
int    N_Buffer = 0;

int    First_N, Second_N, Max_N;
double depth, Depth_Pts;
int    last, direction;
int    shift = 0;
int    num_peak = 0, num_valley = 0;
int    max_Hist_bars;
int    bar_limit = 5 * 24 * 60;

int    NUM_LVLs = 10;
double H_peak[10], L_valley[10];
double curr_Peak, curr_Valley;
datetime HP_Time[10], LV_Time[10];
double Peak2_C[10], Valley2_C[10];

int    den2, den4, den8, den24;

/*============================= TF helpers ==========================*/
struct TimeframeCache
  {
   int bars_in_hour;
   int H24bars;
   int D3bars;
   int H16bars;
   int H8bars;
   int H4bars;
   int H3bars;
   int H2bars;
   int H1bars;
   ENUM_TIMEFRAMES cachedPeriod;

   void Reset()
     {
      bars_in_hour = 0;
      H24bars = D3bars = H16bars = H8bars = H4bars = H3bars = H2bars = H1bars = 0;
      cachedPeriod = PERIOD_CURRENT;
     }
  };

TimeframeCache tf_cache;

/*========================= Utility Helpers ========================*/
bool IsBufferEmpty(const double value)
  {
   return value <= _Point;
  }

class CalculationGuard
  {
private:
   bool *m_flag;
public:
   explicit CalculationGuard(bool &flag)
     {
      m_flag = &flag;
      *m_flag = true;
     }
   ~CalculationGuard()
     {
      if(m_flag)
         *m_flag = false;
     }
  };

bool g_isCalculating = false;

int MinuteOf(datetime t)
  {
   MqlDateTime ts;
   TimeToStruct(t, ts);
   return ts.min;
  }

void UpdateTFDerived()
  {
   ENUM_TIMEFRAMES currentPeriod = (ENUM_TIMEFRAMES)_Period;
   if(tf_cache.bars_in_hour != 0 && tf_cache.cachedPeriod == currentPeriod)
      return;

   int sec = (int)PeriodSeconds(currentPeriod);
   if(sec <= 0)
      sec = (int)PeriodSeconds(PERIOD_CURRENT);

   tf_cache.bars_in_hour = (sec>0) ? (3600/sec) : 0;
   if(tf_cache.bars_in_hour < 1)
      tf_cache.bars_in_hour = 1;

   tf_cache.H1bars  = (tf_cache.bars_in_hour * 1);
   tf_cache.H2bars  = (tf_cache.bars_in_hour * 2);
   tf_cache.H3bars  = (tf_cache.bars_in_hour * 3);
   tf_cache.H4bars  = (tf_cache.bars_in_hour * 4);
   tf_cache.H8bars  = (tf_cache.bars_in_hour * 8);
   tf_cache.H16bars = (tf_cache.bars_in_hour * 16);
   tf_cache.H24bars = (tf_cache.bars_in_hour * 24);
   tf_cache.D3bars  = (tf_cache.bars_in_hour * 24 * 3);
   tf_cache.cachedPeriod = currentPeriod;
  }

void DrawGuideLine(const datetime &time[], int bars, const string &label)
  {
   if(bars <= 0)
      return;

   if(bars < Bars(_Symbol, _Period))
      VerticalLine(time[MathMin(bars, Bars(_Symbol, _Period))-1], label, Aqua, STYLE_DASH, 1);
  }

/*============================= Init ================================*/
int OnInit()
  {
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   string short_name = StringFormat("ZigZag(%d,%s,%s)", Depth_input, "", "");
   IndicatorSetString(INDICATOR_SHORTNAME, short_name);

   SetIndexBuffer(0, zzC, INDICATOR_DATA);
   SetIndexBuffer(1, zzH, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, zzL, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, zzA, INDICATOR_DATA);

   ArraySetAsSeries(zzC, true);
   ArraySetAsSeries(zzH, true);
   ArraySetAsSeries(zzL, true);
   ArraySetAsSeries(zzA, true);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_SECTION);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_SECTION);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 1);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 1);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   ArrayInitialize(zzC, 0.0);
   ArrayInitialize(zzH, 0.0);
   ArrayInitialize(zzL, 0.0);
   ArrayInitialize(zzA, 0.0);

   depth      = Depth_input * _Point;
   Depth_Pts  = Depth_input;
   direction  = 1;

   tf_cache.Reset();
   UpdateTFDerived();

   Print("Initialize Depth ", DoubleToString(Depth_input, 0));
   return(INIT_SUCCEEDED);
  }

/*======================== Globals for calc =========================*/
int starti;
int first_last;
int i;
int prev_calculated_print;
int prev_min = -1;

/*===================== fwd declarations (protos) ===================*/
void ProcessRange(int start_index, int end_index, const double &open[], const double &high[], const double &low[], const double &close[]);

void Assign_zzC(int rates_total);
void Assign_zzA(int rates_total);
int  last_ZZC_dex(int cur, int total_rates);
int  last_ZZHL_dex(int cur, int total_rates);
int  past_ZZHL_dex(int cur, int total_rates, int dir, int ref);
int  fwd_ZZHL_dex(int cur, int dir);

void calc_variables(int rates_total,
                    const datetime &time[], const double &open[], const double &high[],
                    const double &low[], const double &close[]);

void setGlobal_Var();
void DisplayComment(int rates_total,
                    const datetime &time[], const double &open[], const double &high[],
                    const double &low[], const double &close[]);

void HorizontalLine(double price, string name, color c, int style, int thickness);
void VerticalLine(datetime when, string name, color c, int style, int thickness);
void TextBox_Num(string name, double value, int corner, int x, int y, color txt_color, int fontsize);

/*============================ Calculate ============================*/
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 100)
      return 0;

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   UpdateTFDerived();

   if(g_isCalculating)
     {
      Print("ABORT: Already calculating. Tick Count at ", GetTickCount());
      return prev_calculated;
     }

   CalculationGuard guard(g_isCalculating);

   prev_calculated_print = prev_calculated;

   if(prev_calculated == 0)
     {
      last = first_last = rates_total-1;
      i    = starti     = rates_total-1;
      ProcessRange(i, 0, open, high, low, close);
     }
   else
     {
      last = first_last = last + (rates_total - prev_calculated);
      i    = starti     = rates_total - prev_calculated;
      ProcessRange(i, 0, open, high, low, close);
     }

   Assign_zzC(rates_total);
   Assign_zzA(rates_total);
   calc_variables(rates_total, time, open, high, low, close);
   setGlobal_Var();

   if(display)
      DisplayComment(rates_total, time, open, high, low, close);

   DrawGuideLine(time, tf_cache.H1bars,  "1hour");
   DrawGuideLine(time, tf_cache.H2bars,  "2hour");
   DrawGuideLine(time, tf_cache.H3bars,  "3hour");
   DrawGuideLine(time, tf_cache.H4bars,  "4hour");
   DrawGuideLine(time, tf_cache.H8bars,  "8hour");
   DrawGuideLine(time, tf_cache.H16bars, "16hour");
   DrawGuideLine(time, tf_cache.H24bars, "24hour");

   prev_min = MinuteOf(TimeCurrent());
   return(rates_total);
  }

/*=========================== ProcessRange ==========================*/
void ResetZZValues(const int index)
  {
   if(IsBufferEmpty(zzL[index]))
      zzL[index] = 0.0;
   if(IsBufferEmpty(zzH[index]))
      zzH[index] = 0.0;
  }

void HandleBullishMove(const int index, const double &open[], const double &high[], const double &low[], const double &close[], bool &setFlag)
  {
   if(high[index] > zzH[last])
     {
      if(IsBufferEmpty(zzL[last]))
         zzH[last] = 0.0;
      zzH[index] = high[index];

      if(low[index] < high[last] - depth)
        {
         if(open[index] < close[index])
           {
            zzH[last] = high[last];
            if(last != index)
               zzL[index] = low[index];
           }
         else
           {
            direction = -1;
            zzL[index] = low[index];
           }
        }
      last = index;
      setFlag = true;
     }

   if(low[index] < zzH[last] - depth && (!setFlag || open[index] > close[index]))
     {
      zzL[index] = low[index];
      if(high[index] > zzL[index] + depth && open[index] < close[index])
         zzH[index] = high[index];
      else
         direction = -1;
      last = index;
     }
  }

void HandleBearishMove(const int index, const double &open[], const double &high[], const double &low[], const double &close[], bool &setFlag)
  {
   if(low[index] < zzL[last])
     {
      if(IsBufferEmpty(zzH[last]))
         zzL[last] = 0.0;
      zzL[index] = low[index];

      if(high[index] > low[last] + depth)
        {
         if(open[index] > close[index])
           {
            zzL[last] = low[last];
            if(last != index)
               zzH[index] = high[index];
           }
         else
           {
            direction = 1;
            zzH[index] = high[index];
           }
        }
      last = index;
      setFlag = true;
     }

   if(high[index] > zzL[last] + depth && (!setFlag || open[index] < close[index]))
     {
      zzH[index] = high[index];
      if(low[index] < zzH[index] - depth && open[index] > close[index])
         zzL[index] = low[index];
      else
         direction = 1;
      last = index;
     }
  }

void ProcessRange(int start_index, int end_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int index = start_index; index >= end_index; index--)
     {
      bool set=false;
      ResetZZValues(index);

      if(direction > 0)
         HandleBullishMove(index, open, high, low, close, set);
      else
         HandleBearishMove(index, open, high, low, close, set);
     }
  }

/*=============================== InitVar ===========================*/
void InitVar()
  {
   ArrayInitialize(H_peak, 0);
   ArrayInitialize(L_valley, 0);
   ArrayInitialize(HP_Time, 0);
   ArrayInitialize(LV_Time, 0);
   ArrayInitialize(Peak2_C, 0);
   ArrayInitialize(Valley2_C, 0);
  }

/*============================== Assign_zzC =========================*/
void Assign_zzC(int rates_total)
  {
   int cur = MathMax(first_last, starti);

   for(cur=cur; cur>=0; cur--)
     {
      int past    = last_ZZC_dex(cur, rates_total);
      int past_HL = last_ZZHL_dex(cur, rates_total);

      if(zzH[cur] > _Point && zzL[cur] > _Point)
        {
         if(NormalizeDouble(zzC[past] - zzH[past], _Digits) == 0.0)
           {
            if(zzH[cur] > zzC[past] && past == past_HL)
              {
               zzC[past] = 0.0;
               zzC[cur] = zzH[cur];
               zzA[past]=0.0;
              }
            else
              {
               zzC[cur] = zzL[cur];
              }
           }
         else
            if(NormalizeDouble(zzC[past] - zzL[past], _Digits) == 0.0)
              {
               if(zzL[cur] < zzC[past] && past == past_HL)
                 {
                  zzC[past] = 0.0;
                  zzC[cur] = zzL[cur];
                  zzA[past]=0.0;
                 }
               else
                 {
                  zzC[cur] = zzH[cur];
                 }
              }
            else
              {
               Print("PAST is not zzl or zzh cur=",cur," past=",past);
               zzC[cur]=0.0;
              }
        }
      else
        {
         if(zzH[cur] > _Point)
           {
            if(NormalizeDouble(zzC[past] - zzL[past], _Digits) == 0.0)
               zzC[cur] = zzH[cur];
            else
               if(zzH[cur] > zzH[past] && NormalizeDouble(zzC[past] - zzH[past], _Digits) == 0.0 && past == past_HL)
                 { zzC[past]=0.0; zzC[cur]=zzH[cur]; zzA[past]=0.0; }
               else
                  zzC[cur]=0.0;
           }
         else
            if(zzL[cur] > _Point)
              {
               if(NormalizeDouble(zzC[past] - zzH[past], _Digits) == 0.0)
                  zzC[cur] = zzL[cur];
               else
                  if(zzL[cur] < zzL[past] && NormalizeDouble(zzC[past] - zzL[past], _Digits) == 0.0 && past == past_HL)
                    { zzC[past]=0.0; zzC[cur]=zzL[cur]; zzA[past]=0.0; }
                  else
                     zzC[cur]=0.0;
              }
            else
               zzC[cur]=0.0;
        }
     }
  }

/*============================== Assign_zzA =========================*/
void Assign_zzA(int rates_total)
  {
   int cur = MathMax(first_last, starti);

   for(cur=cur; cur>=0; cur--)
     {
      zzA[cur] = zzC[cur];

      if(zzA[cur] > _Point && cur != 0)
        {
         if(NormalizeDouble(zzC[cur] - zzH[cur], _Digits) == 0.0)
           {
            int pastL  = past_ZZHL_dex(cur, rates_total, -1, 1);
            int pastL2 = past_ZZHL_dex(cur, rates_total, -1, 2);
            int pastH  = past_ZZHL_dex(cur, rates_total, 1, 1);

            if(zzC[cur] > zzC[pastH] && zzC[pastL] > zzC[pastL2])
              { zzA[pastH]=0.0; zzA[pastL]=0.0; }
           }
         else
            if(NormalizeDouble(zzC[cur] - zzL[cur], _Digits) == 0.0)
              {
               int pastH  = past_ZZHL_dex(cur, rates_total, 1, 1);
               int pastH2 = past_ZZHL_dex(cur, rates_total, 1, 2);
               int pastL  = past_ZZHL_dex(cur, rates_total, -1, 1);

               if(zzC[cur] < zzC[pastL] && zzC[pastH] < zzC[pastH2])
                 { zzA[pastH]=0.0; zzA[pastL]=0.0; }
              }
        }
     }
  }

/*=============================== Finders ===========================*/
int last_ZZC_dex(int cur, int total_rates)
  {
   int past = total_rates - 1;
   for(int index = cur+1; index < total_rates; index++)
     { if(zzC[index] > _Point) { past = index; break; } }
   return past;
  }

int last_ZZHL_dex(int cur, int total_rates)
  {
   int past = total_rates - 1;
   for(int index = cur+1; index < total_rates; index++)
     { if(zzH[index] > _Point || zzL[index] > _Point) { past = index; break; } }
   return past;
  }

int past_ZZHL_dex(int cur, int total_rates, int dir, int ref)
  {
   int past = total_rates - 1, counter=0;
   for(int index = cur+1; index < total_rates; index++)
     {
      if(counter >= ref)
         break;
      if(dir==1)
        {
         if(zzH[index] > _Point && NormalizeDouble(zzC[index]-zzH[index], _Digits) == 0.0)
           { past=index; counter++; }
        }
      else
         if(dir==-1)
           {
            if(zzL[index] > _Point && NormalizeDouble(zzC[index]-zzL[index], _Digits) == 0.0)
              { past=index; counter++; }
           }
     }
   return past;
  }

int fwd_ZZHL_dex(int cur, int dir)
  {
   int fut = 0;
   for(int index = cur-1; index >= 0; index--)
     {
      if(dir==1)
        {
         if(zzH[index] > _Point && NormalizeDouble(zzA[index]-zzH[index], _Digits) == 0.0)
           { fut=index; break; }
        }
      else
         if(dir==-1)
           {
            if(zzL[index] > _Point && NormalizeDouble(zzA[index]-zzL[index], _Digits) == 0.0)
              { fut=index; break; }
           }
     }
   return fut;
  }

/*========================== calc_variables =========================*/
void calc_variables(int rates_total,
                    const datetime &time[], const double &open[], const double &high[],
                    const double &low[], const double &close[])
  {
   InitVar();
   metrics.Reset();

   int N_dex = tf_cache.bars_in_hour * LK_Back_inHours;

   shift = 0;
   curr_Peak = 0;
   curr_Valley = 0;
   num_peak = 0;
   num_valley = 0;
   N_Buffer = 0;
   First_N = 0;
   Second_N = 0;
   Max_N = 0;
   den2 = den4 = den8 = den24 = 0;

   int nh=0, nl=0;
   double hpx[3] = {0.0};
   double lpx[3] = {0.0};

   max_Hist_bars = MathMin(rates_total, bar_limit);
   int H_dex = MathMin(max_Hist_bars, tf_cache.bars_in_hour*24);

   metrics.displacement = MathAbs((close[0] - close[H_dex-1])/_Point);
   if(metrics.displacement < 1)
      metrics.displacement = 1;

   double prev_sum_disp2 = 0.0, prev_sum_disp4 = 0.0, prev_sum_disp8 = 0.0, prev_sum_displacement = 0.0;
   double upwrd_sum_4hr = 0.0, dwnwrd_sum_4hr = 0.0, updwn_4hr_ratio = 0.0;
   double upwrd_sum_2hr = 0.0, dwnwrd_sum_2hr = 0.0;
   double upwrd_sum_8hr = 0.0, dwnwrd_sum_8hr = 0.0;
   double upwrd_sum_24hr = 0.0, dwnwrd_sum_24hr = 0.0;
   double prev_Px_Point = 0.0;
   double prev_zza_disp = 0.0;
   double prev_sum_disp24 = 0.0;

   int n_zza = 0;
   double prev_ppt_zza=0.0, dist_zza=0.0, upwrd_zza=0.0, dwnwrd_zza=0.0;

   for(int t=shift; t<max_Hist_bars; t++)
     {
      if(!(num_peak < NUM_LVLs-1 || num_valley < NUM_LVLs-1 || t < N_dex || t < H_dex))
         break;

      curr_Peak   = zzH[t];
      curr_Valley = zzL[t];

      if(t < H_dex)
        {
         if(zzC[t] > _Point)
           {
            N_Buffer++;
            if(prev_Px_Point <= _Point)
               prev_Px_Point = zzC[t];

            double distance = (prev_Px_Point - zzC[t])/_Point;

            if(N_Buffer==2)
               metrics.first_segment = distance;

            if(distance >= 0)
              {
               if(t < tf_cache.H2bars || (N_Buffer <= 3 && t >= tf_cache.H2bars))
                 {
                  upwrd_sum_2hr += distance;
                  den2++;
                 }
               if(t < tf_cache.H4bars || (N_Buffer <= 3 && t >= tf_cache.H4bars))
                 {
                  upwrd_sum_4hr += distance;
                  den4++;
                 }
               if(t < tf_cache.H8bars || (N_Buffer <= 3 && t >= tf_cache.H8bars))
                 {
                  upwrd_sum_8hr += distance;
                  den8++;
                 }
               if(t < H_dex  || (N_Buffer <= 3 && t >= tf_cache.H24bars))
                 {
                  upwrd_sum_24hr += distance;
                  den24++;
                 }
              }
            else
              {
               if(t < tf_cache.H2bars || (N_Buffer <= 3 && t >= tf_cache.H2bars))
                 {
                  dwnwrd_sum_2hr += distance;
                  den2++;
                 }
               if(t < tf_cache.H4bars || (N_Buffer <= 3 && t >= tf_cache.H4bars))
                 {
                  dwnwrd_sum_4hr += distance;
                  den4++;
                 }
               if(t < tf_cache.H8bars || (N_Buffer <= 3 && t >= tf_cache.H8bars))
                 {
                  dwnwrd_sum_8hr += distance;
                  den8++;
                 }
               if(t < H_dex  || (N_Buffer <= 3 && t >= tf_cache.H24bars))
                 {
                  dwnwrd_sum_24hr += distance;
                  den24++;
                 }
              }

            prev_sum_displacement += MathAbs(distance);
            prev_Px_Point = zzC[t];

            if(zzA[t] > _Point)
              {
               n_zza++;
               if(prev_ppt_zza <= _Point)
                  prev_ppt_zza = zzA[t];

               dist_zza = (prev_ppt_zza - zzA[t])/_Point;
               if(n_zza==2)
                  metrics.first_segment_zza = dist_zza;

               if(dist_zza >= 0)
                 { if(t < tf_cache.H16bars || (n_zza <= 3 && t >= tf_cache.H16bars)) upwrd_zza += dist_zza; }
               else
                 { if(t < tf_cache.H16bars || (n_zza <= 3 && t >= tf_cache.H16bars)) dwnwrd_zza += dist_zza; }

               prev_ppt_zza = zzA[t];
              }
           }

         if(t == tf_cache.H2bars - 1 && zzC[t] < _Point && N_Buffer > 2)
           {
            den2++;
            double dist_2hr = (prev_Px_Point - close[t])/_Point;
            if(dist_2hr >= 0)
              {
               dist_2hr = MathMax(dist_2hr, Depth_Pts);
               upwrd_sum_2hr += dist_2hr;
              }
            else
              {
               dist_2hr = MathMin(dist_2hr, -Depth_Pts);
               dwnwrd_sum_2hr += dist_2hr;
              }
           }
         if(t == tf_cache.H4bars - 1 && zzC[t] < _Point && N_Buffer > 2)
           {
            den4++;
            double dist_4hr = (prev_Px_Point - close[t])/_Point;
            if(dist_4hr >= 0)
              {
               dist_4hr = MathMax(dist_4hr, Depth_Pts);
               upwrd_sum_4hr += dist_4hr;
              }
            else
              {
               dist_4hr = MathMin(dist_4hr, -Depth_Pts);
               dwnwrd_sum_4hr += dist_4hr;
              }
           }
         if(t == tf_cache.H8bars - 1 && zzC[t] < _Point && N_Buffer > 2)
           {
            den8++;
            double dist_8hr = (prev_Px_Point - close[t])/_Point;
            if(dist_8hr >= 0)
              {
               dist_8hr = MathMax(dist_8hr, Depth_Pts);
               upwrd_sum_8hr += dist_8hr;
              }
            else
              {
               dist_8hr = MathMin(dist_8hr, -Depth_Pts);
               dwnwrd_sum_8hr += dist_8hr;
              }
           }
         if(t == H_dex - 1 && zzC[t] < _Point && N_Buffer > 2)
           {
            den24++;
            double dist_24hr = (prev_Px_Point - close[t])/_Point;
            if(dist_24hr >= 0)
              {
               dist_24hr = MathMax(dist_24hr, Depth_Pts);
               upwrd_sum_24hr += dist_24hr;
              }
            else
              {
               dist_24hr = MathMin(dist_24hr, -Depth_Pts);
               dwnwrd_sum_24hr += dist_24hr;
              }
           }
         if(t == tf_cache.H16bars - 1 && zzA[t] < _Point)
           {
            n_zza++;
            if(prev_ppt_zza <= _Point)
               prev_ppt_zza = zzA[t];
            dist_zza = (prev_ppt_zza - close[t])/_Point;

            if(dist_zza >= 0)
              {
               dist_zza = MathMax(dist_zza, Depth_Pts);
               upwrd_zza += dist_zza;
              }
            else
              {
               dist_zza = MathMin(dist_zza, -Depth_Pts);
               dwnwrd_zza += dist_zza;
              }
           }
        }

      if(num_peak == 0 && curr_Peak > _Point && curr_Peak > close[0] && H_peak[0] <= _Point)
        { H_peak[0]=curr_Peak; HP_Time[0]=time[t]; Peak2_C[0]=(curr_Peak - close[0])/_Point; }
      else
         if(curr_Peak > _Point && curr_Peak > H_peak[num_peak] && curr_Peak > close[0] && num_peak < NUM_LVLs-1)
           { H_peak[num_peak+1]=curr_Peak; HP_Time[num_peak+1]=time[t]; Peak2_C[num_peak+1]=(curr_Peak-close[0])/_Point; num_peak++; }

      if(num_valley == 0 && curr_Valley > _Point && curr_Valley < close[0] && L_valley[0] <= _Point)
        { L_valley[0]=curr_Valley; LV_Time[0]=time[t]; Valley2_C[0]=(curr_Valley - close[0])/_Point; }
      else
         if(curr_Valley > _Point && curr_Valley < L_valley[num_valley] && curr_Valley < close[0] && num_valley < NUM_LVLs-1)
           { L_valley[num_valley+1]=curr_Valley; LV_Time[num_valley+1]=time[t]; Valley2_C[num_valley+1]=(curr_Valley-close[0])/_Point; num_valley++; }
     }

   prev_sum_disp2 = upwrd_sum_2hr + MathAbs(dwnwrd_sum_2hr);
   prev_sum_disp4 = upwrd_sum_4hr + MathAbs(dwnwrd_sum_4hr);
   prev_sum_disp8 = upwrd_sum_8hr + MathAbs(dwnwrd_sum_8hr);
   prev_zza_disp  = upwrd_zza     + MathAbs(dwnwrd_zza);

   metrics.sum_piecewise  = prev_sum_displacement + (MathAbs(prev_Px_Point - close[H_dex-1])/_Point);

   metrics.dd_ratio  = metrics.displacement / metrics.sum_piecewise;
   metrics.dn_ratio  = metrics.sum_piecewise / MathMax(den24,1);
   metrics.dn_ratio2 = prev_sum_disp2 / MathMax(den2,1);
   metrics.dn_ratio4 = prev_sum_disp4 / MathMax(den4,1);
   metrics.dn_ratio8 = prev_sum_disp8 / MathMax(den8,1);
   metrics.dn_ratioZ = prev_zza_disp  / MathMax(n_zza,1);

   if(upwrd_sum_2hr  < Depth_Pts)
      upwrd_sum_2hr  = Depth_Pts;
   if(dwnwrd_sum_2hr > -Depth_Pts)
      dwnwrd_sum_2hr = -Depth_Pts;
   if(upwrd_sum_4hr  < Depth_Pts)
      upwrd_sum_4hr  = Depth_Pts;
   if(dwnwrd_sum_4hr > -Depth_Pts)
      dwnwrd_sum_4hr = -Depth_Pts;
   if(upwrd_sum_8hr  < Depth_Pts)
      upwrd_sum_8hr  = Depth_Pts;
   if(dwnwrd_sum_8hr > -Depth_Pts)
      dwnwrd_sum_8hr = -Depth_Pts;
   if(upwrd_sum_24hr < Depth_Pts)
      upwrd_sum_24hr = Depth_Pts;
   if(dwnwrd_sum_24hr > -Depth_Pts)
      dwnwrd_sum_24hr = -Depth_Pts;

   metrics.updwn_2hr_ratio  = MathAbs(upwrd_sum_2hr  / dwnwrd_sum_2hr);
   metrics.updwn_4hr_ratio  = MathAbs(upwrd_sum_4hr  / dwnwrd_sum_4hr);
   metrics.updwn_8hr_ratio  = MathAbs(upwrd_sum_8hr  / dwnwrd_sum_8hr);
   metrics.updwn_24hr_ratio = MathAbs(upwrd_sum_24hr / dwnwrd_sum_24hr);

   if(upwrd_zza < Depth_Pts)
      upwrd_zza = Depth_Pts;
   if(dwnwrd_zza > -Depth_Pts)
      dwnwrd_zza = -Depth_Pts;
   metrics.zza_ratio = MathAbs(upwrd_zza / dwnwrd_zza);
  }

/*===================== GV name helper + exporter ===================*/
string GVName(const string tag, const int idx)
  {
   return StringFormat("%s%s%d", Symbol(), tag, idx);
  }

void setGlobal_Var()
  {
   for(int idx=0; idx<NUM_LVLs; idx++)
     {
      if(H_peak[idx] != 0.0)
        {
         GlobalVariableSet(GVName("H_peak",  idx), H_peak[idx]);
         GlobalVariableSet(GVName("HP_Time", idx), (double)HP_Time[idx]);
        }
      else
        {
         if(GlobalVariableCheck(GVName("H_peak",  idx)))
            GlobalVariableDel(GVName("H_peak",  idx));
         if(GlobalVariableCheck(GVName("HP_Time", idx)))
            GlobalVariableDel(GVName("HP_Time", idx));
        }

      if(L_valley[idx] != 0.0)
        {
         GlobalVariableSet(GVName("L_valley", idx), L_valley[idx]);
         GlobalVariableSet(GVName("LV_Time",  idx), (double)LV_Time[idx]);
        }
      else
        {
         if(GlobalVariableCheck(GVName("L_valley", idx)))
            GlobalVariableDel(GVName("L_valley", idx));
         if(GlobalVariableCheck(GVName("LV_Time",  idx)))
            GlobalVariableDel(GVName("LV_Time",  idx));
        }
     }

   GlobalVariableSet(StringFormat("%supdwn_2hr_ratio",  Symbol()), metrics.updwn_2hr_ratio);
   GlobalVariableSet(StringFormat("%supdwn_4hr_ratio",  Symbol()), metrics.updwn_4hr_ratio);
   GlobalVariableSet(StringFormat("%supdwn_8hr_ratio",  Symbol()), metrics.updwn_8hr_ratio);
   GlobalVariableSet(StringFormat("%supdwn_24hr_ratio", Symbol()), metrics.updwn_24hr_ratio);

   GlobalVariableSet(StringFormat("%szza_ratio",        Symbol()), metrics.zza_ratio);

   GlobalVariableSet(StringFormat("%sfirst_segmt",      Symbol()), metrics.first_segment);
   GlobalVariableSet(StringFormat("%sfirst_seg_zza",    Symbol()), metrics.first_segment_zza);

   GlobalVariableSet(StringFormat("%sDD_Ratio",         Symbol()), metrics.dd_ratio);
   GlobalVariableSet(StringFormat("%sDN_Ratio2",        Symbol()), metrics.dn_ratio2);
   GlobalVariableSet(StringFormat("%sDN_Ratio4",        Symbol()), metrics.dn_ratio4);
   GlobalVariableSet(StringFormat("%sDN_Ratio8",        Symbol()), metrics.dn_ratio8);
   GlobalVariableSet(StringFormat("%sDN_Ratio",         Symbol()), metrics.dn_ratio);

   GlobalVariableSet(StringFormat("%sDN_RatioZ",        Symbol()), metrics.dn_ratioZ);
  }

/*============================= Display =============================*/
void DisplayComment(int rates_total,
                    const datetime &time[], const double &open[], const double &high[],
                    const double &low[], const double &close[])
  {
   static datetime lastDisplayTime = 0;
   datetime nowTime = TimeCurrent();
   if(lastDisplayTime != 0 && (nowTime - lastDisplayTime) < 60)
      return;

   lastDisplayTime = nowTime;

   string Dcomment = "\n===================== " + TimeToString(time[0], TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\n";
   Dcomment += StringFormat(
      "       max_Hist_bars : %d       rates_total : %d       prev_calculated : %d       first_last : %d       last : %d       starti : %d       sum_piecewise : %s       displacement : %s       depth : %s       High0 : %s       Low0 : %s       Close0 : %s\n",
      max_Hist_bars,
      rates_total,
      prev_calculated_print,
      first_last,
      last,
      starti,
      DoubleToString(metrics.sum_piecewise, 0),
      DoubleToString(metrics.displacement, 0),
      DoubleToString(depth/_Point, 0),
      DoubleToString(high[0], _Digits),
      DoubleToString(low[0], _Digits),
      DoubleToString(close[0], _Digits)
      );
   Dcomment += StringFormat(
      "       first_segmt : %s       updwn_2hr_ratio : %s       updwn_4hr_ratio : %s       updwn_8hr_ratio : %s       updwn_24hr_ratio : %s       Max_N : %d       N_Buffer : %d       DD_Ratio : %s       DN_Ratio : %s\n",
      DoubleToString(metrics.first_segment, 2),
      DoubleToString(metrics.updwn_2hr_ratio, 2),
      DoubleToString(metrics.updwn_4hr_ratio, 2),
      DoubleToString(metrics.updwn_8hr_ratio, 2),
      DoubleToString(metrics.updwn_24hr_ratio, 2),
      Max_N,
      N_Buffer,
      DoubleToString(metrics.dd_ratio, 2),
      DoubleToString(metrics.dn_ratio, 2)
      );
   Dcomment += "=====================\n";

   for(int c1=0; c1<NUM_LVLs; c1++)
     {
      Dcomment += StringFormat(
         "      H_peak[%d] : %s      Peak2_C[%d] : %s      HP_Time[%d] : %s      L_valley[%d] : %s      Valley2_C[%d] : %s      LV_Time[%d] : %s\n",
         c1,
         DoubleToString(H_peak[c1], _Digits),
         c1,
         DoubleToString(Peak2_C[c1], 0),
         c1,
         TimeToString(HP_Time[c1], TIME_DATE|TIME_MINUTES),
         c1,
         DoubleToString(L_valley[c1], _Digits),
         c1,
         DoubleToString(Valley2_C[c1], 0),
         c1,
         TimeToString(LV_Time[c1], TIME_DATE|TIME_MINUTES)
         );
     }

   Dcomment += "=====================\n";

   for(int c2=0; c2<60*1; c2++)
     {
      if(c2 < rates_total && zzC[c2] > _Point)
        {
         Dcomment += StringFormat(
            "\nTime = %s   Counter : %d   zzH : %s   zzL : %s   zzC : %s   zzA : %s   Close : %s   Gap : %s",
            TimeToString(time[c2], TIME_SECONDS),
            c2,
            DoubleToString(zzH[c2], _Digits),
            DoubleToString(zzL[c2], _Digits),
            DoubleToString(zzC[c2], _Digits),
            DoubleToString(zzA[c2], _Digits),
            DoubleToString(close[c2], _Digits),
            DoubleToString((high[c2]-low[c2])/_Point, 0)
            );
        }
     }
   Dcomment += "\n=====================\n";
   Comment(Dcomment);

   int curMin = MinuteOf(TimeCurrent());
   static int prevtime = -1;
   if(curMin != prevtime)
     {
      Print("2hr ", DoubleToString(metrics.dn_ratio2,2), " ", DoubleToString(metrics.dn_ratio4,2), " ", DoubleToString(metrics.dn_ratio8,2),
            " ", DoubleToString(metrics.updwn_2hr_ratio,2), " ", DoubleToString(metrics.updwn_4hr_ratio,2),
            " ", DoubleToString(metrics.updwn_8hr_ratio,2), " ", DoubleToString(metrics.updwn_24hr_ratio,2),
            " ", DoubleToString(metrics.dn_ratio,2), " ",
            DoubleToString(high[0],5), " ", DoubleToString(low[0],5), " ", DoubleToString(close[0],5));
      prevtime = curMin;
     }

   for(int ch=0; ch<NUM_LVLs; ch++)
     {
      HorizontalLine(H_peak[ch], "P"+IntegerToString(ch), Aqua, STYLE_DASH, 1);
      HorizontalLine(L_valley[ch], "V"+IntegerToString(ch), Yellow, STYLE_DASH, 1);
     }

   TextBox_Num("DN_RatioZ", NormalizeDouble(metrics.dn_ratioZ,2), 3, 300,125,  Pink,      20);
   TextBox_Num("DN_Ratio2", NormalizeDouble(metrics.dn_ratio2,2), 3, 300,100,  Aqua,      20);
   TextBox_Num("DN_Ratio4", NormalizeDouble(metrics.dn_ratio4,2), 3, 300, 75,  Aqua,      20);
   TextBox_Num("DN_Ratio8", NormalizeDouble(metrics.dn_ratio8,2), 3, 300, 50,  Yellow,    20);
   TextBox_Num("DN_Ratio",  NormalizeDouble(metrics.dn_ratio, 2), 3, 300, 25,  LimeGreen, 20);

   TextBox_Num("zza_ratio", NormalizeDouble(metrics.zza_ratio,2), 3, 200,125,  Pink,      20);
   TextBox_Num("2hr Ratio", NormalizeDouble(metrics.updwn_2hr_ratio,2), 3, 200,100, Aqua, 20);
   TextBox_Num("4hr Ratio", NormalizeDouble(metrics.updwn_4hr_ratio,2), 3, 200, 75, Aqua, 20);
   TextBox_Num("8hr Ratio", NormalizeDouble(metrics.updwn_8hr_ratio,2), 3, 200, 50, Yellow,20);
   TextBox_Num("24hr Ratio",NormalizeDouble(metrics.updwn_24hr_ratio,2),3, 200, 25, LimeGreen,20);

   TextBox_Num("first_seg_zza", NormalizeDouble(metrics.first_segment_zza,0), 3, 0, 125, Pink, 20);
   TextBox_Num("first_segmt",   NormalizeDouble(metrics.first_segment,  0), 3, 0, 100, Aqua, 20);
  }

/*=========================== Objects helpers =======================*/
void HorizontalLine(double price, string name, color c, int style, int thickness)
  {
   if(price <= 0.0)
      return;

   if(ObjectFind(0, name) == -1)
     {
      if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
        {
         Print("Failed to create horizontal line ", name, " error ", GetLastError());
         ResetLastError();
         return;
        }
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, thickness);
     }
   else
     {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
     }
  }

void VerticalLine(datetime when, string name, color c, int style, int thickness)
  {
   if(ObjectFind(0, name) == -1)
     {
      if(!ObjectCreate(0, name, OBJ_VLINE, 0, when, 0.0))
        {
         Print("Failed to create vertical line ", name, " error ", GetLastError());
         ResetLastError();
         return;
        }
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, thickness);
     }
   else
     {
      ObjectSetInteger(0, name, OBJPROP_TIME, (long)when);
     }
  }

void TextBox_Num(string name, double value, int corner, int x, int y, color txt_color, int fontsize)
  {
   if(ObjectFind(0, name) == -1)
     {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
        {
         Print("Failed to create label ", name, " error ", GetLastError());
         ResetLastError();
         return;
        }
     }

   ObjectSetString(0, name, OBJPROP_TEXT, DoubleToString(value, 2));
   ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt_color);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
  }

/*============================ Cleanup ==============================*/
void FreeAll()
  {
   if(ArrayIsDynamic(zzC))
      ArrayFree(zzC);
   if(ArrayIsDynamic(zzH))
      ArrayFree(zzH);
   if(ArrayIsDynamic(zzL))
      ArrayFree(zzL);
   if(ArrayIsDynamic(zzA))
      ArrayFree(zzA);
  }

void OnDeinit(const int reason)
  {
   FreeAll();
  }

/*======================== Highest / Lowest helpers =================*/
double Highest(const double& array[], int count, int start)
  {
   double res=array[start];
   for(int k=start-1; k>start-count && k>=0; k--)
      if(res < array[k])
         res=array[k];
   return res;
  }

double Lowest(const double& array[], int count, int start)
  {
   double res=array[start];
   for(int k=start-1; k>start-count && k>=0; k--)
      if(res > array[k])
         res=array[k];
   return res;
  }
//------------------------------------------------------------------
